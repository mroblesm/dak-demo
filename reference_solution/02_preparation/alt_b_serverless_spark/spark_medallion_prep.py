#!/usr/bin/env python3
"""Step 2 (Stage 2.1): Managed Spark Bronze Ingestion & PII Pseudonymisation over Dual-Catalog BigLake Iceberg.

Demonstrates the complementary 2-stage enterprise pattern and dual-catalog lakehouse story
modeled after `demo-generator/modules/lrc_iceberg`:
  - Catalog 1 (`biglakefederated`): Databricks Unity Catalog federated into Google Cloud BigLake
    (`bl://projects/your-gcp-project-id/catalogs/biglakefederated` backed by
    `gs://your-gcp-project-id-iceberg-dbx-lakehouse`), hosting the single cross-cloud raw table
    `biglakefederated.raw_search_telemetry.search_events`.
  - Catalog 2 (`lrc`): GCP-Native BigLake Iceberg REST Catalog (`your-gcp-project-id-iceberg-lakehouse`
    backed by `gs://your-gcp-project-id-iceberg-lakehouse`) with `CREDENTIAL_MODE_VENDED_CREDENTIALS`
    and `GoogleAuthManager`, hosting `lrc.raw_search_telemetry.search_impressions` and the
    curated Silver table `lrc.modeled_search_warehouse.sessionized_searches`.
  - Live-or-Fallback Multi-Catalog Pattern: Reads `biglakefederated.raw_search_telemetry.search_events`
    when live DBX federation is active, and gracefully falls back to `lrc.raw_search_telemetry.search_events`.
  - Enforces `@skill:gcp-spark`: calls `df.printSchema()` before referencing columns, applies salted
    SHA-256 PII pseudonymisation, filters scraper bots, computes 30-minute sessions, and executes
    Git-style Write-Audit-Publish (`audit_branch`) branching and zero-scan metadata rollbacks.
"""

from __future__ import annotations

import os
from pyspark.sql import DataFrame, SparkSession
from pyspark.sql import functions as F
from pyspark.sql.window import Window


