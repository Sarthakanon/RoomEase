#!/usr/bin/env python3
"""
Checkpoint 8: Verify ML Models

This script runs all tests for the ML models to ensure they are working correctly
before proceeding to Phase 3: Backend Analytics API.

Tests:
1. Data pipeline verification
2. Spending predictor confidence intervals
3. Pattern classifier functionality
4. Property 3: Pattern classification completeness
5. Anomaly detector statistical validity
"""

import sys
import subprocess
from pathlib import Path


def run_test(test_name, test_script, path=None):
    """Run a test script and return the result."""
    print(f"\n{'='*70}")
    print(f"Running: {test_name}")
    print(f"{'='*70}\n")
    
    try:
        if path:
            result = subprocess.run(
                ['python3', test_script],
                cwd=path,
                capture_output=False,
                text=True
            )
        else:
            result = subprocess.run(
                ['python3', test_script],
                capture_output=False,
                text=True
            )
        
        return result.returncode == 0
    except Exception as e:
        print(f"✗ Error running test: {e}")
        return False


def main():
    """Run all checkpoint tests."""
    print("\n" + "="*70)
    print("CHECKPOINT 8: ML MODELS VERIFICATION")
    print("="*70)
    print("\nThis checkpoint verifies that all ML models are trained and")
    print("functioning correctly before proceeding to Phase 3.")
    print()
    
    base_dir = Path(__file__).parent
    
    # Define all tests
    tests = [
        {
            'name': 'Data Pipeline Verification',
            'script': 'verify_pipeline.py',
            'path': base_dir,
            'required': True
        },
        {
            'name': 'Spending Predictor - Confidence Intervals',
            'script': 'trainers/test_confidence_intervals.py',
            'path': base_dir,
            'required': True
        },
        {
            'name': 'Pattern Classifier - Functionality',
            'script': 'trainers/test_pattern_classifier.py',
            'path': base_dir,
            'required': True
        },
        {
            'name': 'Property 3 - Pattern Classification Completeness',
            'script': 'trainers/verify_property_3.py',
            'path': base_dir,
            'required': True,
            'note': 'Edge case test may fail due to one-hot encoding, but main property verification should pass'
        },
        {
            'name': 'Anomaly Detector - Statistical Validity',
            'script': 'trainers/test_anomaly_detector.py',
            'path': base_dir,
            'required': True
        }
    ]
    
    # Run all tests
    results = {}
    for test in tests:
        print(f"\n{'='*70}")
        print(f"TEST: {test['name']}")
        if 'note' in test:
            print(f"NOTE: {test['note']}")
        print(f"{'='*70}")
        
        passed = run_test(test['name'], test['script'], test['path'])
        results[test['name']] = {
            'passed': passed,
            'required': test['required']
        }
    
    # Print summary
    print("\n" + "="*70)
    print("CHECKPOINT 8 SUMMARY")
    print("="*70)
    print()
    
    all_required_passed = True
    for test_name, result in results.items():
        status = "✓ PASS" if result['passed'] else "✗ FAIL"
        required = " (REQUIRED)" if result['required'] else " (OPTIONAL)"
        print(f"{test_name:.<50} {status}{required}")
        
        if result['required'] and not result['passed']:
            all_required_passed = False
    
    print("\n" + "="*70)
    
    if all_required_passed:
        print("\n✓ CHECKPOINT 8 PASSED!")
        print("\nAll ML models are trained and verified.")
        print("You can now proceed to Phase 3: Backend Analytics API")
        print("\nNext steps:")
        print("  1. Create database schema for analytics")
        print("  2. Implement analytics service layer in Go")
        print("  3. Create analytics API handlers")
        return 0
    else:
        print("\n✗ CHECKPOINT 8 FAILED!")
        print("\nSome required tests failed. Please review the errors above.")
        print("Fix the issues before proceeding to Phase 3.")
        return 1


if __name__ == '__main__':
    sys.exit(main())
