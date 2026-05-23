"""
03_model_training.py
Trains the hybrid model:
  1. REGRESSION: Predict daily spending amount (LightGBM)
  2. CLASSIFICATION: Predict expense category (LightGBM multiclass)
  3. BINARY: Predict overspending risk (LightGBM)

All models use 70/30 train-test split with time-aware splitting
(split by date to avoid leakage).
"""
import pandas as pd
import numpy as np
import json
import joblib
from pathlib import Path
from datetime import datetime

from sklearn.model_selection import train_test_split
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

FEATURES_DIR = Path("../features")
MODELS_DIR = Path("../models")
FIGS_DIR = Path("figs")
MODELS_DIR.mkdir(exist_ok=True)


def train_regression_model(daily_features):
    print("\n" + "=" * 60)
    print("TASK 1: REGRESSION - Predict Daily Spending Amount")
    print("=" * 60)

    feature_cols = [
        'weekday', 'is_weekend', 'day_of_month', 'month', 'year',
        'is_payday', 'quarter', 'week_of_year',
        'rolling_7d_mean', 'rolling_7d_std', 'rolling_7d_sum',
        'rolling_14d_mean', 'rolling_14d_std',
        'rolling_30d_mean', 'rolling_30d_std',
        'prev_day_spend', 'spend_vs_7d_avg',
        'age', 'income', 'spending_multiplier', 'activity_rate',
        'social_tendency', 'consistency', 'splurge_probability', 'daily_lambda',
        'persona_conservative', 'persona_frugal', 'persona_lifestyle',
        'persona_moderate', 'persona_occasional_splurger', 'persona_spender',
        'loc_metro', 'loc_tier2', 'loc_tier3',
        'daily_count', 'daily_neg_count', 'daily_recurring_count', 'daily_group_count',
    ]

    target = 'daily_total'

    df = daily_features.dropna(subset=[target]).copy()
    df = df[df[target] >= 0]

    df['log_target'] = np.log1p(df[target])

    split_date = df['date'].quantile(0.7)
    train = df[df['date'] <= split_date].copy()
    test = df[df['date'] > split_date].copy()

    print(f"  Train: {len(train):,} rows (up to {split_date.strftime('%Y-%m-%d')})")
    print(f"  Test:  {len(test):,} rows (after {split_date.strftime('%Y-%m-%d')})")

    X_train = train[feature_cols]
    y_train = train['log_target']
    X_test = test[feature_cols]
    y_test = test['log_target']

    model = lgb.LGBMRegressor(
        n_estimators=500,
        max_depth=10,
        learning_rate=0.05,
        num_leaves=64,
        min_child_samples=50,
        subsample=0.8,
        colsample_bytree=0.8,
        reg_alpha=0.1,
        reg_lambda=0.1,
        random_state=42,
        n_jobs=-1,
    )

    print("  Training LightGBM regressor...")
    model.fit(
        X_train, y_train,
        eval_set=[(X_test, y_test)],
        callbacks=[lgb.early_stopping(50, verbose=False), lgb.log_evaluation(0)],
    )

    y_pred_log = model.predict(X_test)
    y_pred = np.expm1(y_pred_log)
    y_test_actual = np.expm1(y_test)

    mae = mean_absolute_error(y_test_actual, y_pred)
    rmse = np.sqrt(mean_squared_error(y_test_actual, y_pred))
    r2 = r2_score(y_test_actual, y_pred)
    mape = np.mean(np.abs((y_test_actual - y_pred) / (y_test_actual + 1))) * 100

    print(f"\n  RESULTS:")
    print(f"    MAE:  ${mae:.2f}")
    print(f"    RMSE: ${rmse:.2f}")
    print(f"    R2:   {r2:.4f}")
    print(f"    MAPE: {mape:.1f}%")

    importance = pd.DataFrame({
        'feature': feature_cols,
        'importance': model.feature_importances_,
    }).sort_values('importance', ascending=False)

    print(f"\n  Top 15 features:")
    for _, row in importance.head(15).iterrows():
        print(f"    {row['feature']:30s} {row['importance']:6d}")

    fig, axes = plt.subplots(1, 3, figsize=(18, 5))
    importance.head(20).plot.barh(x='feature', y='importance', ax=axes[0], color='steelblue')
    axes[0].set_title('Feature Importance (Top 20)')
    axes[0].invert_yaxis()

    axes[1].scatter(y_test_actual, y_pred, alpha=0.01, s=1, color='steelblue')
    lim = min(y_test_actual.quantile(0.95), y_pred[np.isfinite(y_pred)].max() * 0.8)
    axes[1].set_xlim(0, lim)
    axes[1].set_ylim(0, lim)
    axes[1].set_xlabel('Actual Daily Spend ($)')
    axes[1].set_ylabel('Predicted Daily Spend ($)')
    axes[1].set_title('Actual vs Predicted')
    axes[1].plot([0, lim], [0, lim], 'r--', alpha=0.5)

    residuals = y_test_actual - y_pred
    axes[2].hist(residuals.clip(-500, 500), bins=100, color='coral')
    axes[2].set_title('Residual Distribution')
    axes[2].set_xlabel('Residual ($)')

    plt.tight_layout()
    plt.savefig(FIGS_DIR / "07_regression_results.png", dpi=150, bbox_inches='tight')
    plt.close()

    joblib.dump(model, MODELS_DIR / "regressor_daily_spend.pkl")
    joblib.dump(feature_cols, MODELS_DIR / "regressor_features.pkl")

    metrics = {'mae': mae, 'rmse': rmse, 'r2': r2, 'mape': mape,
                'train_size': len(train), 'test_size': len(test)}
    with open(MODELS_DIR / "regressor_metrics.json", 'w') as f:
        json.dump(metrics, f, indent=2)

    return model, feature_cols, metrics


