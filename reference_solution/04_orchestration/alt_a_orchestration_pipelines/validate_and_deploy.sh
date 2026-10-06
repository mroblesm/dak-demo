#!/usr/bin/env bash
# ==============================================================================
# Validate and Deploy Declarative Orchestration Pipeline Bundle
# Enforces @skill:gcp-data-cloud-pipeline-orchestration-definition-skill
# ==============================================================================
set -euo pipefail

DRY_RUN=false
if [[ "${1:-}" == "--dry-run" ]]; then
  DRY_RUN=true
fi

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ENV_TARGET="${ORCHESTRATION_ENV:-dev}"

echo "========================================================================"
echo " 1. Validating deployment.yaml & orchestration-pipeline.yaml Schema"
echo "========================================================================"
python3 - "${SCRIPT_DIR}" <<'PY'
from pathlib import Path
import re
import sys

bundle_dir = Path(sys.argv[1])
dep_text = (bundle_dir / "deployment.yaml").read_text(encoding="utf-8")
pipe_text = (bundle_dir / "orchestration-pipeline.yaml").read_text(encoding="utf-8")

assert "environments:" in dep_text, "Missing 'environments:' root key in deployment.yaml"
for env_name in ("dev:", "staging:", "prod:"):
    assert env_name in dep_text, f"Missing environment {env_name} in deployment.yaml"
assert "composer_environment:" in dep_text, "Missing 'composer_environment:' key in deployment.yaml"
assert re.search(r"artifact_storage:\s*\n\s+bucket:", dep_text), "artifact_storage must be a composite object with bucket"
assert re.search(r"path_prefix:", dep_text), "artifact_storage must include path_prefix"

for key in ("modelVersion:", "pipelineId:", "runner:", "triggers:", "startTime:", "endTime:", "tags:", "actions:", "dependsOn:"):
    assert key in pipe_text, f"Missing mandatory key '{key}' in orchestration-pipeline.yaml"
assert "job:datacloud:vscode" in pipe_text, "Missing mandatory 'job:datacloud:vscode' tag"

print("[SCHEMA VALIDATION PASS] deployment.yaml and orchestration-pipeline.yaml conform to v1.0 Orchestration Pipelines schema.")
PY

echo ""
echo "========================================================================"
echo " 2. Executing gcloud beta orchestration-pipelines validate & deploy"
echo "========================================================================"
if [[ "$DRY_RUN" == "true" ]]; then
  echo "[DRY-RUN] gcloud beta orchestration-pipelines deploy --environment=${ENV_TARGET} --local --validate"
  echo "[DRY-RUN] gcloud beta orchestration-pipelines deploy --environment=${ENV_TARGET} --local --no-paused"
else
  (cd "${SCRIPT_DIR}" && gcloud beta orchestration-pipelines deploy --environment="${ENV_TARGET}" --local --validate)
  (cd "${SCRIPT_DIR}" && gcloud beta orchestration-pipelines deploy --environment="${ENV_TARGET}" --local --no-paused)
fi
