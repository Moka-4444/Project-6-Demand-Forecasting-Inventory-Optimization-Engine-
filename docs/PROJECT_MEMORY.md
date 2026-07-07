# StockSense — System Context & Architecture Memory Bank 🧠🔒

> **Purpose:** This document serves as an authoritative, permanent system repository memory bank. It is specifically designed to protect against LLM context window truncations or session restarts by preserving all critical architectural decisions, file mappings, endpoint schemas, and execution commands.

---

## 📸 1. System State Snapshot
- **Project Status:** Complete, tested, and ready for Stage 1 Azure App Service deployment.
- **Core Engine:** Validated 3-model machine learning ensemble predicting FMCG product demand across 4-week horizons.
- **Backend API:** FastAPI server (`src/api/main.py`) running with in-memory Bearer token authentication and automated model/encoder loading on startup via lifecycle events.
- **Frontend App:** StockSense Flutter mobile client (`stocksense/`) with responsive grid layouts, sub-pixel sparkline charts, dynamic dark/light mode toggle, and role-based views.
- **MLOps Automation:** Population Stability Index (PSI) data drift monitoring (`mlops/monitoring/drift_detector.py`) and background retraining script (`mlops/retraining/retrain_pipeline.py`).
- **Containerization:** Production Docker image optimized via `requirements-prod.txt` and `.dockerignore`, keeping image size <1.5GB.

---

## 🏛️ 2. Key Technical Decisions Log

### Decision 1: Discarding Prophet & SARIMA in Favor of Tree-Linear Ensemble
During Milestone 2 benchmarking (`02_model_development.ipynb`), standard time-series models (Facebook Prophet and SARIMA via `statsmodels`) were evaluated against machine learning models.
- **Outcome:** Both Prophet and SARIMA were discarded.
- **Rationale:** The weighted ensemble of **XGBoost (45%)**, **Random Forest (35%)**, and **Ridge Regression (20%)** achieved significantly lower Weighted Mean Absolute Percentage Error (WMAPE) while executing inference in milliseconds. Furthermore, removing Prophet eliminated heavy C++ compiler dependencies (`cmdstanpy`), reducing production Docker build times from >5 minutes down to ~15 seconds.

### Decision 2: Root Directory as Sole Source of Truth
Earlier iterations of the project split source code between the project root and a subfolder named `Demand Forecasting Inventory Optimization Refined/`.
- **Outcome:** All code, MLOps pipelines, data files, and mobile apps were promoted directly to the root project workspace.
- **Rationale:** Maintaining duplicate folder trees caused build confusion and bloated Docker build contexts. The root directory (`Project-6-Demand-Forecasting-Inventory-Optimization-Engine-`) is now the sole source of truth. The legacy `Refined` folder is explicitly excluded in `.dockerignore`.

### Decision 3: Separation of `requirements-prod.txt`
- **Outcome:** Created a dedicated `requirements-prod.txt` containing only runtime serving libraries (`fastapi`, `uvicorn`, `scikit-learn`, `xgboost`, `pandas`, `numpy`, `joblib`, `pyarrow`, `openpyxl`).
- **Rationale:** Development libraries (`jupyter`, `streamlit`, `matplotlib`, `seaborn`, `pytest`, `prophet`) added over 2.5GB of unnecessary bloat to the container image.

### Decision 4: Azure App Service (Linux B1 Tier) Deployment
- **Outcome:** Selected Azure App Service Plan (Linux B1 SKU) with Azure Container Registry (ACR) over Azure Container Instances (ACI).
- **Rationale:** App Service provides built-in HTTPS termination, continuous deployment webhooks from ACR, and robust environment variable injection for production credentials within the allocated $100 Azure credit budget.

---

## 🗺️ 3. Critical File Mapping Table

| Component | File Path | Description |
|---|---|---|
| **API Entrypoint** | `src/api/main.py` | FastAPI application, CORS middleware, lifespan model loading, and route definitions |
| **Model Loader** | `src/api/model_loader.py` | Singleton `ModelEngine` loading `.joblib` models and `.json` target encoders |
| **Authentication** | `src/api/auth.py` | Bearer token session manager and demo user credentials (`manager@stocksense.com`) |
| **API Schemas** | `src/api/schemas.py` | Pydantic validation models for simulation, forecasting, and ordering requests |
| **Drift Detector** | `mlops/monitoring/drift_detector.py` | PSI calculation logic comparing runtime distributions against baseline training data |
| **Retraining Script** | `mlops/retraining/retrain_pipeline.py` | Background retraining script triggered by drift alerts |
| **Processed Data** | `data/processed/` | JSON stock snapshots (`current_stock.json`, `expiry_batches.json`) and CSV forecasts |
| **Mobile App Root** | `stocksense/` | Complete Flutter mobile application codebase |
| **Mobile API Client** | `stocksense/lib/services/api_service.dart` | HTTP client handling auth headers, token storage, and backend communication |
| **Mobile UI Theme** | `stocksense/lib/theme/app_theme.dart` | Dark/Light theme design system, typography, and color tokens |
| **Mobile Dashboard** | `stocksense/lib/screens/dashboard_screen.dart` | Main executive overview screen with KPI cards and demand flow chart |
| **Production Docker**| `Dockerfile` & `.dockerignore` | Multi-stage container build and exclusion configuration |

---

## 🔌 4. API Endpoints Specification

### General & Health
- `GET /health`
  - **Response:** `{"status": "ok", "models_loaded": true}`

### Authentication
- `POST /auth/login`
  - **Request Body:** `{"email": "manager@stocksense.com", "password": "password123"}`
  - **Response:** `{"access_token": "token_hex_string", "token_type": "bearer", "role": "executive"}`

### Inventory & Forecasting (Requires Bearer Token)
- `GET /inventory/report`
  - **Response:** Array of item inventory records with safety stock, reorder points, and EOQ.
- `POST /inventory/simulate`
  - **Request Body:** `{"item_id": "SKU-101", "target_service_level": 0.99, "lead_time_weeks": 3}`
  - **Response:** Simulated inventory metrics showing revised reorder points and order quantities.

### MLOps & Telemetry (Requires Bearer Token)
- `GET /mlops/drift/check`
  - **Response:** `{"drift_detected": false, "max_psi": 0.12, "feature_psi": {"price": 0.05}}`
- `POST /mlops/retrain`
  - **Response:** `{"status": "retraining_triggered", "job_id": "job_123"}`

---

## 💻 5. Quick Reference Commands

```bash
# 1. Run local FastAPI server
pip install -r requirements.txt
uvicorn src.api.main:app --host 0.0.0.0 --port 8000 --reload

# 2. Build and run production Docker container
docker build -t stocksense-api .
docker run -d -p 8000:8000 --name stocksense-container stocksense-api

# 3. Run Flutter mobile app analysis and tests
cd stocksense
flutter pub get
flutter analyze
flutter test

# 4. Azure CLI Deployment Sequence (Stage 1)
az login
az group create --name stocksense-rg --location eastus
az appservice plan create --name stocksense-plan --resource-group stocksense-rg --sku B1 --is-linux
```
