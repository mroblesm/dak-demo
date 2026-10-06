-- =============================================================================
-- Step 3 (Alternative 3A - Part 3): Position-Debiased BQML Conversion Re-Ranker
-- Enforces @skill:ml-best-practices & @skill:developing-with-bigquery (`BQML.md`):
--   1. Chronological Split (`DATA_SPLIT_METHOD = 'SEQ'`, `DATA_SPLIT_COL = 'event_timestamp'`)
--      to prevent future-to-past temporal data leakage.
--   2. Zero Target Leakage (`leak_scan` compliant features only).
--   3. Global Explainability (`ENABLE_GLOBAL_EXPLAIN = TRUE`).
--   4. Position-Bias Debiasing during `ML.PREDICT`:
--      Includes `displayed_rank_position` during training to absorb historical
--      examination bias, then fixes `1 AS displayed_rank_position` during
--      inference so every candidate SKU is scored counterfactually at Rank 1!
-- =============================================================================

SET @@maximum_bytes_billed = 10737418240; -- 10 GB FinOps safety cap

-- 1. Train Position-Aware Conversion Propensity Model
CREATE OR REPLACE MODEL `your-gcp-project-id.serving_clarity_intelligence.bqml_conversion_reranker`
OPTIONS (
  MODEL_TYPE = 'BOOSTED_TREE_CLASSIFIER',
  INPUT_LABEL_COLS = ['purchased'],
  DATA_SPLIT_METHOD = 'SEQ',
  DATA_SPLIT_COL = 'event_timestamp',
  DATA_SPLIT_EVAL_FRACTION = 0.20,
  MAX_ITERATIONS = 40,
  LEARN_RATE = 0.15,
  SUBSAMPLE = 0.85,
  AUTO_CLASS_WEIGHTS = TRUE,
  ENABLE_GLOBAL_EXPLAIN = TRUE
) AS
SELECT
  SAFE_CAST(imp.purchased AS INT64) AS purchased,
  SAFE_CAST(imp.query_length_tokens AS INT64) AS query_length_tokens,
  SAFE_CAST(imp.displayed_rank_position AS INT64) AS displayed_rank_position,
  SAFE_CAST(imp.lexical_bm25_score AS FLOAT64) AS lexical_bm25_score,
  SAFE_CAST(imp.semantic_cosine_similarity AS FLOAT64) AS semantic_cosine_similarity,
  SAFE_CAST(imp.historical_item_ctr AS FLOAT64) AS historical_item_ctr,
  SAFE_CAST(imp.price_usd AS FLOAT64) AS price_usd,
  SAFE_CAST(imp.average_rating AS FLOAT64) AS average_rating,
  COALESCE(imp.customer_clv_segment, 'NEW_EXPLORER') AS customer_clv_segment,
  SAFE.PARSE_TIMESTAMP('%Y-%m-%dT%H:%M:%E*S%Ez', CAST(imp.event_timestamp AS STRING)) AS event_timestamp
FROM `your-gcp-project-id.raw_retail_core.search_impressions` AS imp
WHERE imp.event_date >= DATE_SUB(CURRENT_DATE(), INTERVAL 90 DAY);

-- 2. Evaluate Holdout ROC AUC, PR AUC, and Log Loss
SELECT
  roc_auc,
  precision,
  recall,
  f1_score,
  log_loss
FROM
  ML.EVALUATE(
    MODEL `your-gcp-project-id.serving_clarity_intelligence.bqml_conversion_reranker`
  );

-- 3. Inspect Global Feature Attributions (@skill:ml-best-practices explainability gate)
SELECT
  feature,
  ROUND(attribution, 5) AS shap_global_attribution
FROM
  ML.GLOBAL_EXPLAIN(
    MODEL `your-gcp-project-id.serving_clarity_intelligence.bqml_conversion_reranker`
  )
ORDER BY attribution DESC;

-- 4. Counterfactual Position-Debiased Re-Ranking (`1 AS displayed_rank_position`)
CREATE OR REPLACE TABLE `your-gcp-project-id.serving_clarity_intelligence.clarity_reranked_search_results` AS
SELECT
  search_event_id,
  item_id,
  query_tier,
  original_displayed_rank,
  ROUND(
    (SELECT prob FROM UNNEST(predicted_purchased_probs) WHERE label = 1),
    5
  ) AS debiased_conversion_probability,
  ROW_NUMBER() OVER (
    PARTITION BY search_event_id
    ORDER BY (SELECT prob FROM UNNEST(predicted_purchased_probs) WHERE label = 1) DESC
  ) AS clarity_reranked_position
FROM
  ML.PREDICT(
    MODEL `your-gcp-project-id.serving_clarity_intelligence.bqml_conversion_reranker`,
    (
      SELECT
        search_event_id,
        item_id,
        query_tier,
        displayed_rank_position AS original_displayed_rank,
        query_length_tokens,
        1 AS displayed_rank_position, -- Counterfactual Rank-1 setting removes historical position bias!
        lexical_bm25_score,
        semantic_cosine_similarity,
        historical_item_ctr,
        price_usd,
        average_rating,
        customer_clv_segment,
        SAFE.PARSE_TIMESTAMP('%Y-%m-%dT%H:%M:%E*S%Ez', CAST(event_timestamp AS STRING)) AS event_timestamp
      FROM `your-gcp-project-id.raw_retail_core.search_impressions`
      WHERE event_date >= DATE_SUB(CURRENT_DATE(), INTERVAL 14 DAY)
    )
  );
