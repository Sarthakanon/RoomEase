#!/usr/bin/env python3
"""
Advanced feature engineering for improved model accuracy
"""
import pandas as pd
import numpy as np
from pathlib import Path
from datetime import datetime
import warnings
warnings.filterwarnings('ignore')

def add_temporal_features(df):
    """Add advanced temporal features"""
    print("⏰ Adding temporal features...")
    
    df['date'] = pd.to_datetime(df['date'])
    
    # Basic temporal
    df['year'] = df['date'].dt.year
    df['month'] = df['date'].dt.month
    df['day'] = df['date'].dt.day
    df['day_of_week'] = df['date'].dt.dayofweek
    df['day_of_month'] = df['date'].dt.day
    df['week_of_year'] = df['date'].dt.isocalendar().week
    df['quarter'] = df['date'].dt.quarter
    
    # Advanced temporal
    df['is_weekend'] = (df['day_of_week'] >= 5).astype(int)
    df['is_month_start'] = (df['day_of_month'] <= 5).astype(int)
    df['is_month_end'] = (df['day_of_month'] >= 25).astype(int)
    df['is_quarter_start'] = df['date'].dt.is_quarter_start.astype(int)
    df['is_quarter_end'] = df['date'].dt.is_quarter_end.astype(int)
    
    # Days since epoch (for trend analysis)
    df['days_since_epoch'] = (df['date'] - df['date'].min()).dt.days
    
    print(f"  ✅ Added {12} temporal features")
    return df

def add_amount_features(df):
    """Add amount-based features"""
    print("💰 Adding amount features...")
    
    # Log transform
    df['amount_log'] = np.log1p(df['amount'])
    
    # Normalized amount (0-1 scale)
    df['amount_normalized'] = (df['amount'] - df['amount'].min()) / (df['amount'].max() - df['amount'].min())
    
    # Amount bins
    df['amount_bin'] = pd.qcut(df['amount'], q=10, labels=False, duplicates='drop')
    
    # Square root (for variance stabilization)
    df['amount_sqrt'] = np.sqrt(df['amount'])
    
    print(f"  ✅ Added 4 amount features")
    return df

def add_category_features(df):
    """Add category-based statistical features"""
    print("📊 Adding category features...")
    
    # Category statistics
    category_stats = df.groupby('category')['amount'].agg(['mean', 'std', 'median', 'count'])
    category_stats.columns = ['category_mean', 'category_std', 'category_median', 'category_count']
    
    df = df.merge(category_stats, left_on='category', right_index=True, how='left')
    
    # Z-score within category
    df['category_z_score'] = (df['amount'] - df['category_mean']) / (df['category_std'] + 1e-6)
    
    # Deviation ratio
    df['deviation_ratio'] = df['amount'] / (df['category_mean'] + 1e-6)
    
    # Category frequency
    df['category_frequency'] = df['category'].map(df['category'].value_counts(normalize=True))
    
    print(f"  ✅ Added 7 category features")
    return df

def add_user_features(df):
    """Add user-specific features"""
    print("👤 Adding user features...")
    
    # User statistics
    user_stats = df.groupby('user_id')['amount'].agg(['mean', 'std', 'sum', 'count'])
    user_stats.columns = ['user_mean_amount', 'user_std_amount', 'user_total_spend', 'user_transaction_count']
    
    df = df.merge(user_stats, left_on='user_id', right_index=True, how='left')
    
    # User-category preference
    user_category = df.groupby(['user_id', 'category']).size().reset_index(name='user_category_count')
    df = df.merge(user_category, on=['user_id', 'category'], how='left')
    
    # User spending velocity (trend)
    df = df.sort_values(['user_id', 'date'])
    df['user_spending_velocity'] = df.groupby('user_id')['amount'].diff().fillna(0)
    
    print(f"  ✅ Added 6 user features")
    return df

def add_rolling_features(df):
    """Add rolling window features"""
    print("📈 Adding rolling features...")
    
    df = df.sort_values(['user_id', 'date'])
    
    # Rolling windows: 7, 14, 30, 90 days
    for window in [7, 14, 30, 90]:
        # Rolling mean
        df[f'rolling_mean_{window}d'] = df.groupby('user_id')['amount'].transform(
            lambda x: x.rolling(window=window, min_periods=1).mean()
        )
        
        # Rolling std
        df[f'rolling_std_{window}d'] = df.groupby('user_id')['amount'].transform(
            lambda x: x.rolling(window=window, min_periods=1).std()
        ).fillna(0)
        
        # Rolling count
        df[f'rolling_count_{window}d'] = df.groupby('user_id')['amount'].transform(
            lambda x: x.rolling(window=window, min_periods=1).count()
        )
    
    # Exponential moving average
    df['ema_7d'] = df.groupby('user_id')['amount'].transform(
        lambda x: x.ewm(span=7, adjust=False).mean()
    )
    df['ema_30d'] = df.groupby('user_id')['amount'].transform(
        lambda x: x.ewm(span=30, adjust=False).mean()
    )
    
    print(f"  ✅ Added 14 rolling features")
    return df

