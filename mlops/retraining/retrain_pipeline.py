"""
Model Retraining Pipeline.

Loads weekly.csv, runs feature engineering, trains Ridge, Random Forest, 
and XGBoost models, calculates ensemble weights, evaluates them, and
serializes all trained models and encoders back to src/models/.
"""

import json
import logging
import os
import sys
from pathlib import Path

import joblib
import numpy as np
import pandas as pd
from sklearn.ensemble import RandomForestRegressor
from sklearn.linear_model import Ridge
from sklearn.metrics import mean_absolute_error, mean_squared_error, r2_score
from sklearn.preprocessing import StandardScaler
from xgboost import XGBRegressor

# Add repo root to sys.path so we can import src feature engineer
repo_root = Path(__file__).resolve().parents[2]
sys.path.append(str(repo_root))

from src.features.feature_engineer import build_features_pipeline, FEATURE_COLS

logging.basicConfig(
    level=logging.INFO,
    format="%(asctime)s │ %(levelname)-7s │ %(message)s",
    datefmt="%H:%M:%S",
)
logger = logging.getLogger(__name__)


def to_real(log_preds):
    """Convert log predictions back to real units."""
    return np.clip(np.expm1(np.clip(log_preds, 0, None)), 0, None)


def evaluate_wmape(y_real, pred_real):
    """Calculate MAE, RMSE, WMAPE, and R2 on real scale."""
    mae = mean_absolute_error(y_real, pred_real)
    rmse = np.sqrt(mean_squared_error(y_real, pred_real))
    r2 = r2_score(y_real, pred_real)
    total = np.sum(y_real)
    wmape = np.sum(np.abs(y_real - pred_real)) / total * 100 if total > 0 else 0.0
    return {
        "MAE": mae,
        "RMSE": rmse,
        "WMAPE": wmape,
        "R2": r2
    }


