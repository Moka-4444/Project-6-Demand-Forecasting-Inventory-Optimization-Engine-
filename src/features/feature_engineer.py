"""
Feature Engineering Module.

Extracted from notebooks/02_model_development.ipynb.
Prepares the global dataset, creates lag and rolling features (log scale),
adds price, promo, and temporal features, and applies target encoding.
"""

import logging
import numpy as np
import pandas as pd
from typing import Dict, List, Tuple

logger = logging.getLogger(__name__)

FEATURE_COLS = [
    'lag_1', 'lag_2', 'lag_4', 'rolling_mean_4', 'rolling_std_4',
    'rolling_mean_4_raw',
    'Avg_UnitPrice', 'log_price', 'price_change_pct',
    'Total_Promo', 'has_promo',
    'Week', 'Month', 'week_sin', 'week_cos',
    'Factor', 'UOM_encoded',
    'item_encoded', 'brand_encoded', 'brand_avg_week_qty'
]


def prepare_global_dataset(df_raw: pd.DataFrame) -> pd.DataFrame:
    """
    Clean and filter raw weekly data: clip negatives, filter to active SKUs (>=8 weeks),
    drop leakage columns, and apply log transform on Qty.
    """
    df = df_raw.copy()
    
    # Clip negative quantities (returns)
    df['Qty'] = df['Qty'].clip(lower=0)
    
    # Filter to SKUs with >= 8 weeks of history
    week_counts = df.groupby('ItemID')['Week'].count()
    valid_skus = week_counts[week_counts >= 8].index
    df_global = df[df['ItemID'].isin(valid_skus)].copy()
    
    # Sort chronologically per SKU
    df_global = df_global.sort_values(['ItemID', 'Date']).reset_index(drop=True)
    
    # Log transform target
    df_global['Qty_log'] = np.log1p(df_global['Qty'])
    
    logger.info(f"Prepared global dataset. SKUs: {df_global['ItemID'].nunique()}, Rows: {len(df_global)}")
    return df_global


def create_lag_features(df: pd.DataFrame) -> pd.DataFrame:
    """
    Creates lag features on Qty_log (lag_1, lag_2, lag_4).
    """
    df = df.copy()
    for lag in [1, 2, 4]:
        df[f'lag_{lag}'] = df.groupby('ItemID')['Qty_log'].shift(lag)
    return df


def create_rolling_features(df: pd.DataFrame) -> pd.DataFrame:
    """
    Creates rolling statistics features:
    - rolling_mean_4: rolling mean of Qty_log with window size 4 (log scale)
    - rolling_std_4: rolling standard deviation of Qty_log with window size 4 (log scale)
    - rolling_mean_4_raw: rolling mean of raw Qty (real scale)
    """
    df = df.copy()
    df['rolling_mean_4'] = df.groupby('ItemID')['Qty_log'].transform(
        lambda x: x.shift(1).rolling(window=4, min_periods=2).mean()
    )
    df['rolling_std_4'] = df.groupby('ItemID')['Qty_log'].transform(
        lambda x: x.shift(1).rolling(window=4, min_periods=2).std()
    ).fillna(0)
    
    # Raw scale rolling mean (bridge feature)
    df['rolling_mean_4_raw'] = df.groupby('ItemID')['Qty'].transform(
        lambda x: x.shift(1).rolling(window=4, min_periods=2).mean()
    )
    return df


def create_price_and_promo_features(df: pd.DataFrame) -> pd.DataFrame:
    """
    Creates price change, log price, and promotion flag features.
    """
    df = df.copy()
    df['price_change_pct'] = df.groupby('ItemID')['Avg_UnitPrice'].pct_change().fillna(0).clip(-1, 1)
    df['log_price'] = np.log1p(df['Avg_UnitPrice'])
    df['has_promo'] = (df['Total_Promo'] > 0).astype(int)
    return df


def create_temporal_features(df: pd.DataFrame) -> pd.DataFrame:
    """
    Creates temporal and cyclical encoding features (Month, sin/cos encoding of Week).
    """
    df = df.copy()
    df['Month'] = df['Date'].dt.month
    df['week_sin'] = np.sin(2 * np.pi * df['Week'] / 52)
    df['week_cos'] = np.cos(2 * np.pi * df['Week'] / 52)
    df['UOM_encoded'] = (df['UOM'] == 'PL').astype(int)
    return df


def apply_target_encoding(
    df: pd.DataFrame, 
    item_encoder: Dict[str, float], 
    brand_encoder: Dict[str, float], 
    brand_avg_week: Dict[str, float],
    global_mean_qty: float
) -> pd.DataFrame:
    """
    Applies target encoding to item and brand IDs based on training encoders.
    """
    df = df.copy()
    df['item_encoded'] = df['ItemID'].map(item_encoder).fillna(global_mean_qty)
    
    # Map brand encoded columns using BrandID (extracted from ItemID prefix or mapped)
    # The training dataset has 'BrandID'
    if 'BrandID' in df.columns:
        df['brand_encoded'] = df['BrandID'].map(brand_encoder).fillna(global_mean_qty)
        df['brand_avg_week_qty'] = df['BrandID'].map(brand_avg_week).fillna(global_mean_qty)
    else:
        # Fallback if BrandID not in df
        df['brand_encoded'] = global_mean_qty
        df['brand_avg_week_qty'] = global_mean_qty
        
    return df


def build_features_pipeline(
    df_raw: pd.DataFrame, 
    item_encoder: Dict[str, float], 
    brand_encoder: Dict[str, float], 
    brand_avg_week: Dict[str, float],
    global_mean_qty: float
) -> pd.DataFrame:
    """
    Runs the full feature engineering pipeline on a raw weekly DataFrame.
    """
    df_global = prepare_global_dataset(df_raw)
    df_global = create_lag_features(df_global)
    df_global = create_rolling_features(df_global)
    df_global = create_price_and_promo_features(df_global)
    df_global = create_temporal_features(df_global)
    df_global = apply_target_encoding(
        df_global, item_encoder, brand_encoder, brand_avg_week, global_mean_qty
    )
    
    # Drop rows with NaN in lags or rolling features (usually first few weeks of each product)
    df_model = df_global.dropna(subset=['lag_1', 'lag_2', 'lag_4', 'rolling_mean_4']).copy()
    logger.info(f"Feature engineering pipeline complete. Final shape: {df_model.shape}")
    return df_model
