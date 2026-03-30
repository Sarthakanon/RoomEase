"""
Feature Engineering for RoomEase ML
Creates 60+ features for model training
"""

import pandas as pd
import numpy as np
from datetime import datetime
import warnings

warnings.filterwarnings('ignore')

print("=" * 80)
print("🔧 FEATURE ENGINEERING FOR ROOMEASE ML")
print("=" * 80)

# ==================== LOAD DATA ====================

print("\n📥 Loading datasets...")
users_df = pd.read_csv('data/raw/users.csv')
expenses_df = pd.read_csv('data/raw/expenses.csv')
personal_df = pd.read_csv('data/raw/personal_expenses.csv')
splits_df = pd.read_csv('data/raw/expense_splits.csv')

print(f"✅ Loaded {len(expenses_df) + len(personal_df):,} total expenses")

# ==================== COMBINE DATASETS ====================

print("\n🔗 Combining datasets...")

# Add expense type
expenses_df['expense_type'] = 'shared'
personal_df['expense_type'] = 'personal'

# Standardize columns for combination
expenses_combined = expenses_df.copy()
personal_combined = personal_df.copy()

# Rename user_uid to paid_by for personal expenses
personal_combined = personal_combined.rename(columns={'user_uid': 'paid_by'})
personal_combined['roomspace_id'] = None
personal_combined['split_type'] = None

# Select common columns
common_cols = ['id', 'category', 'amount', 'paid_by', 'created_at',
               'is_anomaly', 'expense_type', 'roomspace_id', 'split_type']

expenses_combined = expenses_combined[common_cols]
personal_combined = personal_combined[common_cols]

# Combine
all_expenses = pd.concat([expenses_combined, personal_combined], ignore_index=True)

# Convert timestamp
all_expenses['created_at'] = pd.to_datetime(all_expenses['created_at'], format='mixed')

print(f"✅ Combined dataset: {len(all_expenses):,} rows")

# ==================== TEMPORAL FEATURES ====================

print("\n📅 Creating temporal features...")

all_expenses['year'] = all_expenses['created_at'].dt.year
all_expenses['month'] = all_expenses['created_at'].dt.month
all_expenses['day'] = all_expenses['created_at'].dt.day
all_expenses['day_of_week'] = all_expenses['created_at'].dt.dayofweek
all_expenses['day_of_month'] = all_expenses['created_at'].dt.day
all_expenses['week_of_year'] = all_expenses['created_at'].dt.isocalendar().week
all_expenses['quarter'] = all_expenses['created_at'].dt.quarter
all_expenses['hour'] = all_expenses['created_at'].dt.hour

# Is weekend
all_expenses['is_weekend'] = (all_expenses['day_of_week'] >= 5).astype(int)

# Is month start/end
all_expenses['is_month_start'] = (all_expenses['day'] <= 5).astype(int)
all_expenses['is_month_end'] = (all_expenses['day'] >= 25).astype(int)

# Time of day categories
all_expenses['time_of_day'] = pd.cut(all_expenses['hour'],
                                     bins=[0, 6, 12, 18, 24],
                                     labels=['night', 'morning', 'afternoon', 'evening'])

print(f"✅ Created 12 temporal features")

# ==================== AMOUNT FEATURES ====================

print("\n💰 Creating amount features...")

# Basic transformations
all_expenses['amount_log'] = np.log1p(all_expenses['amount'])
all_expenses['amount_sqrt'] = np.sqrt(all_expenses['amount'])
all_expenses['amount_squared'] = all_expenses['amount'] ** 2

# Amount bins
all_expenses['amount_bin'] = pd.qcut(all_expenses['amount'],
                                     q=10,
                                     labels=False,
                                     duplicates='drop')

print(f"✅ Created 4 amount features")

# ==================== CATEGORY FEATURES ====================

print("\n📊 Creating category features...")

# Encode categories
category_map = {cat: idx for idx, cat in enumerate(all_expenses['category'].unique())}
all_expenses['category_encoded'] = all_expenses['category'].map(category_map)

# Category statistics (rolling windows)
print("   Calculating category rolling statistics...")

