"""Spending prediction model trainer using Gradient Boosting Regressor.

This module trains a model to predict future spending amounts based on:
- Category
- Time features (day of week, month, etc.)
- Historical averages and patterns

The model also provides confidence intervals using quantile regression.
"""

import pandas as pd
import numpy as np
from sklearn.ensemble import GradientBoostingRegressor
from sklearn.metrics import mean_absolute_error, mean_squared_error, r2_score
from typing import Tuple, Dict, Optional, List
import pickle
import json
from pathlib import Path
from datetime import datetime


class SpendingPredictor:
    """
    Gradient Boosting model for predicting spending amounts with confidence intervals.
    
    This model predicts the expected spending amount for a given category and time period,
    along with confidence intervals to quantify prediction uncertainty.
    """
    
    def __init__(
        self,
        n_estimators: int = 100,
        learning_rate: float = 0.1,
        max_depth: int = 5,
        random_state: int = 42
    ):
        """
        Initialize the spending predictor.
        
        Args:
            n_estimators: Number of boosting stages (default: 100)
            learning_rate: Learning rate shrinks contribution of each tree (default: 0.1)
            max_depth: Maximum depth of individual trees (default: 5)
            random_state: Random seed for reproducibility (default: 42)
        """
        self.n_estimators = n_estimators
        self.learning_rate = learning_rate
        self.max_depth = max_depth
        self.random_state = random_state
        
        # Main predictor (predicts median/mean)
        self.model = GradientBoostingRegressor(
            n_estimators=n_estimators,
            learning_rate=learning_rate,
            max_depth=max_depth,
            random_state=random_state,
            loss='squared_error'
        )
        
        # Quantile regressors for confidence intervals
        # Lower bound (10th percentile)
        self.model_lower = GradientBoostingRegressor(
            n_estimators=n_estimators,
            learning_rate=learning_rate,
            max_depth=max_depth,
            random_state=random_state,
            loss='quantile',
            alpha=0.1  # 10th percentile
        )
        
        # Upper bound (90th percentile)
        self.model_upper = GradientBoostingRegressor(
            n_estimators=n_estimators,
            learning_rate=learning_rate,
            max_depth=max_depth,
            random_state=random_state,
            loss='quantile',
            alpha=0.9  # 90th percentile
        )
        
        self.is_fitted = False
        self.feature_names = None
        self.feature_importance = None
        self.training_metrics = {}
    
    def fit(
        self,
        X_train: pd.DataFrame,
        y_train: pd.Series,
        X_val: Optional[pd.DataFrame] = None,
        y_val: Optional[pd.Series] = None,
        verbose: bool = True
    ) -> 'SpendingPredictor':
        """
        Train the spending prediction model.
        
        Args:
            X_train: Training features
            y_train: Training target (amounts)
            X_val: Validation features (optional)
            y_val: Validation target (optional)
            verbose: Print training progress (default: True)
        
        Returns:
            Self (fitted model)
        """
        if verbose:
            print("Training Spending Predictor...")
            print(f"  Training samples: {len(X_train):,}")
            if X_val is not None:
                print(f"  Validation samples: {len(X_val):,}")
            print(f"  Features: {X_train.shape[1]}")
        
        # Store feature names
        self.feature_names = list(X_train.columns)
        
        # Train main model (mean/median prediction)
        if verbose:
            print("\n  Training main predictor...")
        self.model.fit(X_train, y_train)
        
        # Train lower bound model
        if verbose:
            print("  Training lower bound (10th percentile)...")
        self.model_lower.fit(X_train, y_train)
        
        # Train upper bound model
        if verbose:
            print("  Training upper bound (90th percentile)...")
        self.model_upper.fit(X_train, y_train)
        
        self.is_fitted = True
        
        # Calculate feature importance
        self.feature_importance = dict(zip(
            self.feature_names,
            self.model.feature_importances_
        ))
        
        # Evaluate on training set
        train_pred = self.model.predict(X_train)
        train_mae = mean_absolute_error(y_train, train_pred)
        train_rmse = np.sqrt(mean_squared_error(y_train, train_pred))
        train_r2 = r2_score(y_train, train_pred)
        
        self.training_metrics['train_mae'] = train_mae
        self.training_metrics['train_rmse'] = train_rmse
        self.training_metrics['train_r2'] = train_r2
        
        if verbose:
            print(f"\n  Training Metrics:")
            print(f"    MAE:  ${train_mae:.2f}")
            print(f"    RMSE: ${train_rmse:.2f}")
            print(f"    R²:   {train_r2:.4f}")
        
        # Evaluate on validation set if provided
        if X_val is not None and y_val is not None:
            val_pred = self.model.predict(X_val)
            val_mae = mean_absolute_error(y_val, val_pred)
            val_rmse = np.sqrt(mean_squared_error(y_val, val_pred))
            val_r2 = r2_score(y_val, val_pred)
            
            self.training_metrics['val_mae'] = val_mae
            self.training_metrics['val_rmse'] = val_rmse
            self.training_metrics['val_r2'] = val_r2
            
            if verbose:
                print(f"\n  Validation Metrics:")
                print(f"    MAE:  ${val_mae:.2f}")
                print(f"    RMSE: ${val_rmse:.2f}")
                print(f"    R²:   {val_r2:.4f}")
        
        if verbose:
            print("\n✓ Training complete!")
        
        return self
    
    def predict(
        self,
        X: pd.DataFrame,
        return_confidence: bool = True
    ) -> pd.DataFrame:
        """
        Predict spending amounts with optional confidence intervals.
        
        Args:
            X: Feature DataFrame
            return_confidence: Include confidence intervals (default: True)
        
        Returns:
            DataFrame with columns:
                - predicted_amount: Main prediction
                - confidence_low: Lower bound (10th percentile)
                - confidence_high: Upper bound (90th percentile)
        
        Note:
            Confidence intervals are adjusted to ensure confidence_low <= predicted_amount <= confidence_high
        """
        if not self.is_fitted:
            raise ValueError("Model must be fitted before prediction")
        
        # Ensure features match training
        if list(X.columns) != self.feature_names:
            raise ValueError(
                f"Feature mismatch. Expected {self.feature_names}, "
                f"got {list(X.columns)}"
            )
        
        # Main prediction
        predicted = self.model.predict(X)
        
        results = pd.DataFrame({
            'predicted_amount': predicted
        })
        
        # Add confidence intervals if requested
        if return_confidence:
            confidence_low = self.model_lower.predict(X)
            confidence_high = self.model_upper.predict(X)
            
            # Ensure confidence_low <= predicted_amount <= confidence_high
            # This adjustment is necessary because the three models are trained independently
            # and may occasionally produce inconsistent predictions
            
            # Adjust lower bound: min(confidence_low, predicted_amount)
            confidence_low = np.minimum(confidence_low, predicted)
            
            # Adjust upper bound: max(confidence_high, predicted_amount)
            confidence_high = np.maximum(confidence_high, predicted)
            
            results['confidence_low'] = confidence_low
            results['confidence_high'] = confidence_high
        
        return results
    
    def evaluate(
        self,
        X_test: pd.DataFrame,
        y_test: pd.Series,
        verbose: bool = True
    ) -> Dict[str, float]:
        """
        Evaluate model performance on test set.
        
        Args:
            X_test: Test features
            y_test: Test target
            verbose: Print evaluation results (default: True)
        
        Returns:
            Dictionary of evaluation metrics
        """
        if not self.is_fitted:
            raise ValueError("Model must be fitted before evaluation")
        
        # Make predictions
        predictions = self.predict(X_test, return_confidence=True)
        y_pred = predictions['predicted_amount']
        
        # Calculate metrics
        mae = mean_absolute_error(y_test, y_pred)
        rmse = np.sqrt(mean_squared_error(y_test, y_pred))
        r2 = r2_score(y_test, y_pred)
        
        # Calculate percentage of predictions within confidence interval
        within_ci = (
            (y_test >= predictions['confidence_low']) &
            (y_test <= predictions['confidence_high'])
        ).mean()
        
        # Calculate average confidence interval width
        ci_width = (predictions['confidence_high'] - predictions['confidence_low']).mean()
        
        metrics = {
            'test_mae': mae,
            'test_rmse': rmse,
            'test_r2': r2,
            'ci_coverage': within_ci,
            'avg_ci_width': ci_width
        }
        
        if verbose:
            print("Test Set Evaluation:")
            print(f"  MAE:  ${mae:.2f}")
            print(f"  RMSE: ${rmse:.2f}")
            print(f"  R²:   {r2:.4f}")
            print(f"  CI Coverage: {within_ci*100:.1f}%")
            print(f"  Avg CI Width: ${ci_width:.2f}")
        
        return metrics
    
    def get_feature_importance(self, top_n: int = 10) -> pd.DataFrame:
        """
        Get feature importance rankings.
        
        Args:
            top_n: Number of top features to return (default: 10)
        
        Returns:
            DataFrame with feature names and importance scores
        """
        if not self.is_fitted:
            raise ValueError("Model must be fitted first")
        
        importance_df = pd.DataFrame({
            'feature': list(self.feature_importance.keys()),
            'importance': list(self.feature_importance.values())
        })
        
        importance_df = importance_df.sort_values('importance', ascending=False)
        
        return importance_df.head(top_n)
    
    def save(self, output_dir: str, model_name: str = 'spending_predictor') -> None:
        """
        Save the trained model to disk.
        
        Args:
            output_dir: Directory to save model files
            model_name: Base name for model files (default: 'spending_predictor')
        """
        if not self.is_fitted:
            raise ValueError("Model must be fitted before saving")
        
        output_path = Path(output_dir)
        output_path.mkdir(parents=True, exist_ok=True)
        
        # Save main model
        model_file = output_path / f'{model_name}.pkl'
        with open(model_file, 'wb') as f:
            pickle.dump(self.model, f)
        
        # Save quantile models
        lower_file = output_path / f'{model_name}_lower.pkl'
        with open(lower_file, 'wb') as f:
            pickle.dump(self.model_lower, f)
        
        upper_file = output_path / f'{model_name}_upper.pkl'
        with open(upper_file, 'wb') as f:
            pickle.dump(self.model_upper, f)
        
        # Save metadata
        metadata = {
            'model_name': model_name,
            'trained_at': datetime.now().isoformat(),
            'n_estimators': self.n_estimators,
            'learning_rate': self.learning_rate,
            'max_depth': self.max_depth,
            'feature_names': self.feature_names,
            'feature_importance': self.feature_importance,
            'training_metrics': self.training_metrics
        }
        
        metadata_file = output_path / f'{model_name}_metadata.json'
        with open(metadata_file, 'w') as f:
            json.dump(metadata, f, indent=2)
        
        print(f"\n✓ Model saved to {output_dir}/")
        print(f"  - {model_file.name}")
        print(f"  - {lower_file.name}")
        print(f"  - {upper_file.name}")
        print(f"  - {metadata_file.name}")
    
    @classmethod
    def load(cls, model_dir: str, model_name: str = 'spending_predictor') -> 'SpendingPredictor':
        """
        Load a trained model from disk.
        
        Args:
            model_dir: Directory containing model files
            model_name: Base name of model files (default: 'spending_predictor')
        
        Returns:
            Loaded SpendingPredictor instance
        """
        model_path = Path(model_dir)
        
        # Load metadata
        metadata_file = model_path / f'{model_name}_metadata.json'
        with open(metadata_file, 'r') as f:
            metadata = json.load(f)
        
        # Create instance
        predictor = cls(
            n_estimators=metadata['n_estimators'],
            learning_rate=metadata['learning_rate'],
            max_depth=metadata['max_depth']
        )
        
        # Load models
        model_file = model_path / f'{model_name}.pkl'
        with open(model_file, 'rb') as f:
            predictor.model = pickle.load(f)
        
        lower_file = model_path / f'{model_name}_lower.pkl'
        with open(lower_file, 'rb') as f:
            predictor.model_lower = pickle.load(f)
        
        upper_file = model_path / f'{model_name}_upper.pkl'
        with open(upper_file, 'rb') as f:
            predictor.model_upper = pickle.load(f)
        
        # Restore metadata
        predictor.is_fitted = True
        predictor.feature_names = metadata['feature_names']
        predictor.feature_importance = metadata['feature_importance']
        predictor.training_metrics = metadata['training_metrics']
        
        print(f"✓ Model loaded from {model_dir}/")
        print(f"  Trained at: {metadata['trained_at']}")
        
        return predictor


