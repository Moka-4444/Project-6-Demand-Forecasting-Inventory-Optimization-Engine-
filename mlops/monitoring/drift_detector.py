"""
Drift Detection Module for MLOps.

Calculates the Population Stability Index (PSI) to detect data drift
in key features (Qty, Avg_UnitPrice, Total_Promo) between a reference
dataset and a current dataset.
"""

import argparse
import json
import logging
import os
from pathlib import Path
from typing import Dict, List, Union, Optional


import numpy as np
import pandas as pd

logging.basicConfig(
    level=logging.INFO,
    format="%(asctime)s │ %(levelname)-7s │ %(message)s",
    datefmt="%H:%M:%S",
)
logger = logging.getLogger(__name__)


def calculate_psi(
    expected: np.ndarray, actual: np.ndarray, buckets: int = 10
) -> float:
    """
    Calculate the Population Stability Index (PSI) between expected and actual distributions.

    Parameters
    ----------
    expected : np.ndarray
        Reference/baseline data distribution.
    actual : np.ndarray
        Current/new data distribution.
    buckets : int
        Number of buckets/bins for histogram binning.

    Returns
    -------
    float
        PSI value.
    """
    expected = expected[~np.isnan(expected)]
    actual = actual[~np.isnan(actual)]

    if len(expected) == 0 or len(actual) == 0:
        logger.warning("Empty array provided to calculate_psi.")
        return 0.0

    def scale_range(input_arr: np.ndarray, min_val: float, max_val: float) -> np.ndarray:
        arr_min = np.min(input_arr)
        arr_max = np.max(input_arr)
        if arr_max == arr_min:
            return np.full_like(input_arr, min_val)
        
        scaled = input_arr - arr_min
        scaled = scaled / (arr_max - arr_min) * (max_val - min_val)
        return scaled + min_val

    breakpoints = np.arange(0, buckets + 1) / buckets * 100
    breakpoints = scale_range(breakpoints, np.min(expected), np.max(expected))
    
    # Ensure breakpoints are unique and sorted
    breakpoints = np.unique(breakpoints)
    if len(breakpoints) < 2:
        breakpoints = np.array([np.min(expected) - 1e-5, np.max(expected) + 1e-5])

    expected_counts = np.histogram(expected, breakpoints)[0]
    actual_counts = np.histogram(actual, breakpoints)[0]

    expected_percents = expected_counts / len(expected)
    actual_percents = actual_counts / len(actual)

    def sub_psi(e_perc: float, a_perc: float) -> float:
        if a_perc == 0:
            a_perc = 0.0001
        if e_perc == 0:
            e_perc = 0.0001
        return (e_perc - a_perc) * np.log(e_perc / a_perc)

    psi_value = sum(
        sub_psi(expected_percents[i], actual_percents[i])
        for i in range(len(expected_percents))
    )
    return float(psi_value)


