"""
Model Training for RoomEase ML (Chunk-Based)
Trains models on large datasets by processing data in chunks.
Focuses on the Spending Pattern Classifier.
"""

import pandas as pd
import numpy as np
from sklearn.model_selection import train_test_split
from sklearn.preprocessing import StandardScaler
from sklearn.linear_model import SGDClassifier
from sklearn.ensemble import RandomForestClassifier
import lightgbm as lgb
import joblib
import os
import warnings

warnings.filterwarnings('ignore')

# ==================== CONFIGURATION ====================
print("=" * 80)
print("⚙️ CONFIGURATION")
print("=" * 80)

# --- File Paths ---
SOURCE_DATA_PATH = 'data/processed/features_engineered.csv'
TRAIN_DATA_PATH = 'data/processed/train_data.csv'
TEST_DATA_PATH = 'data/processed/test_data.csv'
MODEL_DIR = 'trained_models'

# --- Model & Training Params ---
TEST_SET_SIZE = 0.2
TRAIN_SAMPLE_SIZE_FOR_RF = 100000  # Num samples to use for Random Forest
CHUNK_SIZE = 50000  # Num rows to process at a time
TARGET_COL = 'pattern_encoded'

# --- Feature Selection ---
# Columns to exclude from the feature set
EXCLUDE_COLS = [
    'id', 'created_at', 'is_anomaly', 'spending_pattern',
    'category', 'expense_type', 'time_of_day', 'paid_by', 'roomspace_id',
    TARGET_COL
]

# Create model directory if it doesn't exist
os.makedirs(MODEL_DIR, exist_ok=True)


# ==================== DATA PREPARATION ====================
print("\n" + "=" * 80)
print("PREPARING DATA: CREATING TRAIN/TEST SPLIT")
print("=" * 80)


def create_train_test_split():
    """
    Splits the source data into training and testing sets without loading the
    entire file into memory, which is crucial for very large datasets.
    """
    if os.path.exists(TRAIN_DATA_PATH) and os.path.exists(TEST_DATA_PATH):
        print("✅ Train/test split files already exist. Skipping creation.")
        # Estimate rows for progress display
        num_rows = sum(1 for line in open(SOURCE_DATA_PATH)) - 1
        return num_rows

    print(f"🔪 Splitting {SOURCE_DATA_PATH} into training and testing sets...")
    print(f"   Test set size: {TEST_SET_SIZE * 100}%")

    # Get header
    header = pd.read_csv(SOURCE_DATA_PATH, nrows=0).columns.tolist()

    # Use a chunked reader to process the large file
    reader = pd.read_csv(SOURCE_DATA_PATH, chunksize=CHUNK_SIZE, iterator=True)

    train_writer = open(TRAIN_DATA_PATH, 'w', newline='')
    test_writer = open(TEST_DATA_PATH, 'w', newline='')

    # Write headers
    train_writer.write(','.join(header) + '\n')
    test_writer.write(','.join(header) + '\n')

    total_rows = 0
    for chunk in reader:
        # Use sklearn's train_test_split on the chunk
        train_chunk, test_chunk = train_test_split(chunk, test_size=TEST_SET_SIZE, random_state=42)

        # Append to respective files without header
        train_chunk.to_csv(train_writer, header=False, index=False)
        test_chunk.to_csv(test_writer, header=False, index=False)

        total_rows += len(chunk)
        print(f"\r   Processed {total_rows:,} rows...", end="")

    train_writer.close()
    test_writer.close()

    print(f"\n✅ Created {TRAIN_DATA_PATH} and {TEST_DATA_PATH}")
    return total_rows


num_total_rows = create_train_test_split()
num_train_rows = int(num_total_rows * (1 - TEST_SET_SIZE))
num_test_rows = num_total_rows - num_train_rows

# ==================== FEATURE SCALING ====================
print("\n" + "=" * 80)
print("PREPARING SCALER")
print("=" * 80)


def fit_scaler():
    """
    Fits a StandardScaler on a sample of the training data. For large datasets,
    fitting a scaler on a reasonably large sample is a common and effective practice.
    """
    scaler_path = os.path.join(MODEL_DIR, 'pattern_scaler.joblib')
    if os.path.exists(scaler_path):
        print("✅ Scaler already exists. Loading it.")
        return joblib.load(scaler_path)

    print("🛠️ Fitting a StandardScaler on a sample of the training data...")
    # Use the first chunk to fit the scaler
    sample_df = pd.read_csv(TRAIN_DATA_PATH, nrows=CHUNK_SIZE)
    feature_cols = [col for col in sample_df.columns if col not in EXCLUDE_COLS]
    
    # Handle potential missing columns if sample is weird
    X_sample = sample_df[feature_cols].copy().fillna(0).replace([np.inf, -np.inf], 0)

    scaler = StandardScaler()
    scaler.fit(X_sample)

    joblib.dump(scaler, scaler_path)
    print(f"✅ Scaler fitted and saved to {scaler_path}")
    return scaler


scaler = fit_scaler()


# ==================== MODEL 1: RANDOM FOREST ====================
print("\n" + "=" * 80)
print("🌳 MODEL 1: RANDOM FOREST (TRAINED ON SAMPLE)")
print("=" * 80)

