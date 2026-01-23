#!/usr/bin/env python3
"""
Hyperparameter tuning for pattern classifier using multiple algorithms
Target: 80%+ accuracy
"""
import pandas as pd
import numpy as np
from pathlib import Path
from sklearn.model_selection import train_test_split, GridSearchCV, cross_val_score
from sklearn.ensemble import RandomForestClassifier, GradientBoostingClassifier
from sklearn.metrics import accuracy_score, classification_report, confusion_matrix
import warnings
warnings.filterwarnings('ignore')

# Try to import advanced libraries
try:
    import xgboost as xgb
    HAS_XGBOOST = True
except ImportError:
    HAS_XGBOOST = False
    print("⚠️  XGBoost not installed. Install with: pip install xgboost")

try:
    import lightgbm as lgb
    HAS_LIGHTGBM = True
except ImportError:
    HAS_LIGHTGBM = False
    print("⚠️  LightGBM not installed. Install with: pip install lightgbm")

try:
    import catboost as cb
    HAS_CATBOOST = True
except ImportError:
    HAS_CATBOOST = False
    print("⚠️  CatBoost not installed. Install with: pip install catboost")

def load_and_prepare_data():
    """Load engineered features and prepare for training"""
    print("📂 Loading engineered features...")
    
    data_file = Path(__file__).parent.parent / 'data' / 'processed' / 'features_engineered.csv'
    
    if not data_file.exists():
        print(f"❌ File not found: {data_file}")
        print("Please run advanced_feature_engineering.py first!")
        return None, None, None, None, None
    
    df = pd.read_csv(data_file)
    print(f"📊 Loaded {len(df):,} records with {len(df.columns)} features")
    
    # Create pattern labels based on frequency
    print("\n🏷️  Creating pattern labels...")
    
    def assign_pattern(row):
        """Assign pattern based on transaction frequency"""
        avg_days = row.get('avg_days_between', 0)
        cv_days = row.get('cv_days_between', 999)
        
        if avg_days == 0:
            return 'irregular'
        elif avg_days <= 2 and cv_days < 0.5:
            return 'daily'
        elif 5 <= avg_days <= 9 and cv_days < 0.5:
            return 'weekly'
        elif 25 <= avg_days <= 35 and cv_days < 0.5:
            return 'monthly'
        else:
            return 'irregular'
    
    df['pattern'] = df.apply(assign_pattern, axis=1)
    
    print(f"Pattern distribution:")
    print(df['pattern'].value_counts())
    print(f"Pattern percentages:")
    print(df['pattern'].value_counts(normalize=True) * 100)
    
    # Select features for training
    exclude_cols = ['date', 'description', 'user_id', 'source', 'pattern', 'category']
    feature_cols = [col for col in df.columns if col not in exclude_cols]
    
    # One-hot encode category
    df_encoded = pd.get_dummies(df, columns=['category'], prefix='cat')
    feature_cols = [col for col in df_encoded.columns if col not in ['date', 'description', 'user_id', 'source', 'pattern']]
    
    X = df_encoded[feature_cols]
    y = df_encoded['pattern']
    
    print(f"\n📊 Feature matrix shape: {X.shape}")
    print(f"🎯 Target distribution: {y.value_counts().to_dict()}")
    
    # Split data
    X_train, X_temp, y_train, y_temp = train_test_split(X, y, test_size=0.3, random_state=42, stratify=y)
    X_val, X_test, y_val, y_test = train_test_split(X_temp, y_temp, test_size=0.5, random_state=42, stratify=y_temp)
    
    print(f"\n📊 Data splits:")
    print(f"  Training: {len(X_train):,} samples")
    print(f"  Validation: {len(X_val):,} samples")
    print(f"  Test: {len(X_test):,} samples")
    
    return X_train, X_val, X_test, y_train, y_val, y_test, feature_cols

def tune_random_forest(X_train, y_train, X_val, y_val):
    """Tune Random Forest"""
    print(f"\n{'='*80}")
    print("🌲 Tuning Random Forest Classifier")
    print('='*80)
    
    param_grid = {
        'n_estimators': [100, 200, 300],
        'max_depth': [10, 20, 30, None],
        'min_samples_split': [2, 5, 10],
        'min_samples_leaf': [1, 2, 4],
        'class_weight': ['balanced', 'balanced_subsample']
    }
    
    rf = RandomForestClassifier(random_state=42, n_jobs=-1)
    
    print("🔍 Searching best parameters...")
    grid_search = GridSearchCV(rf, param_grid, cv=3, scoring='accuracy', n_jobs=-1, verbose=1)
    grid_search.fit(X_train, y_train)
    
    best_model = grid_search.best_estimator_
    val_acc = accuracy_score(y_val, best_model.predict(X_val))
    
    print(f"\n✅ Best parameters: {grid_search.best_params_}")
    print(f"📊 Training accuracy: {grid_search.best_score_:.4f}")
    print(f"📊 Validation accuracy: {val_acc:.4f}")
    
    return best_model, val_acc

