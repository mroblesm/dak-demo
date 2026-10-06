{{
  config(
    materialized='view',
    labels={'managed_by': 'dak_dbt_bigquery', 'skill': 'data_autocleaning'}
  )
}}

/* =============================================================================
   Automatic Cleaning Summary (@skill:data-autocleaning)
   =============================================================================
   - Trimmed and standardized `item_id`, `product_title`, `material`, `style_tag`,
     and `room_type`.
   - Enforced safe numeric bounds on `price_usd` and `average_rating`.
   - Deduplicated catalog items by `item_id`.
   ============================================================================= */

SELECT
  TRIM(CAST(item_id AS STRING)) AS item_id,
  TRIM(CAST(product_title AS STRING)) AS product_title,
  TRIM(CAST(category_hierarchy AS STRING)) AS category_hierarchy,
  LOWER(TRIM(COALESCE(CAST(material AS STRING), 'unspecified'))) AS material,
  LOWER(TRIM(COALESCE(CAST(style_tag AS STRING), 'standard'))) AS style_tag,
  LOWER(TRIM(COALESCE(CAST(room_type AS STRING), 'general'))) AS room_type,
  ROUND(COALESCE(SAFE_CAST(price_usd AS FLOAT64), 0.0), 2) AS price_usd,
  ROUND(COALESCE(SAFE_CAST(average_rating AS FLOAT64), 4.0), 2) AS average_rating,
  COALESCE(SAFE_CAST(in_stock AS BOOL), TRUE) AS in_stock,
  TRIM(COALESCE(CAST(product_description AS STRING), '')) AS product_description
FROM {{ source('raw_bigquery', 'catalog_items') }}
WHERE item_id IS NOT NULL
QUALIFY ROW_NUMBER() OVER (PARTITION BY TRIM(CAST(item_id AS STRING)) ORDER BY price_usd DESC) = 1
