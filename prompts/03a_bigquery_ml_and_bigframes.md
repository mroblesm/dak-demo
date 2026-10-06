@skill:bigframes-codegen @skill:bigquery-ai-rules @skill:ml-best-practices @skill:notebook-best-practices
Read the project configuration from .env (or .env.example if .env is not present: GCP_PROJECT_ID, BQ_LOCATION, RAW_DATASET_ID, MODELED_DATASET_ID, SERVING_DATASET_ID).
Create the directories `workspace/03_ml_training_inference/alt_a_bqml_ai_sql/` and `workspace/03_ml_training_inference/alt_b_bigframes/` and generate the following files:

1. `workspace/03_ml_training_inference/alt_a_bqml_ai_sql/01_ai_intent_enrichment.sql`:
   - Enforce `SET @@maximum_bytes_billed = 10737418240;`.
   - Use `AI.GENERATE_TABLE` with `MODEL <GCP_PROJECT_ID>.serving_clarity_intelligence.gemini_flash_intent_model` and `STRUCT('room_type STRING, material_preference STRING, style_tag STRING, max_budget_usd FLOAT64, pet_safe_required BOOL' AS output_schema, 0.0 AS temperature)` over `modeled_search_warehouse.stg_search_events` (`WHERE query_tier = 'tail'`) to materialize `serving_clarity_intelligence.tail_query_intent_enriched`.

2. `workspace/03_ml_training_inference/alt_a_bqml_ai_sql/02_hybrid_vector_search_rrf.sql`:
   - Materialize `serving_clarity_intelligence.catalog_item_embeddings` using `AI.GENERATE_EMBEDDING` (`MODEL <GCP_PROJECT_ID>.serving_clarity_intelligence.text_embedding_005_model`, `STRUCT('RETRIEVAL_DOCUMENT' AS task_type)`).
   - Materialize `serving_clarity_intelligence.hybrid_rrf_candidates` by fusing semantic `VECTOR_SEARCH(..., top_k => 20, distance_type => 'COSINE')` and lexical `SEARCH()` using Reciprocal Rank Fusion (`1.0 / (60.0 + vector_rank) + 1.0 / (60.0 + lexical_rank)`).

3. `workspace/03_ml_training_inference/alt_a_bqml_ai_sql/03_bqml_conversion_reranker.sql`:
   - Train `CREATE OR REPLACE MODEL <GCP_PROJECT_ID>.serving_clarity_intelligence.bqml_conversion_reranker` with `MODEL_TYPE = 'BOOSTED_TREE_CLASSIFIER'`, `INPUT_LABEL_COLS = ['purchased']`, `DATA_SPLIT_METHOD = 'SEQ'`, `DATA_SPLIT_COL = 'event_timestamp'`, `DATA_SPLIT_EVAL_FRACTION = 0.20`, `AUTO_CLASS_WEIGHTS = TRUE`, and `ENABLE_GLOBAL_EXPLAIN = TRUE` over `raw_retail_core.search_impressions`.
   - Include `ML.EVALUATE` and `ML.GLOBAL_EXPLAIN` queries.
   - Materialize `serving_clarity_intelligence.clarity_reranked_search_results` via `ML.PREDICT` setting `1 AS displayed_rank_position` (counterfactual Rank-1 position-bias debiasing) and ranking candidates per `search_event_id` by predicted conversion probability (`clarity_reranked_position`).

4. `workspace/03_ml_training_inference/alt_a_bqml_ai_sql/04_ai_forecast_demand.sql`:
   - Materialize `serving_clarity_intelligence.category_demand_forecast_30d` using BigQuery's zero-shot `AI.FORECAST` (`data_col => 'daily_revenue_usd'`, `timestamp_col => 'event_date'`, `id_cols => ['query_tier']`, `horizon => 30`, `confidence_level => 0.95`) over `modeled_search_warehouse.fct_search_conversions`.

5. `workspace/03_ml_training_inference/alt_b_bigframes/conversion_modeling_bigframes.ipynb`:
   - Use `bigframes.pandas as bpd`, `bigframes.ml.preprocessing.StandardScaler`, and `bigframes.ml.ensemble.XGBClassifier`.
   - Enforce `@skill:bigframes-codegen` and `@skill:ml-best-practices`: never call `.to_pandas()`, split `raw_retail_core.search_impressions` chronologically on `event_timestamp <= '2026-09-20T00:00:00Z'` *before* fitting `StandardScaler`, train `XGBClassifier(n_estimators=40, max_depth=5, learning_rate=0.15)`, apply counterfactual Rank-1 debiasing (`test_bf[FEATURE_COLS].assign(displayed_rank_position=1)`), and write results via `.to_gbq()`.
   - Include a final cell querying `ML.EVALUATE` on `serving_clarity_intelligence.bqml_conversion_reranker` and summarizing `serving_clarity_intelligence.clarity_reranked_search_results` by `query_tier`.
