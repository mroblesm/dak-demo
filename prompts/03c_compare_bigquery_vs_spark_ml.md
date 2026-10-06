@skill:ml-best-practices @skill:bigframes-codegen @skill:bigquery-ai-rules @skill:gcp-spark
Read the project configuration from .env (or .env.example if .env is not present: GCP_PROJECT_ID, SERVING_DATASET_ID).

1. Compare our two Step 3 ML implementations head-to-head:
   - Path 3A: `reference_solution/03_ml_training_inference/alt_b_bigframes/conversion_modeling_bigframes.ipynb` & `reference_solution/03_ml_training_inference/alt_a_bqml_ai_sql/03_bqml_conversion_reranker.sql` (or the corresponding files in `workspace/03_ml_training_inference/`)
   - Path 3B: `reference_solution/03_ml_training_inference/alt_c_spark_mllib/spark_mllib_reranker.py` (or `workspace/03_ml_training_inference/alt_c_spark_mllib/spark_mllib_reranker.py`)
   Compare them across 5 dimensions: Target Persona, Compute & Data Movement, GenAI/Vector Synergy, Governance/Explainability/Experiment Tracking, and Key DAK Skill Guardrails.

2. Run a live BigQuery SQL query comparing the predictions in `<GCP_PROJECT_ID>.serving_clarity_intelligence.clarity_reranked_search_results` (Path 3A) against `<GCP_PROJECT_ID>.serving_clarity_intelligence.spark_mllib_reranked_results` (Path 3B) grouped by `query_tier` (`COUNT(*)`, `AVG` conversion probability, `MAX` conversion probability), and explain why their predicted probability scales differ (`AUTO_CLASS_WEIGHTS = TRUE` in BQML vs. unweighted empirical probabilities in Spark MLlib).
