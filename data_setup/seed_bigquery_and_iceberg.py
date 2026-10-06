#!/usr/bin/env python3
"""Loads generated JSONL synthetic datasets into BigQuery and stages BigLake Iceberg seed files.

Reads `GCP_PROJECT_ID` from `.env` or environment variables (default placeholder: `your-gcp-project-id`).
- Native GCP LRC Bucket: `gs://<project_id>-iceberg-lakehouse`
- Cross-Cloud Federated LRC Bucket: `gs://<project_id>-iceberg-dbx-lakehouse`
- Seeds BigQuery `raw_retail_core` tables (`catalog_items`, `customer_clv`, `search_impressions`, `search_events`)
- Creates BigQuery remote models (`gemini_flash_intent_model`, `text_embedding_005_model`)
Supports `--dry-run` (default for offline CI) and `--execute` (for live GCP seeding).
"""

from __future__ import annotations

import argparse
import os
from pathlib import Path
import subprocess


def _load_dotenv_if_present() -> None:
    env_path = Path(__file__).resolve().parent.parent / ".env"
    if not env_path.exists():
        return
    for raw_line in env_path.read_text(encoding="utf-8").splitlines():
        line = raw_line.strip()
        if not line or line.startswith("#") or "=" not in line:
            continue
        k, v = line.split("=", 1)
        os.environ.setdefault(k.strip(), v.strip().strip('"').strip("'"))


def seed_tables(project_id: str, raw_dataset: str, data_dir: Path, dry_run: bool = True) -> list[str]:
    """Generate and optionally execute bq load and GCS staging commands."""
    native_lrc_bucket = f"gs://{project_id}-iceberg-lakehouse"
    dbx_federated_bucket = f"gs://{project_id}-iceberg-dbx-lakehouse"
    serving_dataset = os.environ.get("SERVING_DATASET_ID", "serving_clarity_intelligence")
    bq_location = os.environ.get("BQ_LOCATION", "US").lower()

    commands = [
        # 1. Native BigQuery Bronze tables in raw_retail_core
        (
            f"bq load --project_id={project_id} --source_format=NEWLINE_DELIMITED_JSON --autodetect --replace "
            f"{project_id}:{raw_dataset}.catalog_items {data_dir}/catalog_items.jsonl"
        ),
        (
            f"bq load --project_id={project_id} --source_format=NEWLINE_DELIMITED_JSON --autodetect --replace "
            f"{project_id}:{raw_dataset}.customer_clv {data_dir}/customer_clv.jsonl"
        ),
        (
            f"bq load --project_id={project_id} --source_format=NEWLINE_DELIMITED_JSON --autodetect --replace "
            f"{project_id}:{raw_dataset}.search_impressions {data_dir}/search_impressions.jsonl"
        ),
        (
            f"bq load --project_id={project_id} --source_format=NEWLINE_DELIMITED_JSON --autodetect --replace "
            f"{project_id}:{raw_dataset}.search_events {data_dir}/search_events.jsonl"
        ),
        # 2. Stage federated table (search_events) into the Federated Lakehouse bucket
        (
            f"gcloud storage cp {data_dir}/search_events.jsonl {data_dir}/search_events.csv "
            f"{dbx_federated_bucket}/dbx_seed_data/"
        ),
        # 3. Stage seed files into the GCP Native LRC Lakehouse bucket
        (
            f"gcloud storage cp {data_dir}/search_events.jsonl {data_dir}/search_impressions.jsonl "
            f"{data_dir}/search_impressions.csv {native_lrc_bucket}/dbx_seed_data/"
        ),
        # 4. Create BigQuery Remote Models for AI.GENERATE_TABLE and AI.GENERATE_EMBEDDING
        (
            f"bq query --project_id={project_id} --use_legacy_sql=false "
            f"\"CREATE OR REPLACE MODEL \\`{project_id}.{serving_dataset}.gemini_flash_intent_model\\` "
            f"REMOTE WITH CONNECTION \\`{project_id}.{bq_location}.vertex-ai-connection\\` "
            f"OPTIONS (ENDPOINT = 'gemini-2.5-flash');\""
        ),
        (
            f"bq query --project_id={project_id} --use_legacy_sql=false "
            f"\"CREATE OR REPLACE MODEL \\`{project_id}.{serving_dataset}.text_embedding_005_model\\` "
            f"REMOTE WITH CONNECTION \\`{project_id}.{bq_location}.vertex-ai-connection\\` "
            f"OPTIONS (ENDPOINT = 'text-embedding-005');\""
        ),
    ]

    for cmd in commands:
        if dry_run:
            print(f"[DRY-RUN] {cmd}")
        else:
            print(f"[EXEC] {cmd}")
            subprocess.run(cmd, shell=True, check=True)

    return commands


def main() -> None:
    _load_dotenv_if_present()
    default_project = os.environ.get("GCP_PROJECT_ID", "your-gcp-project-id")
    default_raw_ds = os.environ.get("RAW_DATASET_ID", "raw_retail_core")

    parser = argparse.ArgumentParser(description="Seed BigQuery & stage BigLake Iceberg seed files.")
    parser.add_argument("--project-id", default=default_project)
    parser.add_argument("--raw-dataset", default=default_raw_ds)
    parser.add_argument("--data-dir", type=Path, default=Path("data_setup/generated"))
    parser.add_argument("--dry-run", action="store_true", default=True)
    parser.add_argument("--execute", action="store_true", help="Execute live bq load and gcloud storage cp commands")
    args = parser.parse_args()
    is_dry_run = False if args.execute else args.dry_run
    seed_tables(args.project_id, args.raw_dataset, args.data_dir, dry_run=is_dry_run)


if __name__ == "__main__":
    main()
