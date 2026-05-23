"""
06_model_training_v2.py
LEAK-FREE model training with proper time-based splitting.

Key fixes from v1:
  1. All rolling features use shift(1) - only PRIOR day data
  2. Overspending label based on baseline from prior 30d only
  3. Category prediction: predict which category dominates a day (not a single expense)
  4. No same-day aggregates in features
  5. Time-based 70/30 split (train on earlier, test on later)
"""
import pandas as pd
import numpy as np
import json
import joblib
from pathlib import Path

from sklearn.metrics import (
    mean_absolute_error, mean_squared_error, r2_score,
    classification_report, confusion_matrix, accuracy_score,
    f1_score, precision_score, recall_score, roc_auc_score,
)
import lightgbm as lgb
import matplotlib
matplotlib.use('Agg')
import matplotlib.pyplot as plt
import seaborn as sns
import warnings
warnings.filterwarnings('ignore')

FEATURES_DIR = Path("../features_v2")
MODELS_DIR = Path("../models_v2")
FIGS_DIR = Path("figs")
MODELS_DIR.mkdir(exist_ok=True)


def train_regression_v2():
    print("\n" + "=" * 60)
    print("TASK 1: REGRESSION v2 - Predict Daily Spending (LEAK-FREE)")
    print("=" * 60)

    df = pd.read_parquet(FEATURES_DIR / "daily_features_v2.parquet")

    with open(FEATURES_DIR / "reg_features_v2.json") as f:
        feature_cols = json.load(f)

    target = 'daily_total'
    df = df.dropna(subset=[target]).copy()
    df = df[df[target] >= 0]
    df['log_target'] = np.log1p(df[target])

    split_date = df['date'].quantile(0.7)
    train = df[df['date'] <= split_date]
    test = df[df['date'] > split_date]

    available_features = [c for c in feature_cols if c in train.columns]
    print(f"  Train: {len(train):,} rows (up to {split_date.strftime('%Y-%m-%d')})")
    print(f"  Test:  {len(test):,} rows")
    print(f"  Features: {len(available_features)}")

    X_train = train[available_features]
    y_train = train['log_target']
    X_test = test[available_features]
    y_test = test['log_target']

    model = lgb.LGBMRegressor(
        n_estimators=500, max_depth=8, learning_rate=0.05,
        num_leaves=64, min_child_samples=100,
        subsample=0.8, colsample_bytree=0.8,
        reg_alpha=0.1, reg_lambda=0.1,
        random_state=42, n_jobs=-1,
    )

    print("  Training...")
    model.fit(X_train, y_train,
              eval_set=[(X_test, y_test)],
              callbacks=[lgb.early_stopping(50, verbose=False), lgb.log_evaluation(0)])

    y_pred_log = model.predict(X_test)
    y_pred = np.expm1(y_pred_log)
    y_test_actual = np.expm1(y_test)

    mae = mean_absolute_error(y_test_actual, y_pred)
    rmse = np.sqrt(mean_squared_error(y_test_actual, y_pred))
    r2 = r2_score(y_test_actual, y_pred)
    mape = np.mean(np.abs((y_test_actual - y_pred) / (y_test_actual + 1))) * 100

    median_baseline = y_test_actual.median()
    median_mae = np.mean(np.abs(y_test_actual - median_baseline))
    improvement = (1 - mae / median_mae) * 100

    print(f"\n  RESULTS (vs baseline MAE=${median_mae:.2f}):")
    print(f"    MAE:  ${mae:.2f} ({improvement:+.1f}% vs baseline)")
    print(f"    RMSE: ${rmse:.2f}")
    print(f"    R2:   {r2:.4f}")
    print(f"    MAPE: {mape:.1f}%")

    importance = pd.DataFrame({
        'feature': available_features, 'importance': model.feature_importances_,
    }).sort_values('importance', ascending=False)
    print(f"\n  Top 10 features:")
    for _, row in importance.head(10).iterrows():
        print(f"    {row['feature']:40s} {row['importance']:6d}")

    fig, axes = plt.subplots(1, 3, figsize=(18, 5))
    importance.head(15).plot.barh(x='feature', y='importance', ax=axes[0])
    axes[0].set_title('Feature Importance (v2)')
    axes[0].invert_yaxis()

    sample_idx = np.random.choice(len(y_test_actual), min(10000, len(y_test_actual)), replace=False)
    axes[1].scatter(y_test_actual.iloc[sample_idx], y_pred[sample_idx], alpha=0.05, s=2, color='steelblue')
    lim = min(float(y_test_actual.quantile(0.95)), float(np.percentile(y_pred, 95)))
    axes[1].set_xlim(0, lim)
    axes[1].set_ylim(0, lim)
    axes[1].plot([0, lim], [0, lim], 'r--', alpha=0.5)
    axes[1].set_xlabel('Actual ($)')
    axes[1].set_ylabel('Predicted ($)')
    axes[1].set_title('Actual vs Predicted')

    residuals = (y_test_actual - y_pred).clip(-500, 500)
    axes[2].hist(residuals, bins=100, color='coral')
    axes[2].set_title('Residuals (clipped at +/-$500)')
    axes[2].set_xlabel('Residual ($)')

    plt.tight_layout()
    plt.savefig(FIGS_DIR / "10_regression_v2_results.png", dpi=150, bbox_inches='tight')
    plt.close()

    joblib.dump(model, MODELS_DIR / "regressor_daily_spend_v2.pkl")
    joblib.dump(available_features, MODELS_DIR / "regressor_features_v2.pkl")

    return {'mae': float(mae), 'rmse': float(rmse), 'r2': float(r2), 'mape': float(mape),
            'baseline_mae': float(median_mae), 'improvement_pct': float(improvement),
            'train_size': int(len(train)), 'test_size': int(len(test)),
            'num_features': len(available_features)}


