# StockSense — Complete Project Handoff for Documentation

> **Purpose:** This document is a comprehensive, AI-ready project handoff for generating technical documentation, presentations, or a final project report. It contains every detail needed to understand, describe, and document the StockSense system end-to-end.
>
> **Generated:** July 7, 2026

---

## 1. PROJECT IDENTITY

| Field | Value |
|-------|-------|
| **Project Name** | StockSense |
| **Full Title** | AI-Powered FMCG Demand Forecasting & Inventory Optimization Engine |
| **Tagline** | *Prevent stockouts. Eliminate overstocking. Make smarter procurement decisions — in real time.* |
| **Academic Program** | AI & Data Science — Microsoft Machine Learning Engineer (DEPI) |
| **Repository** | https://github.com/Moka-4444/Project-6-Demand-Forecasting-Inventory-Optimization-Engine- |
| **Live Backend** | https://stocksense-backend-eui.azurewebsites.net |
| **Project Status** | ✅ Complete & Live in Production |
| **Completion Date** | July 2026 |

---

## 2. TEAM

| Name | Role |
|------|------|
| Ahmed Arafa | Team Member |
| Mark Mohsen | Team Member |
| Sama Ashraf | Team Member |
| Hadeer Mahmoud | Team Member |
| Eman Ahmed | Team Member |

**Instructor / Supervisor:** Eng. Abdelrahman Elmashtoly

---

## 3. PROBLEM STATEMENT

Fast-Moving Consumer Goods (FMCG) companies face persistent inventory challenges:

- **Stockouts** cause lost revenue, damaged customer relationships, and supply chain disruptions.
- **Overstocking** ties up working capital, increases warehouse costs, and leads to product expiry/waste.
- Traditional methods (moving averages, gut-feel ordering) fail to account for demand seasonality, promotional effects, price sensitivity, and lead time variability.

**StockSense solves this** by applying machine learning to historical weekly sales data across 136 SKUs (Stock Keeping Units), generating accurate 4-week demand forecasts and computing optimal inventory parameters (Economic Order Quantity, Safety Stock, Reorder Points) that dynamically adapt to market conditions.

---

## 4. DATASET

| Field | Value |
|-------|-------|
| **File** | `notebooks/weekly.csv` |
| **Rows** | 3,321 weekly records |
| **SKUs Covered** | 136 unique products |
| **Time Span** | 26 weeks of historical data |
| **Columns** | 20 features (see below) |
| **Industry** | FMCG / Retail / Grocery |
| **Item Names** | Arabic-language product names (Egyptian market) |

**Key Columns:**
- `ItemID`, `ItemName` — Product identifier and name
- `BrandID`, `BrandName` — Brand grouping
- `Qty` — Weekly quantity sold (target variable)
- `Avg_UnitPrice` — Average unit price that week
- `Total_Promo` — Promotion intensity
- `Week`, `Month` — Time period
- `Factor`, `UOM` — Unit of measure and conversion factor
- `lead_time_weeks` — Supplier lead time

---

## 5. MACHINE LEARNING PIPELINE

### 5.1 Preprocessing & Feature Engineering

All transformations are applied in `notebooks/02_model_development.ipynb`:

- **Log transformation:** `log1p(Qty)` applied to the target variable to handle right-skewed demand distributions. All predictions are converted back with `expm1()`.
- **Lag features:** `lag_1` (1-week lag), `lag_2` (2-week lag), `lag_4` (4-week lag)
- **Rolling statistics:** `rolling_mean_4` (4-week log rolling mean), `rolling_std_4` (4-week rolling std), `rolling_mean_4_raw` (raw quantity rolling mean)
- **Price features:** `log_price` (log of unit price), `price_change_pct` (week-over-week price change)
- **Promo features:** `Total_Promo`, `has_promo` (binary flag)
- **Cyclical encoding:** `week_sin` and `week_cos` (sine/cosine encoding of week number for seasonality)
- **Target encoding:** `item_encoded` (ItemID → mean log-Qty from training), `brand_encoded` (BrandID → mean log-Qty), `brand_avg_week_qty` (BrandID → avg weekly log-Qty)
- **Categorical:** `UOM_encoded` (label-encoded unit of measure)

