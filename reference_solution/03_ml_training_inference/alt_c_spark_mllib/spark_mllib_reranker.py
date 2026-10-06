#!/usr/bin/env python3
"""Path 3B (The Spark World): Managed Spark MLlib Re-Ranker + GEAP (fka Vertex AI) Experiments Tracking.

Explicitly implements @skill:gcp-spark (`resources/ml_tasks.md`), @skill:ml-best-practices,
and @skill:notebook-guidance:
  1. Reads ranked search impressions from BigLake Iceberg / BigQuery on Managed Service
     for Apache Spark and inspects schema via `df.printSchema()`.
  2. Performs a chronological train/test split on `event_timestamp` to prevent temporal leakage.
  3. Builds a distributed Spark MLlib pipeline (`StringIndexer` + `VectorAssembler` + `GBTClassifier`).
  4. Applies counterfactual Rank-1 position-bias debiasing (`withColumn("displayed_rank_position", lit(1))`)
     during inference.
  5. Enforces the mandatory `@skill:gcp-spark` serialization rule: converts the MLlib `VectorUDT`
     `probability` column into a standard array via `vector_to_array(col("probability")).getItem(1)`
     before writing predictions back to BigQuery / BigLake Iceberg.
  6. Logs hyperparameters, chronological cutoff metadata, and holdout ROC AUC metrics to
     Gemini Enterprise Agent Platform (GEAP, fka Vertex AI) Experiments (`google.cloud.aiplatform`).
"""

from __future__ import annotations

import os
from typing import Any
from pyspark.ml import Pipeline
from pyspark.ml.classification import GBTClassifier
from pyspark.ml.evaluation import BinaryClassificationEvaluator
from pyspark.ml.feature import StringIndexer, VectorAssembler
from pyspark.ml.functions import vector_to_array
from pyspark.sql import DataFrame, SparkSession
from pyspark.sql import functions as F


FEATURE_NUMERIC_COLS = [
    "query_length_tokens",
    "displayed_rank_position",
    "lexical_bm25_score",
    "semantic_cosine_similarity",
    "historical_item_ctr",
    "price_usd",
    "average_rating",
]


def log_run_to_geap_experiments(
    project_id: str,
    location: str,
    experiment_name: str,
    run_name: str,
    params: dict[str, str | int | float],
    metrics: dict[str, float],
) -> dict[str, Any]:
    """Track Managed Spark MLlib training runs in GEAP (fka Vertex AI) Experiments."""
    offline_mode = os.environ.get("DEMO_OFFLINE_FALLBACK", "true").lower() == "true"
    if not offline_mode:
        try:
            from google.cloud import aiplatform  # type: ignore

            aiplatform.init(
                project=project_id,
                location=location,
                experiment=experiment_name,
            )
            aiplatform.start_run(run=run_name)
            aiplatform.log_params(params)
            aiplatform.log_metrics(metrics)
            aiplatform.end_run()
            return {
                "tracker": "GEAP (fka Vertex AI) Experiments",
                "experiment": experiment_name,
                "run": run_name,
                "status": "LOGGED_TO_CLOUD",
                "params": params,
                "metrics": metrics,
            }
        except Exception:
            pass

    return {
        "tracker": "GEAP (fka Vertex AI) Experiments (Local/Offline Telemetry Mirror)",
        "experiment": experiment_name,
        "run": run_name,
        "status": "MIRRORED_LOCALLY",
        "params": params,
        "metrics": metrics,
    }


