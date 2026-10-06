"""Tests for Step 5 Cloud Run Presentation Layer Applications (Alt 5A React/FastAPI & Alt 5B Streamlit)."""

from __future__ import annotations

import importlib.util
from pathlib import Path


REPO_ROOT = Path(__file__).resolve().parent.parent
REF_ROOT = REPO_ROOT / "reference_solution"


def _load_fastapi_module():
    app_path = REF_ROOT / "05_presentation_app" / "alt_a_react_cloud_run" / "backend" / "app.py"
    spec = importlib.util.spec_from_file_location("clarity_fastapi_app", app_path)
    assert spec is not None and spec.loader is not None
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


def test_alt_5a_fastapi_endpoints_and_frontend_assets() -> None:
    module = _load_fastapi_module()

    health = module.health_check()
    assert health["status"] == "healthy"

    dashboard = module.get_dashboard_data()
    assert len(dashboard["kpi_cards"]) == 4
    assert len(dashboard["query_cohorts_table"]) >= 4

    cohort = module.get_cohort_investigation("Q-TAIL-01")
    assert cohort["cohort_id"] == "Q-TAIL-01"
    assert len(cohort["diagnostic_hypotheses"]) >= 2
    assert "completeness" in cohort["trust_4d_audit"]
    assert "bytes_billed" in cohort["finops_receipt"]

    chat_resp = module.post_conversational_analytics(
        module.ChatRequest(question="Which home office chair SKU gained the highest lift?")
    )
    assert "SKU-1001" in chat_resp["answer"]
    assert "DataChatServiceClient" in chat_resp["engine"]

    # Check frontend HTML & JS for @skill:web-app-development requirements
    html_text = (REF_ROOT / "05_presentation_app" / "alt_a_react_cloud_run" / "frontend" / "index.html").read_text(encoding="utf-8")
    js_text = (REF_ROOT / "05_presentation_app" / "alt_a_react_cloud_run" / "frontend" / "app.js").read_text(encoding="utf-8")
    assert "echarts.min.js" in html_text
    assert "investigation-drawer" in html_text
    assert "finops-ledger-btn" in html_text
    assert "finops-ledger-banner" in html_text
    assert "openInvestigationDrawer" in js_text


def test_alt_5b_streamlit_cloud_run_assets() -> None:
    st_dir = REF_ROOT / "05_presentation_app" / "alt_b_streamlit_cloud_run"
    main_py_path = st_dir / "main.py"
    main_py = main_py_path.read_text(encoding="utf-8")
    config_toml = (st_dir / ".streamlit" / "config.toml").read_text(encoding="utf-8")
    dockerfile = (st_dir / "Dockerfile").read_text(encoding="utf-8")

    assert (st_dir / "mock_demo_payloads.json").exists()
    assert "@st.cache_data(ttl=600)" in main_py
    assert "DataChatServiceClient" in main_py
    assert "st.tabs" in main_py
    assert "port = 8080" in config_toml
    assert "8080" in dockerfile
    assert "mock_demo_payloads.json" in dockerfile

    spec = importlib.util.spec_from_file_location("clarity_streamlit_app", main_py_path)
    assert spec is not None and spec.loader is not None
    st_mod = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(st_mod)
    payload = st_mod.fetch_clarity_dashboard_payload()
    assert len(payload["kpi_cards"]) == 4
    ans = st_mod.invoke_conversational_data_agent("What is the long-tail CVR lift?")
    assert "DataChatServiceClient" in ans
