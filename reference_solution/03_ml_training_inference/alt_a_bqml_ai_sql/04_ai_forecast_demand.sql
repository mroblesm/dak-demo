-- =============================================================================
-- Step 3 (Alternative 3A - Part 4): Zero-Shot Category Demand Forecasting
-- Enforces @skill:developing-with-bigquery (`reference/ai-forecast.md`):
--   Uses BigQuery's built-in `AI.FORECAST` powered by TimesFM 2.0 to generate
--   a 30-day conversion revenue forecast across query tiers with 95% confidence
--   intervals—requiring zero manual ARIMA model creation!
-- =============================================================================

SET @@maximum_bytes_billed = 10737418240; -- 10 GB FinOps safety cap

CREATE OR REPLACE TABLE `your-gcp-project-id.serving_clarity_intelligence.category_demand_forecast_30d` AS
WITH daily_tier_revenue AS (
  SELECT
    event_date,
    query_tier,
    ROUND(SUM(attributed_revenue_usd), 2) AS daily_revenue_usd
  FROM `your-gcp-project-id.modeled_search_warehouse.fct_search_conversions`
  WHERE event_date IS NOT NULL
  GROUP BY event_date, query_tier
)

SELECT
  query_tier,
  forecast_timestamp,
  ROUND(forecast_value, 2) AS forecasted_daily_revenue_usd,
  ROUND(prediction_interval_lower_bound, 2) AS ci_95_lower_usd,
  ROUND(prediction_interval_upper_bound, 2) AS ci_95_upper_usd,
  confidence_level
FROM
  AI.FORECAST(
    TABLE daily_tier_revenue,
    data_col => 'daily_revenue_usd',
    timestamp_col => 'event_date',
    id_cols => ['query_tier'],
    horizon => 30,
    confidence_level => 0.95
  )
ORDER BY query_tier, forecast_timestamp;
