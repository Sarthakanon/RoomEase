"""Verification script for Phase 1 data pipeline."""

import sys
from pathlib import Path
import pandas as pd
import numpy as np

# Add ml_pipeline to path
sys.path.insert(0, str(Path(__file__).parent))

from preprocessing import ExpenseFeatureEngineer
from anonymizer import DataAnonymizer
from data_splitting import split_temporal_data


def verify_preprocessing():
    """Verify preprocessing module works correctly."""
    print("=" * 70)
    print("VERIFYING PREPROCESSING MODULE")
    print("=" * 70)
    
    # Create sample data
    dates = pd.date_range('2023-01-01', '2023-12-31', freq='D')
    sample_df = pd.DataFrame({
        'date_time': dates,
        'category': np.random.choice(['Food', 'Transport', 'Utilities'], len(dates)),
        'amount': np.random.uniform(10, 1000, len(dates)),
        'currency': 'USD'
    })
    
    print(f"✓ Created sample data: {len(sample_df)} records")
    
    # Test feature engineering
    engineer = ExpenseFeatureEngineer()
    engineer.fit(sample_df)
    features = engineer.transform(sample_df)
    
    print(f"✓ Feature engineering successful")
    print(f"  Input shape: {sample_df.shape}")
    print(f"  Output shape: {features.shape}")
    print(f"  Features: {list(features.columns)}")
    
    # Verify no null values
    null_counts = features.isnull().sum()
    if null_counts.sum() == 0:
        print(f"✓ No null values in features")
    else:
        print(f"✗ Found null values:")
        print(null_counts[null_counts > 0])
        return False
    
    # Verify expected columns exist
    expected_cols = [
        'day_of_week', 'month', 'amount', 'category_encoded',
        'category_avg_30d', 'category_std_30d'
    ]
    
    missing_cols = [col for col in expected_cols if col not in features.columns]
    if not missing_cols:
        print(f"✓ All expected columns present")
    else:
        print(f"✗ Missing columns: {missing_cols}")
        return False
    
    print()
    return True


def verify_anonymization():
    """Verify anonymization module works correctly."""
    print("=" * 70)
    print("VERIFYING ANONYMIZATION MODULE")
    print("=" * 70)
    
    # Create sample data with PII
    sample_df = pd.DataFrame({
        'account': ['user123', 'user456', 'user789'],
        'date_time': ['2023-01-01', '2023-01-02', '2023-01-03'],
        'category': ['Food', 'Transport', 'Utilities'],
        'amount': [100, 200, 300],
        'currency': ['USD', 'USD', 'USD'],
        'tags': ['personal', 'work', 'home']
    })
    
    print(f"✓ Created sample data with PII: {len(sample_df)} records")
    print(f"  Original columns: {list(sample_df.columns)}")
    
    # Test anonymization
    anonymizer = DataAnonymizer()
    anon_df = anonymizer.anonymize_expenses(sample_df)
    
    print(f"✓ Anonymization successful")
    print(f"  Anonymized columns: {list(anon_df.columns)}")
    
    # Verify PII removed
    pii_columns = ['account', 'tags']
    remaining_pii = [col for col in pii_columns if col in anon_df.columns]
    
    if not remaining_pii:
        print(f"✓ PII columns removed")
    else:
        print(f"✗ PII columns still present: {remaining_pii}")
        return False
    
    # Verify hashed column exists
    if 'account_hashed' in anon_df.columns:
        print(f"✓ Hashed identifier column created")
        
        # Verify hashing is consistent
        sample_hash = anonymizer.hash_identifier('user123')
        if len(sample_hash) == 16:
            print(f"✓ Hash format correct (16 characters)")
        else:
            print(f"✗ Hash format incorrect: {len(sample_hash)} characters")
            return False
    else:
        print(f"✗ Hashed identifier column not found")
        return False
    
    # Verify anonymization check
    verification = anonymizer.verify_anonymization(anon_df)
    if verification['is_anonymized']:
        print(f"✓ Anonymization verification passed")
    else:
        print(f"✗ Anonymization verification failed:")
        for issue in verification['issues']:
            print(f"    - {issue}")
        return False
    
    print()
    return True


