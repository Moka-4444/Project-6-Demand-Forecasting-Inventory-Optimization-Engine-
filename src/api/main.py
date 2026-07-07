"""
Demand Forecasting & Inventory Optimization — FastAPI Server

Serves ML model predictions and inventory optimization data
through a RESTful API.

Run with:
    uvicorn src.api.main:app --reload --host 0.0.0.0 --port 8000
"""

import logging
from contextlib import asynccontextmanager
from pathlib import Path
from typing import List, Optional


from fastapi import FastAPI, HTTPException, Depends
from fastapi.security import HTTPAuthorizationCredentials
from fastapi.middleware.cors import CORSMiddleware

from .model_loader import engine
from .schemas import (
    AlertItem,
    AlertsResponse,
    HealthResponse,
    InventoryReportResponse,
    InventoryReportRow,
    ProductDetail,
    ProductSummary,
    DriftCheckResponse,
    RetrainResponse,
    StockAdjustmentRequest,
    SimulationResponse,
    ExpiryBatchResponse,
    LoginRequest,
    LoginResponse,
    ModelMetricsResponse,
    BrandMatrixResponse,
    BrandMatrixItem,
    ProductWeeklyHistory,
    ProcurementRequest,
    ProcurementResponse,
)
from .auth import authenticate_user, create_token, revoke_token, require_auth, _bearer

from mlops.monitoring.drift_detector import run_drift_detection
from mlops.retraining.retrain_pipeline import run_retraining


# ── Logging ──────────────────────────────────────────────────────────────────
logging.basicConfig(
    level=logging.INFO,
    format="%(asctime)s │ %(levelname)-7s │ %(message)s",
    datefmt="%H:%M:%S",
)
logger = logging.getLogger(__name__)


# ── Lifespan (startup/shutdown) ──────────────────────────────────────────────
@asynccontextmanager
async def lifespan(app: FastAPI):
    """Load models on startup, clean up on shutdown."""
    logger.info("🚀 Starting Demand Forecasting API...")
    try:
        engine.load_all()
        logger.info("✅ API ready!")
    except Exception as e:
        logger.error(f"❌ Failed to load models: {e}")
        raise
    yield
    logger.info("👋 Shutting down API...")


# ── App ──────────────────────────────────────────────────────────────────────
app = FastAPI(
    title="Demand Forecasting & Inventory Optimization API",
    description=(
        "API for predicting product demand and providing inventory "
        "optimization recommendations (EOQ, Safety Stock, Reorder Point)."
    ),
    version="1.0.0",
    lifespan=lifespan,
)

from fastapi.staticfiles import StaticFiles
from fastapi.responses import FileResponse

# CORS — allow all origins (for mobile app / dashboard access)
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# Serve mobile app simulation
static_dir = Path(__file__).resolve().parents[2] / "static"
static_dir.mkdir(parents=True, exist_ok=True)
app.mount("/static", StaticFiles(directory=str(static_dir)), name="static")

@app.get("/", tags=["Dashboard"])
async def serve_mobile_dashboard():
    """Serve the responsive mobile app mockup dashboard."""
    index_path = static_dir / "index.html"
    if index_path.exists():
        return FileResponse(index_path)
    return {"message": "Mobile mockup static page not found. Please create static/index.html"}



# ══════════════════════════════════════════════════════════════════════════════
# ENDPOINTS
# ══════════════════════════════════════════════════════════════════════════════


@app.get("/health", response_model=HealthResponse, tags=["System"])
async def health_check():
    """Check if the API is running and models are loaded."""
    return HealthResponse(
        status="ok",
        models_loaded=engine.is_loaded,
        products_count=engine.products_count,
        version="1.0.0",
    )


@app.post("/auth/login", response_model=LoginResponse, tags=["Auth"])
async def login(payload: LoginRequest):
    """Authenticate user and return session token."""
    user = authenticate_user(payload.email, payload.password)
    if user is None:
        raise HTTPException(status_code=401, detail="Invalid email or password")
    token = create_token(user["email"])
    return LoginResponse(token=token, email=user["email"], role=user["role"])