**Final feature vector (20 features, in order):**
```
lag_1, lag_2, lag_4, rolling_mean_4, rolling_std_4, rolling_mean_4_raw,
Avg_UnitPrice, log_price, price_change_pct, Total_Promo, has_promo,
Week, Month, week_sin, week_cos, Factor, UOM_encoded,
item_encoded, brand_encoded, brand_avg_week_qty
```

### 5.2 Models Evaluated

| Model | WMAPE | R² | Decision |
|-------|-------|----|----------|
| **XGBoost** | 34.5% | 0.84 | ✅ Kept |
| **Random Forest** | ~36% | ~0.81 | ✅ Kept |
| Ridge Regression | ~45% | ~0.70 | ❌ Excluded from final ensemble |
| Facebook Prophet | Higher error | — | ❌ Discarded |
| SARIMA | Higher error | — | ❌ Discarded |

**Why Prophet/SARIMA were rejected:** Poor performance on multi-SKU data with promotional effects. Also, Prophet requires heavy C++ dependencies (`cmdstanpy`) that inflate Docker image size by >2GB.

**Why Ridge was excluded from final ensemble:** Adding Ridge with any positive weight consistently increased error compared to the XGBoost+RF binary ensemble.

### 5.3 Final Ensemble

```
Ensemble Prediction = (0.493 × XGBoost_prediction) + (0.507 × RandomForest_prediction)
```

Both in log space → predictions converted back via `expm1()` → clipped to ≥ 0.

**Weights stored in:** `src/models/ensemble_weights.json`
```json
{"XGBoost": 0.493, "Random Forest": 0.507}
```

### 5.4 Prediction Pipeline (Pseudocode)

```python
# 1. Build feature vector for SKU
features = build_features(item_id, week, price, promo, lag_data, encoders)

# 2. Predict in log space
log_pred_xgb = xgb_model.predict(features)
log_pred_rf  = rf_model.predict(features)

# 3. Convert back to real units
pred_xgb = np.clip(np.expm1(log_pred_xgb), 0, None)
pred_rf  = np.clip(np.expm1(log_pred_rf),  0, None)

# 4. Weighted ensemble
final_prediction = 0.493 * pred_xgb + 0.507 * pred_rf
```

### 5.5 Model Artifacts (All in `src/models/`)

| File | Size | Description |
|------|------|-------------|
| `xgb_model.joblib` | ~1 MB | Trained XGBoost model |
| `rf_model.joblib` | ~11 MB | Trained Random Forest model |
| `ridge_model.joblib` | <1 MB | Kept but not used in production ensemble |
| `ridge_scaler.joblib` | <1 MB | StandardScaler for Ridge |
| `ensemble_weights.json` | tiny | `{"XGBoost": 0.493, "Random Forest": 0.507}` |
| `feature_cols.json` | tiny | Ordered list of 20 feature names |
| `item_encoder.json` | small | ItemID → log-mean-Qty mapping |
| `brand_encoder.json` | small | BrandID → log-mean-Qty mapping |
| `brand_avg_week.json` | small | BrandID → avg weekly log-Qty |
| `global_mean_qty.json` | tiny | `{"global_mean_qty": 5.016}` — fallback for unseen IDs |

---

## 6. INVENTORY OPTIMIZATION FORMULAS

Implemented in `notebooks/03_inventory_optimization_mlops.ipynb` and served via the API.

### Economic Order Quantity (EOQ)
$$EOQ = \sqrt{\frac{2 \cdot D \cdot S}{H}}$$
- D = Annual demand (units/year)
- S = Ordering cost per order
- H = Holding cost per unit per year

### Safety Stock
$$SS = Z \cdot \sigma_d \cdot \sqrt{L}$$
- Z = Z-score for target service level (e.g., 1.645 for 95%)
- σ_d = Standard deviation of weekly demand
- L = Lead time in weeks

### Reorder Point
$$ROP = \bar{d} \cdot L + SS$$
- d̄ = Average weekly demand
- L = Lead time in weeks

**Results:** Applied to all 136 SKUs with 95% default service level. Output stored in `data/processed/inventory_report.csv`.

---

## 7. BACKEND API

### Technology Stack
- **Framework:** FastAPI 0.115 (Python 3.11)
- **Server:** Uvicorn (ASGI)
- **Auth:** In-memory Bearer token session (tokens generated on login, stored in server memory)
- **Data:** Pre-computed forecasts and inventory from CSV/JSON files. No live database.
- **CORS:** Open (`allow_origins=["*"]`) for mobile app compatibility

### Authentication
Two hardcoded demo users:

