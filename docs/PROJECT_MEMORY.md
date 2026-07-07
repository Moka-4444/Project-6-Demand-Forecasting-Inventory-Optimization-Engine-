# StockSense — System Context & Architecture Memory Bank 🧠🔒

> **Purpose:** This document serves as an authoritative, permanent system repository memory bank. It is specifically designed to protect against LLM context window truncations or session restarts by preserving all critical architectural decisions, file mappings, endpoint schemas, and execution commands.
>
> **Last Updated:** July 7, 2026 — Updated to reflect all post-initial-build changes including full Azure deployment, CI/CD pipeline, Flutter mobile app, bug fixes, and icon overhaul.

---

## 📸 1. System State Snapshot

- **Project Status:** ✅ **Fully complete and live in production.** All milestones done.
- **Live Backend:** `https://stocksense-backend-eui.azurewebsites.net` (Azure App Service, UAE North, B1 Linux)
- **Core Engine:** Validated 3-model ML ensemble (XGBoost 49.3% + Random Forest 50.7%) predicting FMCG product demand across 4-week horizons.
- **Backend API:** FastAPI server (`src/api/main.py`) containerized in Docker, deployed to Azure via GitHub Actions CI/CD.
- **Mobile App:** StockSense Flutter app (`stocksense/`) — release APK built and distributed (~51MB). Features persistent login sessions, role-based views, dark/light mode, and adaptive app icon.
- **MLOps Automation:** PSI-based data drift monitoring and background retraining pipeline complete.
- **Containerization:** Production Docker image on Azure Container Registry (ACR). Auto-deploys on push to `main` via GitHub Actions (pending secrets from repo owner).

---

## 🏛️ 2. Key Technical Decisions Log

### Decision 1: Discarding Prophet & SARIMA in Favor of Tree-Linear Ensemble
During Milestone 2 benchmarking (`02_model_development.ipynb`), standard time-series models (Facebook Prophet and SARIMA via `statsmodels`) were evaluated against machine learning models.
- **Outcome:** Both Prophet and SARIMA were discarded.
- **Rationale:** The weighted ensemble of **XGBoost (49.3%)** and **Random Forest (50.7%)** achieved significantly lower WMAPE while executing inference in milliseconds. Removing Prophet eliminated heavy C++ compiler dependencies (`cmdstanpy`), reducing Docker build times from >5 minutes to ~15 seconds.

### Decision 2: Root Directory as Sole Source of Truth
Earlier iterations split source code between project root and a subfolder `Demand Forecasting Inventory Optimization Refined/`.
- **Outcome:** All code promoted directly to root workspace. Legacy `Refined` folder explicitly excluded in `.dockerignore`.

### Decision 3: Separation of `requirements-prod.txt`
- **Outcome:** Created dedicated `requirements-prod.txt` with only runtime libraries (`fastapi`, `uvicorn`, `scikit-learn`, `xgboost`, `pandas`, `numpy`, `joblib`, `pyarrow`, `openpyxl`).
- **Rationale:** Dev libraries (`jupyter`, `streamlit`, `matplotlib`) added 2.5GB+ of unnecessary container bloat.

### Decision 4: Azure App Service (Linux B1 Tier) Deployment
- **Outcome:** Selected Azure App Service Plan (Linux B1) with Azure Container Registry (ACR).
- **Rationale:** Built-in HTTPS termination, continuous deployment webhooks, and env variable injection within the $100 Azure for Students credit budget.

### Decision 5: Hardcoded Azure URL in Flutter Release APK
- **Outcome:** The `api_service.dart` has the Azure base URL hardcoded (`https://stocksense-backend-eui.azurewebsites.net`). The earlier dynamic server URL UI was removed from the login screen.
- **Rationale:** Dynamic URL switching was a dev-only convenience. Release APKs always target production. Simplifies the login UI.

### Decision 6: Login Timeout Extended to 60 Seconds
- **Outcome:** Login HTTP timeout raised from 8s to 60s. Health check timeout raised from 4s to 30s.
- **Rationale:** Azure B1 Linux tier has cold starts of 30–60 seconds after inactivity. The original 8s timeout caused "Login failed" errors on fresh APK installs. A warm-up hint ("First connection may take up to 60s ☁️") was added to the login screen.

