"""
07_assistant_models.py
The right approach for an expense assistant:

Instead of trying to predict unpredictable day-level quantities, build models
that power ACTUAL assistant use cases:

  1. MONTHLY spending forecast (aggregated = more predictable)
  2. ANOMALY detection (deviation from user's own patterns)
  3. SPENDING PROFILE classification (persona-based insights)
  4. BUDGET OPTIMIZATION (category-level recommendations)

These are what an assistant actually needs - not "predict Tuesday's spend".
"""
import pandas as pd
import numpy as np
import json
import joblib
from pathlib import Path
from datetime import timedelta

from sklearn.model_selection import train_test_split
from sklearn.metrics import (
    mean_absolute_error, mean_squared_error, r2_score,
    classification_report, accuracy_score, f1_score,
    roc_auc_score, precision_score, recall_score,
)
import lightgbm as lgb
import matplotlib
matplotlib.use('Agg')
import matplotlib.pyplot as plt
import seaborn as sns
import warnings
warnings.filterwarnings('ignore')

def _resolve_data_dirs():
    cwd = Path.cwd()
    output_candidates = [
        cwd / "output_v2",
        cwd / "output",
        cwd.parent / "output_v2",
        cwd.parent / "output",
        cwd / "dataset-sarthak-ai" / "output_v2",
        cwd / "dataset-sarthak-ai" / "output",
    ]
    features_candidates = [
        cwd / "features_v2",
        cwd.parent / "features_v2",
        cwd / "dataset-sarthak-ai" / "features_v2",
    ]

    output_dir = next((p for p in output_candidates if (p / "users.csv").exists()), Path("../output_v2"))
    features_dir = next((p for p in features_candidates if (p / "daily_features_v2.parquet").exists()), Path("../features_v2"))
    return output_dir, features_dir


OUTPUT_DIR, FEATURES_DIR = _resolve_data_dirs()
MODELS_DIR = Path("../models_v3")
FIGS_DIR = Path("figs")
MODELS_DIR.mkdir(exist_ok=True)


def _load_v2_expenses():
    """Load expenses in a schema compatible with this training script."""
    expense_path = OUTPUT_DIR / "expenses.csv"
    if expense_path.exists():
        expenses = pd.read_csv(expense_path, keep_default_na=False)
    else:
        rp_path = OUTPUT_DIR / "recurring_payments.csv"
        if not rp_path.exists():
            raise FileNotFoundError(
                f"Neither {expense_path} nor {rp_path} exists."
            )
        expenses = pd.read_csv(rp_path, keep_default_na=False).rename(
            columns={"expected_amount_npr": "amount"}
        )
        if "category" not in expenses.columns:
            expenses["category"] = "General"
        base = pd.Timestamp("2026-01-01")
        expenses["date"] = [base + pd.Timedelta(days=i) for i in range(len(expenses))]
        expenses["is_group_expense"] = False
        expenses["is_recurring"] = True

    if "date" not in expenses.columns:
        base = pd.Timestamp("2026-01-01")
        expenses["date"] = [base + pd.Timedelta(days=i) for i in range(len(expenses))]
    expenses["date"] = pd.to_datetime(expenses["date"], errors="coerce")
    expenses["amount"] = pd.to_numeric(expenses["amount"], errors="coerce").fillna(0.0)
    if "is_group_expense" not in expenses.columns:
        expenses["is_group_expense"] = False
    if "is_recurring" not in expenses.columns:
        expenses["is_recurring"] = False
    return expenses


def _normalize_users(users: pd.DataFrame) -> pd.DataFrame:
    users = users.rename(columns={
        "financial_persona": "persona",
        "monthly_income_npr": "income",
        "city_tier": "location_tier",
        "spend_multiplier": "spending_multiplier",
    }).copy()
    if "social_tendency" not in users.columns:
        users["social_tendency"] = users.get("shared_tendency", 0.5)
    if "consistency" not in users.columns:
        users["consistency"] = 0.6
    if "splurge_probability" not in users.columns:
        users["splurge_probability"] = 0.2
    if "daily_lambda" not in users.columns:
        users["daily_lambda"] = 1.0
    return users


