@echo off
echo ================================================
echo   Demand Forecasting ^& Inventory Optimizer
echo ================================================
echo.
echo [1] Activating virtual environment...
call venv\Scripts\activate.bat
echo.
echo [2] Launching Jupyter Lab...
jupyter lab --notebook-dir=. --no-browser
pause