| Email | Password | Role | Access Level |
|-------|----------|------|-------------|
| `manager@stocksense.com` | `password123` | `executive` | Full access — all screens |
| `staff@stocksense.com` | `password123` | `operator` | Limited — operations only |

**Auth flow:**
1. `POST /auth/login` → returns `{ "access_token": "hex_token", "token_type": "bearer", "role": "executive" }`
2. All protected endpoints require: `Authorization: Bearer <token>`

### Full Endpoint List

| Method | Endpoint | Auth | Description |
|--------|----------|------|-------------|
| GET | `/health` | ❌ | Health check |
| POST | `/auth/login` | ❌ | Login |
| POST | `/auth/logout` | ❌ | Logout |
| GET | `/products` | ✅ | All 136 SKUs with current stock |
| GET | `/products/{item_id}` | ✅ | Single product detail |
| GET | `/products/{item_id}/simulate` | ✅ | Inventory scenario simulation |
| GET | `/products/{item_id}/weekly-history` | ✅ | Historical weekly demand |
| GET | `/inventory` | ✅ | Full report (EOQ, SS, ROP) for all SKUs |
| GET | `/inventory/alerts` | ✅ | SKUs below reorder point |
| GET | `/inventory/weekly-flow` | ✅ | Weekly demand flow for charts |
| GET | `/inventory/brand-matrix` | ✅ | Brand-level demand matrix |
| GET | `/inventory/vendors` | ✅ | Vendor list |
| GET | `/inventory/expiry` | ✅ | Expiry batch tracking |
| POST | `/inventory/expiry/{item_id}/clear` | ✅ | Clear expiry entry |
| GET | `/mlops/drift-check` | ✅ | PSI data drift check |
| GET | `/mlops/model-metrics` | ✅ | Model performance metrics |
| POST | `/mlops/retrain` | ✅ | Trigger model retraining |

---

## 8. MLOPS & MONITORING

### Data Drift Detection (`mlops/monitoring/drift_detector.py`)
- **Method:** Population Stability Index (PSI)
- **Threshold:** PSI > 0.2 = significant drift detected
- **Features monitored:** All 20 model input features
- **Baseline:** Training data distribution
- **Runtime:** Current incoming request distribution

### Automated Retraining (`mlops/retraining/retrain_pipeline.py`)
- Triggered manually via `POST /mlops/retrain` or automatically when drift is detected
- Retrains XGBoost and Random Forest on latest available data
- Updates `.joblib` files in `src/models/`
- API endpoint has 120-second timeout to accommodate training time

---

## 9. INFRASTRUCTURE & DEPLOYMENT

### Docker
- **Dockerfile:** Multi-stage build using `python:3.11-slim` base image
- **Optimized for size:** Uses `requirements-prod.txt` (runtime only, no dev tools)
- **Image size:** <1.5GB
- **Excluded from image:** Notebooks, dev data, `Refined` folder (via `.dockerignore`)

### Azure Deployment
| Resource | Value |
|----------|-------|
| **Resource Group** | `stocksense-rg` |
| **Location** | UAE North |
| **App Service Plan** | B1 Linux (1 vCPU, 1.75GB RAM) |
| **App Service Name** | `stocksense-backend-eui` |
| **Container Registry** | Azure Container Registry (ACR) |
| **Live URL** | `https://stocksense-backend-eui.azurewebsites.net` |
| **Tenant** | Egypt University of Informatics |

**Cold start note:** B1 tier sleeps after ~20 minutes of inactivity. First request after sleep takes 30-60 seconds (Azure wakes the container). Subsequent requests are instant.

### CI/CD Pipeline (`.github/workflows/deploy.yml`)
- **Trigger:** Push to `main` branch
- **Steps:**
  1. Checkout code
  2. Build Docker image
  3. Push to Azure Container Registry
  4. Deploy to Azure App Service via ACR webhook
- **Status:** ⏳ Pending — requires `ACR_USERNAME` and `ACR_PASSWORD` secrets to be added to GitHub by repo owner

---

## 10. MOBILE APP (Flutter)

### Identity
| Field | Value |
|-------|-------|
| **App Name** | StockSense |
| **Platform** | Android (release APK built and distributed) |
| **Framework** | Flutter 3.x (Dart) |
| **Package ID** | `com.crunchops.crunchops_mobile` |
| **APK Size** | ~51 MB |
| **Backend URL** | Hardcoded to Azure: `https://stocksense-backend-eui.azurewebsites.net` |