@app.post("/auth/logout", tags=["Auth"])
async def logout(
    credentials: Optional[HTTPAuthorizationCredentials] = Depends(_bearer),
):
    """Revoke the current session token."""
    if credentials and credentials.credentials:
        revoke_token(credentials.credentials)
    return {"status": "success", "message": "Logged out"}


@app.get("/mlops/model-metrics", response_model=ModelMetricsResponse, tags=["MLOps"])
async def get_model_metrics():
    """Return stored validation WMAPE metrics for each model."""
    metrics = engine.get_model_metrics()
    return ModelMetricsResponse(
        xgb_wmape=metrics.get("xgb_wmape", 0.0),
        rf_wmape=metrics.get("rf_wmape", 0.0),
        ensemble_wmape=metrics.get("ensemble_wmape", 0.0),
    )


@app.get("/products", response_model=List[ProductSummary], tags=["Products"])
async def list_products():
    """
    Get a list of all available products.
    Returns basic info: ID, name, brand, and master brand.
    """
    if not engine.is_loaded:
        raise HTTPException(status_code=503, detail="Models not loaded yet")

    products = engine.get_products_list()
    if not products:
        raise HTTPException(status_code=404, detail="No products found")

    return [ProductSummary(**p) for p in products]


@app.get("/products/{item_id}", response_model=ProductDetail, tags=["Products"])
async def get_product(item_id: str):
    """
    Get full details for a specific product, including:
    - Product info (name, brand)
    - Forecast data (mean, std, actual comparison)
    - Inventory metrics (EOQ, safety stock, reorder point)
    """
    if not engine.is_loaded:
        raise HTTPException(status_code=503, detail="Models not loaded yet")

    detail = engine.get_product_detail(item_id)
    if detail is None:
        raise HTTPException(
            status_code=404, detail=f"Product '{item_id}' not found"
        )

    # Ensure forecast and inventory keys exist
    if "forecast" not in detail:
        detail["forecast"] = {
            "forecast_mean": 0,
            "forecast_std": 0,
            "actual_mean": 0,
            "weeks_of_data": 0,
        }
    if "inventory" not in detail:
        detail["inventory"] = {
            "avg_daily_demand": 0,
            "safety_stock": 0,
            "reorder_point": 0,
            "eoq": None,
            "orders_per_year": None,
        }

    return ProductDetail(**detail)


@app.get(
    "/inventory",
    response_model=InventoryReportResponse,
    tags=["Inventory"],
)
async def get_inventory_report():
    """
    Get the full inventory optimization report for all products.
    Includes EOQ, safety stock, reorder point, and orders per year.
    """
    if not engine.is_loaded:
        raise HTTPException(status_code=503, detail="Models not loaded yet")

    report = engine.get_inventory_report()
    if not report:
        raise HTTPException(status_code=404, detail="Inventory report not found")

    return InventoryReportResponse(
        total_products=len(report),
        report=[InventoryReportRow(**r) for r in report],
    )


@app.get(
    "/inventory/weekly-flow",
    tags=["Inventory"],
)
async def get_weekly_flow():
    """
    Get aggregated weekly actual sales vs ensemble forecast for the last 4 weeks.
    """
    if not engine.is_loaded:
        raise HTTPException(status_code=503, detail="Models not loaded yet")
    return engine.get_weekly_flow()


@app.get(
    "/inventory/brand-matrix",
    response_model=BrandMatrixResponse,
    tags=["Inventory"],
)
async def get_brand_matrix():
    """Get brand-level performance matrix aggregated from sales and alerts."""
    if not engine.is_loaded:
        raise HTTPException(status_code=503, detail="Models not loaded yet")

    brands = engine.get_brand_matrix()
    return BrandMatrixResponse(
        total_brands=len(brands),
        total_skus=engine.products_count,
        brands=[BrandMatrixItem(**b) for b in brands],
    )


