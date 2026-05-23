"""
02_feature_engineering.py
Builds the feature matrix for model training.

Two target tasks:
  REGRESSION: predict daily spending amount per user
  CLASSIFICATION: predict expense category + overspending risk

Features are computed at user-day granularity and at individual expense level,
then merged with user profile data. Outputs Parquet files for training.
"""
import pandas as pd
import numpy as np
from pathlib import Path
import warnings
warnings.filterwarnings('ignore')

OUTPUT_DIR = Path("../output")
FEATURES_DIR = Path("../features")
FEATURES_DIR.mkdir(exist_ok=True)


def build_user_daily_features(expenses, users):
    print("Building user-day features...")
    daily = expenses.groupby(['user_id', 'date']).agg(
        daily_total=('amount', 'sum'),
        daily_count=('amount', 'count'),
        daily_mean=('amount', 'mean'),
        daily_std=('amount', 'std'),
        daily_min=('amount', 'min'),
        daily_max=('amount', 'max'),
        daily_neg_count=('amount', lambda x: (x < 0).sum()),
        daily_recurring_count=('is_recurring', 'sum'),
        daily_group_count=('is_group_expense', 'sum'),
    ).reset_index()
    daily['daily_std'] = daily['daily_std'].fillna(0)
    daily['daily_neg_count'] = daily['daily_neg_count'].astype(int)
    daily['daily_recurring_count'] = daily['daily_recurring_count'].astype(int)
    daily['daily_group_count'] = daily['daily_group_count'].astype(int)
    daily['date'] = pd.to_datetime(daily['date'])
    daily['weekday'] = daily['date'].dt.dayofweek
    daily['is_weekend'] = (daily['weekday'] >= 5).astype(int)
    daily['day_of_month'] = daily['date'].dt.day
    daily['month'] = daily['date'].dt.month
    daily['year'] = daily['date'].dt.year
    daily['is_payday'] = daily['day_of_month'].isin([1, 2, 3, 15, 16]).astype(int)
    daily['quarter'] = daily['date'].dt.quarter
    daily['week_of_year'] = daily['date'].dt.isocalendar().week.astype(int)
    daily = daily.sort_values(['user_id', 'date']).reset_index(drop=True)

    print("Computing rolling windows...")
    for window in [7, 14, 30]:
        daily[f'rolling_{window}d_mean'] = daily.groupby('user_id')['daily_total'].transform(
            lambda x: x.rolling(window, min_periods=1).mean()
        )
        daily[f'rolling_{window}d_std'] = daily.groupby('user_id')['daily_total'].transform(
            lambda x: x.rolling(window, min_periods=1).std().fillna(0)
        )
        daily[f'rolling_{window}d_sum'] = daily.groupby('user_id')['daily_total'].transform(
            lambda x: x.rolling(window, min_periods=1).sum()
        )

    daily['prev_day_spend'] = daily.groupby('user_id')['daily_total'].shift(1).fillna(0)
    daily['spend_vs_7d_avg'] = daily['daily_total'] / (daily['rolling_7d_mean'] + 1)

    print("Merging user profile features...")
    user_features = users[['user_id', 'persona', 'age', 'income', 'location_tier',
                            'spending_multiplier', 'activity_rate', 'social_tendency',
                            'consistency', 'splurge_probability', 'daily_lambda']].copy()
    persona_dummies = pd.get_dummies(user_features['persona'], prefix='persona')
    location_dummies = pd.get_dummies(user_features['location_tier'], prefix='loc')
    user_features = pd.concat([user_features, persona_dummies, location_dummies], axis=1)
    user_features = user_features.drop(columns=['persona', 'location_tier'])

    daily = daily.merge(user_features, on='user_id', how='left')
    print(f"  User-day features: {daily.shape}")
    return daily


