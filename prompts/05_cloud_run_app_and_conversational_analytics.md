@skill:web-app-development @skill:streamlit-data-app
Read the project configuration from .env (or .env.example if .env is not present: GCP_PROJECT_ID, GCP_REGION, SERVING_DATASET_ID, DATA_AGENT_ID).
Create `workspace/05_presentation_app/alt_a_react_cloud_run/` and generate a production-ready Cloud Run application (port `8080`) with the following files:

1. `workspace/05_presentation_app/alt_a_react_cloud_run/backend/app.py` & `backend/mock_demo_payloads.json`:
   - FastAPI backend serving `/api/health`, `/api/dashboard`, `/api/cohorts/{cohort_id}`, `/api/finops`, `/api/chat`, and `/api/chat/stream` (Server-Sent Events), plus static frontend routes `/` (`frontend/index.html`) and `/app.js` (`frontend/app.js`).
   - Implement `query_gemini_data_analytics_agent(question, ca_mode, history)` using `google.cloud.geminidataanalytics.DataChatServiceClient`, supporting both:
     - `ca_mode="custom_data_agent"`: Uses `DataAgentContext(data_agent=f"projects/{project_id}/locations/{location}/dataAgents/{agent_id}")`.
     - `ca_mode="inline_context"`: Uses `Context(datasource_references=DatasourceReferences(bq=BigQueryTableReferences(table_references=[...])))` pointing to native BigQuery Gold tables (`serving_clarity_intelligence.clarity_reranked_search_results`, `category_demand_forecast_30d`, and `modeled_search_warehouse.fct_search_conversions`).
   - Include a deterministic fallback when `DEMO_OFFLINE_FALLBACK=true` or when offline so local testing and CI always succeed.

2. `workspace/05_presentation_app/alt_a_react_cloud_run/frontend/index.html` & `frontend/app.js`:
   - React 18 UMD + Tailwind CSS + Apache ECharts 5.5 executive dashboard featuring:
     - **Header**: Dark/Light theme toggle and collapsible **FinOps 'Show Your Work' Cost & Byte Ledger Banner** (`#finops-ledger-btn`, `#finops-ledger-banner`).
     - **4 KPI Cards**: Long-Tail Query CVR (`2.84%`, `+158.2% lift`), Revenue Per 1,000 Searches (`$142.60`, `+$48.20`), Tail Zero-Result Rate (`8.4%`, `-29.6 pts`), and **4D Data & Model Trust Score (`96.4%`)**.
     - **2 Apache ECharts Visualizations**: (1) A/B/C Experiment CVR % by Query Tier (`Arm A: Legacy Lexical`, `Arm B: Hybrid Vector RRF`, `Arm C: Clarity BQML Re-Ranked`) and (2) 30-Day `AI.FORECAST` Category Revenue Forecast with 95% confidence bounds.
     - **Interactive Query Cohort Table & Slide-Out Investigation Drawer (`#investigation-drawer`)**: Clicking any cohort row opens the Slide-Out Root-Cause Investigation Drawer displaying Multi-Hypothesis Root-Cause evidence (`diagnostic_hypotheses`), 4D Data Trust breakdown (`trust_4d_audit`), and FinOps Byte/Cost Query Receipt (`finops_receipt`).
     - **BigQuery Conversational Analytics Chat**: Mode toggle pill switching between `Custom BQ CA Data Agent (data_agent_context)` and `Stateless CA API (inline_context)`, collapsible reasoning thoughts, generated BigQuery SQL viewer, and interactive follow-up suggestion chips.

3. `workspace/05_presentation_app/alt_a_react_cloud_run/Dockerfile`, `requirements.txt`, & `deploy_cloud_run.sh`:
   - `python:3.11-slim` container running as non-root `appuser` on port `8080` with `/api/health` `HEALTHCHECK`.
   - `deploy_cloud_run.sh` (supporting `--dry-run`) deploying via `gcloud run deploy clarity-search-intelligence-app --source=... --port=8080 --memory=2Gi --cpu=1 --min-instances=0 --max-instances=10`.
