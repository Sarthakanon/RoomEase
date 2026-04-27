#!/usr/bin/env python3
"""
Analyze the actual training data and results
"""

import pandas as pd
import numpy as np

print("=" * 80)
print("🔍 DETAILED DATA ANALYSIS")
print("=" * 80)

# Load the original engineered features
print("\n📊 ORIGINAL DATASET ANALYSIS:")
try:
    df = pd.read_csv('data/processed/features_engineered.csv')
    print(f"   Total rows: {len(df):,}")
    print(f"   Total columns: {df.shape[1]}")
    
    # Check pattern distribution
    if 'spending_pattern' in df.columns:
        print(f"\n🎯 SPENDING PATTERN DISTRIBUTION:")
        pattern_counts = df['spending_pattern'].value_counts()
        for pattern, count in pattern_counts.items():
            percentage = (count / len(df)) * 100
            print(f"   {pattern:<12} {count:>8,} ({percentage:>5.1f}%)")
    
    # Check encoded pattern distribution
    if 'pattern_encoded' in df.columns:
        print(f"\n🔢 ENCODED PATTERN DISTRIBUTION:")
        encoded_counts = df['pattern_encoded'].value_counts().sort_index()
        pattern_map = {0: 'daily', 1: 'weekly', 2: 'monthly', 3: 'irregular', -1: 'unknown/null'}
        
        for encoded, count in encoded_counts.items():
            pattern_name = pattern_map.get(encoded, f'unknown({encoded})')
            percentage = (count / len(df)) * 100
            print(f"   {encoded:>2} ({pattern_name:<12}) {count:>8,} ({percentage:>5.1f}%)")
    
    # Check for missing values
    print(f"\n❓ MISSING VALUES:")
    missing = df.isnull().sum()
    missing = missing[missing > 0].sort_values(ascending=False)
    if len(missing) > 0:
        for col, count in missing.head(10).items():
            percentage = (count / len(df)) * 100
            print(f"   {col:<30} {count:>8,} ({percentage:>5.1f}%)")
    else:
        print("   ✅ No missing values found")
    
    # Check data types
    print(f"\n📋 DATA TYPES:")
    dtype_counts = df.dtypes.value_counts()
    for dtype, count in dtype_counts.items():
        print(f"   {str(dtype):<15} {count:>3} columns")
        
except Exception as e:
    print(f"   ❌ Error loading original data: {e}")

# Check train/test split
print(f"\n📊 TRAIN/TEST SPLIT ANALYSIS:")
try:
    train_df = pd.read_csv('data/processed/train_data.csv')
    test_df = pd.read_csv('data/processed/test_data.csv')
    
    print(f"   Train set: {len(train_df):,} rows")
    print(f"   Test set:  {len(test_df):,} rows")
    
    total = len(train_df) + len(test_df)
    train_pct = len(train_df) / total * 100
    test_pct = len(test_df) / total * 100
    print(f"   Split ratio: {train_pct:.1f}% / {test_pct:.1f}%")
    
    # Check if patterns are balanced in train/test
    if 'pattern_encoded' in train_df.columns and 'pattern_encoded' in test_df.columns:
        print(f"\n🎯 PATTERN DISTRIBUTION IN SPLITS:")
        
        train_patterns = train_df['pattern_encoded'].value_counts().sort_index()
        test_patterns = test_df['pattern_encoded'].value_counts().sort_index()
        
        pattern_map = {0: 'daily', 1: 'weekly', 2: 'monthly', 3: 'irregular', -1: 'unknown'}
        
        print(f"   {'Pattern':<12} {'Train':<12} {'Test':<12} {'Train %':<10} {'Test %':<10}")
        print(f"   {'-'*12} {'-'*12} {'-'*12} {'-'*10} {'-'*10}")
        
        all_patterns = set(train_patterns.index) | set(test_patterns.index)
        for pattern in sorted(all_patterns):
            pattern_name = pattern_map.get(pattern, f'unk({pattern})')
            train_count = train_patterns.get(pattern, 0)
            test_count = test_patterns.get(pattern, 0)
            train_pct = (train_count / len(train_df)) * 100 if len(train_df) > 0 else 0
            test_pct = (test_count / len(test_df)) * 100 if len(test_df) > 0 else 0
            
            print(f"   {pattern_name:<12} {train_count:<12,} {test_count:<12,} {train_pct:<10.1f} {test_pct:<10.1f}")
            
except Exception as e:
    print(f"   ❌ Error analyzing splits: {e}")

# Check feature statistics
print(f"\n📈 FEATURE STATISTICS:")
try:
    df = pd.read_csv('data/processed/features_engineered.csv')
    
    # Exclude non-feature columns
    exclude_cols = [
        'id', 'created_at', 'is_anomaly', 'spending_pattern',
        'category', 'expense_type', 'time_of_day', 'paid_by', 'roomspace_id',
        'pattern_encoded'
    ]
    
    feature_cols = [col for col in df.columns if col not in exclude_cols]
    print(f"   Total features: {len(feature_cols)}")
    
    # Basic statistics for numerical features
    numerical_features = df[feature_cols].select_dtypes(include=[np.number])
    print(f"   Numerical features: {len(numerical_features.columns)}")
    
    if len(numerical_features.columns) > 0:
        print(f"\n   📊 NUMERICAL FEATURE SUMMARY:")
        stats = numerical_features.describe()
        print(f"   {'Feature':<25} {'Mean':<12} {'Std':<12} {'Min':<12} {'Max':<12}")
        print(f"   {'-'*25} {'-'*12} {'-'*12} {'-'*12} {'-'*12}")
        
        # Show first 10 features
        for col in numerical_features.columns[:10]:
            mean_val = stats.loc['mean', col]
            std_val = stats.loc['std', col]
            min_val = stats.loc['min', col]
            max_val = stats.loc['max', col]
            
            print(f"   {col:<25} {mean_val:<12.2f} {std_val:<12.2f} {min_val:<12.2f} {max_val:<12.2f}")
        
        if len(numerical_features.columns) > 10:
            print(f"   ... and {len(numerical_features.columns) - 10} more features")
    
except Exception as e:
    print(f"   ❌ Error analyzing features: {e}")

print("\n" + "=" * 80)
print("✅ DETAILED ANALYSIS COMPLETE")
print("=" * 80)