def tune_xgboost(X_train, y_train, X_val, y_val):
    """Tune XGBoost"""
    if not HAS_XGBOOST:
        return None, 0
    
    print(f"\n{'='*80}")
    print("🚀 Tuning XGBoost Classifier")
    print('='*80)
    
    # Encode labels
    from sklearn.preprocessing import LabelEncoder
    le = LabelEncoder()
    y_train_encoded = le.fit_transform(y_train)
    y_val_encoded = le.transform(y_val)
    
    param_grid = {
        'n_estimators': [100, 200, 300],
        'max_depth': [6, 8, 10],
        'learning_rate': [0.01, 0.1, 0.3],
        'subsample': [0.8, 1.0],
        'colsample_bytree': [0.8, 1.0]
    }
    
    xgb_model = xgb.XGBClassifier(random_state=42, n_jobs=-1, eval_metric='mlogloss')
    
    print("🔍 Searching best parameters...")
    grid_search = GridSearchCV(xgb_model, param_grid, cv=3, scoring='accuracy', n_jobs=-1, verbose=1)
    grid_search.fit(X_train, y_train_encoded)
    
    best_model = grid_search.best_estimator_
    val_acc = accuracy_score(y_val_encoded, best_model.predict(X_val))
    
    print(f"\n✅ Best parameters: {grid_search.best_params_}")
    print(f"📊 Training accuracy: {grid_search.best_score_:.4f}")
    print(f"📊 Validation accuracy: {val_acc:.4f}")
    
    # Wrap model to handle string labels
    class XGBWrapper:
        def __init__(self, model, label_encoder):
            self.model = model
            self.le = label_encoder
        
        def predict(self, X):
            pred_encoded = self.model.predict(X)
            return self.le.inverse_transform(pred_encoded)
        
        def predict_proba(self, X):
            return self.model.predict_proba(X)
    
    wrapped_model = XGBWrapper(best_model, le)
    
    return wrapped_model, val_acc

def tune_lightgbm(X_train, y_train, X_val, y_val):
    """Tune LightGBM"""
    if not HAS_LIGHTGBM:
        return None, 0
    
    print(f"\n{'='*80}")
    print("⚡ Tuning LightGBM Classifier")
    print('='*80)
    
    # Encode labels
    from sklearn.preprocessing import LabelEncoder
    le = LabelEncoder()
    y_train_encoded = le.fit_transform(y_train)
    y_val_encoded = le.transform(y_val)
    
    param_grid = {
        'n_estimators': [100, 200, 300],
        'max_depth': [6, 8, 10],
        'learning_rate': [0.01, 0.1, 0.3],
        'num_leaves': [31, 50, 70],
        'subsample': [0.8, 1.0]
    }
    
    lgb_model = lgb.LGBMClassifier(random_state=42, n_jobs=-1, verbose=-1)
    
    print("🔍 Searching best parameters...")
    grid_search = GridSearchCV(lgb_model, param_grid, cv=3, scoring='accuracy', n_jobs=-1, verbose=1)
    grid_search.fit(X_train, y_train_encoded)
    
    best_model = grid_search.best_estimator_
    val_acc = accuracy_score(y_val_encoded, best_model.predict(X_val))
    
    print(f"\n✅ Best parameters: {grid_search.best_params_}")
    print(f"📊 Training accuracy: {grid_search.best_score_:.4f}")
    print(f"📊 Validation accuracy: {val_acc:.4f}")
    
    # Wrap model
    class LGBWrapper:
        def __init__(self, model, label_encoder):
            self.model = model
            self.le = label_encoder
        
        def predict(self, X):
            pred_encoded = self.model.predict(X)
            return self.le.inverse_transform(pred_encoded)
        
        def predict_proba(self, X):
            return self.model.predict_proba(X)
    
    wrapped_model = LGBWrapper(best_model, le)
    
    return wrapped_model, val_acc