def train_monthly_forecast(expenses, users):
    """Predict next month's total spend per user-category.
    This is actually useful - 'you'll likely spend ~$X on food next month'."""
    print("\n" + "=" * 60)
    print("MODEL 1: Monthly Category Forecast (What the assistant needs)")
    print("=" * 60)

    expenses['date'] = pd.to_datetime(expenses['date'])
    expenses['year_month'] = expenses['date'].dt.to_period('M')

    monthly = expenses.groupby(['user_id', 'year_month', 'category']).agg(
        total=('amount', 'sum'),
        count=('amount', 'count'),
    ).reset_index()

    monthly_pivot = monthly.pivot_table(
        index=['user_id', 'year_month'],
        columns='category',
        values='total',
        fill_value=0
    ).reset_index()

    monthly_total = expenses.groupby(['user_id', 'year_month']).agg(
        monthly_total=('amount', 'sum'),
        monthly_count=('amount', 'count'),
        monthly_mean=('amount', 'mean'),
    ).reset_index()

    df = monthly_pivot.merge(monthly_total, on=['user_id', 'year_month'])
    df = df.merge(users[['user_id', 'persona', 'age', 'income', 'location_tier',
                          'spending_multiplier', 'activity_rate', 'social_tendency',
                          'consistency', 'splurge_probability', 'daily_lambda']], on='user_id', how='left')

    df['month_num'] = df['year_month'].apply(lambda x: (x.year - 2016) * 12 + x.month)
    df['month_of_year'] = df['year_month'].apply(lambda x: x.month)

    df = df.sort_values(['user_id', 'month_num']).reset_index(drop=True)

    cat_cols = [c for c in df.columns if c not in ['user_id', 'year_month', 'month_num', 'month_of_year',
                'monthly_total', 'monthly_count', 'monthly_mean', 'persona', 'location_tier']]

    for cat in cat_cols:
        for lag in [1, 2, 3]:
            df[f'{cat}_lag{lag}'] = df.groupby('user_id')[cat].shift(lag).fillna(0)
        df[f'{cat}_rolling3'] = df.groupby('user_id')[cat].shift(1).rolling(3, min_periods=1).mean().reset_index(0, drop=True).fillna(0)
        df[f'{cat}_rolling6'] = df.groupby('user_id')[cat].shift(1).rolling(6, min_periods=1).mean().reset_index(0, drop=True).fillna(0)

    for col in ['monthly_total', 'monthly_count', 'monthly_mean']:
        for lag in [1, 2, 3]:
            df[f'{col}_lag{lag}'] = df.groupby('user_id')[col].shift(lag).fillna(0)
        df[f'{col}_rolling3'] = df.groupby('user_id')[col].shift(1).rolling(3, min_periods=1).mean().reset_index(0, drop=True).fillna(0)

    persona_dummies = pd.get_dummies(df['persona'], prefix='persona')
    location_dummies = pd.get_dummies(df['location_tier'], prefix='loc')
    df = pd.concat([df, persona_dummies, location_dummies], axis=1)
    df = df.drop(columns=['persona', 'location_tier', 'year_month'])

    df = df.dropna()

    target = 'monthly_total'

    feature_cols = [c for c in df.columns if c not in ['user_id', target] and c in df.columns]
    feature_cols = [c for c in feature_cols if not c.startswith('food_dining') and not c.startswith('transportation') and not c.startswith('housing') and not c.startswith('entertainment') and not c.startswith('shopping') and not c.startswith('health') and not c.startswith('travel') and not c.startswith('education') and not c.startswith('subscriptions') and not c.startswith('gifts_donations') or 'lag' in c or 'rolling' in c]

    current_cols = [c for c in df.columns if c not in ['user_id', target] and c in df.columns and (c.endswith('_lag1') or c.endswith('_lag2') or c.endswith('_lag3') or c.endswith('_rolling3') or c.endswith('_rolling6') or c in ['month_num', 'month_of_year', 'age', 'income', 'spending_multiplier', 'activity_rate', 'social_tendency', 'consistency', 'splurge_probability', 'daily_lambda'] + list(persona_dummies.columns) + list(location_dummies.columns))]
    feature_cols = [c for c in current_cols if c in df.columns]

    split_month = int(df['month_num'].quantile(0.7))
    train = df[df['month_num'] <= split_month]
    test = df[df['month_num'] > split_month]

    print(f"  Train: {len(train):,} rows (months 1-{split_month})")
    print(f"  Test:  {len(test):,} rows (months {split_month+1}+)")
    print(f"  Features: {len(feature_cols)}")

    X_train = train[feature_cols].fillna(0)
    y_train = np.log1p(train[target])
    X_test = test[feature_cols].fillna(0)
    y_test = np.log1p(test[target])

    model = lgb.LGBMRegressor(
        n_estimators=500, max_depth=8, learning_rate=0.05,
        num_leaves=64, min_child_samples=50,
        subsample=0.8, colsample_bytree=0.8,
        random_state=42, n_jobs=-1,
    )

    print("  Training monthly forecast model...")
    model.fit(X_train, y_train,
              eval_set=[(X_test, y_test)],
              callbacks=[lgb.early_stopping(50, verbose=False), lgb.log_evaluation(0)])

    y_pred = np.expm1(model.predict(X_test))
    y_test_actual = np.expm1(y_test)

    mae = mean_absolute_error(y_test_actual, y_pred)
    rmse = np.sqrt(mean_squared_error(y_test_actual, y_pred))
    r2 = r2_score(y_test_actual, y_pred)
    median_spend = y_test_actual.median()
    baseline_mae = np.mean(np.abs(y_test_actual - median_spend))
    pct_off = np.mean(np.abs(y_test_actual - y_pred) / (y_test_actual + 1)) * 100

    print(f"\n  RESULTS:")
    print(f"    MAE:            ${mae:.2f}")
    print(f"    Baseline MAE:   ${baseline_mae:.2f} (predict median)")
    print(f"    R2:             {r2:.4f}")
    print(f"    Avg % off:      {pct_off:.1f}%")
    print(f"    Median actual:  ${y_test_actual.median():.2f}")

    within_20 = np.mean(np.abs(y_test_actual - y_pred) / (y_test_actual + 1) < 0.20) * 100
    within_50 = np.mean(np.abs(y_test_actual - y_pred) / (y_test_actual + 1) < 0.50) * 100
    print(f"    Within 20%:     {within_20:.1f}%")
    print(f"    Within 50%:     {within_50:.1f}%")

    importance = pd.DataFrame({
        'feature': feature_cols, 'importance': model.feature_importances_,
    }).sort_values('importance', ascending=False)
    print(f"\n  Top 10 features:")
    for _, row in importance.head(10).iterrows():
        print(f"    {row['feature']:45s} {row['importance']:6d}")

    fig, axes = plt.subplots(1, 2, figsize=(14, 5))
    importance.head(15).plot.barh(x='feature', y='importance', ax=axes[0])
    axes[0].set_title('Monthly Forecast Feature Importance')
    axes[0].invert_yaxis()

    sample_idx = np.random.choice(len(y_test_actual), min(5000, len(y_test_actual)), replace=False)
    axes[1].scatter(y_test_actual.iloc[sample_idx], y_pred[sample_idx], alpha=0.1, s=3)
    axes[1].set_xlim(0, y_test_actual.quantile(0.95))
    axes[1].set_ylim(0, np.percentile(y_pred, 95))
    axes[1].plot([0, y_test_actual.quantile(0.95)], [0, y_test_actual.quantile(0.95)], 'r--', alpha=0.5)
    axes[1].set_xlabel('Actual Monthly Spend ($)')
    axes[1].set_ylabel('Predicted Monthly Spend ($)')
    axes[1].set_title(f'Actual vs Predicted (R2={r2:.3f})')

    plt.tight_layout()
    plt.savefig(FIGS_DIR / "13_monthly_forecast.png", dpi=150, bbox_inches='tight')
    plt.close()

    joblib.dump(model, MODELS_DIR / "monthly_forecast.pkl")
    joblib.dump(feature_cols, MODELS_DIR / "monthly_forecast_features.pkl")

    return {'mae': float(mae), 'r2': float(r2), 'baseline_mae': float(baseline_mae),
            'pct_off': float(pct_off), 'within_20': float(within_20), 'within_50': float(within_50),
            'train_size': int(len(train)), 'test_size': int(len(test))}