def train_classification_model(expense_df):
    print("\n" + "=" * 60)
    print("TASK 2: CLASSIFICATION - Predict Expense Category")
    print("=" * 60)

    feature_cols = [
        'amount', 'log_amount', 'hour', 'weekday', 'is_weekend',
        'day_of_month', 'month', 'year', 'is_payday', 'quarter',
        'is_negative', 'desc_length', 'is_recurring_flag', 'is_group_expense',
        'amount_vs_category_avg',
        'age', 'income', 'spending_multiplier', 'activity_rate',
        'social_tendency', 'consistency', 'splurge_probability', 'daily_lambda',
        'persona_conservative', 'persona_frugal', 'persona_lifestyle',
        'persona_moderate', 'persona_occasional_splurger', 'persona_spender',
        'loc_metro', 'loc_tier2', 'loc_tier3',
        'user_7d_avg', 'user_7d_std', 'user_30d_avg', 'user_30d_std',
        'amount_vs_user_7d_avg', 'amount_vs_user_30d_avg',
    ]

    df = expense_df.dropna(subset=feature_cols + ['category_label']).copy()

    split_date = df['date'].quantile(0.7)
    train = df[df['date'] <= split_date]
    test = df[df['date'] > split_date]

    print(f"  Train: {len(train):,} rows (up to {split_date.strftime('%Y-%m-%d')})")
    print(f"  Test:  {len(test):,} rows")

    X_train = train[feature_cols]
    y_train = train['category_label'].astype(int)
    X_test = test[feature_cols]
    y_test = test['category_label'].astype(int)

    num_classes = y_train.nunique()
    print(f"  Number of categories: {num_classes}")
    print(f"  Class distribution (train):")
    for label, count in y_train.value_counts().sort_index().items():
        cat_map_inv = {v: k for k, v in json.load(open(FEATURES_DIR / "category_map.json")).items()}
        print(f"    {cat_map_inv.get(label, label)}: {count:,}")

    model = lgb.LGBMClassifier(
        n_estimators=300,
        max_depth=10,
        learning_rate=0.05,
        num_leaves=64,
        min_child_samples=50,
        subsample=0.8,
        colsample_bytree=0.8,
        is_unbalanced=True,
        random_state=42,
        n_jobs=-1,
    )

    print("  Training LightGBM classifier...")
    model.fit(
        X_train, y_train,
        eval_set=[(X_test, y_test)],
        callbacks=[lgb.early_stopping(30, verbose=False), lgb.log_evaluation(0)],
    )

    y_pred = model.predict(X_test)
    accuracy = accuracy_score(y_test, y_pred)
    f1_macro = f1_score(y_test, y_pred, average='macro')
    f1_weighted = f1_score(y_test, y_pred, average='weighted')

    print(f"\n  RESULTS:")
    print(f"    Accuracy:      {accuracy:.4f}")
    print(f"    F1 (macro):    {f1_macro:.4f}")
    print(f"    F1 (weighted): {f1_weighted:.4f}")

    cat_map_inv = {int(v): k for k, v in json.load(open(FEATURES_DIR / "category_map.json")).items()}
    print(f"\n  Classification report:")
    print(classification_report(y_test, y_pred, target_names=[cat_map_inv[i] for i in range(num_classes)], zero_division=0))

    importance = pd.DataFrame({
        'feature': feature_cols,
        'importance': model.feature_importances_,
    }).sort_values('importance', ascending=False)

    print(f"  Top 15 features:")
    for _, row in importance.head(15).iterrows():
        print(f"    {row['feature']:35s} {row['importance']:6d}")

    fig, axes = plt.subplots(1, 2, figsize=(16, 7))
    importance.head(20).plot.barh(x='feature', y='importance', ax=axes[0], color='steelblue')
    axes[0].set_title('Feature Importance (Category Classifier)')
    axes[0].invert_yaxis()

    cm = confusion_matrix(y_test, y_pred)
    sns.heatmap(cm, annot=True, fmt='d', cmap='Blues', ax=axes[1],
                xticklabels=[cat_map_inv[i][:8] for i in range(num_classes)],
                yticklabels=[cat_map_inv[i][:8] for i in range(num_classes)])
    axes[1].set_title('Confusion Matrix')
    axes[1].set_xlabel('Predicted')
    axes[1].set_ylabel('Actual')

    plt.tight_layout()
    plt.savefig(FIGS_DIR / "08_classification_results.png", dpi=150, bbox_inches='tight')
    plt.close()

    joblib.dump(model, MODELS_DIR / "classifier_category.pkl")
    joblib.dump(feature_cols, MODELS_DIR / "classifier_features.pkl")

    metrics = {'accuracy': accuracy, 'f1_macro': f1_macro, 'f1_weighted': f1_weighted,
                'train_size': len(train), 'test_size': len(test)}
    with open(MODELS_DIR / "classifier_metrics.json", 'w') as f:
        json.dump(metrics, f, indent=2)

    return model, feature_cols, metrics