def tune_catboost(X_train, y_train, X_val, y_val):
    """Tune CatBoost"""
    if not HAS_CATBOOST:
        return None, 0
    
    print(f"\n{'='*80}")
    print("🐱 Tuning CatBoost Classifier")
    print('='*80)
    
    param_grid = {
        'iterations': [100, 200, 300],
        'depth': [6, 8, 10],
        'learning_rate': [0.01, 0.1, 0.3],
        'l2_leaf_reg': [1, 3, 5]
    }
    
    cb_model = cb.CatBoostClassifier(random_state=42, verbose=0)
    
    print("🔍 Searching best parameters...")
    grid_search = GridSearchCV(cb_model, param_grid, cv=3, scoring='accuracy', n_jobs=-1, verbose=1)
    grid_search.fit(X_train, y_train)
    
    best_model = grid_search.best_estimator_
    val_acc = accuracy_score(y_val, best_model.predict(X_val))
    
    print(f"\n✅ Best parameters: {grid_search.best_params_}")
    print(f"📊 Training accuracy: {grid_search.best_score_:.4f}")
    print(f"📊 Validation accuracy: {val_acc:.4f}")
    
    return best_model, val_acc

def main():
    """Main tuning pipeline"""
    print("🎯 Pattern Classifier Hyperparameter Tuning")
    print("="*80)
    print("Target: 80%+ validation accuracy")
    print("="*80)
    
    # Load data
    result = load_and_prepare_data()
    if result[0] is None:
        return
    
    X_train, X_val, X_test, y_train, y_val, y_test, feature_cols = result
    
    # Test all algorithms
    results = {}
    
    # Random Forest
    rf_model, rf_acc = tune_random_forest(X_train, y_train, X_val, y_val)
    results['Random Forest'] = (rf_model, rf_acc)
    
    # XGBoost
    if HAS_XGBOOST:
        xgb_model, xgb_acc = tune_xgboost(X_train, y_train, X_val, y_val)
        if xgb_model:
            results['XGBoost'] = (xgb_model, xgb_acc)
    
    # LightGBM
    if HAS_LIGHTGBM:
        lgb_model, lgb_acc = tune_lightgbm(X_train, y_train, X_val, y_val)
        if lgb_model:
            results['LightGBM'] = (lgb_model, lgb_acc)
    
    # CatBoost
    if HAS_CATBOOST:
        cb_model, cb_acc = tune_catboost(X_train, y_train, X_val, y_val)
        if cb_model:
            results['CatBoost'] = (cb_model, cb_acc)
    
    # Compare results
    print(f"\n{'='*80}")
    print("📊 RESULTS COMPARISON")
    print('='*80)
    
    for name, (model, acc) in sorted(results.items(), key=lambda x: x[1][1], reverse=True):
        print(f"{name:20s}: {acc*100:.2f}% accuracy")
    
    # Select best model
    best_name, (best_model, best_acc) = max(results.items(), key=lambda x: x[1][1])
    
    print(f"\n🏆 Best Model: {best_name} with {best_acc*100:.2f}% accuracy")
    
    # Test on holdout set
    print(f"\n{'='*80}")
    print("🧪 Testing on Holdout Set")
    print('='*80)
    
    y_pred = best_model.predict(X_test)
    test_acc = accuracy_score(y_test, y_pred)
    
    print(f"\n📊 Test Accuracy: {test_acc*100:.2f}%")
    print(f"\n📋 Classification Report:")
    print(classification_report(y_test, y_pred))
    
    # Save best configuration
    config_file = Path(__file__).parent.parent / 'models' / 'best_config.txt'
    config_file.parent.mkdir(parents=True, exist_ok=True)
    
    with open(config_file, 'w') as f:
        f.write(f"Best Model: {best_name}\n")
        f.write(f"Validation Accuracy: {best_acc*100:.2f}%\n")
        f.write(f"Test Accuracy: {test_acc*100:.2f}%\n")
        f.write(f"\nModel: {best_model}\n")
    
    print(f"\n✅ Saved best configuration to: {config_file}")
    
    if test_acc >= 0.80:
        print(f"\n🎉 SUCCESS! Achieved {test_acc*100:.2f}% accuracy (target: 80%)")
    elif test_acc >= 0.70:
        print(f"\n✅ GOOD! Achieved {test_acc*100:.2f}% accuracy (close to target)")
    else:
        print(f"\n⚠️  Need improvement: {test_acc*100:.2f}% accuracy (target: 80%)")
        print(f"💡 Try: More data, better features, or ensemble methods")
    
    print(f"\n✨ Next step: Run train_advanced_models.py")

if __name__ == '__main__':
    main()