def run_retraining(data_path, models_dir=None, output_fc_path=None):
    """
    Main training pipeline.
    """
    if models_dir is None:
        models_dir = repo_root / "src" / "models"
    else:
        models_dir = Path(models_dir)
        
    if output_fc_path is None:
        output_fc_path = repo_root / "data" / "processed" / "ml_forecasts.csv"
    else:
        output_fc_path = Path(output_fc_path)

    logger.info(f"Loading data from {data_path} for retraining...")
    df_raw = pd.read_csv(data_path, encoding="utf-8-sig")
    df_raw.columns = [
        'Year', 'Week', 'ItemID', 'Qty', 'ItemName', 'BrandID', 'BrandName',
        'MasterBrandID', 'MasterBrandName', 'UOM', 'Factor',
        'Avg_Daily_Demand', 'Safety_Stock', 'ROP', 'Avg_UnitPrice',
        'Total_Promo', 'Total_CashDiscount', 'Total_ManualDiscount',
        'Total_Taxes', 'Total_Revenue'
    ][:len(df_raw.columns)]

    df_raw['Date'] = pd.to_datetime(
        df_raw['Year'].astype(str) + '-W' + df_raw['Week'].astype(str).str.zfill(2) + '-1',
        format='%G-W%V-%u'
    )

    # 1. Split chronologically for target encoding and validation
    # Use standard splits matching the notebook:
    # Train: Week <= 18
    # Validation: Week 19-22
    # Test: Week >= 23
    train_mask = df_raw['Week'] <= 18
    val_mask = (df_raw['Week'] >= 19) & (df_raw['Week'] <= 22)
    test_mask = df_raw['Week'] >= 23

    # Calculate target encoding on training data ONLY
    df_train_raw = df_raw[train_mask].copy()
    df_train_raw['Qty_log'] = np.log1p(df_train_raw['Qty'].clip(lower=0))
    
    item_target_enc = df_train_raw.groupby('ItemID')['Qty_log'].mean().to_dict()
    global_mean_qty = float(df_train_raw['Qty_log'].mean())
    brand_target_enc = df_train_raw.groupby('BrandID')['Qty_log'].mean().to_dict()
    brand_avg_week = df_train_raw.groupby(['BrandID', 'Week'])['Qty_log'].mean() \
        .groupby('BrandID').mean().to_dict()

    # 2. Run feature engineering pipeline globally using the encoders
    logger.info("Running feature engineering pipeline...")
    df_feat = build_features_pipeline(
        df_raw=df_raw,
        item_encoder=item_target_enc,
        brand_encoder=brand_target_enc,
        brand_avg_week=brand_avg_week,
        global_mean_qty=global_mean_qty
    )

    # Re-split engineered feature dataset
    train_g = df_feat[df_feat['Week'] <= 18].copy()
    val_g   = df_feat[(df_feat['Week'] >= 19) & (df_feat['Week'] <= 22)].copy()
    test_g  = df_feat[df_feat['Week'] >= 23].copy()

    X_train, y_train = train_g[FEATURE_COLS], train_g['Qty_log']
    X_val,   y_val   = val_g[FEATURE_COLS],   val_g['Qty_log']
    X_test,  y_test  = test_g[FEATURE_COLS],  test_g['Qty_log']

    y_val_real  = val_g['Qty'].values
    y_test_real = test_g['Qty'].values

    logger.info(f"Training shapes - Train: {X_train.shape}, Val: {X_val.shape}, Test: {X_test.shape}")

    # 3. Train models
    # A. XGBoost
    logger.info("Training XGBoost Regressor...")
    xgb_model = XGBRegressor(
        n_estimators=500, max_depth=5, learning_rate=0.03,
        subsample=0.8, colsample_bytree=0.7,
        reg_alpha=0.5, reg_lambda=2.0, min_child_weight=3,
        random_state=42, n_jobs=-1, verbosity=0
    )
    xgb_model.fit(X_train, y_train, eval_set=[(X_val, y_val)], verbose=False)
    
    xgb_val_preds = to_real(xgb_model.predict(X_val))
    xgb_test_preds = to_real(xgb_model.predict(X_test))
    xgb_val_metrics = evaluate_wmape(y_val_real, xgb_val_preds)
    logger.info(f"XGBoost Val WMAPE: {xgb_val_metrics['WMAPE']:.2f}%")

    # B. Random Forest
    logger.info("Training Random Forest Regressor...")
    rf_model = RandomForestRegressor(
        n_estimators=300, max_depth=12, min_samples_leaf=3,
        random_state=42, n_jobs=-1
    )
    rf_model.fit(X_train, y_train)
    
    rf_val_preds = to_real(rf_model.predict(X_val))
    rf_test_preds = to_real(rf_model.predict(X_test))
    rf_val_metrics = evaluate_wmape(y_val_real, rf_val_preds)
    logger.info(f"Random Forest Val WMAPE: {rf_val_metrics['WMAPE']:.2f}%")

    # C. Ridge Regression
    logger.info("Training Ridge Regression...")
    ridge_scaler = StandardScaler()
    X_train_s = ridge_scaler.fit_transform(X_train)
    X_val_s   = ridge_scaler.transform(X_val)
    X_test_s  = ridge_scaler.transform(X_test)

    ridge_model = Ridge(alpha=1.0)
    ridge_model.fit(X_train_s, y_train)
    
    ridge_val_preds = to_real(ridge_model.predict(X_val_s))
    ridge_test_preds = to_real(ridge_model.predict(X_test_s))
    ridge_val_metrics = evaluate_wmape(y_val_real, ridge_val_preds)
    logger.info(f"Ridge Val WMAPE: {ridge_val_metrics['WMAPE']:.2f}%")

    # D. Ensemble weights calculation
    logger.info("Calculating Ensemble weights...")
    inv_sum = (1.0 / xgb_val_metrics['WMAPE']) + (1.0 / rf_val_metrics['WMAPE'])
    w_xgb = (1.0 / xgb_val_metrics['WMAPE']) / inv_sum
    w_rf  = (1.0 / rf_val_metrics['WMAPE']) / inv_sum
    ensemble_weights = {'XGBoost': w_xgb, 'Random Forest': w_rf}
    logger.info(f"Ensemble weights - XGB: {w_xgb:.3f}, RF: {w_rf:.3f}")

    ens_val_preds = w_xgb * xgb_val_preds + w_rf * rf_val_preds
    ens_test_preds = w_xgb * xgb_test_preds + w_rf * rf_test_preds
    ens_test_metrics = evaluate_wmape(y_test_real, ens_test_preds)
    logger.info(f"⭐ Ensemble Test WMAPE: {ens_test_metrics['WMAPE']:.2f}%")

    # 4. Serialize models and encoders
    logger.info(f"Saving all artifacts to {models_dir}...")
    models_dir.mkdir(parents=True, exist_ok=True)
    joblib.dump(xgb_model, models_dir / "xgb_model.joblib")
    joblib.dump(rf_model, models_dir / "rf_model.joblib")
    joblib.dump(ridge_model, models_dir / "ridge_model.joblib")
    joblib.dump(ridge_scaler, models_dir / "ridge_scaler.joblib")

    with open(models_dir / 'ensemble_weights.json', 'w') as f: 
        json.dump(ensemble_weights, f, indent=2)
    with open(models_dir / 'feature_cols.json', 'w') as f: 
        json.dump(FEATURE_COLS, f, indent=2)
    with open(models_dir / 'item_encoder.json', 'w') as f: 
        json.dump(item_target_enc, f, indent=2)
    with open(models_dir / 'brand_encoder.json', 'w') as f: 
        json.dump(brand_target_enc, f, indent=2)
    with open(models_dir / 'brand_avg_week.json', 'w') as f: 
        json.dump(brand_avg_week, f, indent=2)
    with open(models_dir / 'global_mean_qty.json', 'w') as f:
        json.dump({'global_mean_qty': global_mean_qty}, f, indent=2)

    # 5. Save new predictions/forecasts file for inventory calculation
    logger.info(f"Exporting new ML forecasts to {output_fc_path}...")
    output_fc_path.parent.mkdir(parents=True, exist_ok=True)

    # Combine all data for forecasting export
    all_data = pd.concat([train_g, val_g, test_g], ignore_index=True)
    X_all = all_data[FEATURE_COLS]
    
    xgb_all_preds = to_real(xgb_model.predict(X_all))
    rf_all_preds = to_real(rf_model.predict(X_all))
    all_data['pred_ens'] = w_xgb * xgb_all_preds + w_rf * rf_all_preds

    LEAD_TIME = 7
    Z = 1.65  # 95% service level
    
    sku_fc = all_data.groupby('ItemID').agg(
        forecast_mean=('pred_ens', 'mean'),
        forecast_std=('pred_ens', 'std'),
        actual_mean=('Qty', 'mean'),
        weeks=('Week', 'count')
    ).reset_index()
    
    sku_fc['forecast_std'] = sku_fc['forecast_std'].fillna(0)
    sku_fc['avg_daily_demand_ml'] = sku_fc['forecast_mean'] / 7
    sku_fc['safety_stock_ml'] = Z * sku_fc['forecast_std'] * np.sqrt(LEAD_TIME / 7)
    sku_fc['rop_ml'] = sku_fc['avg_daily_demand_ml'] * LEAD_TIME + sku_fc['safety_stock_ml']

    # Map name back
    names_df = df_raw[['ItemID', 'ItemName']].drop_duplicates()
    sku_fc = sku_fc.merge(names_df, on='ItemID', how='left')

    sku_fc.to_csv(output_fc_path, index=False, encoding='utf-8-sig')

    # 6. Regenerate inventory report (EOQ, orders/year)
    output_inv_path = repo_root / "data" / "processed" / "inventory_report.csv"
    logger.info(f"Exporting inventory report to {output_inv_path}...")

    avg_prices = df_raw.groupby('ItemID')['Avg_UnitPrice'].mean().reset_index()
    avg_prices.columns = ['ItemID', 'Avg_UnitPrice']
    df_inv = sku_fc.merge(avg_prices, on='ItemID', how='left')
    df_inv['Avg_UnitPrice'] = df_inv['Avg_UnitPrice'].fillna(1.0)

    S = 50.0
    H_RATE = 0.20
    df_inv['Annual_Demand'] = df_inv['forecast_mean'] * 52
    df_inv['Holding_Cost_Unit'] = (df_inv['Avg_UnitPrice'] * H_RATE).replace(0, 0.1)
    df_inv['EOQ'] = np.sqrt((2 * df_inv['Annual_Demand'] * S) / df_inv['Holding_Cost_Unit'])
    df_inv['Orders_Per_Year'] = df_inv['Annual_Demand'] / df_inv['EOQ'].replace(0, np.nan)
    df_inv['EOQ'] = df_inv['EOQ'].fillna(0).round()
    df_inv['Orders_Per_Year'] = df_inv['Orders_Per_Year'].fillna(0).round(1)

    inv_report = df_inv[[
        'ItemID', 'ItemName', 'forecast_mean', 'EOQ',
        'safety_stock_ml', 'rop_ml', 'Orders_Per_Year',
    ]].copy()
    inv_report.to_csv(output_inv_path, index=False, encoding='utf-8-sig')

    metrics_path = models_dir / "model_metrics.json"
    with open(metrics_path, 'w') as f:
        json.dump({
            'xgb_wmape': round(xgb_val_metrics['WMAPE'], 2),
            'rf_wmape': round(rf_val_metrics['WMAPE'], 2),
            'ensemble_wmape': round(ens_test_metrics['WMAPE'], 2),
        }, f, indent=2)

    logger.info("Retraining complete. Ready for API reload.")
    return {
        **ens_test_metrics,
        'XGBoost_WMAPE': xgb_val_metrics['WMAPE'],
        'RandomForest_WMAPE': rf_val_metrics['WMAPE'],
        'Ridge_WMAPE': ridge_val_metrics['WMAPE'],
        'Ensemble_WMAPE': ens_test_metrics['WMAPE'],
    }


if __name__ == "__main__":
    data_file = repo_root / "weekly.csv"
    if not data_file.exists():
        data_file = repo_root / "notebooks" / "weekly.csv"
    if not data_file.exists():
        data_file = Path("weekly.csv")
    
    if data_file.exists():
        run_retraining(data_file)
    else:
        logger.error(f"weekly.csv data file not found at {data_file}")

