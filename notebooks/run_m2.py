"""
Run Milestone 2 Notebook Code — Data Prep + Baseline Forecast
"""
import pandas as pd
import numpy as np
import warnings
from pathlib import Path
from sklearn.metrics import mean_absolute_error, mean_squared_error, r2_score
import matplotlib
matplotlib.use('Agg')  # Non-interactive backend
import matplotlib.pyplot as plt
import seaborn as sns

warnings.filterwarnings('ignore')
np.random.seed(42)
sns.set_theme(style='whitegrid', palette='muted', font_scale=1.1)
plt.rcParams.update({'figure.dpi': 120, 'figure.facecolor': 'white', 'axes.spines.top': False, 'axes.spines.right': False})
COLORS = sns.color_palette('muted', 10)

print('=' * 65)
print('  MILESTONE 2: FORECAST MODEL DEVELOPMENT — BASELINE')
print('=' * 65)

# ── 1. Load Data ──
df = pd.read_csv('weekly.csv', encoding='utf-8-sig')
df.columns = ['Year','Week','ItemID','Qty','ItemName','BrandID','BrandName','MasterBrandID','MasterBrandName','UOM','Factor','Avg_Daily_Demand','Safety_Stock','ROP','Avg_UnitPrice','Total_Promo','Total_CashDiscount','Total_ManualDiscount','Total_Taxes','Total_Revenue']
df['Date'] = pd.to_datetime(df['Year'].astype(str) + '-W' + df['Week'].astype(str).str.zfill(2) + '-1', format='%G-W%V-%u')

print(f'\n✅ Dataset loaded: {df.shape[0]:,} rows × {df.shape[1]} columns')
print(f'   Date range : {df["Date"].min().date()} → {df["Date"].max().date()}')
print(f'   Products   : {df["ItemID"].nunique()}')
print(f'   Weeks      : {df["Week"].nunique()}')

# ── 2. Select Top Product ──
product_sales = df.groupby(['ItemID','ItemName'])['Qty'].sum().sort_values(ascending=False).reset_index().head(10)
product_sales.columns = ['ItemID','ItemName','Total_Qty']

print(f'\n🏆 Top 10 Products by Total Sales:')
print('-' * 60)
for i, row in product_sales.iterrows():
    marker = ' 👈 SELECTED' if i == 0 else ''
    print(f"  {i+1:>2}. {row['ItemName']:<35} {row['Total_Qty']:>10,} units{marker}")

TARGET_ITEM = product_sales.iloc[0]['ItemID']
TARGET_NAME = product_sales.iloc[0]['ItemName']

# ── 3. Filter & Feature Engineering ──
pdf = df[df['ItemID']==TARGET_ITEM].sort_values('Date').reset_index(drop=True).copy()
print(f'\n📊 Selected: {TARGET_NAME}')
print(f'   Series length: {len(pdf)} weeks')
print(f'   Qty range: {pdf["Qty"].min():,} → {pdf["Qty"].max():,}')
print(f'   Qty mean : {pdf["Qty"].mean():,.1f} ± {pdf["Qty"].std():,.1f}')

pdf['lag_1'] = pdf['Qty'].shift(1)
pdf['lag_2'] = pdf['Qty'].shift(2)
pdf['lag_4'] = pdf['Qty'].shift(4)
pdf['rolling_mean_4'] = pdf['Qty'].shift(1).rolling(window=4).mean()
pdf['rolling_std_4'] = pdf['Qty'].shift(1).rolling(window=4).std()
pdf['month'] = pdf['Date'].dt.month

print(f'\n✅ Features created: lag_1, lag_2, lag_4, rolling_mean_4, rolling_std_4, month')

# ── 4. Train/Val/Test Split ──
n = len(pdf)
train_end = int(n * 0.70)
val_end = int(n * 0.85)

train_df = pdf.iloc[:train_end].copy()
val_df = pdf.iloc[train_end:val_end].copy()
test_df = pdf.iloc[val_end:].copy()

