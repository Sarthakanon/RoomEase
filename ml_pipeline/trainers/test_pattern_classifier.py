"""Test script to verify pattern classifier functionality."""

import pandas as pd
import numpy as np
from pathlib import Path
from pattern_classifier import PatternClassifier


def test_pattern_classifier():
    """Test loading and using the pattern classifier."""
    
    print("=" * 70)
    print("PATTERN CLASSIFIER TEST")
    print("=" * 70)
    
    # Paths
    base_dir = Path(__file__).parent.parent
    model_dir = base_dir / 'models'
    data_dir = base_dir / 'data' / 'splits'
    
    # Load the trained model
    print("\n1. Loading trained model...")
    classifier = PatternClassifier.load(str(model_dir), 'pattern_classifier')
    
    # Load test data
    print("\n2. Loading test data...")
    test_file = data_dir / 'synthetic_expenses_test.csv'
    test_df = pd.read_csv(test_file)
    print(f"   Test samples: {len(test_df):,}")
    
    # Engineer features
    print("\n3. Engineering features...")
    X_test = classifier._engineer_pattern_features(test_df)
    print(f"   Feature shape: {X_test.shape}")
    
    # Make predictions
    print("\n4. Making predictions...")
    predictions = classifier.predict(X_test, return_probabilities=True)
    print(f"   Predictions shape: {predictions.shape}")
    print(f"\n   Sample predictions (first 5):")
    print(predictions.head())
    
    # Verify all predictions are valid pattern types
    print("\n5. Validating predictions...")
    valid_patterns = {'daily', 'weekly', 'monthly', 'irregular'}
    predicted_patterns = set(predictions['pattern_type'].unique())
    
    if predicted_patterns.issubset(valid_patterns):
        print(f"   ✓ All predictions are valid pattern types")
        print(f"   Predicted patterns: {sorted(predicted_patterns)}")
    else:
        print(f"   ✗ Invalid patterns found: {predicted_patterns - valid_patterns}")
    
    # Check prediction distribution
    print("\n6. Prediction distribution:")
    for pattern, count in predictions['pattern_type'].value_counts().items():
        print(f"   {pattern:12s}: {count:6,} ({count/len(predictions)*100:.1f}%)")
    
    # Verify probabilities sum to 1
    print("\n7. Verifying probability distributions...")
    prob_cols = [col for col in predictions.columns if col.startswith('prob_')]
    prob_sums = predictions[prob_cols].sum(axis=1)
    
    if np.allclose(prob_sums, 1.0, atol=0.01):
        print(f"   ✓ All probability distributions sum to ~1.0")
        print(f"   Mean sum: {prob_sums.mean():.6f}")
        print(f"   Min sum:  {prob_sums.min():.6f}")
        print(f"   Max sum:  {prob_sums.max():.6f}")
    else:
        print(f"   ✗ Probability distributions don't sum to 1.0")
        print(f"   Mean sum: {prob_sums.mean():.6f}")
    
    # Compare with actual labels
    if 'pattern_type' in test_df.columns:
        print("\n8. Comparing with actual labels...")
        y_test = test_df['pattern_type']
        y_pred = predictions['pattern_type']
        
        accuracy = (y_test == y_pred).mean()
        print(f"   Accuracy: {accuracy:.4f} ({accuracy*100:.2f}%)")
        
        # Show confusion for each class
        print("\n   Per-class accuracy:")
        for pattern in sorted(valid_patterns):
            mask = y_test == pattern
            if mask.sum() > 0:
                class_acc = (y_test[mask] == y_pred[mask]).mean()
                print(f"   {pattern:12s}: {class_acc:.4f} ({class_acc*100:.1f}%)")
    
    print("\n" + "=" * 70)
    print("TEST COMPLETE!")
    print("=" * 70)


if __name__ == '__main__':
    test_pattern_classifier()
