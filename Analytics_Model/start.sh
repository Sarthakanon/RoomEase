#!/bin/bash

# Analytics Model API Startup Script

echo "🚀 Starting Analytics Model API..."
echo ""

# Check if virtual environment exists
if [ ! -d "venv" ]; then
    echo "📦 Creating virtual environment..."
    python3 -m venv venv
    echo "✓ Virtual environment created"
    echo ""
fi

# Activate virtual environment
echo "🔧 Activating virtual environment..."
source venv/bin/activate

# Check if dependencies are installed
if ! python -c "import flask" 2>/dev/null; then
    echo "📥 Installing dependencies..."
    pip install -r requirements.txt
    echo "✓ Dependencies installed"
    echo ""
fi

# Check if models exist
echo "🔍 Checking for trained models..."
if [ ! -f "trained_models/pattern_classifier_lgbm.joblib" ]; then
    echo "❌ Error: Trained models not found in trained_models/"
    echo "Please ensure all .joblib files are present"
    exit 1
fi
echo "✓ Models found"
echo ""

# Start the server
echo "🌐 Starting Flask server on port 5001..."
echo "Press Ctrl+C to stop"
echo ""
python api_server.py
