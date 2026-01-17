"""Test script to verify confidence interval implementation."""

import pandas as pd
import numpy as np
from pathlib import Path
from spending_predictor import SpendingPredictor


def test_confidence_intervals():
    """Verify that confidence intervals are properly implemented."""
    
    print("=" * 70)
    print("CONFIDENCE INTERVAL VERIFICATION TEST")
    print("=" * 70)
    
    # Load the trained model
    model_dir = Path(__file__).parent.parent / 'models'
    
    if not (model_dir / 'spending_predictor.pkl').exists():
        print("\nError: Trained model not found. Please train the model first.")
        return False
    
    print("\n1. Loading trained model...")
    predictor = SpendingPredictor.load(str(model_dir), 'spending_predictor')
    
    # Load test data
    print("\n2. Loading test data...")
    test_file = Path(__file__).parent.parent / 'data' / 'splits' / 'synthetic_expenses_test.csv'
    test_df = pd.read_csv(test_file)
    
    # Feature engineering
    print("\n3. Engineering features...")
    import sys
    sys.path.insert(0, str(Path(__file__).parent.parent))
    from preprocessing import ExpenseFeatureEngineer
    
    engineer = ExpenseFeatureEngineer()
    
    # We need to fit on training data first
    train_file = Path(__file__).parent.parent / 'data' / 'splits' / 'synthetic_expenses_train.csv'
    train_df = pd.read_csv(train_file)
    engineer.fit(train_df)
    
    # Transform test data
    X_test = engineer.transform(test_df)
    y_test = test_df['amount']
    
    # Make predictions with confidence intervals
    print("\n4. Making predictions with confidence intervals...")
    predictions = predictor.predict(X_test, return_confidence=True)
    
    # Verify confidence interval property
    print("\n5. Verifying confidence interval properties...")
    
    # Check: confidence_low < predicted_amount < confidence_high
    violations_low = (predictions['confidence_low'] > predictions['predicted_amount']).sum()
    violations_high = (predictions['predicted_amount'] > predictions['confidence_high']).sum()
    
    total_predictions = len(predictions)
    valid_intervals = total_predictions - violations_low - violations_high
    
    print(f"\n   Total predictions: {total_predictions:,}")
    print(f"   Valid intervals (low < pred < high): {valid_intervals:,} ({valid_intervals/total_predictions*100:.2f}%)")
    print(f"   Violations (low > pred): {violations_low:,}")
    print(f"   Violations (pred > high): {violations_high:,}")
    
    # Show sample predictions
    print("\n6. Sample predictions with confidence intervals:")
    print("\n   " + "-" * 66)
    print(f"   {'Actual':>10} | {'Predicted':>10} | {'CI Low':>10} | {'CI High':>10} | {'Width':>10}")
    print("   " + "-" * 66)
    
    sample_indices = np.random.choice(len(predictions), size=min(10, len(predictions)), replace=False)
    for idx in sample_indices:
        actual = y_test.iloc[idx]
        pred = predictions.iloc[idx]['predicted_amount']
        ci_low = predictions.iloc[idx]['confidence_low']
        ci_high = predictions.iloc[idx]['confidence_high']
        width = ci_high - ci_low
        
        # Check if actual falls within CI
        in_ci = "✓" if ci_low <= actual <= ci_high else "✗"
        
        print(f"   ${actual:9.2f} | ${pred:9.2f} | ${ci_low:9.2f} | ${ci_high:9.2f} | ${width:9.2f} {in_ci}")
    
    print("   " + "-" * 66)
    
    # Calculate coverage
    actual_in_ci = ((y_test >= predictions['confidence_low']) & 
                    (y_test <= predictions['confidence_high'])).sum()
    coverage = actual_in_ci / total_predictions
    
    print(f"\n7. Confidence Interval Coverage:")
    print(f"   Actual values within CI: {actual_in_ci:,} / {total_predictions:,} ({coverage*100:.2f}%)")
    print(f"   Target coverage: 80% (10th to 90th percentile)")
    
    # Average CI width
    avg_width = (predictions['confidence_high'] - predictions['confidence_low']).mean()
    print(f"\n8. Average CI Width: ${avg_width:.2f}")
    
    # Test passes if all intervals are valid
    print("\n" + "=" * 70)
    if violations_low == 0 and violations_high == 0:
        print("✓ TEST PASSED: All confidence intervals satisfy low < predicted < high")
        print("=" * 70)
        return True
    else:
        print("✗ TEST FAILED: Some confidence intervals are invalid")
        print("=" * 70)
        return False


if __name__ == '__main__':
    success = test_confidence_intervals()
    exit(0 if success else 1)