def train_overspending_model(daily_features):
    print("\n" + "=" * 60)
    print("TASK 3: BINARY CLASSIFICATION - Predict Overspending Risk")
    print("=" * 60)

    feature_cols = [
        'weekday', 'is_weekend', 'day_of_month', 'month', 'year',
        'is_payday', 'quarter', 'week_of_year',
        'rolling_7d_mean', 'rolling_7d_std', 'rolling_7d_sum',
        'rolling_14d_mean', 'rolling_14d_std',
        'rolling_30d_mean', 'rolling_30d_std',
        'prev_day_spend', 'spend_vs_7d_avg',
        'daily_count', 'daily_neg_count',
        'age', 'income', 'spending_multiplier', 'activity_rate',
        'social_tendency', 'consistency', 'splurge_probability', 'daily_lambda',
        'persona_conservative', 'persona_frugal', 'persona_lifestyle',
        'persona_moderate', 'persona_occasional_splurger', 'persona_spender',
        'loc_metro', 'loc_tier2', 'loc_tier3',
    ]

    target = 'is_overspending'

    df = daily_features.dropna(subset=feature_cols + [target]).copy()

    split_date = df['date'].quantile(0.7)
    train = df[df['date'] <= split_date]
    test = df[df['date'] > split_date]

    print(f"  Train: {len(train):,} rows (up to {split_date.strftime('%Y-%m-%d')})")
    print(f"  Test:  {len(test):,} rows")
    print(f"  Overspending rate (train): {train[target].mean()*100:.1f}%")
    print(f"  Overspending rate (test):  {test[target].mean()*100:.1f}%")

    X_train = train[feature_cols]
    y_train = train[target].astype(int)
    X_test = test[feature_cols]
    y_test = test[target].astype(int)

    scale_pos_weight = (1 - y_train.mean()) / y_train.mean()

    model = lgb.LGBMClassifier(
        n_estimators=300,
        max_depth=8,
        learning_rate=0.05,
        num_leaves=32,
        min_child_samples=100,
        subsample=0.8,
        colsample_bytree=0.8,
        scale_pos_weight=scale_pos_weight,
        random_state=42,
        n_jobs=-1,
    )

    print("  Training LightGBM classifier...")
    model.fit(
        X_train, y_train,
        eval_set=[(X_test, y_test)],
        callbacks=[lgb.early_stopping(30, verbose=False), lgb.log_evaluation(0)],
    )

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
        'feature': feature_cols,
        'importance': model.feature_importances_,
    }).sort_values('importance', ascending=False)

    print(f"  Top 15 features:")
    for _, row in importance.head(15).iterrows():
        print(f"    {row['feature']:30s} {row['importance']:6d}")

    from sklearn.metrics import PrecisionRecallDisplay, RocCurveDisplay

    fig, axes = plt.subplots(1, 3, figsize=(18, 5))

    importance.head(15).plot.barh(x='feature', y='importance', ax=axes[0], color='steelblue')
    axes[0].set_title('Feature Importance (Overspending Risk)')
    axes[0].invert_yaxis()

    RocCurveDisplay.from_predictions(y_test, y_proba, ax=axes[1], color='coral')
    axes[1].set_title(f'ROC Curve (AUC={auc:.3f})')

    cm = confusion_matrix(y_test, y_pred)
    sns.heatmap(cm, annot=True, fmt='d', cmap='Blues', ax=axes[2],
                xticklabels=['Normal', 'Overspend'], yticklabels=['Normal', 'Overspend'])
    axes[2].set_title('Confusion Matrix')

    plt.tight_layout()
    plt.savefig(FIGS_DIR / "09_overspending_results.png", dpi=150, bbox_inches='tight')
    plt.close()

    joblib.dump(model, MODELS_DIR / "classifier_overspending.pkl")
    joblib.dump(feature_cols, MODELS_DIR / "overspending_features.pkl")

    metrics = {'accuracy': accuracy, 'f1': f1, 'precision': precision,
                'recall': recall, 'auc_roc': auc,
                'train_size': len(train), 'test_size': len(test),
                'overspending_rate': float(y_test.mean())}
    with open(MODELS_DIR / "overspending_metrics.json", 'w') as f:
        json.dump(metrics, f, indent=2)

    return model, feature_cols, metrics


