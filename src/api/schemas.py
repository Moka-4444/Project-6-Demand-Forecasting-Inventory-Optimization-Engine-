"""
Pydantic schemas for the Demand Forecasting API.
Defines request/response models for all endpoints.
"""

from pydantic import BaseModel, Field
from typing import List, Optional


# ── Product Schemas ──────────────────────────────────────────────────────────

class ProductSummary(BaseModel):
    """Summary info for a single product (used in product listing)."""
    item_id: str = Field(..., description="Unique product identifier")
    item_name: str = Field(..., description="Product name (Arabic)")
    brand_name: str = Field(..., description="Brand name")
    master_brand: str = Field(..., description="Master brand name")
    current_stock: Optional[float] = None
    reorder_point: Optional[float] = None
    safety_stock: Optional[float] = None


class ForecastDetail(BaseModel):
    """Forecast details for a product."""
    forecast_mean: float = Field(..., description="Mean weekly forecast (units)")
    forecast_std: float = Field(..., description="Forecast standard deviation")
    actual_mean: float = Field(..., description="Historical actual mean (units)")
    weeks_of_data: int = Field(..., description="Number of weeks of historical data")


class InventoryDetail(BaseModel):
    """Inventory optimization metrics for a product."""
    avg_daily_demand: float = Field(..., description="Average daily demand (units)")
    safety_stock: float = Field(..., description="Safety stock level (units)")
    reorder_point: float = Field(..., description="Reorder point (units)")
    eoq: Optional[float] = Field(None, description="Economic Order Quantity")
    orders_per_year: Optional[float] = Field(None, description="Estimated orders per year")
    current_stock: Optional[float] = Field(None, description="Current physical stock level")


class ProductDetail(BaseModel):
    """Full product details including forecast and inventory data."""
    item_id: str
    item_name: str
    brand_name: str
    master_brand: str
    avg_unit_price: Optional[float] = None
    forecast: ForecastDetail
    inventory: InventoryDetail


# ── Inventory Report Schemas ─────────────────────────────────────────────────

class InventoryReportRow(BaseModel):
    """Single row from the inventory report."""
    item_id: str
    item_name: str
    forecast_mean: float
    eoq: float
    safety_stock: float
    reorder_point: float
    orders_per_year: float
    current_stock: Optional[float] = None


class InventoryReportResponse(BaseModel):
    """Full inventory report."""
    total_products: int
    report: List[InventoryReportRow]


# ── Alert Schemas ────────────────────────────────────────────────────────────

class AlertItem(BaseModel):
    """A product that needs attention (e.g., at or below reorder point)."""
    item_id: str
    item_name: str
    forecast_mean: float
    safety_stock: float
    reorder_point: float
    eoq: Optional[float] = None
    status: str = Field(..., description="Alert status: 'critical' or 'warning'")
    current_stock: Optional[float] = None


class AlertsResponse(BaseModel):
    """List of products needing reorder attention."""
    total_alerts: int
    alerts: List[AlertItem]


# ── Interactive Simulation & Actions Schemas ───────────────────────────────

class StockAdjustmentRequest(BaseModel):
    """Request model to adjust a product's stock."""
    quantity_change: float = Field(..., description="Amount of change in stock (positive for add, negative for remove)")


class SimulationResponse(BaseModel):
    """Response model for demand forecast simulation."""
    base_forecast: float
    simulated_forecast: float
    percent_change: float


class ExpiryBatchResponse(BaseModel):
    """Response model representing a batch near expiration."""
    item_id: str
    item_name: str
    batch_no: str
    expiry_date: str
    qty: float
    days_remaining: int
    days_to_expiry: int


# ── Health Check ─────────────────────────────────────────────────────────────

class HealthResponse(BaseModel):
    """Health check response."""
    status: str = "ok"
    models_loaded: bool = False
    products_count: int = 0
    version: str = "1.0.0"


# ── MLOps Schemas ────────────────────────────────────────────────────────────

class DriftMetric(BaseModel):
    """A drift metric for a monitored feature."""
    feature: str
    psi: float
    status: str


class DriftCheckResponse(BaseModel):
    """Data drift report response."""
    reference_period: str
    current_period: str
    metrics: List[DriftMetric]
    retrain_recommended: bool
    reasons: List[str]


class RetrainResponse(BaseModel):
    """Model retraining execution response."""
    status: str
    metrics: dict


# ── Auth Schemas ─────────────────────────────────────────────────────────────

class LoginRequest(BaseModel):
    email: str
    password: str


class LoginResponse(BaseModel):
    token: str
    email: str
    role: str


class ModelMetricsResponse(BaseModel):
    """Production model validation metrics."""
    xgb_wmape: float
    rf_wmape: float
    ensemble_wmape: float


# ── Brand Matrix Schemas ─────────────────────────────────────────────────────

class BrandMatrixItem(BaseModel):
    brand_name: str
    total_volume: float
    market_share: float
    alert_count: int
    sku_count: int


class BrandMatrixResponse(BaseModel):
    total_brands: int
    total_skus: int
    brands: List[BrandMatrixItem]


# ── Weekly History Schemas ───────────────────────────────────────────────────

class ProductWeeklyHistory(BaseModel):
    weeks: List[str]
    actual_qty: List[float]
    forecast_qty: List[float]


# ── Procurement Schemas ──────────────────────────────────────────────────────

class ProcurementRequest(BaseModel):
    item_id: str
    quantity: float
    vendor: str = Field(default="Giza Logistics & Warehousing")


class ProcurementResponse(BaseModel):
    status: str
    po_id: str
    item_id: str
    quantity: float
    vendor: str
    new_stock: float
    lead_time_days: int = 7

