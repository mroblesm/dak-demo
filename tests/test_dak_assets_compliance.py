"""Comprehensive compliance tests verifying public documentation, prompts, and reference_solution assets."""

from __future__ import annotations

import ast
import json
from pathlib import Path
import subprocess


REPO_ROOT = Path(__file__).resolve().parent.parent
REF_ROOT = REPO_ROOT / "reference_solution"


def test_public_documentation_and_prompts_deliverables() -> None:
    readme_text = (REPO_ROOT / "README.md").read_text(encoding="utf-8")
    gemini_text = (REPO_ROOT / "GEMINI.md").read_text(encoding="utf-8")
    env_example = (REPO_ROOT / ".env.example").read_text(encoding="utf-8")

    assert "reference_solution/" in readme_text
    assert "prompts/" in readme_text
    assert "docs/01_PREREQUISITES_AND_SETUP.md" in readme_text
    assert "docs/02_INFRASTRUCTURE_PROVISIONING.md" in readme_text
    assert "docs/03_E2E_WALKTHROUGH_GUIDE.md" in readme_text
    assert "docs/04_ARCHITECTURE_AND_DESIGN.md" in readme_text
    assert "GCP_PROJECT_ID=your-gcp-project-id" in env_example
    assert "Dataproc Serverless Runtime `2.3`" in gemini_text

    # Verify all 4 documentation guides and all 10 prompt files exist
    for doc_name in (
        "01_PREREQUISITES_AND_SETUP.md",
        "02_INFRASTRUCTURE_PROVISIONING.md",
        "03_E2E_WALKTHROUGH_GUIDE.md",
        "04_ARCHITECTURE_AND_DESIGN.md",
    ):
        assert (REPO_ROOT / "docs" / doc_name).exists(), f"Missing docs/{doc_name}"

    for prompt_name in (
        "README.md",
        "00_environment_and_catalog_check.md",
        "01_discovery_and_property_graph.md",
        "02a_spark_bronze_medallion_iceberg.md",
        "02b_dbt_silver_gold_and_scorecards.md",
        "03a_bigquery_ml_and_bigframes.md",
        "03b_spark_mllib_and_experiments.md",
        "03c_compare_bigquery_vs_spark_ml.md",
        "04a_declarative_orchestration_pipeline.md",
        "04b_composer_rca_troubleshooting.md",
        "05_cloud_run_app_and_conversational_analytics.md",
    ):
        assert (REPO_ROOT / "prompts" / prompt_name).exists(), f"Missing prompts/{prompt_name}"


def test_step_1_discovery_assets() -> None:
    script = (REF_ROOT / "01_discovery" / "dak_discovery_walkthrough.sh").read_text(encoding="utf-8")
    sql = (REF_ROOT / "01_discovery" / "discovery_inspection_queries.sql").read_text(encoding="utf-8")

    assert "gcloud dataplex entries search" in script
    assert "--semantic-search" in script
    assert "gcloud dataplex context lookup" in script
    assert "maximum_bytes_billed" in sql
    assert "APPROX_TOP_COUNT" in sql
    assert "INFORMATION_SCHEMA.PARTITIONS" in sql
    assert "CREATE OR REPLACE PROPERTY GRAPH" in sql


def test_step_2_preparation_both_alternatives() -> None:
    # Alt 2A: dbt-bigquery + Knowledge Catalog Scorecards
    dbt_dir = REF_ROOT / "02_preparation" / "alt_a_dbt_dea"
    sources_yml = (dbt_dir / "models" / "staging" / "_sources.yml").read_text(encoding="utf-8")
    macro_sql = (dbt_dir / "macros" / "generate_schema_name.sql").read_text(encoding="utf-8")
    stg_sql = (dbt_dir / "models" / "staging" / "stg_search_events.sql").read_text(encoding="utf-8")
    mart_sql = (dbt_dir / "models" / "marts" / "fct_search_conversions.sql").read_text(encoding="utf-8")
    test_yml = (dbt_dir / "models" / "marts" / "_test.yml").read_text(encoding="utf-8")
    dea_payload = json.loads((dbt_dir / "dea_a2a_workflow_request.json").read_text(encoding="utf-8"))

    assert "ICEBERG_CATALOG_SCHEMA" in sources_yml
    assert "macro generate_schema_name" in macro_sql
    assert "Automatic Cleaning Summary" in stg_sql
    assert "ROW_NUMBER() OVER" in stg_sql
    assert "WHERE EXISTS" in mart_sql
    assert "unit_tests:" in test_yml
    assert dea_payload["protocol"] == "google.cloud.a2a.v1"

    # Alt 2B: Serverless Spark Medallion ETL (Runtime 2.3 + Iceberg 1.5.0)
    spark_py = (REF_ROOT / "02_preparation" / "alt_b_serverless_spark" / "spark_medallion_prep.py").read_text(encoding="utf-8")
    spark_sh = (REF_ROOT / "02_preparation" / "alt_b_serverless_spark" / "submit_serverless_batch.sh").read_text(encoding="utf-8")

    assert "org.apache.iceberg.spark.SparkCatalog" in spark_py
    assert "header.Authorization" in spark_py
    assert "printSchema()" in spark_py
    assert "--version=2.3" in spark_sh
    assert "maxExecutors=8" in spark_sh
    assert "--ttl=1800s" in spark_sh