def add_frequency_features(df):
    """Add transaction frequency features"""
    print("🔄 Adding frequency features...")
    
    df = df.sort_values(['user_id', 'category', 'date'])
    
    # Days since last transaction (overall)
    df['days_since_last'] = df.groupby('user_id')['date'].diff().dt.days.fillna(0)
    
    # Days since last transaction in same category
    df['days_since_last_category'] = df.groupby(['user_id', 'category'])['date'].diff().dt.days.fillna(0)
    
    # Transaction count in last 7, 30 days
    df['count_7d'] = df.groupby('user_id').rolling(window='7D', on='date').size().reset_index(level=0, drop=True)
    df['count_30d'] = df.groupby('user_id').rolling(window='30D', on='date').size().reset_index(level=0, drop=True)
    
    # Category transaction count in last 30 days
    df['category_count_30d'] = df.groupby(['user_id', 'category']).rolling(window='30D', on='date').size().reset_index(level=[0,1], drop=True)
    
    # Average days between transactions
    df['avg_days_between'] = df.groupby(['user_id', 'category'])['days_since_last_category'].transform('mean')
    df['std_days_between'] = df.groupby(['user_id', 'category'])['days_since_last_category'].transform('std').fillna(0)
    
    # Coefficient of variation for frequency
    df['cv_days_between'] = df['std_days_between'] / (df['avg_days_between'] + 1e-6)
    
    print(f"  ✅ Added 8 frequency features")
    return df

def add_pattern_features(df):
    """Add pattern detection features"""
    print("🎯 Adding pattern features...")
    
    # Spending streak (consecutive days with transactions)
    df = df.sort_values(['user_id', 'date'])
    df['has_transaction'] = 1
    df['spending_streak'] = df.groupby('user_id')['has_transaction'].transform(
        lambda x: x.groupby((x != x.shift()).cumsum()).cumsum()
    )
    
    # Regularity score (inverse of coefficient of variation)
    df['regularity_score'] = 1 / (df['cv_days_between'] + 1)
    
    # Is recurring (based on frequency)
    df['is_recurring'] = ((df['avg_days_between'] > 0) & (df['avg_days_between'] < 35)).astype(int)
    
    # Amount consistency (inverse of CV)
    df['amount_consistency'] = 1 / (df.groupby(['user_id', 'category'])['amount'].transform('std') / 
                                     df.groupby(['user_id', 'category'])['amount'].transform('mean') + 1)
    
    print(f"  ✅ Added 4 pattern features")
    return df

def add_budget_features(df):
    """Add budget-related features"""
    print("💳 Adding budget features...")
    
    # Monthly total spend per user
    df['year_month'] = df['date'].dt.to_period('M')
    monthly_spend = df.groupby(['user_id', 'year_month'])['amount'].sum().reset_index()
    monthly_spend.columns = ['user_id', 'year_month', 'monthly_total_spend']
    df = df.merge(monthly_spend, on=['user_id', 'year_month'], how='left')
    
    # Budget utilization (current transaction as % of monthly spend)
    df['budget_utilization'] = df['amount'] / (df['monthly_total_spend'] + 1e-6)
    
    # Cumulative spend in month
    df = df.sort_values(['user_id', 'date'])
    df['cumulative_monthly_spend'] = df.groupby(['user_id', 'year_month'])['amount'].cumsum()
    
    # Days into month
    df['days_into_month'] = df['day_of_month']
    
    # Projected monthly spend (based on current rate)
    df['projected_monthly_spend'] = df['cumulative_monthly_spend'] * (30 / df['days_into_month'].clip(lower=1))
    
    print(f"  ✅ Added 5 budget features")
    return df

def main():
    """Main feature engineering pipeline"""
    print("⚙️  Advanced Feature Engineering Pipeline")
    print("="*80)
    
    # Load merged dataset
    data_file = Path(__file__).parent.parent / 'data' / 'processed' / 'merged_expenses.csv'
    
    if not data_file.exists():
        print(f"❌ File not found: {data_file}")
        print("Please run clean_and_merge_datasets.py first!")
        return
    
    print(f"📂 Loading data from: {data_file}")
    df = pd.read_csv(data_file)
    print(f"📊 Original shape: {df.shape}")
    print(f"📋 Original columns: {len(df.columns)}")
    
    # Apply feature engineering
    df = add_temporal_features(df)
    df = add_amount_features(df)
    df = add_category_features(df)
    df = add_user_features(df)
    df = add_rolling_features(df)
    df = add_frequency_features(df)
    df = add_pattern_features(df)
    df = add_budget_features(df)
    
    # Handle any remaining NaN values
    print("\n🔧 Handling missing values...")
    df = df.fillna(0)
    
    # Remove temporary columns
    if 'year_month' in df.columns:
        df = df.drop('year_month', axis=1)
    if 'has_transaction' in df.columns:
        df = df.drop('has_transaction', axis=1)
    
    print(f"\n📊 Final shape: {df.shape}")
    print(f"📋 Final columns: {len(df.columns)}")
    print(f"✨ Added {len(df.columns) - 6} new features!")  # 6 original columns
    
    # Save engineered dataset
    output_file = Path(__file__).parent.parent / 'data' / 'processed' / 'features_engineered.csv'
    df.to_csv(output_file, index=False)
    print(f"\n✅ Saved engineered dataset to: {output_file}")
    print(f"📦 File size: {output_file.stat().st_size / 1024 / 1024:.2f} MB")
    
    # Show feature summary
    print(f"\n📈 Feature Summary:")
    print(f"  Temporal features: 12")
    print(f"  Amount features: 4")
    print(f"  Category features: 7")
    print(f"  User features: 6")
    print(f"  Rolling features: 14")
    print(f"  Frequency features: 8")
    print(f"  Pattern features: 4")
    print(f"  Budget features: 5")
    print(f"  Total new features: 60+")
    
    print(f"\n✨ Next step: Run tune_pattern_classifier.py")

if __name__ == '__main__':
    main()