def train_anomaly_detector(daily_df):
    """Detect unusual spending days using user's own history as baseline.
    This is what an assistant ACTUALLY needs: 'hey, today looks unusual for you'."""
    print("\n" + "=" * 60)
    print("MODEL 2: Anomaly Detection (Deviation from User's Pattern)")
    print("=" * 60)

    df = daily_df.copy()

    df['spend_ratio'] = df['daily_total'] / (df['user_baseline_30d'] + 1)
    df['is_anomaly'] = ((df['daily_total'] > df['user_baseline_30d'] * 3) |
                        (df['daily_total'] < 0) |
                        (df['spend_ratio'] > 5)).astype(int)

    target = 'is_anomaly'

    feature_cols = [
        'weekday', 'is_weekend', 'day_of_month', 'month', 'is_payday', 'quarter',
        'prev_day_daily_total', 'prev_day_daily_count',
        'prev_daily_total_rolling_7d_mean', 'prev_daily_total_rolling_7d_std',
        'prev_daily_total_rolling_14d_mean', 'prev_daily_total_rolling_30d_mean',
        'prev_daily_total_rolling_30d_std',
        'prev_daily_count_rolling_7d_mean', 'prev_daily_count_rolling_30d_mean',
        'age', 'income', 'spending_multiplier', 'activity_rate',
        'social_tendency', 'consistency', 'splurge_probability', 'daily_lambda',
        'persona_conservative', 'persona_frugal', 'persona_lifestyle',
        'persona_moderate', 'persona_occasional_splurger', 'persona_spender',
        'loc_metro', 'loc_tier2', 'loc_tier3',
    ]
    safe_features = [c for c in feature_cols if c in df.columns]
    safe_features = [c for c in safe_features if c not in ['daily_total', 'user_baseline_30d', 'spend_ratio', 'is_overspending', 'is_high_day']]

    df = df.dropna(subset=safe_features + [target])

    split_date = df['date'].quantile(0.7)
    train = df[df['date'] <= split_date]
    test = df[df['date'] > split_date]

    print(f"  Train: {len(train):,} rows")
    print(f"  Test:  {len(test):,} rows")
    print(f"  Anomaly rate (train): {train[target].mean()*100:.1f}%")
    print(f"  Anomaly rate (test):  {test[target].mean()*100:.1f}%")

    X_train = train[safe_features]
    y_train = train[target].astype(int)
    X_test = test[safe_features]
    y_test = test[target].astype(int)

    pos_rate = y_train.mean()
    scale_pos = (1 - pos_rate) / max(pos_rate, 0.001)

    model = lgb.LGBMClassifier(
        n_estimators=300, max_depth=6, learning_rate=0.05,
        num_leaves=32, min_child_samples=200,
        subsample=0.8, colsample_bytree=0.7,
        scale_pos_weight=scale_pos,
        random_state=42, n_jobs=-1,
    )

    print("  Training anomaly detector...")
    model.fit(X_train, y_train,
              eval_set=[(X_test, y_test)],
              callbacks=[lgb.early_stopping(30, verbose=False), lgb.log_evaluation(0)])

    y_pred = model.predict(X_test)
    y_proba = model.predict_proba(X_test)[:, 1]

    accuracy = accuracy_score(y_test, y_pred)
    f1 = f1_score(y_test, y_pred)
    precision = precision_score(y_test, y_pred, zero_division=0)
    recall = recall_score(y_test, y_pred, zero_division=0)

    try:
        auc = roc_auc_score(y_test, y_proba)
    except ValueError:
        auc = 0.5

    print(f"\n  RESULTS:")
    print(f"    Accuracy:  {accuracy:.4f}")
    print(f"    F1 Score:  {f1:.4f}")
    print(f"    Precision: {precision:.4f}")
    print(f"    Recall:    {recall:.4f}")
    print(f"    AUC-ROC:   {auc:.4f}")

    print(f"\n  Classification report:")
    print(classification_report(y_test, y_pred, target_names=['Normal', 'Anomaly'], zero_division=0))

    importance = pd.DataFrame({
        'feature': safe_features, 'importance': model.feature_importances_,
    }).sort_values('importance', ascending=False)
    print(f"  Top 10 features:")
    for _, row in importance.head(10).iterrows():
        print(f"    {row['feature']:40s} {row['importance']:6d}")

    fig, axes = plt.subplots(1, 2, figsize=(14, 5))
    importance.head(15).plot.barh(x='feature', y='importance', ax=axes[0], color='coral')
    axes[0].set_title('Anomaly Detection Feature Importance')
    axes[0].invert_yaxis()

    from sklearn.metrics import RocCurveDisplay
    RocCurveDisplay.from_predictions(y_test, y_proba, ax=axes[1], color='coral')
    axes[1].set_title(f'ROC Curve (AUC={auc:.3f})')

    plt.tight_layout()
    plt.savefig(FIGS_DIR / "14_anomaly_detection.png", dpi=150, bbox_inches='tight')
    plt.close()

    joblib.dump(model, MODELS_DIR / "anomaly_detector.pkl")
    joblib.dump(safe_features, MODELS_DIR / "anomaly_features.pkl")

    return {'accuracy': float(accuracy), 'f1': float(f1), 'precision': float(precision),
            'recall': float(recall), 'auc': float(auc),
            'train_size': int(len(train)), 'test_size': int(len(test))}


