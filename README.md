# StockSense — Demand Forecasting & Inventory Optimization Engine 📈⚡

An advanced AI-powered FMCG demand forecasting and inventory optimization control center. **StockSense** seamlessly combines a high-precision machine learning ensemble, a real-time FastAPI server, automated MLOps drift monitoring, and an ultra-smooth 120Hz Flutter mobile application to prevent stockouts and eliminate overstocking.

---

## 🏗️ System Architecture

```text
Project-6-Demand-Forecasting-Inventory-Optimization-Engine-/
├── data/
│   ├── processed/          # Cleaned runtime datasets (current_stock.json, expiry_batches.json, csv reports)
│   └── raw/                # Immutable historical transaction logs
├── docs/                   # Project memory, handoff plans, and architectural documentation
├── mlops/                  # MLOps automated monitoring and retraining pipelines
│   ├── monitoring/         # PSI (Population Stability Index) data drift detection
│   └── retraining/         # Automated background model retraining pipeline
├── notebooks/              # Jupyter notebooks for exploratory data analysis and model benchmarking
├── scripts/                # Startup utilities and helper scripts (start_backend.bat)
├── src/
│   ├── api/                # FastAPI server (main.py, auth.py, model_loader.py, schemas.py)
│   ├── data/               # Data loading and validation scripts
│   ├── features/           # Target encoding and temporal feature engineering pipelines
│   └── models/             # Trained ML ensemble artifacts (.joblib) and encoders (.json)
├── static/                 # Single-page web dashboard mockup (index.html)
├── stocksense/             # StockSense Flutter mobile application (iOS, Android, Web, Desktop)
├── Dockerfile              # Production multi-stage Docker build configuration
├── requirements-prod.txt   # Lightweight runtime Python dependencies
├── requirements.txt        # Full development and training dependencies
└── README.md               # Project documentation
```

---

## 🌟 Key Features & Components

### 1. 🤖 3-Model Machine Learning Ensemble
Our demand forecasting engine utilizes a weighted ensemble combining three complementary models to achieve superior forecasting accuracy across FMCG product categories:
- **XGBoost (`xgb_model.joblib`)**: Captures complex non-linear interactions and promotion spikes.
- **Random Forest (`rf_model.joblib`)**: Provides robust baseline variance reduction.
- **Ridge Regression (`ridge_model.joblib`)**: Stabilizes linear trend extrapolation over longer horizons.
> *Note: During initial model benchmarking (Milestone 2), Prophet and SARIMA were evaluated but superseded by our tree-linear ensemble due to significantly higher accuracy and 10x faster inference speed.*

### 2. ⚡ Real-Time FastAPI Server
Located in `src/api/`, the high-concurrency Python backend serves:
- **Demand Predictions**: 4-week horizon forecasting with confidence intervals.
- **Inventory Optimization**: Real-time calculation of Economic Order Quantity (EOQ), Safety Stock, and Reorder Points based on configurable lead times and target service levels (e.g., 95% or 99%).
- **Expiry Monitoring**: Automated batch tracking to flag stock nearing expiration and trigger markdown alerts.
- **Role-Based Security**: Bearer token session management supporting Manager and Staff privileges.

### 3. 📱 StockSense Flutter Mobile App (`stocksense/`)
A state-of-the-art mobile client built with Flutter, designed for operations teams:
- **120Hz Ultra-Smooth UI**: Optimized rendering with sub-pixel aligned sparkline charts and glassmorphism styling.
- **Dynamic Theme Toggle**: Instant switching between sleek Dark Mode and vibrant Light Mode with persistent local state.
- **Interactive Inventory Simulation**: Slide controls for lead time and service levels to instantly recompute inventory health metrics on the go.
- **Role Onboarding**: Tailored workflows and UI terminology for Managers vs. Staff members.

### 4. 🔄 MLOps & Drift Monitoring (`mlops/`)
To prevent model degradation over time, our continuous monitoring suite features:
- **PSI Drift Detection**: Evaluates Population Stability Index across feature distributions to detect shifts in consumer behavior.
- **Automated Retraining**: Automatically triggers pipeline execution when significant drift ($PSI \ge 0.25$) is detected.

---

## 🔐 Demo Authentication Credentials

Use these credentials to log into the StockSense mobile app or test authenticated API endpoints:

| Role | Email Address | Password | Permissions |
|---|---|---|---|
| **Manager** | `manager@stocksense.com` | `password123` | Full access: inventory simulation, procurement ordering, system health, and MLOps triggers |
| **Staff** | `staff@stocksense.com` | `password123` | Operational access: barcode scanning, current stock view, and telemetry monitoring |
> *Note: Legacy credentials (`executive@crunchops.com` and `operator@crunchops.com`) remain supported for backward compatibility.*

---

## 🚀 Quickstart & Execution Guide

### Option A: Local Development Setup

1. **Start the FastAPI Backend:**
   Ensure you have Python 3.10+ installed and your virtual environment activated:
   ```bash
   pip install -r requirements.txt
   scripts\start_backend.bat
   # Or run directly via Uvicorn:
   # uvicorn src.api.main:app --host 0.0.0.0 --port 8000 --reload
   ```
   *The API interactive Swagger documentation will be available at `http://localhost:8000/docs`.*

2. **Launch the StockSense Mobile App:**
   Open a new terminal, navigate to the mobile app folder, and launch Flutter:
   ```bash
   cd stocksense
   flutter pub get
   flutter run
   ```

---

### Option B: Production Docker Container

Our production Docker build uses `requirements-prod.txt` (excluding development libraries like Jupyter and Matplotlib) to create an ultra-lean runtime container (<1.5GB):

1. **Build the Docker Image:**
   ```bash
   docker build -t stocksense-api .
   ```

2. **Run the Container Locally:**
   ```bash
   docker run -d -p 8000:8000 --name stocksense-server stocksense-api
   ```

3. **Verify Container Health:**
   ```bash
   curl http://localhost:8000/health
   # Expected Output: {"status":"ok","models_loaded":true}
   ```

---

## 📚 Further Documentation
For detailed system memory, endpoint schemas, and architectural logs, please refer to:
- [`docs/PROJECT_MEMORY.md`](./docs/PROJECT_MEMORY.md) — The permanent System Context & Architecture Memory Bank.