def test_step_3_ml_training_and_inference_all_three_alternatives() -> None:
    # Alt 3A: BQML & BigQuery AI SQL
    sql_dir = REF_ROOT / "03_ml_training_inference" / "alt_a_bqml_ai_sql"
    s1 = (sql_dir / "01_ai_intent_enrichment.sql").read_text(encoding="utf-8")
    s2 = (sql_dir / "02_hybrid_vector_search_rrf.sql").read_text(encoding="utf-8")
    s3 = (sql_dir / "03_bqml_conversion_reranker.sql").read_text(encoding="utf-8")
    s4 = (sql_dir / "04_ai_forecast_demand.sql").read_text(encoding="utf-8")

    assert "AI.GENERATE_TABLE" in s1
    assert "VECTOR_SEARCH" in s2 and "SEARCH(" in s2
    assert "BOOSTED_TREE_CLASSIFIER" in s3
    assert "DATA_SPLIT_METHOD = 'SEQ'" in s3
    assert "1 AS displayed_rank_position" in s3
    assert "AI.FORECAST" in s4

    # Alt 3B: BigFrames Notebook
    bf_nb = json.loads(
        (REF_ROOT / "03_ml_training_inference" / "alt_b_bigframes" / "conversion_modeling_bigframes.ipynb").read_text(encoding="utf-8")
    )
    code_cells = ["".join(c["source"]) for c in bf_nb["cells"] if c["cell_type"] == "code"]
    full_bf_code = "\n".join(code_cells)
    assert "bigframes.pandas" in full_bf_code
    assert "XGBClassifier" in full_bf_code
    assert ".to_pandas()" not in full_bf_code

    # Alt 3C: Spark MLlib
    mllib_py = (REF_ROOT / "03_ml_training_inference" / "alt_c_spark_mllib" / "spark_mllib_reranker.py").read_text(encoding="utf-8")
    assert "GBTClassifier" in mllib_py
    assert "vector_to_array" in mllib_py


def test_step_4_orchestration_and_composer_rca() -> None:
    for script_rel in [
        "infra/provision_demo_infra.sh",
        "reference_solution/01_discovery/dak_discovery_walkthrough.sh",
        "reference_solution/02_preparation/alt_b_serverless_spark/submit_serverless_batch.sh",
        "reference_solution/04_orchestration/alt_a_orchestration_pipelines/validate_and_deploy.sh",
        "reference_solution/05_presentation_app/alt_a_react_cloud_run/deploy_cloud_run.sh",
    ]:
        res = subprocess.run(
            ["bash", script_rel, "--dry-run"],
            cwd=REPO_ROOT,
            capture_output=True,
            text=True,
            check=True,
        )
        assert res.returncode == 0
        if "validate_and_deploy.sh" in script_rel:
            assert "SCHEMA VALIDATION PASS" in res.stdout

    logs = json.loads(
        (REF_ROOT / "04_orchestration" / "alt_b_cloud_composer" / "simulated_composer_error_logs.json").read_text(encoding="utf-8")
    )
    assert logs[0]["resource"]["type"] == "cloud_composer_environment"
    assert "require_partition_filter" in logs[0]["jsonPayload"]["message"]

    # Verify both Composer DAGs import cleanly
    import importlib.util

    for dag_file in ("clarity_search_pipeline_dag.py", "broken_dag_for_rca_demo.py"):
        dag_path = REF_ROOT / "04_orchestration" / "alt_b_cloud_composer" / dag_file
        spec = importlib.util.spec_from_file_location(dag_file.removesuffix(".py"), dag_path)
        assert spec is not None and spec.loader is not None
        mod = importlib.util.module_from_spec(spec)
        spec.loader.exec_module(mod)
        assert hasattr(mod, "dag")


def test_all_python_files_and_notebooks_parse_cleanly() -> None:
    for py_path in REPO_ROOT.rglob("*.py"):
        if any(part in (".venv", "_private_demo_prep") for part in py_path.parts):
            continue
        source = py_path.read_text(encoding="utf-8")
        ast.parse(source, filename=str(py_path))

    for nb_path in REPO_ROOT.rglob("*.ipynb"):
        if "_private_demo_prep" in nb_path.parts:
            continue
        nb = json.loads(nb_path.read_text(encoding="utf-8"))
        assert len(nb.get("cells", [])) >= 2
        for cell in nb["cells"]:
            if cell.get("cell_type") == "code":
                code_str = "".join(cell.get("source", []))
                ast.parse(code_str, filename=str(nb_path))