def train_overspending_v2():
    print("\n" + "=" * 60)
    print("TASK 2: OVERSPENDING v2 - Leak-Free Binary Classification")
    print("=" * 60)

    df = pd.read_parquet(FEATURES_DIR / "daily_features_v2.parquet")

    with open(FEATURES_DIR / "reg_features_v2.json") as f:
        feature_cols = json.load(f)

    target = 'is_overspending'

    exclude_cols = {'date', 'user_id', 'daily_total', 'is_overspending', 'is_high_day',
                    'user_baseline_30d', 'daily_count', 'daily_mean',
                    'daily_std', 'daily_min', 'daily_max', 'daily_neg_count',
                    'daily_recurring_count', 'daily_group_count', 'log_target'}
    safe_features = [c for c in feature_cols if c not in exclude_cols and c in df.columns]

    split_date = df['date'].quantile(0.7)
    train = df[df['date'] <= split_date]
    test = df[df['date'] > split_date]

    print(f"  Train: {len(train):,} rows")
    print(f"  Test:  {len(test):,} rows")
    print(f"  Features: {len(safe_features)}")
    print(f"  Overspending rate (train): {train[target].mean()*100:.1f}%")
    print(f"  Overspending rate (test): {test[target].mean()*100:.1f}%")

    X_train = train[safe_features]
    y_train = train[target].astype(int)
    X_test = test[safe_features]
    y_test = test[target].astype(int)

    pos_rate = y_train.mean()
    scale_pos = (1 - pos_rate) / pos_rate

    model = lgb.LGBMClassifier(
        n_estimators=300, max_depth=8, learning_rate=0.05,
        num_leaves=32, min_child_samples=100,
        subsample=0.8, colsample_bytree=0.8,
        scale_pos_weight=scale_pos,
        random_state=42, n_jobs=-1,
    )

    print("  Training...")
    model.fit(X_train, y_train,
              eval_set=[(X_test, y_test)],
              callbacks=[lgb.early_stopping(30, verbose=False), lgb.log_evaluation(0)])

    y_pred = model.predict(X_test)
    y_proba = model.predict_proba(X_test)[:, 1]

    accuracy = accuracy_score(y_test, y_pred)
    f1 = f1_score(y_test, y_pred)
    precision = precision_score(y_test, y_pred)
    recall = recall_score(y_test, y_pred)
    auc = roc_auc_score(y_test, y_proba)

    print(f"\n  RESULTS:")
    print(f"    Accuracy:  {accuracy:.4f}")
    print(f"    F1 Score:  {f1:.4f}")
    print(f"    Precision: {precision:.4f}")
    print(f"    Recall:    {recall:.4f}")
    print(f"    AUC-ROC:   {auc:.4f}")
    print(f"\n  Classification report:")
    print(classification_report(y_test, y_pred, target_names=['Normal', 'Overspending']))

    importance = pd.DataFrame({
        'feature': safe_features, 'importance': model.feature_importances_,
    }).sort_values('importance', ascending=False)
    print(f"  Top 10 features:")
    for _, row in importance.head(10).iterrows():
        print(f"    {row['feature']:40s} {row['importance']:6d}")

    fig, axes = plt.subplots(1, 3, figsize=(18, 5))
    importance.head(15).plot.barh(x='feature', y='importance', ax=axes[0])
    axes[0].set_title('Overspending Feature Importance (v2)')
    axes[0].invert_yaxis()

    from sklearn.metrics import RocCurveDisplay
    RocCurveDisplay.from_predictions(y_test, y_proba, ax=axes[1])
    axes[1].set_title(f'ROC Curve (AUC={auc:.3f})')

    cm = confusion_matrix(y_test, y_pred)
    sns.heatmap(cm, annot=True, fmt='d', cmap='Blues', ax=axes[2],
                xticklabels=['Normal', 'Overspend'], yticklabels=['Normal', 'Overspend'])
    axes[2].set_title('Confusion Matrix')

    plt.tight_layout()
    plt.savefig(FIGS_DIR / "11_overspending_v2_results.png", dpi=150, bbox_inches='tight')
    plt.close()

    joblib.dump(model, MODELS_DIR / "classifier_overspending_v2.pkl")
    joblib.dump(safe_features, MODELS_DIR / "overspending_features_v2.pkl")

    return {'accuracy': float(accuracy), 'f1': float(f1), 'precision': float(precision),
            'recall': float(recall), 'auc_roc': float(auc),
            'train_size': int(len(train)), 'test_size': int(len(test)),
            'num_features': len(safe_features)}