def main():
    print("Loading feature data...")
    daily_features = pd.read_parquet(FEATURES_DIR / "user_daily_features.parquet")
    expense_features = pd.read_parquet(FEATURES_DIR / "expense_features_sample.parquet")

    print(f"  Daily features: {daily_features.shape}")
    print(f"  Expense features: {expense_features.shape}")

    reg_model, reg_features, reg_metrics = train_regression_model(daily_features)
    clf_model, clf_features, clf_metrics = train_classification_model(expense_features)
    over_model, over_features, over_metrics = train_overspending_model(daily_features)

    summary = {
        'regression': reg_metrics,
        'classification': clf_metrics,
        'overspending': over_metrics,
        'split_ratio': '70/30 (time-based)',
        'train_period': 'up to 70th percentile date',
        'test_period': 'after 70th percentile date',
        'models': {
            'daily_spend_regressor': 'LightGBM, log1p target',
            'category_classifier': 'LightGBM multiclass, 10 categories',
            'overspending_classifier': 'LightGBM binary, scale_pos_weight balanced',
        }
    }
    with open(MODELS_DIR / "training_summary.json", 'w') as f:
        json.dump(summary, f, indent=2, default=str)

    print("\n" + "=" * 60)
    print("TRAINING COMPLETE")
    print(f"  Models saved to {MODELS_DIR}/")
    print(f"  Regression:  MAE=${reg_metrics['mae']:.2f}, R2={reg_metrics['r2']:.4f}")
    print(f"  Category:    Accuracy={clf_metrics['accuracy']:.4f}, F1={clf_metrics['f1_weighted']:.4f}")
    print(f"  Overspend:   AUC={over_metrics['auc_roc']:.4f}, F1={over_metrics['f1']:.4f}")
    print("=" * 60)


if __name__ == "__main__":
    main()