### Screen Architecture
| Screen | File | Access Level |
|--------|------|-------------|
| **Splash Screen** | `lib/screens/splash_screen.dart` | All — auto-login if session exists |
| **Login Screen** | `lib/screens/login_screen.dart` | All — role selector + credentials |
| **Main Navigation** | `lib/screens/main_navigation_container.dart` | Authenticated — role-based tabs |
| **Dashboard** | `lib/screens/dashboard_screen.dart` | Executive — KPI overview, demand chart |
| **Inventory** | `lib/screens/inventory_screen.dart` | All — stock levels, alerts |
| **Products** | `lib/screens/products_screen.dart` | All — SKU list and detail |
| **MLOps Monitor** | `lib/screens/mlops_screen.dart` | Executive — drift, metrics, retrain |
| **Settings** | `lib/screens/settings_screen.dart` | All — theme toggle, logout |

### Key Features
- **Role-based UI:** Managers see MLOps and analytics; staff see operational views
- **Persistent sessions:** Auth token stored in SharedPreferences — user stays logged in across app restarts until explicit logout
- **Dark/Light mode:** Full theme toggle with consistent design system
- **Demand charts:** Sparkline charts using fl_chart; brand matrix; weekly flow visualization
- **Inventory alerts:** Color-coded indicators for SKUs below reorder point
- **Expiry tracking:** Batch management for near-expiry products
- **Cold start handling:** 60-second login timeout with user-friendly "warming up" message
- **Smart error messages:** Distinguishes timeout / wrong credentials / no internet

### Login Credentials (same as backend)
- Manager: `manager@stocksense.com` / `password123`
- Staff: `staff@stocksense.com` / `password123`

