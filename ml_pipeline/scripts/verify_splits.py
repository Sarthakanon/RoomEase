"""Verify that data splits maintain temporal ordering and have no leakage."""

import pandas as pd
import sys
from pathlib import Path

# Add parent directory to path
sys.path.insert(0, str(Path(__file__).parent.parent))

from data_splitting import load_splits


def verify_temporal_ordering(train_df, val_df, test_df, date_column='date_time'):
    """Verify that splits maintain temporal ordering with no overlap."""
    
    print("Verifying temporal ordering...")
    
    # Convert to datetime
    train_df[date_column] = pd.to_datetime(train_df[date_column])
    val_df[date_column] = pd.to_datetime(val_df[date_column])
    test_df[date_column] = pd.to_datetime(test_df[date_column])
    
    # Get date ranges
    train_min = train_df[date_column].min()
    train_max = train_df[date_column].max()
    val_min = val_df[date_column].min()
    val_max = val_df[date_column].max()
    test_min = test_df[date_column].min()
    test_max = test_df[date_column].max()
    
    print(f"\nDate ranges:")
    print(f"  Train: {train_min} to {train_max}")
    print(f"  Val:   {val_min} to {val_max}")
    print(f"  Test:  {test_min} to {test_max}")
    
    # Check for temporal leakage
    issues = []
    
    if train_max > val_min:
        issues.append(f"❌ Train data leaks into validation (train_max={train_max} > val_min={val_min})")
    else:
        print(f"\n✓ No leakage between train and validation")
    
    if val_max > test_min:
        issues.append(f"❌ Validation data leaks into test (val_max={val_max} > test_min={test_min})")
    else:
        print(f"✓ No leakage between validation and test")
    
    if train_max > test_min:
        issues.append(f"❌ Train data leaks into test (train_max={train_max} > test_min={test_min})")
    else:
        print(f"✓ No leakage between train and test")
    
    # Check ordering within each set
    for name, df in [('Train', train_df), ('Val', val_df), ('Test', test_df)]:
        if not df[date_column].is_monotonic_increasing:
            issues.append(f"❌ {name} set is not sorted by date")
        else:
            print(f"✓ {name} set is properly sorted")
    
    return len(issues) == 0, issues


def verify_split_ratios(train_df, val_df, test_df, expected_ratios=(0.8, 0.1, 0.1)):
    """Verify that split ratios are close to expected."""
    
    print("\n\nVerifying split ratios...")
    
    total = len(train_df) + len(val_df) + len(test_df)
    train_ratio = len(train_df) / total
    val_ratio = len(val_df) / total
    test_ratio = len(test_df) / total
    
    print(f"\nActual ratios:")
    print(f"  Train: {train_ratio:.3f} (expected: {expected_ratios[0]:.3f})")
    print(f"  Val:   {val_ratio:.3f} (expected: {expected_ratios[1]:.3f})")
    print(f"  Test:  {test_ratio:.3f} (expected: {expected_ratios[2]:.3f})")
    
    # Check if within 1% tolerance
    tolerance = 0.01
    issues = []
    
    if abs(train_ratio - expected_ratios[0]) > tolerance:
        issues.append(f"❌ Train ratio {train_ratio:.3f} differs from expected {expected_ratios[0]:.3f}")
    else:
        print(f"\n✓ Train ratio is within tolerance")
    
    if abs(val_ratio - expected_ratios[1]) > tolerance:
        issues.append(f"❌ Val ratio {val_ratio:.3f} differs from expected {expected_ratios[1]:.3f}")
    else:
        print(f"✓ Val ratio is within tolerance")
    
    if abs(test_ratio - expected_ratios[2]) > tolerance:
        issues.append(f"❌ Test ratio {test_ratio:.3f} differs from expected {expected_ratios[2]:.3f}")
    else:
        print(f"✓ Test ratio is within tolerance")
    
    # Check that ratios sum to 1.0
    total_ratio = train_ratio + val_ratio + test_ratio
    if abs(total_ratio - 1.0) > 0.001:
        issues.append(f"❌ Ratios sum to {total_ratio:.3f}, not 1.0")
    else:
        print(f"✓ Ratios sum to 1.0")
    
    return len(issues) == 0, issues


def main():
    """Main verification function."""
    
    splits_dir = Path(__file__).parent.parent / 'data' / 'splits'
    
    print("=" * 70)
    print("VERIFYING DATA SPLITS")
    print("=" * 70)
    
    # Load splits
    train_df, val_df, test_df = load_splits(str(splits_dir), prefix='synthetic_expenses')
    
    print("\n" + "=" * 70)
    
    # Verify temporal ordering
    temporal_ok, temporal_issues = verify_temporal_ordering(train_df, val_df, test_df)
    
    # Verify split ratios
    ratio_ok, ratio_issues = verify_split_ratios(train_df, val_df, test_df)
    
    # Print summary
    print("\n" + "=" * 70)
    print("VERIFICATION SUMMARY")
    print("=" * 70)
    
    all_issues = temporal_issues + ratio_issues
    
    if len(all_issues) == 0:
        print("\n✅ All verifications passed!")
        print("   - Temporal ordering is correct")
        print("   - No data leakage detected")
        print("   - Split ratios are within tolerance")
        return 0
    else:
        print("\n❌ Verification failed with the following issues:")
        for issue in all_issues:
            print(f"   {issue}")
        return 1


if __name__ == '__main__':
    exit(main())
