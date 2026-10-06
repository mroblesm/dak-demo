#!/usr/bin/env python3
"""Behavioral Insight Gate (`insight_gate.py`) for the Google Cloud Data Agent Kit Demo.

Implements Lesson 1 from Agentic Data Engineering & ML Best Practices:
Never accept "file exists" or `ROW_COUNT > 0` as done. Before running dbt, Serverless Spark,
or BQML training, statistically verify that the synthetic dataset embeds:
  1. Gate 1 — Position Bias Rank Decay: Rank 1 CTR > Rank 5 CTR > Rank 10 CTR.
  2. Gate 2 — Tail Query Vocabulary Mismatch ("The Conversion Desert"):
     - Tail (4+ tokens) zero-result rate > 3.0x Head (1-2 tokens) zero-result rate.
     - Tail session conversion rate (CVR) is >40% lower than Head session CVR.
  3. Gate 3 — Zero Target Leakage (`leak_scan`):
     - Training feature columns must not include any post-click or post-purchase fields.
  4. Gate 4 — Intentional Raw Data Dirtiness Present:
     - Verifies whitespace/casing anomalies, NULL device_types, duplicates, and bot rows exist
       so `@skill:data-autocleaning` and Serverless Spark Medallion ETL are truly tested.
"""

from __future__ import annotations

import argparse
import json
from pathlib import Path
import sys
from typing import Any


TRAINING_FEATURE_COLUMNS = [
    "query_length_tokens",
    "displayed_rank_position",
    "lexical_bm25_score",
    "semantic_cosine_similarity",
    "historical_item_ctr",
    "price_usd",
    "average_rating",
    "customer_clv_segment",
]

FORBIDDEN_LEAKAGE_PATTERNS = (
    "clicked",
    "purchased",
    "attributed_revenue",
    "post_click",
    "order_total",
    "conversion_timestamp",
    "checkout_",
)