def run_drift_detection(
    data_path: Union[str, Path],
    ref_max_week: int = 18,
    cur_min_week: int = 23,
    output_report_path: Optional[Union[str, Path]] = None,
) -> Dict:
    """
    Run data drift detection on historical sales data.

    Parameters
    ----------
    data_path : str or Path
        Path to the weekly sales CSV dataset (e.g. weekly.csv).
    ref_max_week : int
        Maximum week number for the reference/baseline dataset (default: 18).
    cur_min_week : int
        Minimum week number for the current dataset to monitor (default: 23).
    output_report_path : str or Path, optional
        Path to save the JSON drift report.

    Returns
    -------
    dict
        Drift detection summary report.
    """
    logger.info(f"Loading data from {data_path} for drift detection...")
    df = pd.read_csv(data_path, encoding="utf-8-sig")
    
    # Rename columns to standard names if needed
    expected_cols = {
        'Year', 'Week', 'ItemID', 'Qty', 'ItemName', 'BrandID', 'BrandName',
        'MasterBrandID', 'MasterBrandName', 'UOM', 'Factor',
        'Avg_Daily_Demand', 'Safety_Stock', 'ROP', 'Avg_UnitPrice',
        'Total_Promo', 'Total_CashDiscount', 'Total_ManualDiscount',
        'Total_Taxes', 'Total_Revenue'
    }
    
    if not set(df.columns).issuperset({'Week', 'Qty', 'Avg_UnitPrice', 'Total_Promo'}):
        # Fallback renaming if columns don't match standard names
        df.columns = [
            'Year', 'Week', 'ItemID', 'Qty', 'ItemName', 'BrandID', 'BrandName',
            'MasterBrandID', 'MasterBrandName', 'UOM', 'Factor',
            'Avg_Daily_Demand', 'Safety_Stock', 'ROP', 'Avg_UnitPrice',
            'Total_Promo', 'Total_CashDiscount', 'Total_ManualDiscount',
            'Total_Taxes', 'Total_Revenue'
        ][:len(df.columns)]

    ref_df = df[df['Week'] <= ref_max_week].copy()
    cur_df = df[df['Week'] >= cur_min_week].copy()

    logger.info(f"Reference period (Weeks <= {ref_max_week}): {len(ref_df)} rows")
    logger.info(f"Current period (Weeks >= {cur_min_week}): {len(cur_df)} rows")

    features_to_monitor = ['Qty', 'Avg_UnitPrice', 'Total_Promo']
    results = []
    retrain_recommended = False
    reasons = []

    for feat in features_to_monitor:
        if feat not in df.columns:
            logger.warning(f"Feature '{feat}' not found in dataset. Skipping.")
            continue
            
        ref_vals = ref_df[feat].dropna().values
        cur_vals = cur_df[feat].dropna().values

        if len(ref_vals) > 0 and len(cur_vals) > 0:
            psi_val = calculate_psi(ref_vals, cur_vals)
            
            if psi_val < 0.1:
                status = "✅ Stable"
            elif psi_val < 0.25:
                status = "⚠️ Moderate Drift"
            else:
                status = "🚨 Severe Drift"
                retrain_recommended = True
                reasons.append(f"Severe data drift detected in feature '{feat}' (PSI = {psi_val:.4f})")

            results.append({
                "feature": feat,
                "psi": round(psi_val, 4),
                "status": status
            })
            logger.info(f"Feature: {feat:<15} │ PSI: {psi_val:.4f} │ Status: {status}")
        else:
            logger.warning(f"Insufficient data for feature '{feat}' to calculate PSI.")

    report = {
        "reference_period": f"Weeks <= {ref_max_week}",
        "current_period": f"Weeks >= {cur_min_week}",
        "metrics": results,
        "retrain_recommended": retrain_recommended,
        "reasons": reasons
    }

    if output_report_path:
        out_path = Path(output_report_path)
        out_path.parent.mkdir(parents=True, exist_ok=True)
        with open(out_path, "w", encoding="utf-8") as f:
            json.dump(report, f, indent=4, ensure_ascii=False)
        logger.info(f"Saved drift report to {out_path}")

    return report


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description="Run MLOps data drift detection using PSI.")
    parser.add_argument(
        "--data",
        type=str,
        default="weekly.csv",
        help="Path to weekly sales dataset"
    )
    parser.add_argument(
        "--ref-max",
        type=int,
        default=18,
        help="Maximum week for baseline/reference data"
    )
    parser.add_argument(
        "--cur-min",
        type=int,
        default=23,
        help="Minimum week for new/current data"
    )
    parser.add_argument(
        "--output",
        type=str,
        default="data/processed/drift_report.json",
        help="Path to save JSON report"
    )
    args = parser.parse_args()

    # Resolve paths relative to repo root if run from other dirs
    data_file = Path(args.data)
    if not data_file.exists():
        data_file = Path(__file__).resolve().parents[2] / args.data
    if not data_file.exists() and args.data == "weekly.csv":
        data_file = Path(__file__).resolve().parents[2] / "notebooks" / "weekly.csv"


    if data_file.exists():
        run_drift_detection(
            data_path=data_file,
            ref_max_week=args.ref_max,
            cur_min_week=args.cur_min,
            output_report_path=args.output
        )
    else:
        logger.error(f"Weekly data file not found at {args.data} or {data_file}")
