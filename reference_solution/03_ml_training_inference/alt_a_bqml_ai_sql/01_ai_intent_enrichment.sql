-- =============================================================================
-- Step 3 (Alternative 3A - Part 1): Structured Query Intent Extraction
-- Enforces @skill:developing-with-bigquery & @skill:bigquery-ai-rules:
--   Uses `AI.GENERATE_TABLE` with a strongly typed `output_schema` to parse
--   4+ token long-tail queries (e.g., "ergonomic mesh home office chair under 300")
--   into structured filter attributes (`room_type`, `material_preference`,
--   `style_tag`, `max_budget_usd`, `pet_safe_required`).
-- =============================================================================

SET @@maximum_bytes_billed = 10737418240; -- 10 GB FinOps safety cap

CREATE OR REPLACE TABLE `your-gcp-project-id.serving_clarity_intelligence.tail_query_intent_enriched` AS
SELECT
  search_event_id,
  normalized_query_text,
  query_length_tokens,
  room_type,
  material_preference,
  style_tag,
  max_budget_usd,
  pet_safe_required
FROM
  AI.GENERATE_TABLE(
    MODEL `your-gcp-project-id.serving_clarity_intelligence.gemini_flash_intent_model`,
    (
      SELECT DISTINCT
        search_event_id,
        normalized_query_text,
        query_length_tokens,
        CONCAT(
          'Extract structured retail home & furniture shopping attributes from this user search query: "',
          normalized_query_text,
          '". Return room_type, material_preference, style_tag, max_budget_usd (NULL if not specified), and pet_safe_required.'
        ) AS prompt
      FROM `your-gcp-project-id.modeled_search_warehouse.stg_search_events`
      WHERE query_tier = 'tail'
        AND event_date >= DATE_SUB(CURRENT_DATE(), INTERVAL 30 DAY)
    ),
    STRUCT(
      'room_type STRING, material_preference STRING, style_tag STRING, max_budget_usd FLOAT64, pet_safe_required BOOL' AS output_schema,
      0.0 AS temperature
    )
  );
