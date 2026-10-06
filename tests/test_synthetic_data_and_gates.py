"""Tests for synthetic data generation and behavioral Insight Gates (`insight_gate.py`)."""

from __future__ import annotations

from pathlib import Path

from data_setup.generate_demo_data import generate_datasets
from data_setup.insight_gate import run_insight_gates


REPO_ROOT = Path(__file__).resolve().parent.parent
GENERATED_DIR = REPO_ROOT / "data_setup" / "generated"


def test_synthetic_data_generation_and_behavioral_gates() -> None:
    if not (GENERATED_DIR / "search_events.json").exists():
        generate_datasets(GENERATED_DIR, seed=42, num_sessions=1200)

    report = run_insight_gates(GENERATED_DIR)
    assert report["overall_status"] == "PASS"

    gates = report["gates"]
    assert gates["gate_1_position_bias_rank_decay"]["status"] == "PASS"
    assert gates["gate_1_position_bias_rank_decay"]["rank_1_to_10_ratio"] >= 2.5

    assert gates["gate_2_tail_vocabulary_mismatch"]["status"] == "PASS"
    assert gates["gate_2_tail_vocabulary_mismatch"]["tail_to_head_zero_result_ratio"] >= 3.0
    assert gates["gate_2_tail_vocabulary_mismatch"]["relative_tail_cvr_drop_pct"] >= 40.0

    assert gates["gate_3_leak_scan"]["status"] == "PASS"
    assert gates["gate_3_leak_scan"]["leaked_columns_detected"] == []

    assert gates["gate_4_autocleaning_dirtiness_seeded"]["status"] == "PASS"
    assert gates["gate_4_autocleaning_dirtiness_seeded"]["whitespace_or_casing_anomalies"] > 50
    assert gates["gate_4_autocleaning_dirtiness_seeded"]["scraper_bot_rows"] > 10
    assert gates["gate_4_autocleaning_dirtiness_seeded"]["duplicate_retry_rows"] > 10
