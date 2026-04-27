@echo off
REM Start Analytics Model API Server
REM This script starts the ML API server that provides AI-powered analytics

echo 🚀 Starting Analytics Model API Server...

REM Check if Python is installed
python --version >nul 2>&1
if errorlevel 1 (
    echo ❌ Python is not installed. Please install Python first.
    pause
    exit /b 1
)

REM Check if virtual environment exists
if not exist ".venv" (
    echo 📦 Creating virtual environment...
    python -m venv .venv
)

REM Activate virtual environment
echo 🔧 Activating virtual environment...
call .venv\Scripts\activate.bat

REM Install dependencies
echo 📚 Installing dependencies...
pip install -q flask flask-cors pandas numpy scikit-learn joblib

REM Check if models exist
if not exist "trained_models\pattern_classifier_lgbm.joblib" (
    echo ⚠️  Warning: Trained models not found. The API will work with limited functionality.
    echo    To get full ML capabilities, run the training scripts first.
)

REM Set environment variables
set FLASK_ENV=development
set PORT=5001

REM Start the API server
echo 🎯 Starting ML API server on port 5001...
echo 📡 Available endpoints:
echo    - GET  /health
echo    - POST /api/ml/predictions
echo    - POST /api/ml/recommendations
echo    - POST /api/ml/anomalies
echo    - POST /api/analytics/predict-pattern
echo    - POST /api/analytics/analyze-spending
echo.
echo 🔗 Backend should connect to: http://localhost:5001
echo 💡 Press Ctrl+C to stop the server
echo.

python api_server.py

pause