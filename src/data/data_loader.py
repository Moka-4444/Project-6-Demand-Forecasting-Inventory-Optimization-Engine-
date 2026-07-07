"""
Data Loading & Preparation Module.

Extracted from notebooks/00_data_prepairing.ipynb.
Handles raw data ingestion, aggregation (daily → weekly),
financial feature merging, and inventory metric calculations.
"""

import logging
from pathlib import Path
from typing import Optional, Union

import numpy as np
import pandas as pd

logger = logging.getLogger(__name__)


def load_raw_sales_data(path: Union[str, Path]) -> pd.DataFrame:
    """
    Load raw sales data from an Excel file.

    Parameters
    ----------
    path : str or Path
        Path to the SalesData Excel file.

    Returns
    -------
    pd.DataFrame
        Raw sales DataFrame with Date parsed.
    """
    df = pd.read_excel(path)
    df["Date"] = pd.to_datetime(df["Date"]).dt.normalize()
    logger.info(f"Loaded raw data: {df.shape[0]:,} rows × {df.shape[1]} columns")
    return df


def load_item_map(path: Union[str, Path]) -> pd.DataFrame:
    """
    Load the item mapping file (ItemID → Name, Brand, UOM, Factor).

    Parameters
    ----------
    path : str or Path
        Path to the item map Excel file.

    Returns
    -------
    pd.DataFrame
        Item mapping indexed by 'ItemID Map'.
    """
    item_map = pd.read_excel(path)
    item_map = item_map.set_index("ItemID Map")
    logger.info(f"Loaded item map: {len(item_map)} products")
    return item_map


def aggregate_daily(df: pd.DataFrame) -> pd.DataFrame:
    """
    Aggregate raw sales to daily level per product.

    Parameters
    ----------
    df : pd.DataFrame
        Raw sales data with 'Date', 'ItemID-', and 'Qty' columns.

    Returns
    -------
    pd.DataFrame
        Daily aggregated demand.
    """
    daily = df.groupby(["Date", "ItemID-"])["Qty"].sum().reset_index()
    logger.info(f"Daily aggregation: {len(daily):,} rows")
    return daily


def aggregate_weekly(
    daily_demand: pd.DataFrame,
    item_map: pd.DataFrame,
    lead_time: int = 7,
    safety_factor: float = 0.2,
) -> pd.DataFrame:
    """
    Aggregate daily demand to weekly level, merge with item info,
    and compute inventory metrics.

    Parameters
    ----------
    daily_demand : pd.DataFrame
        Daily demand with 'Date', 'ItemID-', 'Qty', and item map columns.
    item_map : pd.DataFrame
        Item mapping table.
    lead_time : int
        Lead time in days (default: 7).
    safety_factor : float
        Safety stock percentage (default: 0.2 = 20%).

    Returns
    -------
    pd.DataFrame
        Weekly demand with inventory metrics.
    """
    # Add Week and Year
    daily_demand["Week"] = daily_demand["Date"].dt.isocalendar().week
    daily_demand["Year"] = daily_demand["Date"].dt.year

    # Aggregate to weekly
    weekly = (
        daily_demand.groupby(["Year", "Week", "ItemID-"])["Qty"]
        .sum()
        .reset_index()
    )

    # Merge item info
    weekly = weekly.merge(
        item_map, left_on="ItemID-", right_on="ItemID Map", how="left"
    )

    # Inventory metrics
    weekly["Avg_Daily_Demand"] = weekly["Qty"] / 7
    weekly["Safety_Stock"] = (
        weekly["Avg_Daily_Demand"] * safety_factor * weekly["Factor"]
    )
    weekly["ROP"] = (
        weekly["Avg_Daily_Demand"] * lead_time + weekly["Safety_Stock"]
    )

    logger.info(f"Weekly aggregation: {len(weekly):,} rows")
    return weekly


def add_financial_features(
    raw_df: pd.DataFrame, weekly_demand: pd.DataFrame
) -> pd.DataFrame:
    """
    Compute and merge weekly financial aggregates (price, promo,
    discounts, taxes, revenue) into the weekly demand DataFrame.

    Parameters
    ----------
    raw_df : pd.DataFrame
        Raw sales data with financial columns.
    weekly_demand : pd.DataFrame
        Weekly demand DataFrame.

    Returns
    -------
    pd.DataFrame
        Weekly demand enriched with financial features.
    """
    raw_df["Week"] = raw_df["Date"].dt.isocalendar().week

    weekly_financials = (
        raw_df.groupby(["Week", "ItemID-"])
        .agg(
            Avg_UnitPrice=("UnitPrice", "mean"),
            Total_Promo=("PromotionsTotal", "sum"),
            Total_CashDiscount=("CashDiscount", "sum"),
            Total_ManualDiscount=("ManualDiscount", "sum"),
            Total_Taxes=("TaxesTotal", "sum"),
            Total_Revenue=("LineTotal", "sum"),
        )
        .reset_index()
    )

    # Extract week number if period object
    weekly_financials["Week"] = weekly_financials["Week"].apply(
        lambda x: x.week if hasattr(x, "week") else x
    )

    result = weekly_demand.merge(
        weekly_financials, on=["Week", "ItemID-"], how="outer"
    )
    logger.info(f"Financial features merged: {result.shape[1]} columns")
    return result


def save_weekly_csv(
    df: pd.DataFrame, output_path: Union[str, Path]
) -> None:
    """
    Save the weekly demand DataFrame to CSV.

    Parameters
    ----------
    df : pd.DataFrame
        Weekly demand data.
    output_path : str or Path
        Output file path.
    """
    output_path = Path(output_path)
    output_path.parent.mkdir(parents=True, exist_ok=True)
    df.to_csv(output_path, index=False, encoding="utf-8-sig")
    logger.info(f"Saved weekly CSV: {output_path} ({len(df):,} rows)")


def build_weekly_dataset(
    sales_path: Union[str, Path],
    item_map_path: Union[str, Path],
    output_path: Optional[Union[str, Path]] = None,
    lead_time: int = 7,
    safety_factor: float = 0.2,
) -> pd.DataFrame:
    """
    End-to-end pipeline: load raw data → aggregate → enrich → save.

    Parameters
    ----------
    sales_path : str or Path
        Path to the raw sales Excel file.
    item_map_path : str or Path
        Path to the item mapping Excel file.
    output_path : str or Path, optional
        If provided, saves the result to this path.
    lead_time : int
        Lead time in days.
    safety_factor : float
        Safety stock percentage.

    Returns
    -------
    pd.DataFrame
        Complete weekly demand dataset.
    """
    logger.info("=" * 50)
    logger.info("  Building Weekly Dataset")
    logger.info("=" * 50)

    # 1. Load raw data
    raw_df = load_raw_sales_data(sales_path)
    item_map = load_item_map(item_map_path)

    # 2. Aggregate daily
    daily = aggregate_daily(raw_df)

    # 3. Merge item info into daily
    daily = daily.merge(
        item_map, left_on="ItemID-", right_on="ItemID Map", how="left"
    )

    # 4. Aggregate to weekly
    weekly = aggregate_weekly(daily, item_map, lead_time, safety_factor)

    # 5. Add financial features
    weekly = add_financial_features(raw_df, weekly)

    # 6. Save if path provided
    if output_path is not None:
        save_weekly_csv(weekly, output_path)

    logger.info(f"✅ Weekly dataset ready: {weekly.shape}")
    return weekly