def run_insight_gates(data_dir: Path) -> dict[str, Any]:
    """Evaluate all statistical and leakage gates on generated demo data."""
    events_path = data_dir / "search_events.json"
    impressions_path = data_dir / "search_impressions.json"

    if not events_path.exists() or not impressions_path.exists():
        raise FileNotFoundError(
            f"Generated data not found in {data_dir}. Run `python3 -m data_setup.generate_demo_data` first."
        )

    with open(events_path, "r", encoding="utf-8") as f:
        events = json.load(f)
    with open(impressions_path, "r", encoding="utf-8") as f:
        impressions = json.load(f)

    # -------------------------------------------------------------------------
    # Gate 1: Position Bias Rank Decay (Rank 1 > Rank 5 > Rank 10)
    # -------------------------------------------------------------------------
    by_rank: dict[int, list[int]] = {1: [], 5: [], 10: []}
    for imp in impressions:
        r = imp["displayed_rank_position"]
        if r in by_rank:
            by_rank[r].append(imp["clicked"])

    ctr_r1 = sum(by_rank[1]) / max(1, len(by_rank[1]))
    ctr_r5 = sum(by_rank[5]) / max(1, len(by_rank[5]))
    ctr_r10 = sum(by_rank[10]) / max(1, len(by_rank[10]))
    gate_1_pass = (ctr_r1 > ctr_r5 > ctr_r10) and (ctr_r1 / max(0.0001, ctr_r10) >= 2.5)

    # -------------------------------------------------------------------------
    # Gate 2: Tail Vocabulary Mismatch ("The Conversion Desert")
    # -------------------------------------------------------------------------
    non_bot_events = [e for e in events if "ScraperBot" not in e["user_agent"]]
    # Deduplicate by search_event_id for ground-truth session check
    dedup_events = {e["search_event_id"]: e for e in non_bot_events}

    head_events = [e for e in dedup_events.values() if e["query_tier"] == "head"]
    tail_events = [e for e in dedup_events.values() if e["query_tier"] == "tail"]

    head_zero_rate = sum(e["zero_results_flag"] for e in head_events) / max(1, len(head_events))
    tail_zero_rate = sum(e["zero_results_flag"] for e in tail_events) / max(1, len(tail_events))

    purchased_by_event: dict[str, int] = {}
    for imp in impressions:
        eid = imp["search_event_id"]
        purchased_by_event[eid] = max(purchased_by_event.get(eid, 0), imp["purchased"])

    head_cvr = sum(purchased_by_event.get(e["search_event_id"], 0) for e in head_events) / max(1, len(head_events))
    tail_cvr = sum(purchased_by_event.get(e["search_event_id"], 0) for e in tail_events) / max(1, len(tail_events))

    zero_rate_ratio = tail_zero_rate / max(0.001, head_zero_rate)
    cvr_drop_pct = (head_cvr - tail_cvr) / max(0.0001, head_cvr)
    gate_2_pass = (zero_rate_ratio >= 3.0) and (cvr_drop_pct >= 0.40)

    # -------------------------------------------------------------------------
    # Gate 3: Zero Target Leakage (`leak_scan`)
    # -------------------------------------------------------------------------
    leaked_columns = [
        col for col in TRAINING_FEATURE_COLUMNS
        if any(pat in col.lower() for pat in FORBIDDEN_LEAKAGE_PATTERNS)
    ]
    missing_in_schema = [col for col in TRAINING_FEATURE_COLUMNS if col not in impressions[0]]
    gate_3_pass = (len(leaked_columns) == 0) and (len(missing_in_schema) == 0)

    # -------------------------------------------------------------------------
    # Gate 4: Intentional Raw Data Dirtiness for @skill:data-autocleaning
    # -------------------------------------------------------------------------
    whitespace_or_upper_count = sum(
        1 for e in events
        if e["raw_query_text"] != e["raw_query_text"].strip() or e["raw_query_text"] != e["raw_query_text"].lower()
    )
    null_device_count = sum(1 for e in events if e["device_type"] is None)
    bot_event_count = sum(1 for e in events if "ScraperBot" in e["user_agent"])
    duplicate_event_count = len(events) - len({e["search_event_id"] for e in events})
    gate_4_pass = (
        whitespace_or_upper_count > 50
        and null_device_count > 20
        and bot_event_count > 10
        and duplicate_event_count > 10
    )

    all_passed = gate_1_pass and gate_2_pass and gate_3_pass and gate_4_pass

    report = {
        "overall_status": "PASS" if all_passed else "FAIL",
        "gates": {
            "gate_1_position_bias_rank_decay": {
                "status": "PASS" if gate_1_pass else "FAIL",
                "rank_1_ctr": round(ctr_r1, 4),
                "rank_5_ctr": round(ctr_r5, 4),
                "rank_10_ctr": round(ctr_r10, 4),
                "rank_1_to_10_ratio": round(ctr_r1 / max(0.0001, ctr_r10), 2),
            },
            "gate_2_tail_vocabulary_mismatch": {
                "status": "PASS" if gate_2_pass else "FAIL",
                "head_zero_result_rate": round(head_zero_rate, 4),
                "tail_zero_result_rate": round(tail_zero_rate, 4),
                "tail_to_head_zero_result_ratio": round(zero_rate_ratio, 2),
                "head_session_cvr": round(head_cvr, 4),
                "tail_session_cvr": round(tail_cvr, 4),
                "relative_tail_cvr_drop_pct": round(cvr_drop_pct * 100.0, 1),
            },
            "gate_3_leak_scan": {
                "status": "PASS" if gate_3_pass else "FAIL",
                "verified_feature_columns": TRAINING_FEATURE_COLUMNS,
                "leaked_columns_detected": leaked_columns,
            },
            "gate_4_autocleaning_dirtiness_seeded": {
                "status": "PASS" if gate_4_pass else "FAIL",
                "whitespace_or_casing_anomalies": whitespace_or_upper_count,
                "null_device_rows": null_device_count,
                "scraper_bot_rows": bot_event_count,
                "duplicate_retry_rows": duplicate_event_count,
            },
        },
    }
    return report


def main() -> None:
    parser = argparse.ArgumentParser(description="Run Project Clarity Behavioral Insight Gates.")
    parser.add_argument("--data-dir", type=Path, default=Path("data_setup/generated"))
    args = parser.parse_args()

    report = run_insight_gates(args.data_dir)
    print(json.dumps(report, indent=2))
    if report["overall_status"] != "PASS":
        sys.exit(1)


if __name__ == "__main__":
    main()