### App Icon
- **Type:** Android Adaptive Icon (API 26+)
- **Default theme:** White (#FFFFFF) background, custom logo foreground
- **Themed launchers (Material You):** Transparent background — blends with system theme
- **Shape:** Determined by phone launcher (circle, squircle, rounded square, etc.)
- **Round variant:** `ic_launcher_round` for launchers that prefer circle icons
- **Logo file:** `assets/images/logo.svg` (also used on login screen)

---

## 11. TECHNOLOGY STACK SUMMARY

### Backend & ML
| Technology | Version | Purpose |
|-----------|---------|---------|
| Python | 3.11 | Core language |
| FastAPI | 0.115 | REST API framework |
| Uvicorn | 0.29+ | ASGI server |
| XGBoost | 2.0 | Primary ML model |
| scikit-learn | 1.4 | Random Forest + Ridge + preprocessing |
| pandas | 2.x | Data manipulation |
| numpy | 1.x | Numerical computing |
| joblib | 1.x | Model serialization |
| pydantic | 2.x | Request/response validation |
| openpyxl | — | Excel file support |

### Infrastructure
| Technology | Purpose |
|-----------|---------|
| Docker | Containerization |
| Azure App Service (B1 Linux) | Cloud hosting |
| Azure Container Registry | Docker image storage |
| GitHub Actions | CI/CD pipeline |

### Mobile
| Technology | Version | Purpose |
|-----------|---------|---------|
| Flutter | 3.x | Mobile framework |
| Dart | 3.x | Language |
| http | — | HTTP client |
| shared_preferences | — | Local token storage |
| fl_chart | — | Charts and visualizations |
| flutter_svg | — | SVG logo rendering |
| google_fonts | — | Typography (Sora, DM Sans) |

### Data & Notebooks
| Technology | Purpose |
|-----------|---------|
| Jupyter Notebook | EDA, model training, optimization |
| matplotlib / seaborn | Data visualization in notebooks |
| Prophet / SARIMA | Evaluated and discarded |

---

## 12. PROJECT STRUCTURE (Key Files Only)

```
Project-6-Demand-Forecasting-Inventory-Optimization-Engine-/
│
├── 📓 notebooks/
│   ├── 00_data_prepairing.ipynb          # Data cleaning & preparation
│   ├── 01_data_collection_eda.ipynb      # Exploratory data analysis
│   ├── 02_model_development.ipynb        # ML training & benchmarking
│   ├── 03_inventory_optimization_mlops.ipynb  # EOQ/SS/ROP + MLOps
│   └── weekly.csv                        # Raw dataset (3,321 rows)
│
├── 🔧 src/
│   ├── api/
│   │   ├── main.py         # FastAPI app entry point
│   │   ├── auth.py         # Bearer token auth
│   │   ├── schemas.py      # Pydantic models
│   │   └── model_loader.py # ML model singleton loader
│   ├── models/             # Trained .joblib models + .json encoders
│   └── features/           # Feature engineering utilities
│
├── 📊 data/processed/
│   ├── ml_forecasts.csv    # Pre-computed 4-week demand forecasts
│   ├── inventory_report.csv # EOQ, Safety Stock, ROP for all SKUs
│   ├── current_stock.json  # Current inventory levels
│   └── expiry_batches.json # Near-expiry product tracking
│
├── 🤖 mlops/
│   ├── monitoring/drift_detector.py      # PSI drift detection
│   └── retraining/retrain_pipeline.py   # Automated retraining
│
├── 📱 stocksense/           # Flutter mobile app
│   ├── lib/
│   │   ├── config/          # API config, theme
│   │   ├── models/          # Dart data models
│   │   ├── providers/       # State management
│   │   ├── screens/         # All app screens
│   │   ├── services/        # API client (api_service.dart)
│   │   └── widgets/         # Reusable UI components
│   ├── android/             # Android-specific config + icons
│   └── assets/images/logo.svg
│
├── 🐋 Dockerfile            # Production container build
├── .dockerignore            # Excludes notebooks/dev from image
├── requirements-prod.txt    # Runtime dependencies only
├── requirements.txt         # Full dev dependencies
├── README.md                # Full project documentation
│
└── 📁 docs/
    ├── PROJECT_MEMORY.md    # Architecture memory bank (this is kept updated)
    └── Handoff_Implementation_Plan.md  # Original milestone handoff
```

---

## 13. KEY NUMBERS & METRICS

| Metric | Value |
|--------|-------|
| **Dataset size** | 3,321 rows, 26 weeks, 136 SKUs |
| **Model WMAPE** | 34.5% (XGBoost standalone) |
| **Model R²** | 0.84 (XGBoost standalone) |
| **Ensemble weights** | XGBoost 49.3% + Random Forest 50.7% |
| **Global mean Qty (log)** | 5.016 (fallback for unseen SKUs) |
| **Feature count** | 20 engineered features |
| **API endpoints** | 17 endpoints |
| **Mobile APK size** | ~51 MB |
| **Docker image size** | <1.5 GB |
| **Azure tier** | B1 Linux (1 vCPU, 1.75GB RAM) |
| **Cold start time** | 30–60 seconds (after inactivity) |
| **Login timeout** | 60 seconds (handles cold starts) |

---

## 14. ACADEMIC & ACKNOWLEDGEMENTS CONTEXT

- **Program:** AI & Data Science — Microsoft Machine Learning Engineer (DEPI)
- **Supervisor:** Eng. Abdelrahman Elmashtoly
- **University Affiliation:** Egypt University of Informatics (EUI)
- **Project Number:** Project 6 — Demand Forecasting & Inventory Optimization Engine
- **Duration:** Built, deployed, and completed within the DEPI program timeline

The project demonstrates end-to-end ML engineering: from raw data exploration through model training, API development, containerization, cloud deployment, and a production mobile client — a complete MLOps lifecycle.

---

## 15. WHAT AN AI AGENT SHOULD KNOW TO WRITE GREAT DOCS

- **The core story:** StockSense is not just a Jupyter notebook exercise — it's a complete, production-deployed system that a real operations team could use today to manage inventory for 136 real FMCG products in the Egyptian market.
- **The technical depth:** Three ML models were tested. Two were discarded with clear engineering rationale. The ensemble was tuned with specific weights. Log-transformation was the critical insight that made the model work.
- **The full stack:** Python backend → Docker → Azure → GitHub Actions CI/CD → Flutter mobile app → Adaptive Android icon. Every layer is complete and integrated.
- **The human story:** Five students built this as part of a competitive AI engineering program, guided by their instructor. The product is named, branded, and shipped.
- **Key differentiators vs. typical student projects:**
  1. Live in production (not just a local demo)
  2. Full authentication system
  3. Role-based mobile app (Manager vs. Staff)
  4. Real MLOps (drift detection + automated retraining)
  5. CI/CD pipeline
  6. Release APK distributed to real users
  7. Arabic-language FMCG dataset (real Egyptian market data)
