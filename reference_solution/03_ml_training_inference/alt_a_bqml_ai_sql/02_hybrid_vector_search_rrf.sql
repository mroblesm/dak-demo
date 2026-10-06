-- =============================================================================
-- Step 3 (Alternative 3A - Part 2): Hybrid Lexical + Vector Search with RRF
-- Enforces @skill:developing-with-bigquery (`reference/vector-search.md`) &
-- @skill:bigquery-ai-rules:
--   1. Generates embeddings via `AI.GENERATE_EMBEDDING` (`text-embedding-005`).
--   2. Runs dense semantic retrieval via `VECTOR_SEARCH` (`COSINE` distance).
--   3. Runs lexical inverted-index retrieval via `SEARCH()`.
--   4. Fuses both candidate rankings using Reciprocal Rank Fusion (RRF, k=60)
--      to eliminate the 38% long-tail zero-result rate ("The Conversion Desert").
-- =============================================================================

SET @@maximum_bytes_billed = 10737418240; -- 10 GB FinOps safety cap

-- 1. Materialize Catalog Embeddings Table
CREATE OR REPLACE TABLE `your-gcp-project-id.serving_clarity_intelligence.catalog_item_embeddings` AS
SELECT
  item_id,
  product_title,
  category_hierarchy,
  material,
  style_tag,
  room_type,
  price_usd,
  average_rating,
  embedding
FROM
  AI.GENERATE_EMBEDDING(
    MODEL `your-gcp-project-id.serving_clarity_intelligence.text_embedding_005_model`,
    (
      SELECT
        item_id,
        product_title,
        category_hierarchy,
        material,
        style_tag,
        room_type,
        price_usd,
        average_rating,
        CONCAT(
          product_title, ' | Category: ', category_hierarchy,
          ' | Material: ', material, ' | Style: ', style_tag,
          ' | Room: ', room_type, ' | Details: ', product_description
        ) AS content
      FROM `your-gcp-project-id.modeled_search_warehouse.stg_catalog_items`
      WHERE in_stock = TRUE
    ),
    STRUCT('RETRIEVAL_DOCUMENT' AS task_type)
  );

-- 2. Hybrid Retrieval + Reciprocal Rank Fusion (RRF, k=60) for Tail Queries
CREATE OR REPLACE TABLE `your-gcp-project-id.serving_clarity_intelligence.hybrid_rrf_candidates` AS
WITH query_embeddings AS (
  SELECT
    search_event_id,
    normalized_query_text,
    embedding AS query_embedding
  FROM
    AI.GENERATE_EMBEDDING(
      MODEL `your-gcp-project-id.serving_clarity_intelligence.text_embedding_005_model`,
      (
        SELECT
          search_event_id,
          normalized_query_text,
          normalized_query_text AS content
        FROM `your-gcp-project-id.modeled_search_warehouse.stg_search_events`
        WHERE query_tier = 'tail'
          AND event_date >= DATE_SUB(CURRENT_DATE(), INTERVAL 30 DAY)
      ),
      STRUCT('RETRIEVAL_QUERY' AS task_type)
    )
),

semantic_candidates AS (
  SELECT
    vs.query.search_event_id,
    vs.query.normalized_query_text,
    vs.base.item_id,
    ROUND(1.0 - vs.distance, 4) AS semantic_cosine_similarity,
    ROW_NUMBER() OVER (PARTITION BY vs.query.search_event_id ORDER BY vs.distance ASC) AS vector_rank
  FROM
    VECTOR_SEARCH(
      TABLE `your-gcp-project-id.serving_clarity_intelligence.catalog_item_embeddings`,
      'embedding',
      TABLE query_embeddings,
      'query_embedding',
      top_k => 20,
      distance_type => 'COSINE'
    ) AS vs
),

lexical_candidates AS (
  SELECT
    q.search_event_id,
    cat.item_id,
    ROW_NUMBER() OVER (
      PARTITION BY q.search_event_id
      ORDER BY cat.average_rating DESC, cat.price_usd ASC
    ) AS lexical_rank
  FROM query_embeddings AS q
  JOIN `your-gcp-project-id.modeled_search_warehouse.stg_catalog_items` AS cat
    ON SEARCH((cat.product_title, cat.product_description, cat.material, cat.style_tag), q.normalized_query_text)
)

SELECT
  COALESCE(s.search_event_id, l.search_event_id) AS search_event_id,
  COALESCE(s.item_id, l.item_id) AS item_id,
  COALESCE(s.semantic_cosine_similarity, 0.35) AS semantic_cosine_similarity,
  s.vector_rank,
  l.lexical_rank,
  ROUND(
    COALESCE(1.0 / (60.0 + s.vector_rank), 0.0)
    + COALESCE(1.0 / (60.0 + l.lexical_rank), 0.0),
    6
  ) AS rrf_hybrid_score
FROM semantic_candidates AS s
FULL OUTER JOIN lexical_candidates AS l
  ON s.search_event_id = l.search_event_id
  AND s.item_id = l.item_id;