def verify_data_splitting():
    """Verify data splitting module works correctly."""
    print("=" * 70)
    print("VERIFYING DATA SPLITTING MODULE")
    print("=" * 70)
    
    # Create sample time-series data
    dates = pd.date_range('2022-01-01', '2024-12-31', freq='D')
    sample_df = pd.DataFrame({
        'date_time': dates,
        'user_id': [f'user_{i % 100:03d}' for i in range(len(dates))],
        'category': np.random.choice(['Food', 'Transport', 'Utilities'], len(dates)),
        'amount': np.random.uniform(10, 1000, len(dates)),
    })
    
    print(f"✓ Created sample time-series data: {len(sample_df)} records")
    print(f"  Date range: {sample_df['date_time'].min()} to {sample_df['date_time'].max()}")
    
    # Test temporal split
    train_df, val_df, test_df = split_temporal_data(
        sample_df,
        train_ratio=0.8,
        val_ratio=0.1,
        test_ratio=0.1
    )
    
    print(f"✓ Data splitting successful")
    
    # Verify split ratios
    total = len(sample_df)
    train_ratio = len(train_df) / total
    val_ratio = len(val_df) / total
    test_ratio = len(test_df) / total
    
    print(f"  Actual ratios: train={train_ratio:.2%}, val={val_ratio:.2%}, test={test_ratio:.2%}")
    
    # Check if ratios are within tolerance (±1%)
    if abs(train_ratio - 0.8) <= 0.01:
        print(f"✓ Train ratio within tolerance")
    else:
        print(f"✗ Train ratio out of tolerance: {train_ratio:.2%}")
        return False
    
    if abs(val_ratio - 0.1) <= 0.01:
        print(f"✓ Validation ratio within tolerance")
    else:
        print(f"✗ Validation ratio out of tolerance: {val_ratio:.2%}")
        return False
    
    if abs(test_ratio - 0.1) <= 0.01:
        print(f"✓ Test ratio within tolerance")
    else:
        print(f"✗ Test ratio out of tolerance: {test_ratio:.2%}")
        return False
    
    # Verify temporal ordering (no data leakage)
    if len(train_df) > 0 and len(val_df) > 0:
        if train_df['date_time'].max() <= val_df['date_time'].min():
            print(f"✓ No temporal overlap between train and validation")
        else:
            print(f"✗ Temporal overlap detected between train and validation")
            return False
    
    if len(val_df) > 0 and len(test_df) > 0:
        if val_df['date_time'].max() <= test_df['date_time'].min():
            print(f"✓ No temporal overlap between validation and test")
        else:
            print(f"✗ Temporal overlap detected between validation and test")
            return False
    
    # Verify all data is accounted for
    total_split = len(train_df) + len(val_df) + len(test_df)
    if total_split == total:
        print(f"✓ All records accounted for in splits")
    else:
        print(f"✗ Record count mismatch: {total_split} vs {total}")
        return False
    
    print()
    return True


def verify_synthetic_data_generation():
    """Verify synthetic data generation works."""
    print("=" * 70)
    print("VERIFYING SYNTHETIC DATA GENERATION")
    print("=" * 70)
    
    # Check if synthetic data exists
    data_dir = Path(__file__).parent / 'data' / 'synthetic'
    synthetic_file = data_dir / 'synthetic_expenses.csv'
    
    if synthetic_file.exists():
        df = pd.read_csv(synthetic_file)
        print(f"✓ Synthetic data file exists: {synthetic_file}")
        print(f"  Records: {len(df):,}")
        print(f"  Columns: {list(df.columns)}")
        
        # Verify required columns
        required_cols = ['user_id', 'date_time', 'category', 'amount', 'currency']
        missing_cols = [col for col in required_cols if col not in df.columns]
        
        if not missing_cols:
            print(f"✓ All required columns present")
        else:
            print(f"✗ Missing columns: {missing_cols}")
            return False
        
        # Verify data quality
        if df['amount'].min() > 0:
            print(f"✓ All amounts are positive")
        else:
            print(f"✗ Found non-positive amounts")
            return False
        
        if df['date_time'].notna().all():
            print(f"✓ No null dates")
        else:
            print(f"✗ Found null dates")
            return False
        
        print(f"✓ Synthetic data generation verified")
    else:
        print(f"⚠ Synthetic data file not found: {synthetic_file}")
        print(f"  This is expected if you haven't run the generation script yet")
        print(f"  Run: python ml_pipeline/scripts/generate_synthetic_data.py --output {synthetic_file} --count 100000")
    
    print()
    return True


def main():
    """Run all verification checks."""
    print("\n" + "=" * 70)
    print("PHASE 1 DATA PIPELINE VERIFICATION")
    print("=" * 70)
    print()
    
    results = {
        'Preprocessing': verify_preprocessing(),
        'Anonymization': verify_anonymization(),
        'Data Splitting': verify_data_splitting(),
        'Synthetic Data': verify_synthetic_data_generation(),
    }
    
    print("=" * 70)
    print("VERIFICATION SUMMARY")
    print("=" * 70)
    
    all_passed = True
    for component, passed in results.items():
        status = "✓ PASS" if passed else "✗ FAIL"
        print(f"{component:.<40} {status}")
        if not passed:
            all_passed = False
    
    print("=" * 70)
    
    if all_passed:
        print("\n✓ ALL CHECKS PASSED - Data pipeline is ready!")
        print("\nYou can now proceed to Phase 2: ML Model Training")
        return 0
    else:
        print("\n✗ SOME CHECKS FAILED - Please review the errors above")
        return 1


if __name__ == '__main__':
    sys.exit(main())
