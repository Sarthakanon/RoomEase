#!/usr/bin/env python3
"""
Simple script to check model training results without additional dependencies
"""

import pandas as pd
import numpy as np
import joblib
import os
from sklearn.metrics import accuracy_score, classification_report

# Configuration
MODEL_DIR = 'trained_models'
TEST_DATA_PATH = 'data/processed/test_data.csv'
TARGET_COL = 'pattern_encoded'
CLASSES = {0: 'daily', 1: 'weekly', 2: 'monthly', 3: 'irregular'}

# Exclude columns (same as in training)
EXCLUDE_COLS = [
    'id', 'created_at', 'is_anomaly', 'spending_pattern',
    'category', 'expense_type', 'time_of_day', 'paid_by', 'roomspace_id',
    TARGET_COL
]

print("=" * 80)
print("🔍 ANALYTICS MODEL TRAINING RESULTS")
print("=" * 80)

# Check if models exist
models_info = {
    'Random Forest': 'pattern_classifier_rf.joblib',
    'SGD (Logistic Regression)': 'pattern_classifier_sgd.joblib', 
    'LightGBM': 'pattern_classifier_lgbm.joblib',
    'Scaler': 'pattern_scaler.joblib'
}

print("\n📦 MODEL FILES STATUS:")
for name, filename in models_info.items():
    path = os.path.join(MODEL_DIR, filename)
    status = "✅ EXISTS" if os.path.exists(path) else "❌ MISSING"
    if os.path.exists(path):
        size = os.path.getsize(path) / (1024*1024)  # MB
        print(f"   {name:<25} {status} ({size:.1f} MB)")
    else:
        print(f"   {name:<25} {status}")

# Check data files
print("\n📊 DATASET INFORMATION:")
try:
    # Load test data
    test_df = pd.read_csv(TEST_DATA_PATH)
    print(f"   Test Set Size: {len(test_df):,} rows")
    
    # Check train data size
    train_path = 'data/processed/train_data.csv'
    if os.path.exists(train_path):
        with open(train_path, 'r') as f:
            train_rows = sum(1 for line in f) - 1  # Subtract header
        print(f"   Train Set Size: {train_rows:,} rows")
        
        # Calculate split ratio
        total_rows = len(test_df) + train_rows
        test_ratio = len(test_df) / total_rows
        train_ratio = train_rows / total_rows
        print(f"   Train/Test Split: {train_ratio:.1%} / {test_ratio:.1%}")
    
    # Check target distribution
    if TARGET_COL in test_df.columns:
        print(f"\n🎯 TARGET DISTRIBUTION (Test Set):")
        target_counts = test_df[TARGET_COL].value_counts().sort_index()
        for class_id, count in target_counts.items():
            class_name = CLASSES.get(class_id, f'Unknown({class_id})')
            percentage = (count / len(test_df)) * 100
            print(f"   {class_name:<12} {count:>8,} ({percentage:>5.1f}%)")
    
    # Feature information
    feature_cols = [col for col in test_df.columns if col not in EXCLUDE_COLS]
    print(f"\n🔧 FEATURES:")
    print(f"   Total Features: {len(feature_cols)}")
    print(f"   Excluded Cols: {len(EXCLUDE_COLS)}")
    
except Exception as e:
    print(f"   ❌ Error loading data: {e}")

# Try to load and evaluate models
print("\n🤖 MODEL EVALUATION:")

try:
    # Load scaler
    scaler = joblib.load(os.path.join(MODEL_DIR, 'pattern_scaler.joblib'))
    print("   ✅ Scaler loaded successfully")
    
    # Prepare test data
    test_df = pd.read_csv(TEST_DATA_PATH)
    feature_cols = [col for col in test_df.columns if col not in EXCLUDE_COLS]
    X_test = test_df[feature_cols].copy().fillna(0).replace([np.inf, -np.inf], 0)
    y_test = test_df[TARGET_COL].copy()
    
    # Scale features
    X_test_scaled = scaler.transform(X_test)
    print(f"   ✅ Test data prepared: {X_test_scaled.shape}")
    
    # Evaluate each model
    model_files = {
        'Random Forest': 'pattern_classifier_rf.joblib',
        'SGD Classifier': 'pattern_classifier_sgd.joblib',
        'LightGBM': 'pattern_classifier_lgbm.joblib'
    }
    
    results = {}
    
    for model_name, filename in model_files.items():
        try:
            model_path = os.path.join(MODEL_DIR, filename)
            model = joblib.load(model_path)
            
            # Make predictions
            y_pred = model.predict(X_test_scaled)
            
            # Handle LightGBM output format
            if model_name == 'LightGBM' and hasattr(y_pred, 'ndim') and y_pred.ndim > 1:
                y_pred = np.argmax(y_pred, axis=1)
            elif model_name == 'LightGBM':
                y_pred = y_pred.round().astype(int)
            
            # Calculate accuracy
            accuracy = accuracy_score(y_test, y_pred)
            results[model_name] = accuracy
            
            print(f"\n   📈 {model_name}:")
            print(f"      Accuracy: {accuracy:.4f} ({accuracy*100:.2f}%)")
            
            # Basic classification report (without sklearn's fancy formatting)
            unique_labels = sorted(y_test.unique())
            print(f"      Per-class Performance:")
            
            for label in unique_labels:
                class_name = CLASSES.get(label, f'Class_{label}')
                
                # Calculate precision, recall, f1 manually
                true_positives = ((y_test == label) & (y_pred == label)).sum()
                false_positives = ((y_test != label) & (y_pred == label)).sum()
                false_negatives = ((y_test == label) & (y_pred != label)).sum()
                
                precision = true_positives / (true_positives + false_positives) if (true_positives + false_positives) > 0 else 0
                recall = true_positives / (true_positives + false_negatives) if (true_positives + false_negatives) > 0 else 0
                f1 = 2 * (precision * recall) / (precision + recall) if (precision + recall) > 0 else 0
                
                print(f"         {class_name:<12} P:{precision:.3f} R:{recall:.3f} F1:{f1:.3f}")
                
        except Exception as e:
            print(f"   ❌ Error evaluating {model_name}: {e}")
    
    # Show best model
    if results:
        best_model = max(results.items(), key=lambda x: x[1])
        print(f"\n🏆 BEST MODEL: {best_model[0]} (Accuracy: {best_model[1]:.4f})")
        
except Exception as e:
    print(f"   ❌ Error during evaluation: {e}")

print("\n" + "=" * 80)
print("✅ ANALYSIS COMPLETE")
print("=" * 80)