def train_spending_predictor(
    train_data_path: str,
    val_data_path: str,
    test_data_path: str,
    output_dir: str,
    model_name: str = 'spending_predictor'
) -> SpendingPredictor:
    """
    Complete training pipeline for spending predictor.
    
    Args:
        train_data_path: Path to training data CSV
        val_data_path: Path to validation data CSV
        test_data_path: Path to test data CSV
        output_dir: Directory to save trained model
        model_name: Name for the model (default: 'spending_predictor')
    
    Returns:
        Trained SpendingPredictor instance
    """
    try:
        from ..preprocessing import ExpenseFeatureEngineer
    except ImportError:
        # Handle direct script execution
        import sys
        from pathlib import Path
        sys.path.insert(0, str(Path(__file__).parent.parent))
        from preprocessing import ExpenseFeatureEngineer
    
    print("=" * 70)
    print("SPENDING PREDICTOR TRAINING PIPELINE")
    print("=" * 70)
    
    # Load data
    print("\n1. Loading data...")
    train_df = pd.read_csv(train_data_path)
    val_df = pd.read_csv(val_data_path)
    test_df = pd.read_csv(test_data_path)
    
    print(f"   Train: {len(train_df):,} records")
    print(f"   Val:   {len(val_df):,} records")
    print(f"   Test:  {len(test_df):,} records")
    
    # Feature engineering
    print("\n2. Engineering features...")
    engineer = ExpenseFeatureEngineer()
    
    # Fit on training data
    engineer.fit(train_df)
    
    # Transform all sets
    X_train = engineer.transform(train_df)
    X_val = engineer.transform(val_df)
    X_test = engineer.transform(test_df)
    
    # Target is the amount
    y_train = train_df['amount']
    y_val = val_df['amount']
    y_test = test_df['amount']
    
    print(f"   Feature shape: {X_train.shape}")
    print(f"   Features: {list(X_train.columns)}")
    
    # Train model
    print("\n3. Training model...")
    predictor = SpendingPredictor(
        n_estimators=100,
        learning_rate=0.1,
        max_depth=5,
        random_state=42
    )
    
    predictor.fit(X_train, y_train, X_val, y_val, verbose=True)
    
    # Evaluate on test set
    print("\n4. Evaluating on test set...")
    test_metrics = predictor.evaluate(X_test, y_test, verbose=True)
    
    # Show feature importance
    print("\n5. Top 10 Most Important Features:")
    importance_df = predictor.get_feature_importance(top_n=10)
    for idx, row in importance_df.iterrows():
        print(f"   {row['feature']:25s} {row['importance']:.4f}")
    
    # Save model
    print("\n6. Saving model...")
    predictor.save(output_dir, model_name)
    
    print("\n" + "=" * 70)
    print("TRAINING COMPLETE!")
    print("=" * 70)
    
    return predictor


if __name__ == '__main__':
    """Train the spending predictor model."""
    from pathlib import Path
    
    # Paths
    base_dir = Path(__file__).parent.parent
    data_dir = base_dir / 'data' / 'splits'
    output_dir = base_dir / 'models'
    
    train_file = data_dir / 'synthetic_expenses_train.csv'
    val_file = data_dir / 'synthetic_expenses_val.csv'
    test_file = data_dir / 'synthetic_expenses_test.csv'
    
    # Check if data exists
    if not train_file.exists():
        print(f"Error: Training data not found at {train_file}")
        print("Please run the data generation and splitting scripts first.")
        exit(1)
    
    # Train model
    predictor = train_spending_predictor(
        train_data_path=str(train_file),
        val_data_path=str(val_file),
        test_data_path=str(test_file),
        output_dir=str(output_dir),
        model_name='spending_predictor'
    )