print(f'\n📊 Time-Based Split:')
print(f'   Train      : {len(train_df):>3} weeks  (Week {train_df["Week"].iloc[0]:>2} → {train_df["Week"].iloc[-1]:>2})  {len(train_df)/n*100:.0f}%')
print(f'   Validation : {len(val_df):>3} weeks  (Week {val_df["Week"].iloc[0]:>2} → {val_df["Week"].iloc[-1]:>2})  {len(val_df)/n*100:.0f}%')
print(f'   Test       : {len(test_df):>3} weeks  (Week {test_df["Week"].iloc[0]:>2} → {test_df["Week"].iloc[-1]:>2})  {len(test_df)/n*100:.0f}%')

# ── 5. Naive Forecast ──
val_df['Naive_Pred'] = val_df['Qty'].shift(1)
val_df.iloc[0, val_df.columns.get_loc('Naive_Pred')] = train_df['Qty'].iloc[-1]
test_df['Naive_Pred'] = test_df['Qty'].shift(1)
test_df.iloc[0, test_df.columns.get_loc('Naive_Pred')] = val_df['Qty'].iloc[-1]

# ── 6. Moving Average ──
MA_WINDOW = 4
full = pd.concat([train_df[['Week','Qty']], val_df[['Week','Qty']]], ignore_index=True)
ma_v = []
for i in range(len(val_df)):
    he = len(train_df) + i
    h = full['Qty'].iloc[max(0, he-MA_WINDOW):he]
    ma_v.append(h.mean())
val_df['MA_Pred'] = ma_v

full2 = pd.concat([train_df[['Week','Qty']], val_df[['Week','Qty']], test_df[['Week','Qty']]], ignore_index=True)
ma_t = []
for i in range(len(test_df)):
    he = len(train_df) + len(val_df) + i
    h = full2['Qty'].iloc[max(0, he-MA_WINDOW):he]
    ma_t.append(h.mean())
test_df['MA_Pred'] = ma_t

# ── 7. Evaluation ──
def evaluate_model(y_true, y_pred, model_name):
    mask = ~(np.isnan(y_true) | np.isnan(y_pred))
    yt = np.array(y_true)[mask]
    yp = np.array(y_pred)[mask]
    mae = mean_absolute_error(yt, yp)
    rmse = np.sqrt(mean_squared_error(yt, yp))
    mape = np.mean(np.abs((yt - yp) / np.where(yt == 0, 1, yt))) * 100
    r2 = r2_score(yt, yp)
    return {'Model': model_name, 'MAE': round(mae, 2), 'RMSE': round(rmse, 2), 'MAPE (%)': round(mape, 2), 'R²': round(r2, 4)}

print('\n' + '=' * 65)
print('  📊 BASELINE MODEL RESULTS')
print('=' * 65)

print('\n▶ Validation Set Predictions:')
print(val_df[['Week','Qty','Naive_Pred','MA_Pred']].to_string(index=False))

results_val = []
results_val.append(evaluate_model(val_df['Qty'], val_df['Naive_Pred'], 'Naive Forecast'))
results_val.append(evaluate_model(val_df['Qty'], val_df['MA_Pred'], f'Moving Avg ({MA_WINDOW}w)'))
rv = pd.DataFrame(results_val)
print('\n▶ Validation Metrics:')
print(rv.to_string(index=False))

print('\n▶ Test Set Predictions:')
print(test_df[['Week','Qty','Naive_Pred','MA_Pred']].to_string(index=False))

results_test = []
results_test.append(evaluate_model(test_df['Qty'], test_df['Naive_Pred'], 'Naive Forecast'))
results_test.append(evaluate_model(test_df['Qty'], test_df['MA_Pred'], f'Moving Avg ({MA_WINDOW}w)'))
rt = pd.DataFrame(results_test)
print('\n▶ Test Metrics:')
print(rt.to_string(index=False))

best_val = rv.loc[rv['MAE'].idxmin(), 'Model']
best_test = rt.loc[rt['MAE'].idxmin(), 'Model']
print(f'\n🏆 Best Baseline (Validation): {best_val}')
print(f'🏆 Best Baseline (Test)      : {best_test}')