# Sort by user and date for proper rolling calculations
all_expenses = all_expenses.sort_values(['paid_by', 'created_at'])

# Group by user and category
for window in [7, 30, 90]:
    print(f"   - {window}-day window...")

    # Rolling mean by category
    all_expenses[f'category_amount_mean_{window}d'] = all_expenses.groupby(
        ['paid_by', 'category']
    )['amount'].transform(
        lambda x: x.rolling(window=window, min_periods=1).mean()
    )

    # Rolling std by category
    all_expenses[f'category_amount_std_{window}d'] = all_expenses.groupby(
        ['paid_by', 'category']
    )['amount'].transform(
        lambda x: x.rolling(window=window, min_periods=1).std().fillna(0)
    )

    # Rolling count by category
    all_expenses[f'category_count_{window}d'] = all_expenses.groupby(
        ['paid_by', 'category']
    ).cumcount() + 1

# Category frequency (total count per user per category)
category_freq = all_expenses.groupby(['paid_by', 'category']).size().reset_index(name='category_frequency')
all_expenses = all_expenses.merge(category_freq, on=['paid_by', 'category'], how='left')

print(f"✅ Created 10+ category features")

# ==================== USER FEATURES ====================

print("\n👤 Creating user features...")

# Merge user data
all_expenses = all_expenses.merge(
    users_df[['user_uid', 'persona', 'age', 'monthly_budget', 'roommate_count']],
    left_on='paid_by',
    right_on='user_uid',
    how='left'
)

# Encode persona
persona_map = {p: idx for idx, p in enumerate(users_df['persona'].unique())}
all_expenses['persona_encoded'] = all_expenses['persona'].map(persona_map)

# User spending statistics (rolling windows)
print("   Calculating user spending patterns...")

for window in [7, 30, 90]:
    print(f"   - {window}-day window...")

    # Total spending
    all_expenses[f'user_total_spending_{window}d'] = all_expenses.groupby('paid_by')['amount'].transform(
        lambda x: x.rolling(window=window, min_periods=1).sum()
    )

    # Average spending
    all_expenses[f'user_avg_spending_{window}d'] = all_expenses.groupby('paid_by')['amount'].transform(
        lambda x: x.rolling(window=window, min_periods=1).mean()
    )

    # Spending volatility (std)
    all_expenses[f'user_spending_volatility_{window}d'] = all_expenses.groupby('paid_by')['amount'].transform(
        lambda x: x.rolling(window=window, min_periods=1).std().fillna(0)
    )

    # Transaction count
    all_expenses[f'user_transaction_count_{window}d'] = all_expenses.groupby('paid_by').cumcount() + 1

# Budget utilization (amount / monthly_budget)
all_expenses['budget_utilization'] = (all_expenses['amount'] / all_expenses['monthly_budget']).fillna(0)

# Days since last expense
all_expenses['days_since_last_expense'] = all_expenses.groupby('paid_by')['created_at'].diff().dt.days.fillna(0)

print(f"✅ Created 15+ user features")

# ==================== SPENDING PATTERNS ====================

print("\n📈 Creating spending pattern features...")

# Expense frequency metrics
all_expenses['expense_number'] = all_expenses.groupby('paid_by').cumcount() + 1

# Average days between expenses
avg_days_between = all_expenses.groupby('paid_by')['days_since_last_expense'].transform('mean')
all_expenses['avg_days_between_expenses'] = avg_days_between

# Spending velocity (trend)
all_expenses['spending_velocity'] = all_expenses.groupby('paid_by')['amount'].transform(
    lambda x: x.rolling(window=10, min_periods=1).mean().diff().fillna(0)
)

# Deviation from user average
user_avg_amount = all_expenses.groupby('paid_by')['amount'].transform('mean')
all_expenses['deviation_from_avg'] = all_expenses['amount'] - user_avg_amount
all_expenses['deviation_ratio'] = (all_expenses['amount'] / user_avg_amount).fillna(1)

# Z-score (anomaly indicator)
user_mean = all_expenses.groupby('paid_by')['amount'].transform('mean')
user_std = all_expenses.groupby('paid_by')['amount'].transform('std').fillna(1)
all_expenses['z_score'] = (all_expenses['amount'] - user_mean) / user_std

