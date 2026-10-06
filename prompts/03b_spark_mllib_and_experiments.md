@skill:gcp-spark @skill:ml-best-practices @skill:notebook-best-practices
Read the project configuration from .env (or .env.example if .env is not present: GCP_PROJECT_ID, GCP_REGION, SPARK_SESSION_TEMPLATE).
Create the directory `workspace/03_ml_training_inference/alt_c_spark_mllib/` and generate the following two files:

1. `workspace/03_ml_training_inference/alt_c_spark_mllib/spark_mllib_reranker.py`:
   - Read `raw_retail_core.search_impressions` via the Spark BigQuery connector (with fallback to `gs://<GCP_PROJECT_ID>-iceberg-lakehouse/dbx_seed_data/search_impressions.jsonl`).
   - Enforce `@skill:gcp-spark` & `@skill:ml-best-practices`:
     1. Call `impressions_df.printSchema()` before referencing columns.
     2. Compute an 80/20 chronological split on `event_timestamp` using `F.percentile_approx(F.unix_timestamp("event_ts"), 0.80)` (never use `randomSplit`).
     3. Build a PySpark `Pipeline` with `StringIndexer(inputCol="customer_clv_segment", handleInvalid="keep")`, `VectorAssembler`, and `GBTClassifier(labelCol="purchased_label", featuresCol="features", maxIter=25, maxDepth=5, seed=42)`.
     4. Evaluate holdout `areaUnderROC` using `BinaryClassificationEvaluator`.
     5. Apply counterfactual Rank-1 position-bias debiasing (`test_df.withColumn("displayed_rank_position", F.lit(1))`).
     6. Convert `GBTClassifier`'s `VectorUDT` `probability` column into a standard SQL array using `from pyspark.ml.functions import vector_to_array` (`vector_to_array(F.col("probability")).getItem(1).alias("predicted_conversion_prob")`) before writing to `serving_clarity_intelligence.spark_mllib_reranked_results`.
   - Implement `log_run_to_geap_experiments(project_id, location, experiment_name, run_name, params, metrics)` using `google.cloud.aiplatform` (`aiplatform.init`, `aiplatform.start_run`, `aiplatform.log_params`, `aiplatform.log_metrics`, `aiplatform.end_run`) with a graceful offline fallback dictionary.

2. `workspace/03_ml_training_inference/alt_c_spark_mllib/spark_mllib_reranker.ipynb`:
   - Define `train_and_score_spark_mllib` and `log_run_to_geap_experiments` **inline inside the notebook cell** (do NOT import from `spark_mllib_reranker.py`, which is not on the remote Dataproc Serverless VM).
   - Automatically detect whether the notebook is running inside a remote Dataproc Serverless Jupyter kernel (`os.path.exists("/usr/lib/spark")`) or a local Python kernel (`DataprocSparkSession`), and inject the OAuth `Bearer` token into `spark.sql.catalog.lrc.header.Authorization`.
