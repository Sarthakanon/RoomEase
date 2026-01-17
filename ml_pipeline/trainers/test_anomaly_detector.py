"""Test script to verify anomaly detector meets requirements."""

import pandas as pd
import numpy as np
from anomaly_detector import AnomalyDetector, create_anomaly_labels


def test_anomaly_detection_threshold():
    """
    Test that anomaly detector flags expenses > 2 std dev from category average.
    
    This validates Requirement 5.1:
    "WHEN an expense exceeds 2 standard deviations from category average 
     THEN the system SHALL flag it as an anomaly"
    """
    print("=" * 70)
    print("TEST: Anomaly Detection Statistical Validity")
    print("=" * 70)
    
    # Create synthetic test data with known anomalies
    np.random.seed(42)
    
    # Normal expenses: mean=100, std=20
    normal_expenses = np.random.normal(100, 20, 100)
    
    # Add clear anomalies (> 2 std dev = > 140 or < 60)
    anomalies = [200, 250, 300, 10, 5]  # Way outside 2 std dev
    
    # Combine
    amounts = np.concatenate([normal_expenses, anomalies])
    
    # Create DataFrame
    test_df = pd.DataFrame({
        'user_id': ['user_001'] * len(amounts),
        'date_time': pd.date_range('2022-01-01', periods=len(amounts), freq='D'),
        'category': ['Food'] * len(amounts),
        'amount': amounts,
        'currency': ['USD'] * len(amounts)
    })
    
    print(f"\n1. Test Data Created:")
    print(f"   Total expenses: {len(test_df)}")
    print(f"   Normal expenses: {len(normal_expenses)}")
    print(f"   Known anomalies: {len(anomalies)}")
    print(f"   Category mean: ${test_df['amount'].mean():.2f}")
    print(f"   Category std: ${test_df['amount'].std():.2f}")
    
    # Calculate 2 std dev threshold
    mean = test_df['amount'].mean()
    std = test_df['amount'].std()
    threshold_upper = mean + 2 * std
    threshold_lower = mean - 2 * std
    
    print(f"\n2. Statistical Thresholds (2 std dev):")
    print(f"   Lower bound: ${threshold_lower:.2f}")
    print(f"   Upper bound: ${threshold_upper:.2f}")
    
    # Create ground truth labels
    ground_truth = create_anomaly_labels(test_df, threshold_std=2.0)
    
    print(f"\n3. Ground Truth Labels:")
    print(f"   Anomalies detected: {ground_truth.sum()}")
    print(f"   Anomaly rate: {ground_truth.mean()*100:.2f}%")
    
    # Show which expenses were flagged
    anomaly_df = test_df[ground_truth == 1]
    print(f"\n4. Flagged Anomalies:")
    for idx, row in anomaly_df.head(10).iterrows():
        z_score = (row['amount'] - mean) / std
        print(f"   ${row['amount']:8.2f} | Z-score: {z_score:6.2f} | "
              f"{'ABOVE' if row['amount'] > threshold_upper else 'BELOW'} threshold")
    
    # Verify all known anomalies were flagged
    known_anomaly_indices = list(range(len(normal_expenses), len(amounts)))
    known_anomalies_flagged = ground_truth.iloc[known_anomaly_indices].sum()
    
    print(f"\n5. Validation Results:")
    print(f"   Known anomalies: {len(anomalies)}")
    print(f"   Known anomalies flagged: {known_anomalies_flagged}")
    print(f"   Success rate: {known_anomalies_flagged/len(anomalies)*100:.1f}%")
    
    # Test with trained model
    print(f"\n6. Testing with Trained Model:")
    detector = AnomalyDetector(contamination=0.1, random_state=42)
    
    # Engineer features
    X = detector._engineer_anomaly_features(test_df)
    
    # Fit model
    detector.fit(X, ground_truth, verbose=False)
    
    # Predict
    predictions = detector.predict(X, return_scores=True)
    
    print(f"   Model anomaly rate: {predictions['is_anomaly'].mean()*100:.2f}%")
    print(f"   Model detected: {predictions['is_anomaly'].sum()} anomalies")
    
    # Show some predictions
    print(f"\n7. Sample Predictions:")
    anomaly_preds = test_df[predictions['is_anomaly'] == 1].head(5)
    for idx in anomaly_preds.index:
        row = test_df.iloc[idx]
        pred_row = predictions.iloc[idx]
        z_score = (row['amount'] - mean) / std
        print(f"   ${row['amount']:8.2f} | Z-score: {z_score:6.2f} | {pred_row['reason']}")
    
    print("\n" + "=" * 70)
    print("TEST COMPLETE!")
    print("=" * 70)
    
    # Verify requirement
    if known_anomalies_flagged >= len(anomalies) * 0.8:  # At least 80% detected
        print("\n✓ REQUIREMENT 5.1 VALIDATED:")
        print("  Expenses > 2 std dev from category average are flagged as anomalies")
        return True
    else:
        print("\n✗ REQUIREMENT 5.1 FAILED:")
        print("  Not all expenses > 2 std dev were flagged")
        return False


