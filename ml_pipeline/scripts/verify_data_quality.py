#!/usr/bin/env python3
"""
Verify data quality of merged dataset
"""
import pandas as pd
import numpy as np
from pathlib import Path
from datetime import datetime, timedelta

def verify_data_quality():
    """Run comprehensive data quality checks"""
    print("✅ Data Quality Verification")
    print("="*80)
    
    # Load merged dataset
    data_file = Path(__file__).parent.parent / 'data' / 'processed' / 'merged_expenses.csv'
    
    if not data_file.exists():
        print(f"❌ File not found: {data_file}")
        print("Please run clean_and_merge_datasets.py first!")
        return False
    
    df = pd.read_csv(data_file)
    df['date'] = pd.to_datetime(df['date'])
    
    print(f"\n📊 Dataset Overview:")
    print(f"  Total records: {len(df):,}")
    print(f"  Columns: {list(df.columns)}")
    
    # Quality checks
    checks_passed = 0
    total_checks = 0
    
    # Check 1: Minimum records
    total_checks += 1
    print(f"\n{'='*80}")
    print(f"Check 1: Minimum Records (Target: 50,000+)")
    print('='*80)
    if len(df) >= 50000:
        print(f"✅ PASS: {len(df):,} records (exceeds 50,000)")
        checks_passed += 1
    elif len(df) >= 30000:
        print(f"⚠️  WARNING: {len(df):,} records (acceptable but below target)")
        checks_passed += 1
    else:
        print(f"❌ FAIL: {len(df):,} records (need at least 30,000)")
    
    # Check 2: Missing values
    total_checks += 1
    print(f"\n{'='*80}")
    print(f"Check 2: Missing Values (Target: <5%)")
    print('='*80)
    missing_pct = (df.isnull().sum() / len(df) * 100)
    max_missing = missing_pct.max()
    print(f"Missing values by column:")
    for col in df.columns:
        if missing_pct[col] > 0:
            print(f"  {col}: {missing_pct[col]:.2f}%")
    
    if max_missing < 5:
        print(f"✅ PASS: Maximum missing {max_missing:.2f}% (below 5%)")
        checks_passed += 1
    else:
        print(f"❌ FAIL: Maximum missing {max_missing:.2f}% (exceeds 5%)")
    
    # Check 3: Date range
    total_checks += 1
    print(f"\n{'='*80}")
    print(f"Check 3: Date Range (Target: 6+ months)")
    print('='*80)
    date_range = (df['date'].max() - df['date'].min()).days
    months = date_range / 30
    print(f"Date range: {df['date'].min().date()} to {df['date'].max().date()}")
    print(f"Duration: {date_range} days ({months:.1f} months)")
    
    if months >= 6:
        print(f"✅ PASS: {months:.1f} months (exceeds 6 months)")
        checks_passed += 1
    elif months >= 3:
        print(f"⚠️  WARNING: {months:.1f} months (acceptable but below target)")
        checks_passed += 1
    else:
        print(f"❌ FAIL: {months:.1f} months (need at least 3 months)")
    
    # Check 4: Category balance
    total_checks += 1
    print(f"\n{'='*80}")
    print(f"Check 4: Category Balance (Target: No category >40%)")
    print('='*80)
    category_dist = df['category'].value_counts(normalize=True) * 100
    print(f"Category distribution:")
    for cat, pct in category_dist.items():
        print(f"  {cat}: {pct:.2f}%")
    
    max_category_pct = category_dist.max()
    if max_category_pct < 40:
        print(f"✅ PASS: Maximum category {max_category_pct:.2f}% (below 40%)")
        checks_passed += 1
    elif max_category_pct < 50:
        print(f"⚠️  WARNING: Maximum category {max_category_pct:.2f}% (acceptable)")
        checks_passed += 1
    else:
        print(f"❌ FAIL: Maximum category {max_category_pct:.2f}% (too imbalanced)")
    
    # Check 5: Amount distribution
    total_checks += 1
    print(f"\n{'='*80}")
    print(f"Check 5: Amount Distribution")
    print('='*80)
    print(f"Amount statistics:")
    print(f"  Min: ${df['amount'].min():.2f}")
    print(f"  Max: ${df['amount'].max():.2f}")
    print(f"  Mean: ${df['amount'].mean():.2f}")
    print(f"  Median: ${df['amount'].median():.2f}")
    print(f"  Std Dev: ${df['amount'].std():.2f}")
    
    # Check for reasonable amounts
    if df['amount'].min() > 0 and df['amount'].max() < 1000000:
        print(f"✅ PASS: Amounts are in reasonable range")
        checks_passed += 1
    else:
        print(f"⚠️  WARNING: Some amounts may be outliers")
        checks_passed += 1
    
    # Check 6: Unique users
    total_checks += 1
    print(f"\n{'='*80}")
    print(f"Check 6: User Diversity (Target: 10+ users)")
    print('='*80)
    n_users = df['user_id'].nunique()
    print(f"Unique users: {n_users:,}")
    
    if n_users >= 10:
        print(f"✅ PASS: {n_users:,} users (exceeds 10)")
        checks_passed += 1
    elif n_users >= 5:
        print(f"⚠️  WARNING: {n_users:,} users (acceptable)")
        checks_passed += 1
    else:
        print(f"❌ FAIL: {n_users:,} users (need at least 5)")
    
    # Check 7: Duplicates
    total_checks += 1
    print(f"\n{'='*80}")
    print(f"Check 7: Duplicates (Target: <1%)")
    print('='*80)
    duplicates = df.duplicated(subset=['date', 'amount', 'category', 'user_id']).sum()
    dup_pct = duplicates / len(df) * 100
    print(f"Duplicate records: {duplicates:,} ({dup_pct:.2f}%)")
    
    if dup_pct < 1:
        print(f"✅ PASS: {dup_pct:.2f}% duplicates (below 1%)")
        checks_passed += 1
    else:
        print(f"⚠️  WARNING: {dup_pct:.2f}% duplicates (consider removing)")
        checks_passed += 1
    
    # Check 8: Data sources
    total_checks += 1
    print(f"\n{'='*80}")
    print(f"Check 8: Data Sources")
    print('='*80)
    if 'source' in df.columns:
        sources = df['source'].value_counts()
        print(f"Records by source:")
        for source, count in sources.items():
            print(f"  {source}: {count:,} ({count/len(df)*100:.1f}%)")
        print(f"✅ PASS: {len(sources)} data source(s)")
        checks_passed += 1
    else:
        print(f"⚠️  No source column found")
        checks_passed += 1
    
    # Final summary
    print(f"\n{'='*80}")
    print(f"📊 QUALITY SUMMARY")
    print('='*80)
    print(f"Checks passed: {checks_passed}/{total_checks}")
    
    if checks_passed == total_checks:
        print(f"✅ EXCELLENT: All quality checks passed!")
        quality_score = "EXCELLENT"
    elif checks_passed >= total_checks * 0.8:
        print(f"✅ GOOD: Most quality checks passed")
        quality_score = "GOOD"
    elif checks_passed >= total_checks * 0.6:
        print(f"⚠️  ACCEPTABLE: Some quality issues detected")
        quality_score = "ACCEPTABLE"
    else:
        print(f"❌ POOR: Significant quality issues detected")
        quality_score = "POOR"
    
    # Recommendations
    print(f"\n💡 Recommendations:")
    if len(df) < 50000:
        print(f"  • Download more datasets to reach 50,000+ records")
    if max_missing >= 5:
        print(f"  • Handle missing values in columns with >5% missing")
    if months < 6:
        print(f"  • Find datasets with longer time periods (6+ months)")
    if max_category_pct >= 40:
        print(f"  • Add more diverse datasets to balance categories")
    if n_users < 10:
        print(f"  • Include datasets with more users/accounts")
    
    if quality_score in ["EXCELLENT", "GOOD"]:
        print(f"\n✨ Next step: Run advanced_feature_engineering.py")
    else:
        print(f"\n⚠️  Consider improving data quality before proceeding")
    
    return quality_score in ["EXCELLENT", "GOOD", "ACCEPTABLE"]

if __name__ == '__main__':
    verify_data_quality()