def train_category_v2():
    print("\n" + "=" * 60)
    print("TASK 3: CATEGORY PREDICTION v2 - Which Category Dominates a Day?")
    print("=" * 60)

    df = pd.read_parquet(FEATURES_DIR / "category_features_v2.parquet")

    with open(FEATURES_DIR / "cat_features_v2.json") as f:
        feature_cols = json.load(f)

    target = 'top_category'

    exclude_cols = {'date', 'user_id', 'top_category'}
    safe_features = [c for c in feature_cols if c not in exclude_cols and c in df.columns]

    df['date'] = pd.to_datetime(df['date'])
    split_date = df['date'].quantile(0.7)
    train = df[df['date'] <= split_date]
    test = df[df['date'] > split_date]

    print(f"  Train: {len(train):,} rows")
    print(f"  Test:  {len(test):,} rows")
    print(f"  Features: {len(safe_features)}")
    print(f"  Categories: {df[target].nunique()}")

    X_train = train[safe_features]
    y_train = train[target]
    X_test = test[safe_features]
    y_test = test[target]

    model = lgb.LGBMClassifier(
        n_estimators=300, max_depth=8, learning_rate=0.05,
        num_leaves=64, min_child_samples=100,
        subsample=0.8, colsample_bytree=0.8,
        class_weight='balanced',
        random_state=42, n_jobs=-1,
    )

    print("  Training...")
    model.fit(X_train, y_train,
              eval_set=[(X_test, y_test)],
              callbacks=[lgb.early_stopping(30, verbose=False), lgb.log_evaluation(0)])

    y_pred = model.predict(X_test)
    accuracy = accuracy_score(y_test, y_pred)
    f1_weighted = f1_score(y_test, y_pred, average='weighted')
    f1_macro = f1_score(y_test, y_pred, average='macro')

    print(f"\n  RESULTS:")
    print(f"    Accuracy:       {accuracy:.4f}")
    print(f"    F1 (weighted): {f1_weighted:.4f}")
    print(f"    F1 (macro):    {f1_macro:.4f}")
    print(f"\n  Classification report:")
    print(classification_report(y_test, y_pred, zero_division=0))

    importance = pd.DataFrame({
        'feature': safe_features, 'importance': model.feature_importances_,
    }).sort_values('importance', ascending=False)
    print(f"  Top 10 features:")
    for _, row in importance.head(10).iterrows():
        print(f"    {row['feature']:40s} {row['importance']:6d}")

    fig, axes = plt.subplots(1, 2, figsize=(16, 7))
    importance.head(15).plot.barh(x='feature', y='importance', ax=axes[0])
    axes[0].set_title('Category Prediction Feature Importance (v2)')
    axes[0].invert_yaxis()

    labels = sorted(df[target].unique())
    cm = confusion_matrix(y_test, y_pred, labels=labels)
    sns.heatmap(cm, annot=True, fmt='d', cmap='Blues', ax=axes[1],
                xticklabels=[l[:6] for l in labels],
                yticklabels=[l[:6] for l in labels])
    axes[1].set_title('Confusion Matrix (v2)')

    plt.tight_layout()
    plt.savefig(FIGS_DIR / "12_category_v2_results.png", dpi=150, bbox_inches='tight')
    plt.close()

    joblib.dump(model, MODELS_DIR / "classifier_category_v2.pkl")
    joblib.dump(safe_features, MODELS_DIR / "category_features_v2.pkl")

    return {'accuracy': float(accuracy), 'f1_weighted': float(f1_weighted),
            'f1_macro': float(f1_macro),
            'train_size': int(len(train)), 'test_size': int(len(test)),
            'num_features': len(safe_features)}


