FROM python:3.11-slim

WORKDIR /app

# Install production dependencies
COPY requirements-prod.txt .
RUN pip install --no-cache-dir -r requirements-prod.txt

# Copy runtime code and processed data
COPY src/ ./src/
COPY data/processed/ ./data/processed/
COPY mlops/ ./mlops/
COPY static/ ./static/
# Required for auto-retrain fallback path in model_loader.py
COPY notebooks/weekly.csv ./notebooks/weekly.csv

EXPOSE 8000

CMD ["uvicorn", "src.api.main:app", "--host", "0.0.0.0", "--port", "8000"]
