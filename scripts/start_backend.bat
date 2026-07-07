@echo off
REM CrunchOps — Setup and start backend
cd /d "%~dp0.."
echo === Installing Python dependencies ===
python -m pip install -r requirements.txt
echo.
echo === Training ML models (if missing) ===
if not exist "src\models\xgb_model.joblib" (
    python mlops\retraining\retrain_pipeline.py
) else (
    echo Models already exist, skipping training.
)
echo.
echo === Starting FastAPI server on http://0.0.0.0:8000 ===
python -m uvicorn src.api.main:app --host 0.0.0.0 --port 8000 --reload