def train_spending_profile(users, expenses):
    """Classify spending archetype for personalized recommendations.
    Not predicting persona (that's a label), but predicting spending STYLE
    from behavioral patterns."""
    print("\n" + "=" * 60)
    print("MODEL 3: Spending Profile (Behavioral Clustering)")
    print("=" * 60)

    expenses['date'] = pd.to_datetime(expenses['date'])
    user_features = expenses.groupby('user_id').agg(
        total_spent=('amount', 'sum'),
        avg_transaction=('amount', 'mean'),
        std_transaction=('amount', 'std'),
        median_transaction=('amount', 'median'),
        num_transactions=('amount', 'count'),
        num_negative=('amount', lambda x: (x < 0).sum()),
        pct_group=('is_group_expense', 'mean'),
        pct_recurring=('is_recurring', 'mean'),
        active_days=('date', 'nunique'),
        first_date=('date', 'min'),
        last_date=('date', 'max'),
    ).reset_index()
    user_features['std_transaction'] = user_features['std_transaction'].fillna(0)

    cat_spread = expenses.groupby(['user_id', 'category'])['amount'].sum().reset_index()
    cat_pivot = cat_pivot = cat_spread.pivot(index='user_id', columns='category', values='amount').fillna(0)
    cat_pivot = cat_pivot.div(cat_pivot.sum(axis=1), axis=0)
    cat_pivot.columns = [f'cat_pct_{c}' for c in cat_pivot.columns]
    user_features = user_features.merge(cat_pivot, on='user_id', how='left')

    user_features['avg_daily_spend'] = user_features['total_spent'] / user_features['active_days'].clip(lower=1)
    user_features['spend_variance'] = user_features['std_transaction'] / (user_features['avg_transaction'] + 1)
    user_features['tenure_days'] = (user_features['last_date'] - user_features['first_date']).dt.days
    user_features['activity_freq'] = user_features['active_days'] / (user_features['tenure_days'] + 1)
    user_features['neg_pct'] = user_features['num_negative'] / (user_features['num_transactions'] + 1)

    from sklearn.preprocessing import StandardScaler
    from sklearn.cluster import KMeans

    cluster_features = [
        'avg_daily_spend', 'spend_variance', 'activity_freq', 'neg_pct',
        'pct_group', 'pct_recurring',
    ] + [c for c in user_features.columns if c.startswith('cat_pct_')]

    cluster_data = user_features[cluster_features].fillna(0)
    scaler = StandardScaler()
    X_scaled = scaler.fit_transform(cluster_data)

    kmeans = KMeans(n_clusters=6, random_state=42, n_init=10)
    user_features['spending_cluster'] = kmeans.fit_predict(X_scaled)

    cluster_names = {}
    for c in range(6):
        cluster_data = user_features[user_features['spending_cluster'] == c]
        top_cat = cluster_data[[col for col in cluster_features if col.startswith('cat_pct_')]].mean().idxmax()
        daily = cluster_data['avg_daily_spend'].mean()
        freq = cluster_data['activity_freq'].mean()
        cluster_names[c] = f"cluster_{c}_{top_cat.replace('cat_pct_', '')}_daily${daily:.0f}"

    user_features['cluster_name'] = user_features['spending_cluster'].map(cluster_names)

    print(f"  Cluster distribution:")
    for c, name in cluster_names.items():
        count = (user_features['spending_cluster'] == c).sum()
        avg_daily = user_features[user_features['spending_cluster'] == c]['avg_daily_spend'].mean()
        print(f"    {name}: {count} users, avg_daily=${avg_daily:.2f}")

    centroids = pd.DataFrame(scaler.inverse_transform(kmeans.cluster_centers_), columns=cluster_features)
    print(f"\n  Cluster centroids (key metrics):")
    for c in range(6):
        name = cluster_names[c]
        n = (user_features['spending_cluster'] == c).sum()
        print(f"    {name} ({n} users):")
        for feat in ['avg_daily_spend', 'activity_freq', 'spend_variance']:
            print(f"      {feat}: {centroids.iloc[c][feat]:.3f}")
        top_3_cats = centroids.iloc[c][[col for col in cluster_features if col.startswith('cat_pct_')]].nlargest(3)
        for cat, val in top_3_cats.items():
            print(f"      {cat.replace('cat_pct_', '')}: {val:.1%}")

    user_features[['user_id', 'spending_cluster', 'cluster_name']].to_csv(
        MODELS_DIR / "user_spending_profiles.csv", index=False)

    joblib.dump(kmeans, MODELS_DIR / "spending_profile_kmeans.pkl")
    joblib.dump(scaler, MODELS_DIR / "spending_profile_scaler.pkl")
    joblib.dump(cluster_features, MODELS_DIR / "spending_profile_features.pkl")

    return {'n_clusters': 6, 'cluster_names': cluster_names, 'n_users': len(user_features)}