def build_expense_level_features(expenses, users):
    print("Building expense-level features...")
    df = expenses.copy()
    df['date'] = pd.to_datetime(df['date'])
    df['amount'] = df['amount'].astype(float)
    df['hour'] = pd.to_datetime(df['created_at'], errors='coerce').dt.hour
    df['weekday'] = df['date'].dt.dayofweek
    df['is_weekend'] = (df['weekday'] >= 5).astype(int)
    df['day_of_month'] = df['date'].dt.day
    df['month'] = df['date'].dt.month
    df['year'] = df['date'].dt.year
    df['is_payday'] = df['day_of_month'].isin([1, 2, 3, 15, 16]).astype(int)
    df['quarter'] = df['date'].dt.quarter
    df['is_negative'] = (df['amount'] < 0).astype(int)
    df['is_weekend_expense'] = df['is_weekend']
    df['desc_length'] = df['description'].str.len()
    df['has_empty_desc'] = (df['description'] == '').astype(int)
    df['is_recurring_flag'] = df['is_recurring'].astype(int)

    category_avg = df.groupby('category')['amount'].transform('mean')
    df['amount_vs_category_avg'] = df['amount'] / (category_avg + 1)
    df['log_amount'] = np.log1p(df['amount'].clip(lower=0))

    print("Computing user rolling stats at expense level...")
    df = df.sort_values(['user_id', 'date']).reset_index(drop=True)
    for window in [7, 30]:
        df[f'user_{window}d_avg'] = df.groupby('user_id')['amount'].transform(
            lambda x: x.rolling(window, min_periods=1).mean()
        )
        df[f'user_{window}d_std'] = df.groupby('user_id')['amount'].transform(
            lambda x: x.rolling(window, min_periods=1).std().fillna(0)
        )
    df['amount_vs_user_7d_avg'] = df['amount'] / (df['user_7d_avg'] + 1)
    df['amount_vs_user_30d_avg'] = df['amount'] / (df['user_30d_avg'] + 1)

    user_features = users[['user_id', 'persona', 'age', 'income', 'location_tier',
                            'spending_multiplier', 'activity_rate', 'social_tendency',
                            'consistency', 'splurge_probability', 'daily_lambda']].copy()
    persona_dummies = pd.get_dummies(user_features['persona'], prefix='persona')
    location_dummies = pd.get_dummies(user_features['location_tier'], prefix='loc')
    user_features = pd.concat([user_features, persona_dummies, location_dummies], axis=1)
    user_features = user_features.drop(columns=['persona', 'location_tier'])
    df = df.merge(user_features, on='user_id', how='left')
    print(f"  Expense-level features: {df.shape}")
    return df


def build_overspending_labels(daily):
    """Create overspending risk label: 1 if daily spend > 1.5x rolling 30d avg."""
    print("Creating overspending labels...")
    threshold = 1.5
    daily['is_overspending'] = (daily['daily_total'] > daily['rolling_30d_mean'] * threshold).astype(int)
    pct_3x = (daily['spend_vs_7d_avg'] > 3.0).astype(int)
    daily['is_anomaly'] = ((daily['daily_total'] > daily['rolling_30d_mean'] * 3) |
                           (daily['daily_total'] < 0)).astype(int)
    print(f"  Overspending rate: {daily['is_overspending'].mean()*100:.1f}%")
    print(f"  Anomaly rate: {daily['is_anomaly'].mean()*100:.1f}%")
    return daily


def build_category_labels(expense_df):
    """Map categories to numeric labels."""
    cats = sorted(expense_df['category'].unique())
    cat_map = {c: i for i, c in enumerate(cats)}
    expense_df['category_label'] = expense_df['category'].map(cat_map)
    print(f"  Category mapping: {cat_map}")
    return expense_df, cat_map


def main():
    print("=" * 60)
    print("FEATURE ENGINEERING")
    print("=" * 60)

    print("Loading data...")
    users = pd.read_csv(OUTPUT_DIR / "users.csv")
    expenses = pd.read_csv(OUTPUT_DIR / "expenses.csv", keep_default_na=False)
    expenses['date'] = pd.to_datetime(expenses['date'])
    expenses['amount'] = expenses['amount'].astype(float)
    expenses['is_group_expense'] = expenses['is_group_expense'].astype(bool)
    expenses['is_recurring'] = expenses['is_recurring'].astype(bool)

    daily_features = build_user_daily_features(expenses, users)
    daily_features = build_overspending_labels(daily_features)

    expense_features = build_expense_level_features(expenses, users)
    expense_features, cat_map = build_category_labels(expense_features)

    print("\nSaving features...")
    daily_features.to_parquet(FEATURES_DIR / "user_daily_features.parquet", index=False)
    print(f"  user_daily_features: {daily_features.shape}")
    print(f"  Columns: {list(daily_features.columns)}")

    sample = expense_features.sample(n=min(500000, len(expense_features)), random_state=42)
    sample.to_parquet(FEATURES_DIR / "expense_features_sample.parquet", index=False)
    print(f"  expense_features_sample: {sample.shape} (sampled for memory)")

    pd.Series(cat_map).to_json(FEATURES_DIR / "category_map.json")
    print(f"  category_map.json saved")

    print("\nFeature engineering summary:")
    print(f"  Daily features: {daily_features.shape[0]:,} rows, {daily_features.shape[1]} cols")
    print(f"  Expense features sample: {sample.shape[0]:,} rows, {sample.shape[1]} cols")
    print(f"  Overspending rate: {daily_features['is_overspending'].mean()*100:.1f}%")
    print(f"  Anomaly rate: {daily_features['is_anomaly'].mean()*100:.1f}%")
    print("\nDONE")


if __name__ == "__main__":
    main()