"""
Model Evaluation for RoomEase ML
Evaluates the performance of trained pattern classifiers on the test set.
"""

import pandas as pd
import numpy as np
import joblib
import os
import seaborn as sns
import matplotlib.pyplot as plt
from sklearn.metrics import accuracy_score, classification_report, confusion_matrix

# ==================== CONFIGURATION ====================
print("=" * 80)
print("⚙️ CONFIGURATION")
print("=" * 80)

# --- File Paths ---
TEST_DATA_PATH = 'data/processed/test_data.csv'
MODEL_DIR = 'trained_models'
VISUALIZATIONS_DIR = 'visualizations'

# --- Model Info ---
SCALER_PATH = os.path.join(MODEL_DIR, 'pattern_scaler.joblib')
MODELS_TO_EVALUATE = {
    'Random Forest (Sampled)': 'pattern_classifier_rf.joblib',
    'Logistic Regression (SGD)': 'pattern_classifier_sgd.joblib',
    'LightGBM (GPU)': 'pattern_classifier_lgbm.joblib'
}
TARGET_COL = 'pattern_encoded'
CLASSES = {0: 'daily', 1: 'weekly', 2: 'monthly', 3: 'irregular'}

# --- Feature Selection ---
EXCLUDE_COLS = [
    'id', 'created_at', 'is_anomaly', 'spending_pattern',
    'category', 'expense_type', 'time_of_day', 'paid_by', 'roomspace_id',
    TARGET_COL
]

# Create visualizations directory if it doesn't exist
os.makedirs(VISUALIZATIONS_DIR, exist_ok=True)


# ==================== LOAD DATA & MODELS ====================
print("\n" + "=" * 80)
print("📥 LOADING DATA AND MODELS")
print("=" * 80)

# --- Load Test Data ---
try:
    print(f"Loading test data from {TEST_DATA_PATH}...")
    test_df = pd.read_csv(TEST_DATA_PATH)
    print(f"✅ Loaded {len(test_df):,} rows from the test set.")
except FileNotFoundError:
    print(f"❌ ERROR: Test data file not found at {TEST_DATA_PATH}.")
    print("Please run the 03_model_training.py script first to generate the test set.")
    exit()

# --- Prepare Features and Target ---
feature_cols = [col for col in test_df.columns if col not in EXCLUDE_COLS]
X_test = test_df[feature_cols].copy().fillna(0).replace([np.inf, -np.inf], 0)
y_test = test_df[TARGET_COL].copy()

# --- Load Scaler ---
try:
    print("Loading feature scaler...")
    scaler = joblib.load(SCALER_PATH)
    print("✅ Scaler loaded.")
except FileNotFoundError:
    print(f"❌ ERROR: Scaler not found at {SCALER_PATH}.")
    print("Please run the 03_model_training.py script first.")
    exit()

# --- Scale Test Data ---
print("Applying scaling to test data...")
X_test_scaled = scaler.transform(X_test)
print("✅ Test data scaled.")


# ==================== EVALUATION ====================
def evaluate_model(model_name, model_path):
    """Loads a model, evaluates it, and prints the performance."""
    
    print("\n" + "=" * 80)
    print(f"🔎 EVALUATING: {model_name}")
    print("=" * 80)
    
    # --- Load Model ---
    try:
        model = joblib.load(model_path)
    except FileNotFoundError:
        print(f"❌ ERROR: Model file not found at {model_path}.")
        print("Skipping evaluation for this model.")
        return

    # --- Make Predictions ---
    print("Making predictions on the test set...")
    y_pred = model.predict(X_test_scaled)
    
    # LightGBM might return float probabilities, so we round for class prediction
    if "LightGBM" in model_name and y_pred.ndim > 1:
        y_pred = np.argmax(y_pred, axis=1)
    elif "LightGBM" in model_name: # Handle case of single prediction per row
        y_pred = y_pred.round().astype(int)

    # --- Calculate Metrics ---
    accuracy = accuracy_score(y_test, y_pred)
    report = classification_report(y_test, y_pred, target_names=CLASSES.values(), zero_division=0)
    
    print(f"\n📊 Performance Metrics for {model_name}:")
    print(f"✅ Accuracy: {accuracy:.4f} ({accuracy * 100:.2f}%)")
    print("\n📋 Classification Report:")
    print(report)
    
    # --- Generate and Save Confusion Matrix ---
    print("Generating confusion matrix...")
    cm = confusion_matrix(y_test, y_pred)
    plt.figure(figsize=(10, 8))
    sns.heatmap(cm, annot=True, fmt='d', cmap='Blues', xticklabels=CLASSES.values(), yticklabels=CLASSES.values())
    plt.title(f'Confusion Matrix - {model_name}', fontsize=16)
    plt.ylabel('Actual', fontsize=12)
    plt.xlabel('Predicted', fontsize=12)
    
    cm_filename = f"11_confusion_matrix_{model_name.replace(' ', '_').lower()}.png"
    cm_path = os.path.join(VISUALIZATIONS_DIR, cm_filename)
    plt.savefig(cm_path)
    plt.close()
    
    print(f"✅ Confusion matrix saved to {cm_path}")


# Loop through all models and evaluate them
for name, filename in MODELS_TO_EVALUATE.items():
    full_path = os.path.join(MODEL_DIR, filename)
    evaluate_model(name, full_path)

# ==================== SUMMARY ====================
print("\n" + "=" * 80)
print("🎉 EVALUATION COMPLETE!")
print("=" * 80)
print("All specified models have been evaluated on the test set.")
print("Check the console output for classification reports and the 'visualizations/' directory for confusion matrices.")
