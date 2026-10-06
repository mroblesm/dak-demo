# ==============================================================================
# Step 5 (Alternative 5B): Cloud Run Container for Streamlit Data App
# Enforces @skill:streamlit-data-app packaging standard (Port 8080)
# ==============================================================================
FROM python:3.11-slim

WORKDIR /app

COPY requirements.txt /app/requirements.txt
RUN pip install --no-cache-dir -r /app/requirements.txt

COPY .streamlit/ /app/.streamlit/
COPY mock_demo_payloads.json /app/mock_demo_payloads.json
COPY main.py /app/main.py

ENV PORT=8080
EXPOSE 8080

CMD ["streamlit", "run", "main.py", "--server.port=8080", "--server.address=0.0.0.0"]