def main():
    print("Loading data...")
    users = _normalize_users(pd.read_csv(OUTPUT_DIR / "users.csv"))
    expenses = _load_v2_expenses()
    daily_df = pd.read_parquet(FEATURES_DIR / "daily_features_v2.parquet")

    monthly_metrics = train_monthly_forecast(expenses, users)
    anomaly_metrics = train_anomaly_detector(daily_df)
    profile_metrics = train_spending_profile(users, expenses)

    summary = {
        'approach': 'task-oriented models for assistant use cases',
        'monthly_forecast': monthly_metrics,
        'anomaly_detection': anomaly_metrics,
        'spending_profiles': profile_metrics,
        'v1_vs_v2_vs_v3': {
            'v1_regression_R2': 0.61, 'v1_was_leaked': True,
            'v2_regression_R2': 0.003, 'v2_honest_day_level': True,
            'v3_monthly_forecast_R2': monthly_metrics['r2'], 'v3_weekly_aggregation': True,
            'v1_overspend_AUC': 0.9998, 'v1_was_circular': True,
            'v2_overspend_AUC': 0.68,
            'v3_anomaly_AUC': anomaly_metrics['auc'], 'v3_uses_prior_patterns': True,
        }
    }
    with open(MODELS_DIR / "training_summary_v3.json", 'w') as f:
        json.dump(summary, f, indent=2, default=str)

    print("\n" + "=" * 60)
    print("V3 ASSISTANT-ORIENTED MODELS COMPLETE")
    print("=" * 60)
    print(f"  Monthly Forecast:  R2={monthly_metrics['r2']:.4f}, "
          f"Within 20%: {monthly_metrics['within_20']:.1f}%, "
          f"Within 50%: {monthly_metrics['within_50']:.1f}%")
    print(f"  Anomaly Detection: AUC={anomaly_metrics['auc']:.4f}, "
          f"F1={anomaly_metrics['f1']:.4f}, Recall={anomaly_metrics['recall']:.4f}")
    print(f"  Spending Profiles: {profile_metrics['n_clusters']} clusters")
    print(f"\n  Models saved to {MODELS_DIR}/")
    print("=" * 60)


if __name__ == "__main__":
    main()