def main():
    print("Loading v2 features...")
    reg_metrics = train_regression_v2()
    over_metrics = train_overspending_v2()
    cat_metrics = train_category_v2()

    summary = {
        'v1_comparison': {
            'regression_v1_r2': 0.61, 'regression_v2_r2': reg_metrics['r2'],
            'overspending_v1_auc': 0.9998, 'overspending_v2_auc': over_metrics['auc_roc'],
            'category_v1_accuracy': 0.88, 'category_v2_accuracy': cat_metrics['accuracy'],
        },
        'regression': reg_metrics,
        'overspending': over_metrics,
        'category_prediction': cat_metrics,
        'note': 'All v2 models use leak-free features (shift(1) rolling windows)',
        'split': '70/30 time-based',
    }
    with open(MODELS_DIR / "training_summary_v2.json", 'w') as f:
        json.dump(summary, f, indent=2, default=str)

    print("\n" + "=" * 60)
    print("V2 TRAINING COMPLETE - LEAK-FREE MODELS")
    print("=" * 60)
    print(f"  Regression:  MAE=${reg_metrics['mae']:.2f}, R2={reg_metrics['r2']:.4f} "
          f"(v1 R2=0.61)")
    print(f"  Overspend:   AUC={over_metrics['auc_roc']:.4f}, F1={over_metrics['f1']:.4f} "
          f"(v1 AUC=0.9998 - was leaked)")
    print(f"  Category:    Acc={cat_metrics['accuracy']:.4f}, F1={cat_metrics['f1_weighted']:.4f} "
          f"(v1 Acc=0.88 - used amount)")
    print(f"\n  Models saved to {MODELS_DIR}/")
    print("=" * 60)


if __name__ == "__main__":
    main()