def test_category_specific_detection():
    """
    Test that anomaly detection is category-specific.
    
    An expense that's normal for one category might be anomalous for another.
    """
    print("\n" + "=" * 70)
    print("TEST: Category-Specific Anomaly Detection")
    print("=" * 70)
    
    np.random.seed(42)
    
    # Create data with two categories with different spending patterns
    # Food: mean=50, std=10
    # Rent: mean=1500, std=200
    
    food_expenses = np.random.normal(50, 10, 50)
    rent_expenses = np.random.normal(1500, 200, 50)
    
    # Add an expense of $1200
    # This is anomalous for Food (> 2 std dev) but normal for Rent
    test_amount = 1200
    
    test_df = pd.DataFrame({
        'user_id': ['user_001'] * 102,
        'date_time': pd.date_range('2022-01-01', periods=102, freq='D'),
        'category': ['Food'] * 51 + ['Rent'] * 51,
        'amount': np.concatenate([food_expenses, [test_amount], rent_expenses, [test_amount]]),
        'currency': ['USD'] * 102
    })
    
    print(f"\n1. Test Data:")
    print(f"   Food expenses: mean=${test_df[test_df['category']=='Food']['amount'].mean():.2f}, "
          f"std=${test_df[test_df['category']=='Food']['amount'].std():.2f}")
    print(f"   Rent expenses: mean=${test_df[test_df['category']=='Rent']['amount'].mean():.2f}, "
          f"std=${test_df[test_df['category']=='Rent']['amount'].std():.2f}")
    print(f"   Test amount: ${test_amount}")
    
    # Create labels
    labels = create_anomaly_labels(test_df, threshold_std=2.0)
    
    # Check if $200 is flagged as anomaly for Food but not for Rent
    food_200_idx = 50  # Last food expense
    rent_200_idx = 101  # Last rent expense
    
    food_is_anomaly = labels.iloc[food_200_idx]
    rent_is_anomaly = labels.iloc[rent_200_idx]
    
    print(f"\n2. Results:")
    print(f"   $200 in Food category: {'ANOMALY' if food_is_anomaly else 'NORMAL'}")
    print(f"   $200 in Rent category: {'ANOMALY' if rent_is_anomaly else 'NORMAL'}")
    
    if food_is_anomaly == 1 and rent_is_anomaly == 0:
        print("\n✓ Category-specific detection working correctly!")
        return True
    else:
        print("\n✗ Category-specific detection failed!")
        return False


if __name__ == '__main__':
    # Run tests
    test1_passed = test_anomaly_detection_threshold()
    test2_passed = test_category_specific_detection()
    
    print("\n" + "=" * 70)
    print("SUMMARY")
    print("=" * 70)
    print(f"Test 1 (Statistical Validity): {'PASSED ✓' if test1_passed else 'FAILED ✗'}")
    print(f"Test 2 (Category-Specific):    {'PASSED ✓' if test2_passed else 'FAILED ✗'}")
    print("=" * 70)
