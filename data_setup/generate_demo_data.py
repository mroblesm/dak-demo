#!/usr/bin/env python3
"""Deterministic synthetic retail search, product catalog, and CLV generator for the DAK Demo.

Embeds three verifiable structural signals required by the Project Clarity demo:
1. Position Bias Rank Decay: Monotonic click & conversion decay from Rank 1 to Rank 10.
2. Tail Query Vocabulary Mismatch ("The Conversion Desert"): 4+ token long-tail queries
   suffer >3x higher zero-result rate and >40% lower CVR under legacy lexical search.
3. Intentional Raw Telemetry Dirtiness: Whitespace padding, mixed casing, NULL attributes,
   duplicate retry events, and automated scraper bots for @skill:data-autocleaning and
   Serverless Spark Medallion ETL to clean.
"""

from __future__ import annotations

import argparse
from datetime import datetime, timedelta, timezone
import json
from pathlib import Path
import random
from typing import Any


CATALOG_SEED_PRODUCTS = [
    ("SKU-1001", "AeroMesh Ergonomic Home Office Chair with Lumbar Support", "Furniture > Office > Office Chairs", "breathable mesh", "modern ergonomic", "home office", 279.00, 4.8),
    ("SKU-1002", "Executive Bonded Leather High-Back Desk Chair", "Furniture > Office > Office Chairs", "bonded leather", "traditional executive", "home office", 349.00, 4.5),
    ("SKU-1003", "Nordic Solid Oak Standing Desk 60 Inch Electric Height Adjustable", "Furniture > Office > Desks", "solid oak wood", "scandinavian minimalist", "home office", 529.00, 4.9),
    ("SKU-1004", "Compact Walnut Writing Desk with Built-In Cable Management", "Furniture > Office > Desks", "walnut veneer", "mid-century modern", "home office", 245.00, 4.6),
    ("SKU-1005", "CloudPlush Performance Velvet Emerald Sectional Sofa", "Furniture > Living Room > Sectionals", "stain-resistant velvet", "contemporary luxe", "living room", 1299.00, 4.7),
    ("SKU-1006", "Pet-Safe Performance Linen Slipcovered 3-Seater Couch", "Furniture > Living Room > Sofas", "weave performance linen", "coastal casual", "living room", 980.00, 4.8),
    ("SKU-1007", "Low-Light Indoor Calathea & Parlor Palm Live Plant Duo (Pet Non-Toxic)", "Decor > Plants > Indoor Live Plants", "organic Ceramic pot", "biophilic natural", "living room", 68.00, 4.9),
    ("SKU-1008", "Artisan Hand-Tufted Wool Geometric Area Rug 8x10", "Rugs > Area Rugs > Wool Rugs", "100% New Zealand wool", "bohemian geometric", "living room", 420.00, 4.6),
    ("SKU-1009", "Montessori Solid Birch Low Twin Platform Bed Frame", "Furniture > Bedroom > Kids Beds", "solid birch wood", "scandinavian minimalist", "bedroom", 310.00, 4.8),
    ("SKU-1010", "Hypoallergenic Cooling Bamboo King Mattress Topper", "Bedding > Mattress Toppers", "organic bamboo viscose", "modern comfort", "bedroom", 165.00, 4.7),
    ("SKU-1011", "Weatherproof Teak Outdoor Dining Set for 6 with Sunbrella Cushions", "Outdoor > Patio Dining > Dining Sets", "kiln-dried teak", "coastal outdoor", "patio", 1590.00, 4.8),
    ("SKU-1012", "Industrial Matte Black Narrow Entryway Console Table", "Furniture > Entryway > Console Tables", "powder-coated steel", "industrial modern", "entryway", 189.00, 4.5),
]

HEAD_QUERIES = [
    ("office chair", "SKU-1001"),
    ("standing desk", "SKU-1003"),
    ("velvet sofa", "SKU-1005"),
    ("area rug", "SKU-1008"),
    ("patio dining", "SKU-1011"),
    ("desk chair", "SKU-1002"),
]