### Decision 7: Adaptive App Icon Architecture (Android)
- **Outcome:** Implemented Android adaptive icon system (API 26+) with foreground/background separation. White (#FFFFFF) background on default launchers; transparent background on themed launchers (Material You, etc.). Icon shape (circle, squircle, rounded square) is determined by the phone's launcher.
- **Rationale:** Matches modern Android icon design standards. Mirrors the SafetyWatch project's icon setup.

---

## 🗺️ 3. Critical File Mapping Table

### Backend & ML

| Component | File Path | Description |
|---|---|---|
| **API Entrypoint** | `src/api/main.py` | FastAPI app, CORS, lifespan model loading, all route definitions |
| **Model Loader** | `src/api/model_loader.py` | Singleton `ModelEngine` loading `.joblib` models and `.json` encoders |
| **Authentication** | `src/api/auth.py` | Bearer token session manager. Users: `manager@stocksense.com` / `staff@stocksense.com` |
| **API Schemas** | `src/api/schemas.py` | Pydantic validation models for all requests/responses |
| **Drift Detector** | `mlops/monitoring/drift_detector.py` | PSI calculation comparing runtime vs training distributions |
| **Retraining Script** | `mlops/retraining/retrain_pipeline.py` | Background retraining triggered by drift alerts |
| **Processed Data** | `data/processed/` | `current_stock.json`, `expiry_batches.json`, `ml_forecasts.csv`, `inventory_report.csv` |
| **Production Docker** | `Dockerfile` & `.dockerignore` | Multi-stage container build using `requirements-prod.txt` |

### CI/CD & Deployment

| Component | File Path | Description |
|---|---|---|
| **GitHub Actions Workflow** | `.github/workflows/deploy.yml` | Builds Docker image, pushes to ACR, deploys to Azure App Service on push to `main` |
| **Required Secrets** | GitHub repo Settings → Secrets | `ACR_USERNAME`, `ACR_PASSWORD` — must be added by repo owner to activate CI/CD |
| **Azure Resource Group** | `stocksense-rg` | Location: UAE North |
| **Azure App Service** | `stocksense-backend-eui` | Plan: B1 Linux. Registry: ACR. Live at `azurewebsites.net` |

### Flutter Mobile App (`stocksense/`)

| Component | File Path | Description |
|---|---|---|
| **API Client** | `lib/services/api_service.dart` | HTTP client, token storage (SharedPreferences), 60s login timeout, `lastLoginError` tracking |
| **Login Screen** | `lib/screens/login_screen.dart` | Login UI, specific error messages per failure type, cold start hint |
| **Main Nav Container** | `lib/screens/main_navigation_container.dart` | Bottom nav, role-based tab rendering, fixed logout (captures context before async) |
| **Theme System** | `lib/config/theme.dart` | Dark/Light design tokens, colors, typography |
| **App Config** | `lib/config/api_config.dart` | Base URL constant pointing to Azure |
| **Android Manifest** | `android/app/src/main/AndroidManifest.xml` | `INTERNET` permission, `roundIcon` attribute |
| **Adaptive Icon XML** | `android/app/src/main/res/mipmap-anydpi-v26/ic_launcher.xml` | Adaptive icon with background color + foreground inset |
| **Icon Background** | `android/app/src/main/res/values/colors.xml` | `ic_launcher_background = #FFFFFF` |
| **Icon Foreground** | `android/app/src/main/res/drawable-{density}/ic_launcher_foreground.png` | Custom logo at mdpi/hdpi/xhdpi/xxhdpi/xxxhdpi densities |
| **Legacy Icons** | `android/app/src/main/res/mipmap-{density}/ic_launcher*.png` | Fallback icons for pre-API-26 Android |
| **App Logo (SVG)** | `assets/images/logo.svg` | Transparent SVG used in login screen and README |
| **Release APK** | `build/app/outputs/flutter-apk/app-release.apk` | ~51MB production APK for direct distribution |

---

## 🔌 4. Full API Endpoints Reference

### Base URL (Production)
```
https://stocksense-backend-eui.azurewebsites.net
```

### Public Endpoints (No Auth)
| Method | Endpoint | Description |
|--------|----------|-------------|
| `GET` | `/health` | Health check → `{"status": "ok", "models_loaded": true}` |
| `POST` | `/auth/login` | Login → returns `access_token`, `token_type`, `role` |
| `POST` | `/auth/logout` | Invalidate session token |

**Login credentials:**
- Manager: `manager@stocksense.com` / `password123` → role: `executive`
- Staff: `staff@stocksense.com` / `password123` → role: `operator`

### Protected Endpoints (Bearer Token Required)
| Method | Endpoint | Description |
|--------|----------|-------------|
| `GET` | `/products` | List all 136 SKUs with current stock |
| `GET` | `/products/{item_id}` | Single product detail |
| `GET` | `/products/{item_id}/simulate` | Simulate inventory scenarios |
| `GET` | `/products/{item_id}/weekly-history` | Historical weekly demand data |
| `GET` | `/inventory` | Full inventory report (EOQ, SS, ROP for all SKUs) |
| `GET` | `/inventory/alerts` | SKUs currently below reorder point |
| `GET` | `/inventory/weekly-flow` | Weekly demand flow data for charts |
| `GET` | `/inventory/brand-matrix` | Brand-level demand matrix |
| `GET` | `/inventory/vendors` | Vendor list |
| `GET` | `/inventory/expiry` | Expiry batch tracking |
| `POST` | `/inventory/expiry/{item_id}/clear` | Clear expiry batch |
| `GET` | `/mlops/drift-check` | PSI drift check across all features |
| `GET` | `/mlops/model-metrics` | Current model performance metrics |
| `POST` | `/mlops/retrain` | Trigger background model retraining (120s timeout) |

---

## 🐛 5. Bug Fixes Applied (Post-Launch)

| Bug | Root Cause | Fix Applied |
|-----|-----------|-------------|
| **Logout button not working** | `Navigator.of(context)` called after async gap — context was stale | Captured `navigator` variable before `await clearSession()` in `main_navigation_container.dart` |
| **Session lost on app close** | Token not persisted across app restarts | `saveSession()` writes to SharedPreferences; `loadSession()` restores on splash screen |
| **"Login Failed" on APK** (first attempt) | Azure B1 cold start (30-60s) exceeded 8s timeout | Login timeout raised to 60s; health check to 30s; `TimeoutException` caught separately |
| **"Cannot reach server" on APK** | `android.permission.INTERNET` missing from `AndroidManifest.xml` | Added `<uses-permission android:name="android.permission.INTERNET"/>` |
| **Generic error message** | All failures showed same "Login failed" message | `lastLoginError` static field tracks `'timeout'` / `'auth'` / `'network'`; login screen shows specific message per type |

---

## 💻 6. Quick Reference Commands

```bash
# ── Run local FastAPI server ───────────────────────────────────────────
pip install -r requirements.txt
uvicorn src.api.main:app --host 0.0.0.0 --port 8000 --reload
# Docs: http://localhost:8000/docs

# ── Build Docker container ─────────────────────────────────────────────
docker build -t stocksense-api .
docker run -d -p 8000:8000 --name stocksense-container stocksense-api

# ── Flutter mobile app ─────────────────────────────────────────────────
cd stocksense
flutter pub get
flutter run                          # debug mode (connect USB/emulator)
flutter build apk --release          # release APK for distribution
# APK output: build/app/outputs/flutter-apk/app-release.apk

# ── Git workflow ───────────────────────────────────────────────────────
git add .
git commit -m "your message"
git push origin main                 # triggers CI/CD deploy to Azure (once secrets added)
```

---

## 📋 7. Pending Actions

| Action | Owner | Status |
|--------|-------|--------|
| Add `ACR_USERNAME` and `ACR_PASSWORD` GitHub secrets | Repo owner (Mark) | ⏳ Pending |
| CI/CD auto-deploy on push to `main` | Automated (after secrets added) | ⏳ Blocked on secrets |