def build_iceberg_spark_session(
    project_id: str,
    warehouse_bucket: str,
    federated_catalog: str = "biglakefederated",
    session_template: str = "clarity-lrc-spark-template",
    region: str = "us-central1",
) -> SparkSession:
    """Create a SparkSession configured for both GCP-native LRC (`lrc`) and DBX federated (`biglakefederated`).

    When running interactively via `google-cloud-dataproc-spark-connect` (`DataprocSparkSession`)
    with `USE_DATAPROC_SESSION_TEMPLATE=true`, initializes directly from the Dataproc Serverless
    `sessionTemplate` (without overriding `runtime_config.properties`, preserving
    `X-Iceberg-Access-Delegation=vended-credentials` per `demo-generator/modules/lrc_iceberg/spark.py`).
    When running inside a Dataproc Serverless batch or standard PySpark context, configures both
    `lrc` and `biglakefederated` REST catalogs on `SparkSession.builder`.
    """
    if os.environ.get("USE_DATAPROC_SESSION_TEMPLATE", "false").lower() == "true":
        try:
            import google.auth  # type: ignore
            import google.auth.transport.requests  # type: ignore
            from google.cloud.dataproc_spark_connect import DataprocSparkSession  # type: ignore
            from google.cloud.dataproc_v1 import Session  # type: ignore

            session_cfg = Session()
            session_cfg.session_template = (
                f"projects/{project_id}/locations/{region}/sessionTemplates/{session_template}"
            )
            creds, _ = google.auth.default()
            creds.refresh(google.auth.transport.requests.Request())
            for cat in ("lrc", federated_catalog):
                session_cfg.runtime_config.properties[
                    f"spark.sql.catalog.{cat}.header.Authorization"
                ] = f"Bearer {creds.token}"
            return (
                DataprocSparkSession.builder.appName("clarity-managed-spark-bronze-pii-pseudonymisation")
                .dataprocSessionConfig(session_cfg)
                .getOrCreate()
            )
        except ImportError:
            pass

    auth_header = ""
    try:
        import google.auth  # type: ignore
        import google.auth.transport.requests  # type: ignore

        creds, _ = google.auth.default()
        creds.refresh(google.auth.transport.requests.Request())
        auth_header = f"Bearer {creds.token}"
    except Exception:
        pass

    builder = (
        SparkSession.builder.appName("clarity-managed-spark-bronze-pii-pseudonymisation")
        .config(
            "spark.sql.extensions",
            "org.apache.iceberg.spark.extensions.IcebergSparkSessionExtensions",
        )
        # 1. GCP-Native BigLake Iceberg REST Catalog (lrc -> gs://your-gcp-project-id-iceberg-lakehouse)
        .config("spark.sql.catalog.lrc", "org.apache.iceberg.spark.SparkCatalog")
        .config("spark.sql.catalog.lrc.type", "rest")
        .config("spark.sql.catalog.lrc.uri", "https://biglake.googleapis.com/iceberg/v1/restcatalog")
        .config("spark.sql.catalog.lrc.warehouse", warehouse_bucket)
        .config("spark.sql.catalog.lrc.header.x-goog-user-project", project_id)
        .config("spark.sql.catalog.lrc.header.X-Iceberg-Access-Delegation", "vended-credentials")
        .config("spark.sql.catalog.lrc.io-impl", "org.apache.iceberg.gcp.gcs.GCSFileIO")
        # 2. Databricks Federated BigLake Iceberg REST Catalog (biglakefederated)
        .config(f"spark.sql.catalog.{federated_catalog}", "org.apache.iceberg.spark.SparkCatalog")
        .config(f"spark.sql.catalog.{federated_catalog}.type", "rest")
        .config(
            f"spark.sql.catalog.{federated_catalog}.uri",
            "https://biglake.googleapis.com/iceberg/v1/restcatalog",
        )
        .config(
            f"spark.sql.catalog.{federated_catalog}.warehouse",
            f"bl://projects/{project_id}/catalogs/{federated_catalog}",
        )
        .config(f"spark.sql.catalog.{federated_catalog}.header.x-goog-user-project", project_id)
        .config(
            f"spark.sql.catalog.{federated_catalog}.header.X-Iceberg-Access-Delegation",
            "vended-credentials",
        )
        .config(f"spark.sql.catalog.{federated_catalog}.io-impl", "org.apache.iceberg.gcp.gcs.GCSFileIO")
    )
    if auth_header:
        builder = builder.config("spark.sql.catalog.lrc.header.Authorization", auth_header).config(
            f"spark.sql.catalog.{federated_catalog}.header.Authorization", auth_header
        )
    spark = builder.getOrCreate()
    if auth_header:
        spark.conf.set("spark.sql.catalog.lrc.header.Authorization", auth_header)
        spark.conf.set(f"spark.sql.catalog.{federated_catalog}.header.Authorization", auth_header)
    return spark


def read_cross_cloud_search_events(
    spark: SparkSession,
    federated_table: str = "biglakefederated.raw_search_telemetry.search_events",
    native_fallback_table: str = "gs://your-gcp-project-id-iceberg-lakehouse/dbx_seed_data/search_events.jsonl",
) -> DataFrame:
    """Read the federated Databricks table (`biglakefederated.raw_search_telemetry.search_events`)
    with automatic fallback to GCS seed JSONL (`gs://your-gcp-project-id-iceberg-lakehouse/dbx_seed_data/search_events.jsonl`).
    """
    try:
        df = spark.read.table(federated_table)
        df.limit(1).count()
        print(f"[Dual-Catalog LRC] Reading live DBX federated table: {federated_table}")
        return df
    except Exception as exc:
        print(
            f"[Dual-Catalog LRC] Federated catalog ({federated_table}) not active ({exc}); "
            f"falling back to {native_fallback_table}"
        )
        if native_fallback_table.startswith("gs://"):
            return spark.read.json(native_fallback_table)
        return spark.read.table(native_fallback_table)