@app.get(
    "/products/{item_id}/weekly-history",
    response_model=ProductWeeklyHistory,
    tags=["Products"],
)
async def get_product_weekly_history(item_id: str):
    """Get last 4 weeks of actual vs forecast demand for a single SKU."""
    if not engine.is_loaded:
        raise HTTPException(status_code=503, detail="Models not loaded yet")

    history = engine.get_product_weekly_history(item_id)
    if history is None:
        raise HTTPException(status_code=404, detail=f"Product '{item_id}' not found")
    return ProductWeeklyHistory(**history)


@app.get("/inventory/vendors", tags=["Inventory"])
async def get_vendors():
    """Return available procurement vendor list."""
    return {
        "vendors": [
            "Giza Logistics & Warehousing",
            "Delta FMCG Distributors",
            "Cairo Central Logistics Corp",
        ]
    }


@app.post(
    "/inventory/procurement",
    response_model=ProcurementResponse,
    tags=["Inventory"],
)
async def create_procurement_order(payload: ProcurementRequest):
    """Submit a purchase order and update stock levels."""
    if not engine.is_loaded:
        raise HTTPException(status_code=503, detail="Models not loaded yet")

    if not engine.product_exists(payload.item_id):
        raise HTTPException(
            status_code=404, detail=f"Product '{payload.item_id}' not found"
        )

    success = engine.adjust_stock(payload.item_id, payload.quantity)
    if not success:
        raise HTTPException(status_code=500, detail="Failed to update stock")

    import time
    po_id = f"CR-PO-{int(time.time())}"

    return ProcurementResponse(
        status="success",
        po_id=po_id,
        item_id=payload.item_id,
        quantity=payload.quantity,
        vendor=payload.vendor,
        new_stock=engine.current_stock.get(payload.item_id, 0.0),
        lead_time_days=7,
    )


@app.get(
    "/inventory/alerts",
    response_model=AlertsResponse,
    tags=["Inventory"],
)
async def get_inventory_alerts():
    """
    Get products that need reorder attention.
    - **critical**: forecast is at or below safety stock level
    - **warning**: forecast is below reorder point
    """
    if not engine.is_loaded:
        raise HTTPException(status_code=503, detail="Models not loaded yet")

    alerts = engine.get_alerts()
    return AlertsResponse(
        total_alerts=len(alerts),
        alerts=[AlertItem(**a) for a in alerts],
    )


@app.get(
    "/products/{item_id}/simulate",
    response_model=SimulationResponse,
    tags=["Products"],
)
async def simulate_whatif(item_id: str, new_price: float, new_promo: int):
    """
    Run a simulation for a specific product by adjusting its price
    and promotional settings, and return the comparison metrics.
    """
    if not engine.is_loaded:
        raise HTTPException(status_code=503, detail="Models not loaded yet")

    detail = engine.get_product_detail(item_id)
    if detail is None:
        raise HTTPException(
            status_code=404, detail=f"Product '{item_id}' not found"
        )

    base_forecast = detail.get("forecast", {}).get("forecast_mean", 0.0)
    if base_forecast <= 0:
        try:
            orig_price = 15.0
            if engine.weekly_data is not None:
                item_rows = engine.weekly_data[engine.weekly_data["ItemID"] == item_id]
                if not item_rows.empty:
                    orig_price = float(item_rows.sort_values("Week").iloc[-1]["Avg_UnitPrice"])
            base_forecast = engine.predict_whatif(item_id, orig_price, 0)
        except Exception:
            base_forecast = 1200.0

    try:
        simulated_forecast = engine.predict_whatif(item_id, new_price, new_promo)
    except Exception as e:
        raise HTTPException(
            status_code=400, detail=f"Simulation failed: {e}"
        )

    if base_forecast > 0:
        percent_change = ((simulated_forecast - base_forecast) / base_forecast) * 100
    else:
        percent_change = 0.0

    return SimulationResponse(
        base_forecast=round(base_forecast, 2),
        simulated_forecast=round(simulated_forecast, 2),
        percent_change=round(percent_change, 2),
    )