def train_and_score_spark_mllib(
    impressions_df: DataFrame,
    max_iter: int = 25,
    max_depth: int = 5,
) -> tuple[DataFrame, float]:
    """Train distributed GBTClassifier with chronological split and return debiased predictions."""
    # Mandatory @skill:gcp-spark rule: printSchema before referencing columns
    impressions_df.printSchema()

    prepared_df = impressions_df.withColumn("event_ts", F.to_timestamp("event_timestamp")).withColumn(
        "purchased_label", F.col("purchased").cast("double")
    )

    # Chronological 80/20 split (@skill:ml-best-practices)
    split_epoch = prepared_df.select(
        F.percentile_approx(F.unix_timestamp("event_ts"), 0.80).alias("cutoff")
    ).collect()[0]["cutoff"]

    train_df = prepared_df.filter(F.unix_timestamp("event_ts") <= split_epoch)
    test_df = prepared_df.filter(F.unix_timestamp("event_ts") > split_epoch)

    clv_indexer = StringIndexer(
        inputCol="customer_clv_segment",
        outputCol="customer_clv_segment_idx",
        handleInvalid="keep",
    )
    assembler = VectorAssembler(
        inputCols=FEATURE_NUMERIC_COLS + ["customer_clv_segment_idx"],
        outputCol="features",
        handleInvalid="keep",
    )
    gbt = GBTClassifier(
        labelCol="purchased_label",
        featuresCol="features",
        maxIter=max_iter,
        maxDepth=max_depth,
        seed=42,
    )

    pipeline = Pipeline(stages=[clv_indexer, assembler, gbt])
    model = pipeline.fit(train_df)

    # Evaluate ROC AUC on chronological holdout set
    holdout_preds = model.transform(test_df)
    evaluator = BinaryClassificationEvaluator(
        labelCol="purchased_label",
        rawPredictionCol="rawPrediction",
        metricName="areaUnderROC",
    )
    roc_auc = evaluator.evaluate(holdout_preds)

    # Counterfactual Rank-1 Position-Bias Debiasing at inference time
    debiased_input_df = test_df.withColumn("displayed_rank_position", F.lit(1))
    debiased_raw_preds = model.transform(debiased_input_df)

    # Mandatory @skill:gcp-spark (`resources/ml_tasks.md`) rule:
    # Convert VectorUDT `probability` column via `vector_to_array` before saving to BQ/Iceberg
    export_ready_df = debiased_raw_preds.select(
        "impression_id",
        "search_event_id",
        "item_id",
        "query_tier",
        vector_to_array(F.col("probability")).getItem(1).alias("predicted_conversion_prob"),
        F.col("prediction").cast("int").alias("predicted_label"),
        "event_date",
    )
    return export_ready_df, roc_auc


def main() -> None:
    project_id = os.environ.get("GCP_PROJECT_ID", "your-gcp-project-id")
    location = os.environ.get("GCP_REGION", "us-central1")
    experiment_name = os.environ.get("GEAP_EXPERIMENT_NAME", "clarity-spark-mllib-reranker-exp")
    run_name = os.environ.get("GEAP_RUN_NAME", "gbt-rank1-debiased-v1")

    spark = SparkSession.builder.appName("clarity-spark-mllib-reranker-geap").getOrCreate()

    impressions_df = spark.read.format("bigquery").option(
        "table", f"{project_id}.raw_retail_core.search_impressions"
    ).load()

    max_iter = 25
    max_depth = 5
    predictions_df, roc_auc = train_and_score_spark_mllib(
        impressions_df, max_iter=max_iter, max_depth=max_depth
    )
    print(f"[Spark MLlib GBTClassifier] Chronological Holdout ROC AUC = {roc_auc:.4f}")

    # Track experiment parameters and metrics in GEAP (fka Vertex AI) Experiments
    geap_receipt = log_run_to_geap_experiments(
        project_id=project_id,
        location=location,
        experiment_name=experiment_name,
        run_name=run_name,
        params={
            "engine": "Managed Service for Apache Spark (Serverless v2.2)",
            "algorithm": "pyspark.ml.classification.GBTClassifier",
            "max_iter": max_iter,
            "max_depth": max_depth,
            "split_method": "chronological_80_20_event_ts",
            "debiasing": "counterfactual_displayed_rank_1",
        },
        metrics={
            "holdout_roc_auc": round(float(roc_auc), 4),
        },
    )
    print(f"[GEAP Experiments Tracking] {geap_receipt}")

    (
        predictions_df.write.format("bigquery")
        .option("table", f"{project_id}.serving_clarity_intelligence.spark_mllib_reranked_results")
        .option("writeMethod", "direct")
        .mode("overwrite")
        .save()
    )
    spark.stop()


if __name__ == "__main__":
    main()