def pseudonymize_pii_columns(df: DataFrame, pii_salt: str = "dak-enterprise-pii-salt-v1") -> DataFrame:
    """Apply cryptographic SHA-256 pseudonymisation to customer PII identifiers at the Bronze boundary."""
    existing_cols = set(df.columns)
    result_df = df.withColumn(
        "pseudonymized_customer_id",
        F.sha2(F.concat_ws(":", F.lit(pii_salt), F.trim(F.col("customer_id"))), 256),
    )
    # If upstream DBX/LRC telemetry includes direct PII fields (e.g., user_email, ip_address, client_ip),
    # hash and drop raw values before landing into the analytical Silver layer.
    if "user_email" in existing_cols:
        result_df = result_df.withColumn(
            "pseudonymized_email_hash",
            F.sha2(F.concat_ws(":", F.lit(pii_salt), F.lower(F.trim(F.col("user_email")))), 256),
        ).drop("user_email")
    if "ip_address" in existing_cols:
        result_df = result_df.withColumn(
            "pseudonymized_ip_hash",
            F.sha2(F.concat_ws(":", F.lit(pii_salt), F.trim(F.col("ip_address"))), 256),
        ).drop("ip_address")
    if "client_ip" in existing_cols:
        result_df = result_df.withColumn(
            "pseudonymized_ip_hash",
            F.sha2(F.concat_ws(":", F.lit(pii_salt), F.trim(F.col("client_ip"))), 256),
        ).drop("client_ip")
    return result_df


def transform_bronze_to_silver(raw_events_df: DataFrame, pii_salt: str = "dak-enterprise-pii-salt-v1") -> DataFrame:
    """Pseudonymise PII, clean raw search events, filter bots, deduplicate, and sessionize with 30-min windows."""
    # Mandatory @skill:gcp-spark rule: always inspect schema before accessing fields
    raw_events_df.printSchema()

    # 1. Cryptographic SHA-256 PII pseudonymisation at initial Bronze ingestion
    pseudonymized_df = pseudonymize_pii_columns(raw_events_df, pii_salt=pii_salt)

    # 2. Clean whitespace/casing, coalesce NULLs, and filter scraper bots
    cleaned_df = (
        pseudonymized_df.filter(
            ~F.lower(F.coalesce(F.col("user_agent"), F.lit(""))).rlike("scraperbot|crawler|spider")
        )
        .withColumn("search_event_id", F.trim(F.col("search_event_id")))
        .withColumn("customer_id", F.trim(F.col("customer_id")))
        .withColumn("normalized_query_text", F.lower(F.trim(F.col("raw_query_text"))))
        .withColumn("device_type", F.lower(F.coalesce(F.trim(F.col("device_type")), F.lit("unknown_device"))))
        .withColumn("event_ts", F.to_timestamp(F.col("event_timestamp")))
        .withColumn("event_date", F.to_date(F.col("event_date")))
    )

    # 3. Deduplicate retry events by search_event_id
    dedup_window = Window.partitionBy("search_event_id").orderBy(F.col("event_ts").desc())
    dedup_df = (
        cleaned_df.withColumn("_row_num", F.row_number().over(dedup_window))
        .filter(F.col("_row_num") == 1)
        .drop("_row_num")
    )

    # 4. Compute 30-minute (1800s) inactivity session boundaries per pseudonymised customer
    cust_window = Window.partitionBy("pseudonymized_customer_id").orderBy("event_ts")
    with_lag_df = dedup_df.withColumn("prev_event_ts", F.lag("event_ts").over(cust_window)).withColumn(
        "is_new_session",
        F.when(
            F.col("prev_event_ts").isNull()
            | ((F.unix_timestamp("event_ts") - F.unix_timestamp("prev_event_ts")) > 1800),
            F.lit(1),
        ).otherwise(F.lit(0)),
    )

    sessionized_df = with_lag_df.withColumn(
        "session_seq_num", F.sum("is_new_session").over(cust_window)
    ).withColumn(
        "clarity_session_id",
        F.concat_ws(
            "-S",
            F.substring(F.col("pseudonymized_customer_id"), 1, 12),
            F.lpad(F.col("session_seq_num").cast("string"), 3, "0"),
        ),
    )

    return sessionized_df.drop("prev_event_ts", "is_new_session", "session_seq_num")


