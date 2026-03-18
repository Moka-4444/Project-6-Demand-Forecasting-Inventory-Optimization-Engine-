# 📓 Notebooks

This folder contains all Jupyter notebooks for the **Demand Forecasting & Inventory Optimization Engine** project.

---

## 📋 Notebook Index

| # | Notebook | Milestone | Description |
|---|----------|-----------|-------------|
| 01 | [`01_data_collection_eda.ipynb`](./01_data_collection_eda.ipynb) | **M1 — Data Collection & EDA** | Load raw data, quality checks, cleaning, univariate/time-series/multivariate analysis |
| 02 | [`02_model_development.ipynb`](./02_model_development.ipynb) | **M2 — Model Development** | Train/Val/Test splits, Baseline, SARIMA, Prophet, XGBoost, model comparison, save best model |
| 03 | [`03_inventory_optimization_mlops.ipynb`](./03_inventory_optimization_mlops.ipynb) | **M3 & M4 — Inventory + MLOps** | EOQ, Safety Stock, Reorder Point, Inventory Simulation, Data Drift (PSI), Model Drift Monitoring, Retrain Decision |

---

## 🚀 How to Run

### 1. Install dependencies
```bash
pip install -r ../requirements.txt
```

### 2. Launch Jupyter
```bash
jupyter notebook
# OR
jupyter lab
```

### 3. Run in order
Always run the notebooks **in order** (01 → 02 → 03) since each notebook depends on outputs from the previous one.

---

## 📁 Data Flow

```
data/raw/your_dataset.csv
        │
        ▼
01_data_collection_eda.ipynb
        │  ──► saves ──► data/processed/demand_cleaned.parquet
        │  ──► saves ──► docs/eda_*.png
        ▼
02_model_development.ipynb
        │  ──► saves ──► src/models/xgboost_demand_forecast.pkl
        │  ──► saves ──► docs/model_*.png
        ▼
03_inventory_optimization_mlops.ipynb
           ──► saves ──► docs/inventory_simulation.png
           ──► saves ──► docs/mlops_*.png
           ──► saves ──► docs/milestone_3_4_summary.csv
```

---

## 🔧 Configuration (Per Notebook)

Each notebook has a clearly marked **CONFIGURE** section at the top. Update these variables to match your dataset:

```python
DATA_FILE  = 'your_dataset.csv'   # Your data filename in data/raw/
DATE_COL   = 'date'               # Name of the date column
TARGET_COL = 'demand'             # Name of the target column
```

---

## 👥 Team

| Name | GitHub |
|---|---|
| Mark Mohsen Nasry | @mark |
| Fady Milad Shahat | @fady |
| Ahmed Arafa Hafez | @ahmed |
| Eman Ahmed Sayed | @eman |
| Sama Ashraf Mahmoud | @sama |
| Hadeer Mahmoud Abdelsalam | @hadeer |

> **Tip:** Use Jupyter's cell tagging feature to mark cells as `parameters` when using Papermill for automation.
