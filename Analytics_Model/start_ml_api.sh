#!/bin/bash

# Start Analytics Model API Server
# This script starts the ML API server that provides AI-powered analytics

echo "🚀 Starting Analytics Model API Server..."

# Check if Python is installed
if ! command -v python3 &> /dev/null; then
    echo "❌ Python3 is not installed. Please install Python3 first."
    exit 1
fi

# Check if virtual environment exists
if [ ! -d ".venv" ]; then
    echo "📦 Creating virtual environment..."
    python3 -m venv .venv
fi

# Activate virtual environment
echo "🔧 Activating virtual environment..."
source .venv/bin/activate

# Install dependencies
echo "📚 Installing dependencies..."
pip install -q flask flask-cors pandas numpy scikit-learn joblib

# Check if models exist
if [ ! -f "trained_models/pattern_classifier_lgbm.joblib" ]; then
    echo "⚠️  Warning: Trained models not found. The API will work with limited functionality."
    echo "   To get full ML capabilities, run the training scripts first."
fi

# Set environment variables
export FLASK_ENV=development
export PORT=5001

# Start the API server
echo "🎯 Starting ML API server on port 5001..."
echo "📡 Available endpoints:"
echo "   - GET  /health"
echo "   - POST /api/ml/predictions"
echo "   - POST /api/ml/recommendations"
echo "   - POST /api/ml/anomalies"
echo "   - POST /api/analytics/predict-pattern"
echo "   - POST /api/analytics/analyze-spending"
echo ""
echo "🔗 Backend should connect to: http://localhost:5001"
echo "💡 Press Ctrl+C to stop the server"
echo ""

python3 api_server.py