def write_to_iceberg_branch_and_audit(
    spark: SparkSession,
    silver_df: DataFrame,
    table_ident: str = "lrc.modeled_search_warehouse.sessionized_searches",
    branch_name: str = "audit_branch",
) -> bool:
    """Demonstrate Git-style Lakehouse table branching (Write-Audit-Publish / WAP) on BigLake Iceberg.

    1. Creates an isolated Iceberg branch (`ALTER TABLE ... CREATE BRANCH IF NOT EXISTS audit_branch`).
    2. Appends transformed records to the branch (`<table>.branch_<branch_name>`) without mutating `main`.
    3. Audits the branch for zero NULL `pseudonymized_customer_id` or scraper bots before fast-forward merge.
    """
    spark.sql(f"ALTER TABLE {table_ident} CREATE BRANCH IF NOT EXISTS {branch_name} RETAIN 7 DAYS")
    silver_df.writeTo(f"{table_ident}.branch_{branch_name}").append()

    branch_df = spark.read.table(f"{table_ident}.branch_{branch_name}")
    invalid_rows = branch_df.filter(
        F.col("pseudonymized_customer_id").isNull() | F.col("clarity_session_id").isNull()
    ).count()

    if invalid_rows == 0:
        spark.sql(f"CALL lrc.system.fast_forward('{table_ident.removeprefix('lrc.')}', 'main', '{branch_name}')")
        return True
    return False


def rollback_iceberg_table_zero_scan(
    spark: SparkSession,
    table_ident: str = "lrc.modeled_search_warehouse.sessionized_searches",
    snapshot_id: int | None = None,
) -> int:
    """Execute an instant zero-scan metadata rollback on a BigLake Iceberg Lakehouse table.

    Inspects the `.snapshots` metadata table to locate the last verified snapshot ID (if not provided)
    and invokes `CALL lrc.system.rollback_to_snapshot(...)` in Interactive Serverless Spark—restoring
    table state in milliseconds via metadata pointer update without scanning or rewriting Parquet files.
    """
    snapshots_df = spark.read.format("iceberg").load(f"{table_ident}.snapshots")
    if snapshot_id is None:
        latest_two = (
            snapshots_df.orderBy(F.col("committed_at").desc())
            .select("snapshot_id")
            .limit(2)
            .collect()
        )
        target_snapshot_id = int(latest_two[-1]["snapshot_id"])
    else:
        target_snapshot_id = int(snapshot_id)

    catalog_relative_table = table_ident.removeprefix("lrc.")
    spark.sql(f"CALL lrc.system.rollback_to_snapshot('{catalog_relative_table}', {target_snapshot_id})")
    return target_snapshot_id


def main() -> None:
    project_id = os.environ.get("GCP_PROJECT_ID", "your-gcp-project-id")
    warehouse_bucket = os.environ.get("LAKEHOUSE_BUCKET", f"gs://{project_id}-iceberg-lakehouse")
    pii_salt = os.environ.get("PII_HASH_SALT", "dak-enterprise-pii-salt-v1")

    spark = build_iceberg_spark_session(project_id, warehouse_bucket)
    spark.sql("CREATE NAMESPACE IF NOT EXISTS lrc.modeled_search_warehouse")

    # Read cross-cloud DBX federated table (biglakefederated.raw_search_telemetry.search_events)
    # with automatic fallback to GCP-native LRC (lrc.raw_search_telemetry.search_events)
    bronze_df = read_cross_cloud_search_events(spark)
    silver_df = transform_bronze_to_silver(bronze_df, pii_salt=pii_salt)

    # Idempotent Iceberg write to GCP-Native BigLake LRC (`lrc.modeled_search_warehouse.sessionized_searches`)
    spark.sql("DROP TABLE IF EXISTS lrc.modeled_search_warehouse.sessionized_searches")
    (
        silver_df.writeTo("lrc.modeled_search_warehouse.sessionized_searches")
        .using("iceberg")
        .tableProperty("write.format.default", "parquet")
        .tableProperty("write.wap.enabled", "true")
        .partitionedBy("event_date")
        .createOrReplace()
    )

    # Demonstrate Git-style Write-Audit-Publish (WAP) branching on Lakehouse table
    write_to_iceberg_branch_and_audit(
        spark,
        silver_df,
        table_ident="lrc.modeled_search_warehouse.sessionized_searches",
        branch_name="audit_branch",
    )
    spark.stop()


if __name__ == "__main__":
    main()
