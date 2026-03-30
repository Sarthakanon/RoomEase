@echo off
REM Analytics Model API Startup Script for Windows

echo Starting Analytics Model API...
echo.

REM Check if virtual environment exists
if not exist "venv" (
    echo Creating virtual environment...
    python -m venv venv
    echo Virtual environment created
    echo.
)

REM Activate virtual environment
echo Activating virtual environment...
call venv\Scripts\activate.bat

REM Check if dependencies are installed
python -c "import flask" 2>nul
if errorlevel 1 (
    echo Installing dependencies...
    pip install -r requirements.txt
    echo Dependencies installed
    echo.
)

REM Check if models exist
echo Checking for trained models...
if not exist "trained_models\pattern_classifier_lgbm.joblib" (
    echo Error: Trained models not found in trained_models\
    echo Please ensure all .joblib files are present
    pause
    exit /b 1
)
echo Models found
echo.

REM Start the server
echo Starting Flask server on port 5001...
echo Press Ctrl+C to stop
echo.
python api_server.py

pause