def train_random_forest():
    model_path = os.path.join(MODEL_DIR, 'pattern_classifier_rf.joblib')
    if os.path.exists(model_path):
        print("✅ Random Forest model already trained. Skipping.")
        return

    print(f"🏋️ Training RandomForestClassifier on a sample of {TRAIN_SAMPLE_SIZE_FOR_RF:,} rows...")
    
    # Read a sample from the training data
    df_sample = pd.read_csv(TRAIN_DATA_PATH, nrows=TRAIN_SAMPLE_SIZE_FOR_RF)
    feature_cols = [col for col in df_sample.columns if col not in EXCLUDE_COLS]
    
    X_rf = df_sample[feature_cols].copy().fillna(0).replace([np.inf, -np.inf], 0)
    y_rf = df_sample[TARGET_COL].copy()

    X_rf_scaled = scaler.transform(X_rf)

    rf_model = RandomForestClassifier(
        n_estimators=100,
        max_depth=20,
        random_state=42,
        n_jobs=-1,
        min_samples_leaf=5
    )
    rf_model.fit(X_rf_scaled, y_rf)
    
    joblib.dump(rf_model, model_path)
    print(f"✅ Random Forest model trained and saved to {model_path}")

train_random_forest()

# ==================== INCREMENTAL TRAINING (SGD & LGBM) ====================
print("\n" + "=" * 80)
print("🔄 MODEL 2 & 3: INCREMENTAL TRAINING (LOGISTIC REGRESSION & LIGHTGBM)")
print("=" * 80)

def incremental_training():
    """
    Trains SGDClassifier and LightGBM models by iterating through the training
    data in chunks. This is memory-efficient for large datasets.
    """
    sgd_model_path = os.path.join(MODEL_DIR, 'pattern_classifier_sgd.joblib')
    lgbm_model_path = os.path.join(MODEL_DIR, 'pattern_classifier_lgbm.joblib')

    # --- Initialize Models ---
    sgd_model = SGDClassifier(loss='log_loss', random_state=42, warm_start=True)
    lgbm_model = None  # Will be initialized in the first chunk

    # --- Check for existing checkpoints ---
    if os.path.exists(sgd_model_path):
        print("✅ SGD checkpoint found. Loading model.")
        sgd_model = joblib.load(sgd_model_path)
    if os.path.exists(lgbm_model_path):
        print("✅ LightGBM checkpoint found. Loading model.")
        lgbm_model = joblib.load(lgbm_model_path)
    
    print("🏋️ Starting chunk-based training for SGD and LightGBM...")
    
    reader = pd.read_csv(TRAIN_DATA_PATH, chunksize=CHUNK_SIZE, iterator=True)
    
    processed_rows = 0
    for i, chunk in enumerate(reader):
        feature_cols = [col for col in chunk.columns if col not in EXCLUDE_COLS]
        X_chunk = chunk[feature_cols].copy().fillna(0).replace([np.inf, -np.inf], 0)
        y_chunk = chunk[TARGET_COL].copy()
        
        # Scale features for the current chunk
        X_chunk_scaled = scaler.transform(X_chunk)
        
        # --- Train SGDClassifier ---
        sgd_model.partial_fit(X_chunk_scaled, y_chunk, classes=np.array([0, 1, 2, 3]))

        # --- Train LightGBM ---
        # For GPU, add device='gpu' to params. Ensure you have the GPU version of LightGBM.
        lgbm_params = {
            'objective': 'multiclass',
            'num_class': 4,
            'metric': 'multi_logloss',
            'boosting_type': 'gbdt',
            'n_estimators': 100,
            'learning_rate': 0.05,
            'num_leaves': 31,
            'max_depth': -1,
            'seed': 42,
            'n_jobs': -1,
            'verbose': -1,
            'device': 'gpu' # Use 'cpu' if you don't have a GPU build
        }
        
        lgbm_model = lgb.train(
            params=lgbm_params,
            train_set=lgb.Dataset(X_chunk_scaled, label=y_chunk),
            init_model=lgbm_model, # This continues training from the previous state
            keep_training_booster=True
        )

        processed_rows += len(chunk)
        progress = (processed_rows / num_train_rows) * 100
        print(f"\r   Chunk {i+1} done. Processed {processed_rows:,}/{num_train_rows:,} rows ({progress:.2f}%). Checkpoints saved.", end="")

        # --- Save Checkpoints ---
        joblib.dump(sgd_model, sgd_model_path)
        joblib.dump(lgbm_model, lgbm_model_path)

    print("\n✅ Incremental training complete.")

incremental_training()

# ==================== SUMMARY ====================
print("\n" + "=" * 80)
print("🎉 MODEL TRAINING COMPLETE!")
print("=" * 80)
print("💾 All models and the scaler have been saved in the 'trained_models/' directory.")
print(f"   - {'pattern_classifier_rf.joblib':<35} (Trained on sample)")
print(f"   - {'pattern_classifier_sgd.joblib':<35} (Trained on all data via chunks)")
print(f"   - {'pattern_classifier_lgbm.joblib':<35} (Trained on all data via chunks)")
print(f"   - {'pattern_scaler.joblib':<35} (Fitted on a sample)")

print("\nNext step: Run 04_model_evaluation.py to evaluate these models on the test set.")