print(f"✅ Created 7 pattern features")

# ==================== EXPENSE TYPE FEATURES ====================

print("\n🏠 Creating expense type features...")

# Is shared
all_expenses['is_shared'] = (all_expenses['expense_type'] == 'shared').astype(int)

# Has roommates
all_expenses['has_roommates'] = (all_expenses['roommate_count'] > 0).astype(int)

# Split type encoding (for shared expenses)
split_type_map = {'EQUAL': 0, 'PERCENTAGE': 1, 'EXACT': 2}
all_expenses['split_type_encoded'] = all_expenses['split_type'].map(split_type_map).fillna(-1)

print(f"✅ Created 3 expense type features")

# ==================== CREATE PATTERN LABELS ====================

print("\n🎯 Creating pattern labels for classification...")


# Determine spending pattern based on frequency
def classify_pattern(user_expenses):
    """Classify spending pattern: daily, weekly, monthly, irregular"""
    if len(user_expenses) < 2:
        return 'irregular'

    avg_days = user_expenses['days_since_last_expense'].mean()

    if avg_days <= 7:
        return 'daily'
    elif avg_days <= 30:
        return 'weekly'
    elif avg_days <= 90:
        return 'monthly'
    else:
        return 'irregular'


# Calculate pattern for each user-category combination
user_category_patterns = all_expenses.groupby(['paid_by', 'category']).apply(classify_pattern)
user_category_patterns = user_category_patterns.reset_index(name='spending_pattern')

all_expenses = all_expenses.merge(user_category_patterns, on=['paid_by', 'category'], how='left')

# Encode pattern
pattern_map = {'daily': 0, 'weekly': 1, 'monthly': 2, 'irregular': 3}
all_expenses['pattern_encoded'] = all_expenses['spending_pattern'].map(pattern_map)

print(f"✅ Pattern distribution:")
print(all_expenses['spending_pattern'].value_counts())

# ==================== CLEAN UP & SAVE ====================

print("\n🧹 Cleaning up and saving...")

# Drop intermediate columns
columns_to_drop = ['user_uid', 'persona', 'split_type']
all_expenses = all_expenses.drop(columns=[col for col in columns_to_drop if col in all_expenses.columns])

# Fill NaN values appropriately based on column type
for col in all_expenses.columns:
    if pd.api.types.is_numeric_dtype(all_expenses[col]):
        all_expenses[col] = all_expenses[col].fillna(0)
    elif pd.api.types.is_object_dtype(all_expenses[col]) or pd.api.types.is_categorical_dtype(all_expenses[col]):
        # For categorical columns, add 'Unknown' as a category if it doesn't exist
        if pd.api.types.is_categorical_dtype(all_expenses[col]) and 'Unknown' not in all_expenses[col].cat.categories:
            all_expenses[col] = all_expenses[col].cat.add_categories('Unknown')
        all_expenses[col] = all_expenses[col].fillna('Unknown')

# Save processed data
output_path = 'data/processed/features_engineered.csv'
all_expenses.to_csv(output_path, index=False)

print(f"\n✅ Saved processed data to: {output_path}")
print(f"   Shape: {all_expenses.shape}")
print(f"   Features: {all_expenses.shape[1]} columns")

# ==================== SUMMARY ====================

print("\n" + "=" * 80)
print("📊 FEATURE ENGINEERING SUMMARY")
print("=" * 80)

print(f"\n✅ Total Features Created: {all_expenses.shape[1]}")
print(f"\nFeature Categories:")
print(f"   - Temporal: 12 features")
print(f"   - Amount: 4 features")
print(f"   - Category: 10+ features")
print(f"   - User: 15+ features")
print(f"   - Patterns: 7 features")
print(f"   - Expense Type: 3 features")
print(f"   - Original: ~10 features")

print(f"\n📋 Feature List:")
feature_list = sorted(all_expenses.columns.tolist())
for i, feat in enumerate(feature_list, 1):
    print(f"   {i:2d}. {feat}")

print("\n" + "=" * 80)
print("✅ FEATURE ENGINEERING COMPLETE!")
print("=" * 80)
print("\nNext step: Run 03_model_training.py")