# ── 8. Save Plots ──
# Plot 1: Time series
fig, ax = plt.subplots(figsize=(14, 5))
ax.plot(pdf['Week'], pdf['Qty'], 'o-', color=COLORS[0], linewidth=2, markersize=6)
ax.fill_between(pdf['Week'], pdf['Qty'], alpha=0.15, color=COLORS[0])
ax.axhline(y=pdf['Qty'].mean(), color='red', linestyle='--', alpha=0.5, label=f'Mean = {pdf["Qty"].mean():,.0f}')
ax.set_xlabel('Week'); ax.set_ylabel('Qty'); ax.set_title(f'Weekly Sales — {TARGET_NAME}', fontweight='bold')
ax.legend()
plt.tight_layout(); plt.savefig('plot_timeseries.png', dpi=120, bbox_inches='tight'); plt.close()
print('\n✅ Saved: plot_timeseries.png')

# Plot 2: Split visualization
fig, ax = plt.subplots(figsize=(14, 5))
ax.plot(train_df['Week'], train_df['Qty'], 'o-', color=COLORS[0], linewidth=2, label='Train', markersize=7)
ax.plot(val_df['Week'], val_df['Qty'], 's-', color=COLORS[1], linewidth=2, label='Validation', markersize=7)
ax.plot(test_df['Week'], test_df['Qty'], 'D-', color=COLORS[3], linewidth=2, label='Test', markersize=7)
ax.axvline(x=val_df['Week'].iloc[0]-0.5, color='gray', linestyle='--', alpha=0.7)
ax.axvline(x=test_df['Week'].iloc[0]-0.5, color='gray', linestyle='--', alpha=0.7)
ax.set_xlabel('Week'); ax.set_ylabel('Qty'); ax.set_title('Train / Validation / Test Split', fontweight='bold')
ax.legend()
plt.tight_layout(); plt.savefig('plot_split.png', dpi=120, bbox_inches='tight'); plt.close()
print('✅ Saved: plot_split.png')

# Plot 3: Actual vs Predicted (Validation)
fig, ax = plt.subplots(figsize=(14, 6))
ax.plot(train_df['Week'], train_df['Qty'], 'o-', color='gray', alpha=0.4, linewidth=1.5, markersize=5, label='Train')
ax.plot(val_df['Week'], val_df['Qty'], 'ko-', linewidth=2, markersize=8, label='Actual (Val)')
ax.plot(val_df['Week'], val_df['Naive_Pred'], 's--', color=COLORS[0], linewidth=2, markersize=7, label='Naive')
ax.plot(val_df['Week'], val_df['MA_Pred'], 'D--', color=COLORS[2], linewidth=2, markersize=7, label=f'MA({MA_WINDOW}w)')
ax.axvline(x=val_df['Week'].iloc[0]-0.5, color='gray', linestyle='--', alpha=0.5)
ax.set_xlabel('Week'); ax.set_ylabel('Qty'); ax.set_title(f'Baseline vs Actual — Validation', fontweight='bold')
ax.legend()
plt.tight_layout(); plt.savefig('plot_baseline_val.png', dpi=120, bbox_inches='tight'); plt.close()
print('✅ Saved: plot_baseline_val.png')

# Plot 4: Actual vs Predicted (Test)
fig, ax = plt.subplots(figsize=(14, 6))
hweeks = list(train_df['Week']) + list(val_df['Week'])
hqty = list(train_df['Qty']) + list(val_df['Qty'])
ax.plot(hweeks, hqty, 'o-', color='gray', alpha=0.4, linewidth=1.5, markersize=4, label='History')
ax.plot(test_df['Week'], test_df['Qty'], 'ko-', linewidth=2, markersize=8, label='Actual (Test)')
ax.plot(test_df['Week'], test_df['Naive_Pred'], 's--', color=COLORS[0], linewidth=2, markersize=7, label='Naive')
ax.plot(test_df['Week'], test_df['MA_Pred'], 'D--', color=COLORS[2], linewidth=2, markersize=7, label=f'MA({MA_WINDOW}w)')
ax.axvline(x=test_df['Week'].iloc[0]-0.5, color='gray', linestyle='--', alpha=0.5)
ax.set_xlabel('Week'); ax.set_ylabel('Qty'); ax.set_title(f'Baseline vs Actual — Test', fontweight='bold')
ax.legend()
plt.tight_layout(); plt.savefig('plot_baseline_test.png', dpi=120, bbox_inches='tight'); plt.close()
print('✅ Saved: plot_baseline_test.png')

print('\n' + '=' * 65)
print('  ✅ ALL CELLS EXECUTED SUCCESSFULLY!')
print('=' * 65)
