# RoomEase ML Pipeline

Machine learning pipeline for spending analytics, predictions, and recommendations.

## Setup

```bash
# Create virtual environment
python -m venv venv
source venv/bin/activate  # On Windows: venv\Scripts\activate

# Install dependencies
pip install -r requirements.txt
pip install -e .
```

## Download Dataset

```bash
python scripts/download_kaggle_data.py
```

## Train Models

```bash
# Train all models
python scripts/train_all.py

# Train specific model
python trainers/spending_predictor.py
python trainers/pattern_classifier.py
python trainers/anomaly_detector.py
```

## Export Models

```bash
python scripts/export_models.py --format tflite
python scripts/export_models.py --format onnx
```

## Project Structure

```
ml_pipeline/
├── data/              # Training data
├── models/            # Trained model artifacts
├── scripts/           # Utility scripts
├── trainers/          # Model training modules
├── preprocessing.py   # Feature engineering
├── anonymizer.py      # Data anonymization
└── requirements.txt   # Dependencies
```
