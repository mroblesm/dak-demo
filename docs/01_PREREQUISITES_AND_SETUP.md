# 01 — Prerequisites, Google Cloud SDK & VS Code + AGY + DAK Setup

This guide walks through setting up your local workstation to run the **Google Cloud Data Agent Kit (DAK)** end-to-end workflow in **VS Code** with **Antigravity (AGY)** (or any MCP/Skills-compatible coding agent such as Gemini CLI or Claude Code).

---

## 1. System Prerequisites

Ensure the following tools are installed on your machine (macOS or Linux):

| Tool | Minimum Version | Verification Command |
| :--- | :--- | :--- |
| **Google Cloud SDK (`gcloud`, `bq`)** | `480.0.0+` (with `beta` components) | `gcloud --version` |
| **Python** | `3.11+` | `python3 --version` |
| **Terraform** *(optional, for IaC setup)* | `1.5.0+` | `terraform --version` |
| **Docker** *(optional, for local container builds)* | `24.0+` | `docker --version` |
| **VS Code** / **Antigravity IDE** | Latest | `code --version` or `agy --version` |

### Install Google Cloud SDK Components
```bash
gcloud components install beta bq
gcloud components update
```

---

## 2. Google Cloud Authentication (CLI & Application Default Credentials)

Both `gcloud` CLI commands and Python SDKs (`google-cloud-bigquery`, `bigframes`, `google-cloud-dataproc-spark-connect`, `google-cloud-geminidataanalytics`) require active credentials.

```bash
# 1. Authenticate gcloud CLI
gcloud auth login

# 2. Authenticate Application Default Credentials (ADC) for Python & Terraform
gcloud auth application-default login

# 3. Set your target GCP Project ID and quota project
export GCP_PROJECT_ID="your-gcp-project-id"
gcloud config set project "${GCP_PROJECT_ID}"
gcloud auth application-default set-quota-project "${GCP_PROJECT_ID}"
```

---

## 3. Local Python Environment Setup

From the root of this repository, create a Python virtual environment and install the required packages:

```bash
python3 -m venv .venv
source .venv/bin/activate
pip install --upgrade pip
pip install -r requirements.txt
```

---

## 4. Setting Up Antigravity (AGY) & Data Agent Kit (DAK) in VS Code

Both **Antigravity (AGY)** and the **Google Cloud Data Agent Kit (DAK)** can be installed directly from the **VS Code Extensions Marketplace** (`Cmd+Shift+X` / `Ctrl+Shift+X`):

### Step 4.1: Install Extensions from the VS Code Marketplace
Open the Extensions view in VS Code and install:
1. **Antigravity (AGY)** — Provides the agentic coding assistant inside VS Code.
2. **Google Cloud Data Cloud / Data Agent Kit** (`GoogleCloudTools.datacloud`) — Automatically provisions the visual Data Cloud explorer (BigQuery, BigLake Iceberg catalogs, Property Graph viewer, Interactive Serverless Spark kernel picker with `SparkMonitor`, and Orchestration Pipelines UI) along with the **DAK agent skills (`@skill:...`) and MCP tools**.
3. **Jupyter** (`ms-toolsai.jupyter`) & **Python** (`ms-python.python`) — For running interactive BigFrames and Serverless Spark notebooks.

> *Optional (Standalone CLI Agents)*: If you also want to use the DAK skills outside VS Code (for example in standalone Claude Code or Gemini CLI), you can install them from the [GoogleCloudPlatform/data-agent-kit](https://github.com/GoogleCloudPlatform/data-agent-kit) repository.

### Step 4.2: Sign In to Google Cloud in the DAK Extension
1. Click the **Google Cloud Data Cloud** icon in the VS Code Activity Bar (left sidebar).
2. Click **Sign In to Google Cloud** and authenticate with the same Google Cloud account used in Step 2.
3. Select your target project (`your-gcp-project-id`).

---

## 5. Troubleshooting: Corporate SSL Proxy / Custom Root CA (`UNABLE_TO_GET_ISSUER_CERT`)

If your workstation sits behind a corporate SSL-inspecting proxy and signing into the DAK VS Code extension fails with:
```text
request to https://oauth2.googleapis.com/token failed, reason: unable to get issuer certificate (UNABLE_TO_GET_ISSUER_CERT)
```

1. **In VS Code Settings (`Cmd+,` / `Ctrl+,`)**:
   - Set `http.systemCertificates` to `true`.
   - Set `http.proxySupport` to `override` (or `on`).
2. **Pass the System CA Bundle to VS Code's Node.js Runtime**:
   Launch VS Code or Antigravity from your terminal with `NODE_EXTRA_CA_CERTS` pointing to your system root certificate bundle:
   ```bash
   # Linux:
   NODE_EXTRA_CA_CERTS=/etc/ssl/certs/ca-certificates.crt code .

   # macOS (using macOS / Homebrew CA bundle):
   NODE_EXTRA_CA_CERTS=/etc/ssl/cert.pem "/Applications/Visual Studio Code.app/Contents/Resources/app/bin/code" .
   ```

---

## Next Step
Proceed to **[02 — Greenfield Infrastructure Provisioning & Data Seeding](02_INFRASTRUCTURE_PROVISIONING.md)**.