TORSO_QUERIES = [
    ("oak standing desk", "SKU-1003"),
    ("walnut writing desk", "SKU-1004"),
    ("linen pet couch", "SKU-1006"),
    ("wool geometric rug", "SKU-1008"),
    ("narrow console table", "SKU-1012"),
]

TAIL_QUERIES = [
    ("ergonomic mesh home office chair under 300 lumbar support", "SKU-1001"),
    ("pet safe indoor low light live plants non toxic", "SKU-1007"),
    ("scratch resistant pet friendly performance linen sofa living room", "SKU-1006"),
    ("electric height adjustable solid oak standing desk home office", "SKU-1003"),
    ("kids low profile montessori solid birch twin bed frame", "SKU-1009"),
    ("cooling hypoallergenic bamboo king size mattress pad topper", "SKU-1010"),
    ("small space mid century walnut writing desk cable tray", "SKU-1004"),
    ("weather resistant teak patio dining table sunbrella chairs", "SKU-1011"),
]


def generate_datasets(output_dir: Path, seed: int = 42, num_sessions: int = 1200) -> dict[str, Any]:
    """Generate deterministic retail catalog, CLV, search telemetry, and ranked impressions."""
    rng = random.Random(seed)
    output_dir.mkdir(parents=True, exist_ok=True)

    # 1. Generate Catalog Items
    catalog_items: list[dict[str, Any]] = []
    for idx in range(48):
        base = CATALOG_SEED_PRODUCTS[idx % len(CATALOG_SEED_PRODUCTS)]
        sku_id = base[0] if idx < len(CATALOG_SEED_PRODUCTS) else f"SKU-{1001 + idx}"
        price_jitter = 1.0 if idx < len(CATALOG_SEED_PRODUCTS) else rng.uniform(0.85, 1.25)
        catalog_items.append({
            "item_id": sku_id,
            "product_title": base[1] if idx < len(CATALOG_SEED_PRODUCTS) else f"{base[1]} (Edition {idx})",
            "category_hierarchy": base[2],
            "material": base[3],
            "style_tag": base[4],
            "room_type": base[5],
            "price_usd": round(base[6] * price_jitter, 2),
            "average_rating": round(max(3.8, min(5.0, base[7] + rng.uniform(-0.2, 0.1))), 2),
            "in_stock": True if idx < 42 else rng.choice([True, False]),
            "product_description": (
                f"{base[1]} crafted with {base[3]} in a {base[4]} design for {base[5]} spaces."
            ),
        })

    catalog_by_id = {item["item_id"]: item for item in catalog_items}

    # 2. Generate Customer Lifecycle CLV Summary
    segments = ["VIP_PLATINUM", "HIGH_VALUE_GOLD", "CORE_REPEAT", "NEW_EXPLORER"]
    customers: list[dict[str, Any]] = []
    for c_idx in range(1, 201):
        seg = segments[c_idx % len(segments)]
        base_clv = {"VIP_PLATINUM": 2400.0, "HIGH_VALUE_GOLD": 1150.0, "CORE_REPEAT": 540.0, "NEW_EXPLORER": 210.0}[seg]
        customers.append({
            "customer_id": f"CUST-{c_idx:04d}",
            "clv_segment": seg,
            "historical_orders": rng.randint(1, 18) if seg != "NEW_EXPLORER" else 1,
            "predicted_12m_clv_usd": round(base_clv * rng.uniform(0.85, 1.25), 2),
            "preferred_style": rng.choice(["modern ergonomic", "scandinavian minimalist", "coastal casual", "mid-century modern"]),
        })

    # 3. Generate Search Events & Ranked Impressions
    base_time = datetime(2026, 9, 15, 12, 0, 0, tzinfo=timezone.utc)
    search_events: list[dict[str, Any]] = []
    search_impressions: list[dict[str, Any]] = []

    for s_idx in range(1, num_sessions + 1):
        event_id = f"SRCH-{s_idx:05d}"
        customer = rng.choice(customers)
        event_ts = base_time + timedelta(minutes=s_idx * 7 + rng.randint(0, 5))
        event_date = event_ts.strftime("%Y-%m-%d")

        # Choose query tier: 40% head, 25% torso, 35% tail
        tier_roll = rng.random()
        if tier_roll < 0.40:
            query_tier = "head"
            clean_query, target_sku = rng.choice(HEAD_QUERIES)
            zero_result_prob = 0.03
        elif tier_roll < 0.65:
            query_tier = "torso"
            clean_query, target_sku = rng.choice(TORSO_QUERIES)
            zero_result_prob = 0.11
        else:
            query_tier = "tail"
            clean_query, target_sku = rng.choice(TAIL_QUERIES)
            zero_result_prob = 0.36  # High zero-result rate under legacy lexical search

        # Inject intentional raw dirtiness on ~18% of rows for @skill:data-autocleaning
        raw_query = clean_query
        if s_idx % 5 == 0:
            raw_query = f"   {clean_query.upper()}  "
        elif s_idx % 7 == 0:
            raw_query = f" {clean_query.title()} "

        is_bot = (s_idx % 29 == 0)
        user_agent = "Mozilla/5.0 (compatible; PriceScraperBot/2.1)" if is_bot else "Mozilla/5.0 (Macintosh; Intel Mac OS X)"
        device_type = None if (s_idx % 11 == 0) else rng.choice(["desktop", "mobile_ios", "mobile_android"])

        zero_results_flag = 1 if (not is_bot and rng.random() < zero_result_prob) else 0
        token_count = len(clean_query.split())

        event_record = {
            "search_event_id": event_id,
            "customer_id": customer["customer_id"],
            "user_email": f"shopper.{customer['customer_id'].lower()}@example-retail.com",
            "ip_address": f"192.0.2.{(s_idx % 250) + 1}",
            "raw_query_text": raw_query,
            "normalized_query_text": clean_query,
            "query_length_tokens": token_count,
            "query_tier": query_tier,
            "device_type": device_type,
            "user_agent": user_agent,
            "zero_results_flag": zero_results_flag,
            "search_algorithm_arm": rng.choice(["ARM_A_LEGACY_LEXICAL", "ARM_B_HYBRID_VECTOR", "ARM_C_CLARITY_RERANKED"]),
            "event_timestamp": event_ts.isoformat(),
            "event_date": event_date,
        }
        search_events.append(event_record)

        # Inject duplicate retry event on ~4% of rows so deduplication rules are exercised
        if s_idx % 25 == 0:
            dup_record = dict(event_record)
            dup_record["event_timestamp"] = (event_ts - timedelta(seconds=2)).isoformat()
            search_events.append(dup_record)

        if is_bot or zero_results_flag == 1:
            continue

        # Generate top 10 ranked impressions for non-bot, non-zero-result searches
        # Under legacy lexical search, tail queries often bury the Exact match at Rank 6-10
        target_rank = rng.choice([1, 2, 3]) if query_tier == "head" else (
            rng.choice([2, 3, 4, 5]) if query_tier == "torso" else rng.choice([5, 6, 7, 8, 9])
        )

        other_skus = [sku for sku in catalog_by_id if sku != target_sku]
        sampled_others = rng.sample(other_skus, 9)

        for rank in range(1, 11):
            sku = target_sku if rank == target_rank else sampled_others.pop()
            item = catalog_by_id[sku]
            if sku == target_sku:
                relevance_grade = "Exact"
                semantic_sim = round(rng.uniform(0.84, 0.97), 4)
                lexical_bm25 = round(rng.uniform(0.65, 0.92) if query_tier != "tail" else rng.uniform(0.22, 0.48), 4)
                intrinsic_rel_prob = 0.62 if query_tier != "tail" else 0.34
            elif item["room_type"] == catalog_by_id[target_sku]["room_type"]:
                relevance_grade = "Partial"
                semantic_sim = round(rng.uniform(0.58, 0.79), 4)
                lexical_bm25 = round(rng.uniform(0.35, 0.68), 4)
                intrinsic_rel_prob = 0.22 if query_tier != "tail" else 0.09
            else:
                relevance_grade = "Irrelevant"
                semantic_sim = round(rng.uniform(0.15, 0.45), 4)
                lexical_bm25 = round(rng.uniform(0.10, 0.40), 4)
                intrinsic_rel_prob = 0.04 if query_tier != "tail" else 0.015

            # Structural Position Bias Decay: P(examine | rank k) = 1 / (k ^ 0.72)
            examination_prob = 1.0 / (rank ** 0.72)
            click_prob = examination_prob * intrinsic_rel_prob
            clicked = 1 if rng.random() < click_prob else 0

            # Conversion conditional on click & relevance
            conv_cond_prob = 0.28 if (relevance_grade == "Exact" and query_tier != "tail") else (
                0.18 if (relevance_grade == "Exact" and query_tier == "tail") else (
                    0.07 if relevance_grade == "Partial" else 0.01
                )
            )
            purchased = 1 if (clicked == 1 and rng.random() < conv_cond_prob) else 0
            attributed_revenue = round(item["price_usd"], 2) if purchased == 1 else 0.0

            search_impressions.append({
                "impression_id": f"{event_id}-R{rank:02d}",
                "search_event_id": event_id,
                "customer_id": customer["customer_id"],
                "item_id": sku,
                "query_tier": query_tier,
                "query_length_tokens": token_count,
                "displayed_rank_position": rank,
                "lexical_bm25_score": lexical_bm25,
                "semantic_cosine_similarity": semantic_sim,
                "historical_item_ctr": round(0.04 + 0.12 * (1.0 if relevance_grade == "Exact" else 0.3), 4),
                "price_usd": item["price_usd"],
                "average_rating": item["average_rating"],
                "customer_clv_segment": customer["clv_segment"],
                "latent_relevance_grade": relevance_grade,
                "clicked": clicked,
                "purchased": purchased,
                "attributed_revenue_usd": attributed_revenue,
                "event_timestamp": event_ts.isoformat(),
                "event_date": event_date,
            })

    # Write JSONL, JSON, and CSV files (for BigQuery & Databricks Unity Catalog / Iceberg upload)
    import csv

    files_written = {}
    for name, records in [
        ("catalog_items", catalog_items),
        ("customer_clv", customers),
        ("search_events", search_events),
        ("search_impressions", search_impressions),
    ]:
        json_path = output_dir / f"{name}.json"
        with open(json_path, "w", encoding="utf-8") as f:
            json.dump(records, f, indent=2)
        jsonl_path = output_dir / f"{name}.jsonl"
        with open(jsonl_path, "w", encoding="utf-8") as f:
            for row in records:
                f.write(json.dumps(row) + "\n")
        csv_path = output_dir / f"{name}.csv"
        if records:
            with open(csv_path, "w", encoding="utf-8", newline="") as f:
                writer = csv.DictWriter(f, fieldnames=list(records[0].keys()))
                writer.writeheader()
                writer.writerows(records)
        files_written[name] = len(records)

    summary = {
        "seed": seed,
        "output_dir": str(output_dir),
        "row_counts": files_written,
    }
    print(json.dumps(summary, indent=2))
    return summary


def main() -> None:
    parser = argparse.ArgumentParser(description="Generate synthetic Project Clarity datasets for DAK demo.")
    parser.add_argument("--output-dir", type=Path, default=Path("data_setup/generated"))
    parser.add_argument("--seed", type=int, default=42)
    parser.add_argument("--num-sessions", type=int, default=1200)
    args = parser.parse_args()
    generate_datasets(args.output_dir, seed=args.seed, num_sessions=args.num_sessions)


if __name__ == "__main__":
    main()
