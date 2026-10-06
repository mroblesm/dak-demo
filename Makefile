.PHONY: help generate-data verify-gates provision-dry-run validate-orchestration test run-react-app run-streamlit-app clean

VENV_PYTHON := .venv/bin/python
PYTHON ?= $(shell if [ -x "$(VENV_PYTHON)" ]; then echo "$(VENV_PYTHON)"; else echo "python3"; fi)

help:
	@echo "Google Cloud Data Agent Kit (DAK) — End-to-End Reference Commands:"
	@echo "  make generate-data          Generate synthetic retail catalog, search telemetry, and CLV datasets"
	@echo "  make verify-gates           Run behavioral Insight Gate (rank decay, tail mismatch, zero leakage)"
	@echo "  make provision-dry-run      Execute GCP 3-tier Data Mesh & BigLake Iceberg provisioning in dry-run mode"
	@echo "  make validate-orchestration Validate declarative Orchestration Pipelines YAML files"
	@echo "  make test                   Run full verification suite across all DAK reference assets"
	@echo "  make run-react-app          Start Alternative 5A (React 18 + Apache ECharts + FastAPI) on port 8080"
	@echo "  make run-streamlit-app      Start Alternative 5B (Streamlit + Gemini Data Analytics) on port 8501"

generate-data:
	$(PYTHON) -m data_setup.generate_demo_data --output-dir data_setup/generated

verify-gates:
	$(PYTHON) -m data_setup.insight_gate --data-dir data_setup/generated

provision-dry-run:
	bash infra/provision_demo_infra.sh --dry-run

validate-orchestration:
	bash reference_solution/04_orchestration/alt_a_orchestration_pipelines/validate_and_deploy.sh --dry-run

test: generate-data
	$(PYTHON) -m pytest tests/ -v

run-react-app:
	PYTHONPATH=reference_solution $(PYTHON) -m uvicorn 05_presentation_app.alt_a_react_cloud_run.backend.app:app --host 0.0.0.0 --port 8080

run-streamlit-app:
	streamlit run reference_solution/05_presentation_app/alt_b_streamlit_cloud_run/main.py --server.port 8501

clean:
	rm -rf data_setup/generated .pytest_cache __pycache__ */__pycache__ */*/__pycache__
