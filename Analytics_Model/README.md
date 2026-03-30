# Analytics Model

Machine Learning models for spending pattern analysis and predictions.

## Overview

This directory contains trained ML models and an API server to provide analytics capabilities for the RoomEase application.

## Contents

- **`trained_models/`** - Pre-trained ML models (.joblib files)
- **`scripts/`** - Feature engineering and model training scripts
- **`generators/`** - Data generation utilities
- **`data/`** - Training and processed data
- **`api_server.py`** - Flask REST API server
- **`requirements.txt`** - Python dependencies

## Quick Start

### Linux/Mac
```bash
./start.sh
```

### Windows
```batch
start.bat
```

### Manual Start
```bash
# Create virtual environment
python -m venv venv
source venv/bin/activate  # Linux/Mac
# or
venv\Scripts\activate  # Windows

# Install dependencies
pip install -r requirements.txt

# Start server
python api_server.py
```

## API Endpoints

### Health Check
```
GET http://localhost:5001/health
```

### Predict Spending Pattern
```
POST http://localhost:5001/api/analytics/predict-pattern
Content-Type: application/json

{
  "expenses": [...],
  "user_data": {...}
}
```

### Analyze Spending
```
POST http://localhost:5001/api/analytics/analyze-spending
Content-Type: application/json

{
  "user_id": "string",
  "expenses": [...],
  "start_date": "YYYY-MM-DD",
  "end_date": "YYYY-MM-DD"
}
```

## Documentation

- **[QUICK_START.md](QUICK_START.md)** - Quick setup guide
- **[INTEGRATION_README.md](INTEGRATION_README.md)** - Integration with backend
- **[IMPLEMENTATION_GUIDE.md](IMPLEMENTATION_GUIDE.md)** - Model implementation details

## Models

The following trained models are included:

1. **LightGBM Classifier** (`pattern_classifier_lgbm.joblib`) - Recommended
2. **Random Forest Classifier** (`pattern_classifier_rf.joblib`)
3. **SGD Classifier** (`pattern_classifier_sgd.joblib`)
4. **Feature Scaler** (`pattern_scaler.joblib`)

## Requirements

- Python 3.8+
- Flask 3.0.0
- pandas 2.1.4
- scikit-learn 1.3.2
- lightgbm 4.1.0
- joblib 1.3.2

## Development

### Running Tests
```bash
python -m pytest tests/
```

### Training Models
```bash
python scripts/03_model_training.py
```

### Feature Engineering
```bash
python scripts/02_feature_engineering.py
```

## Deployment

### Docker
```bash
docker build -t analytics-model .
docker run -p 5001:5001 analytics-model
```

### Production
```bash
pip install gunicorn
gunicorn -w 4 -b 0.0.0.0:5001 api_server:app
```

## Support

For issues or questions, see the documentation files or check the main project README.