@app.post(
    "/products/{item_id}/adjust-stock",
    tags=["Inventory"],
)
async def adjust_stock(item_id: str, payload: StockAdjustmentRequest):
    """
    Adjust the current stock level for a product.
    This can represent a new replenishment order or a sales consumption scan.
    """
    if not engine.is_loaded:
        raise HTTPException(status_code=503, detail="Models not loaded yet")

    success = engine.adjust_stock(item_id, payload.quantity_change)
    if not success:
        raise HTTPException(
            status_code=404, detail=f"Product '{item_id}' not found"
        )

    return {"status": "success", "new_stock": engine.current_stock.get(item_id, 0.0)}


@app.get(
    "/inventory/expiry",
    response_model=List[ExpiryBatchResponse],
    tags=["Inventory"],
)
async def get_expiry_batches():
    """
    Retrieve batches of products that are near expiration or already expired.
    """
    batches = []
    for b in engine.expiry_batches:
        batches.append(
            ExpiryBatchResponse(
                item_id=b["item_id"],
                item_name=b["item_name"],
                batch_no=b["batch_no"],
                expiry_date=b["expiry_date"],
                qty=b["qty"],
                days_remaining=b.get("days_remaining", 0),
                days_to_expiry=b.get("days_remaining", 0)
            )
        )
    return batches


@app.post(
    "/inventory/expiry/{item_id}/clear",
    tags=["Inventory"],
)
async def clear_expired_batch(item_id: str):
    """
    Clear/dispose of expired batches for a product.
    Decrements the inventory stock level accordingly.
    """
    if not engine.is_loaded:
        raise HTTPException(status_code=503, detail="Models not loaded yet")

    success = engine.clear_expiry(item_id)
    if not success:
        raise HTTPException(
            status_code=404, detail=f"No near-expiry batch found for product '{item_id}'"
        )

    return {"status": "success", "remaining_batches": len(engine.expiry_batches)}


# ── MLOps Endpoints ─────────────────────────────────────────────────────────

BASE_DIR = Path(__file__).resolve().parents[2]
WEEKLY_DATA_PATH = BASE_DIR / "notebooks" / "weekly.csv"



@app.get("/mlops/drift-check", response_model=DriftCheckResponse, tags=["MLOps"])
async def drift_check():
    """
    Run data drift detection using Population Stability Index (PSI).
    Monitors key features: Qty, Avg_UnitPrice, and Total_Promo.
    """
    try:
        report = run_drift_detection(data_path=WEEKLY_DATA_PATH)
        return DriftCheckResponse(**report)
    except Exception as e:
        logger.error(f"Error during drift check: {e}")
        raise HTTPException(status_code=500, detail=str(e))


@app.post("/mlops/retrain", response_model=RetrainResponse, tags=["MLOps"])
async def retrain_models():
    """
    Trigger the model retraining pipeline.
    Re-fits Ridge, Random Forest, and XGBoost models, saves them,
    re-computes forecasts and inventory metrics, and reloads models in-memory.
    """
    try:
        logger.info("Triggering MLOps retraining pipeline...")
        metrics = run_retraining(data_path=WEEKLY_DATA_PATH)
        logger.info("Retraining successful! Reloading models in-memory...")
        engine.load_all()
        return RetrainResponse(status="success", metrics=metrics)
    except Exception as e:
        logger.error(f"Error during retraining: {e}")
        raise HTTPException(status_code=500, detail=str(e))


# ── Run directly ─────────────────────────────────────────────────────────────
if __name__ == "__main__":
    import uvicorn

    uvicorn.run("src.api.main:app", host="0.0.0.0", port=8000, reload=True)

