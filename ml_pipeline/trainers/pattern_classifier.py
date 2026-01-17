"""Pattern classification model trainer using Random Forest Classifier.

This module trains a model to classify spending patterns into categories:
- daily: Expenses that occur daily or near-daily
- weekly: Expenses that occur weekly
- monthly: Expenses that occur monthly (e.g., rent, subscriptions)
- irregular: Expenses with no clear pattern

The model uses features like:
- Frequency of expenses in a category
- Amount variance
- Time gaps between expenses
- Category type
"""

import pandas as pd
import numpy as np
from sklearn.ensemble import RandomForestClassifier
from sklearn.metrics import (
    accuracy_score,
    precision_recall_fscore_support,
    classification_report,
    confusion_matrix
)
from typing import Tuple, Dict, Optional, List
import pickle
import json
from pathlib import Path
from datetime import datetime


class PatternClassifier:
    """
    Random Forest classifier for identifying spending patterns.
    
    This model classifies expenses into pattern types:
    - daily: Regular daily expenses (groceries, coffee, etc.)
    - weekly: Weekly recurring expenses (groceries, entertainment)
    - monthly: Monthly recurring expenses (rent, subscriptions, utilities)
    - irregular: Non-recurring or unpredictable expenses
    """
    
    def __init__(
        self,
        n_estimators: int = 100,
        max_depth: Optional[int] = 10,
        min_samples_split: int = 5,
        min_samples_leaf: int = 2,
        random_state: int = 42
    ):
        """
        Initialize the pattern classifier.
        
        Args:
            n_estimators: Number of trees in the forest (default: 100)
            max_depth: Maximum depth of trees (default: 10)
            min_samples_split: Minimum samples required to split (default: 5)
            min_samples_leaf: Minimum samples required at leaf node (default: 2)
            random_state: Random seed for reproducibility (default: 42)
        """
        self.n_estimators = n_estimators
        self.max_depth = max_depth
        self.min_samples_split = min_samples_split
        self.min_samples_leaf = min_samples_leaf
        self.random_state = random_state
        
        self.model = RandomForestClassifier(
            n_estimators=n_estimators,
            max_depth=max_depth,
            min_samples_split=min_samples_split,
            min_samples_leaf=min_samples_leaf,
            random_state=random_state,
            class_weight='balanced'  # Handle class imbalance
        )
        
        self.is_fitted = False
        self.feature_names = None
        self.feature_importance = None
        self.classes = None
        self.training_metrics = {}
    
    def _engineer_pattern_features(self, df: pd.DataFrame) -> pd.DataFrame:
        """
        Engineer features for pattern classification.
        
        Args:
            df: DataFrame with expense data
        
        Returns:
            DataFrame with pattern-specific features
        """
        # Create copy to avoid modifying original
        df = df.copy()
        
        # Parse datetime
        df['date_time'] = pd.to_datetime(df['date_time'])
        df = df.sort_values(['user_id', 'category', 'date_time']).reset_index(drop=True)
        
        features = pd.DataFrame()
        
        # === Frequency Features ===
        # Calculate time gaps between consecutive expenses in same category
        df['days_since_last'] = df.groupby(['user_id', 'category'])['date_time'].diff().dt.days
        
        # Rolling statistics on time gaps (per user, per category)
        features['avg_days_between'] = df.groupby(['user_id', 'category'])['days_since_last'].transform(
            lambda x: x.rolling(window=10, min_periods=1).mean()
        )
        features['std_days_between'] = df.groupby(['user_id', 'category'])['days_since_last'].transform(
            lambda x: x.rolling(window=10, min_periods=1).std().fillna(0)
        )
        
        # Coefficient of variation for time gaps (std/mean)
        features['cv_days_between'] = features['std_days_between'] / (features['avg_days_between'] + 1e-6)
        
        # === Amount Variance Features ===
        # Rolling statistics on amounts (per user, per category)
        features['avg_amount'] = df.groupby(['user_id', 'category'])['amount'].transform(
            lambda x: x.rolling(window=10, min_periods=1).mean()
        )
        features['std_amount'] = df.groupby(['user_id', 'category'])['amount'].transform(
            lambda x: x.rolling(window=10, min_periods=1).std().fillna(0)
        )
        
        # Coefficient of variation for amounts
        features['cv_amount'] = features['std_amount'] / (features['avg_amount'] + 1e-6)
        
        # === Frequency Count Features ===
        # Count expenses in last 30 days
        features['count_30d'] = df.groupby(['user_id', 'category'])['amount'].transform(
            lambda x: x.rolling(window=30, min_periods=1).count()
        )
        
        # Count expenses in last 7 days
        features['count_7d'] = df.groupby(['user_id', 'category'])['amount'].transform(
            lambda x: x.rolling(window=7, min_periods=1).count()
        )
        
        # === Category Encoding ===
        # One-hot encode category (some categories are more likely to be monthly, etc.)
        category_dummies = pd.get_dummies(df['category'], prefix='cat')
        features = pd.concat([features, category_dummies], axis=1)
        
        # === Time Features ===
        features['day_of_month'] = df['date_time'].dt.day
        features['is_month_start'] = (features['day_of_month'] <= 5).astype(int)
        features['is_month_end'] = (features['day_of_month'] >= 25).astype(int)
        
        # === Amount Features ===
        features['amount'] = df['amount']
        features['amount_log'] = np.log1p(df['amount'])
        
        # Fill any remaining NaN values
        features = features.fillna(0)
        
        return features
    
    def fit(
        self,
        X_train: pd.DataFrame,
        y_train: pd.Series,
        X_val: Optional[pd.DataFrame] = None,
        y_val: Optional[pd.Series] = None,
        verbose: bool = True
    ) -> 'PatternClassifier':
        """
        Train the pattern classification model.
        
        Args:
            X_train: Training features
            y_train: Training target (pattern types)
            X_val: Validation features (optional)
            y_val: Validation target (optional)
            verbose: Print training progress (default: True)
        
        Returns:
            Self (fitted model)
        """
        if verbose:
            print("Training Pattern Classifier...")
            print(f"  Training samples: {len(X_train):,}")
            if X_val is not None:
                print(f"  Validation samples: {len(X_val):,}")
            print(f"  Features: {X_train.shape[1]}")
            print(f"  Classes: {sorted(y_train.unique())}")
        
        # Store feature names
        self.feature_names = list(X_train.columns)
        
        # Train model
        if verbose:
            print("\n  Training Random Forest...")
        self.model.fit(X_train, y_train)
        
        self.is_fitted = True
        self.classes = self.model.classes_
        
        # Calculate feature importance
        self.feature_importance = dict(zip(
            self.feature_names,
            self.model.feature_importances_
        ))
        
        # Evaluate on training set
        train_pred = self.model.predict(X_train)
        train_acc = accuracy_score(y_train, train_pred)
        train_prec, train_rec, train_f1, _ = precision_recall_fscore_support(
            y_train, train_pred, average='weighted', zero_division=0
        )
        
        self.training_metrics['train_accuracy'] = train_acc
        self.training_metrics['train_precision'] = train_prec
        self.training_metrics['train_recall'] = train_rec
        self.training_metrics['train_f1'] = train_f1
        
        if verbose:
            print(f"\n  Training Metrics:")
            print(f"    Accuracy:  {train_acc:.4f}")
            print(f"    Precision: {train_prec:.4f}")
            print(f"    Recall:    {train_rec:.4f}")
            print(f"    F1 Score:  {train_f1:.4f}")
        
        # Evaluate on validation set if provided
        if X_val is not None and y_val is not None:
            val_pred = self.model.predict(X_val)
            val_acc = accuracy_score(y_val, val_pred)
            val_prec, val_rec, val_f1, _ = precision_recall_fscore_support(
                y_val, val_pred, average='weighted', zero_division=0
            )
            
            self.training_metrics['val_accuracy'] = val_acc
            self.training_metrics['val_precision'] = val_prec
            self.training_metrics['val_recall'] = val_rec
            self.training_metrics['val_f1'] = val_f1
            
            if verbose:
                print(f"\n  Validation Metrics:")
                print(f"    Accuracy:  {val_acc:.4f}")
                print(f"    Precision: {val_prec:.4f}")
                print(f"    Recall:    {val_rec:.4f}")
                print(f"    F1 Score:  {val_f1:.4f}")
        
        if verbose:
            print("\n✓ Training complete!")
        
        return self
    
    def predict(
        self,
        X: pd.DataFrame,
        return_probabilities: bool = False
    ) -> pd.DataFrame:
        """
        Predict pattern types for expenses.
        
        Args:
            X: Feature DataFrame
            return_probabilities: Include class probabilities (default: False)
        
        Returns:
            DataFrame with columns:
                - pattern_type: Predicted pattern (daily/weekly/monthly/irregular)
                - prob_daily: Probability of daily pattern (if return_probabilities=True)
                - prob_weekly: Probability of weekly pattern (if return_probabilities=True)
                - prob_monthly: Probability of monthly pattern (if return_probabilities=True)
                - prob_irregular: Probability of irregular pattern (if return_probabilities=True)
        """
        if not self.is_fitted:
            raise ValueError("Model must be fitted before prediction")
        
        # Ensure features match training
        if list(X.columns) != self.feature_names:
            raise ValueError(
                f"Feature mismatch. Expected {self.feature_names}, "
                f"got {list(X.columns)}"
            )
        
        # Predict pattern types
        predicted = self.model.predict(X)
        
        results = pd.DataFrame({
            'pattern_type': predicted
        })
        
        # Add probabilities if requested
        if return_probabilities:
            probabilities = self.model.predict_proba(X)
            
            for idx, class_name in enumerate(self.classes):
                results[f'prob_{class_name}'] = probabilities[:, idx]
        
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
        predictions = self.predict(X_test, return_probabilities=False)
        y_pred = predictions['pattern_type']
        
        # Calculate metrics
        accuracy = accuracy_score(y_test, y_pred)
        precision, recall, f1, _ = precision_recall_fscore_support(
            y_test, y_pred, average='weighted', zero_division=0
        )
        
        # Per-class metrics
        class_report = classification_report(y_test, y_pred, output_dict=True, zero_division=0)
        
        # Confusion matrix
        conf_matrix = confusion_matrix(y_test, y_pred, labels=self.classes)
        
        metrics = {
            'test_accuracy': accuracy,
            'test_precision': precision,
            'test_recall': recall,
            'test_f1': f1,
            'per_class_metrics': class_report,
            'confusion_matrix': conf_matrix.tolist()
        }
        
        if verbose:
            print("Test Set Evaluation:")
            print(f"  Accuracy:  {accuracy:.4f}")
            print(f"  Precision: {precision:.4f}")
            print(f"  Recall:    {recall:.4f}")
            print(f"  F1 Score:  {f1:.4f}")
            
            print("\n  Per-Class Metrics:")
            for class_name in self.classes:
                if class_name in class_report:
                    metrics_dict = class_report[class_name]
                    print(f"    {class_name:12s} - P: {metrics_dict['precision']:.3f}, "
                          f"R: {metrics_dict['recall']:.3f}, F1: {metrics_dict['f1-score']:.3f}")
            
            print("\n  Confusion Matrix:")
            print(f"    Classes: {list(self.classes)}")
            for i, row in enumerate(conf_matrix):
                print(f"    {self.classes[i]:12s}: {row}")
        
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
    
    def save(self, output_dir: str, model_name: str = 'pattern_classifier') -> None:
        """
        Save the trained model to disk.
        
        Args:
            output_dir: Directory to save model files
            model_name: Base name for model files (default: 'pattern_classifier')
        """
        if not self.is_fitted:
            raise ValueError("Model must be fitted before saving")
        
        output_path = Path(output_dir)
        output_path.mkdir(parents=True, exist_ok=True)
        
        # Save model
        model_file = output_path / f'{model_name}.pkl'
        with open(model_file, 'wb') as f:
            pickle.dump(self.model, f)
        
        # Save metadata
        metadata = {
            'model_name': model_name,
            'trained_at': datetime.now().isoformat(),
            'n_estimators': self.n_estimators,
            'max_depth': self.max_depth,
            'min_samples_split': self.min_samples_split,
            'min_samples_leaf': self.min_samples_leaf,
            'feature_names': self.feature_names,
            'feature_importance': self.feature_importance,
            'classes': self.classes.tolist() if self.classes is not None else None,
            'training_metrics': self.training_metrics
        }
        
        metadata_file = output_path / f'{model_name}_metadata.json'
        with open(metadata_file, 'w') as f:
            json.dump(metadata, f, indent=2)
        
        print(f"\n✓ Model saved to {output_dir}/")
        print(f"  - {model_file.name}")
        print(f"  - {metadata_file.name}")
    
    @classmethod
    def load(cls, model_dir: str, model_name: str = 'pattern_classifier') -> 'PatternClassifier':
        """
        Load a trained model from disk.
        
        Args:
            model_dir: Directory containing model files
            model_name: Base name of model files (default: 'pattern_classifier')
        
        Returns:
            Loaded PatternClassifier instance
        """
        model_path = Path(model_dir)
        
        # Load metadata
        metadata_file = model_path / f'{model_name}_metadata.json'
        with open(metadata_file, 'r') as f:
            metadata = json.load(f)
        
        # Create instance
        classifier = cls(
            n_estimators=metadata['n_estimators'],
            max_depth=metadata['max_depth'],
            min_samples_split=metadata['min_samples_split'],
            min_samples_leaf=metadata['min_samples_leaf']
        )
        
        # Load model
        model_file = model_path / f'{model_name}.pkl'
        with open(model_file, 'rb') as f:
            classifier.model = pickle.load(f)
        
        # Restore metadata
        classifier.is_fitted = True
        classifier.feature_names = metadata['feature_names']
        classifier.feature_importance = metadata['feature_importance']
        classifier.classes = np.array(metadata['classes']) if metadata['classes'] else None
        classifier.training_metrics = metadata['training_metrics']
        
        print(f"✓ Model loaded from {model_dir}/")
        print(f"  Trained at: {metadata['trained_at']}")
        
        return classifier


def train_pattern_classifier(
    train_data_path: str,
    val_data_path: str,
    test_data_path: str,
    output_dir: str,
    model_name: str = 'pattern_classifier'
) -> PatternClassifier:
    """
    Complete training pipeline for pattern classifier.
    
    Args:
        train_data_path: Path to training data CSV
        val_data_path: Path to validation data CSV
        test_data_path: Path to test data CSV
        output_dir: Directory to save trained model
        model_name: Name for the model (default: 'pattern_classifier')
    
    Returns:
        Trained PatternClassifier instance
    """
    print("=" * 70)
    print("PATTERN CLASSIFIER TRAINING PIPELINE")
    print("=" * 70)
    
    # Load data
    print("\n1. Loading data...")
    train_df = pd.read_csv(train_data_path)
    val_df = pd.read_csv(val_data_path)
    test_df = pd.read_csv(test_data_path)
    
    print(f"   Train: {len(train_df):,} records")
    print(f"   Val:   {len(val_df):,} records")
    print(f"   Test:  {len(test_df):,} records")
    
    # Check for pattern_type column
    if 'pattern_type' not in train_df.columns:
        raise ValueError("Training data must contain 'pattern_type' column")
    
    # Initialize classifier
    classifier = PatternClassifier(
        n_estimators=100,
        max_depth=10,
        min_samples_split=5,
        min_samples_leaf=2,
        random_state=42
    )
    
    # Feature engineering
    print("\n2. Engineering pattern features...")
    X_train = classifier._engineer_pattern_features(train_df)
    X_val = classifier._engineer_pattern_features(val_df)
    X_test = classifier._engineer_pattern_features(test_df)
    
    # Target is the pattern_type
    y_train = train_df['pattern_type']
    y_val = val_df['pattern_type']
    y_test = test_df['pattern_type']
    
    print(f"   Feature shape: {X_train.shape}")
    print(f"   Pattern distribution (train):")
    for pattern, count in y_train.value_counts().items():
        print(f"     {pattern:12s}: {count:6,} ({count/len(y_train)*100:.1f}%)")
    
    # Train model
    print("\n3. Training model...")
    classifier.fit(X_train, y_train, X_val, y_val, verbose=True)
    
    # Evaluate on test set
    print("\n4. Evaluating on test set...")
    test_metrics = classifier.evaluate(X_test, y_test, verbose=True)
    
    # Show feature importance
    print("\n5. Top 10 Most Important Features:")
    importance_df = classifier.get_feature_importance(top_n=10)
    for idx, row in importance_df.iterrows():
        print(f"   {row['feature']:30s} {row['importance']:.4f}")
    
    # Save model
    print("\n6. Saving model...")
    classifier.save(output_dir, model_name)
    
    print("\n" + "=" * 70)
    print("TRAINING COMPLETE!")
    print("=" * 70)
    
    return classifier


if __name__ == '__main__':
    """Train the pattern classifier model."""
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
    classifier = train_pattern_classifier(
        train_data_path=str(train_file),
        val_data_path=str(val_file),
        test_data_path=str(test_file),
        output_dir=str(output_dir),
        model_name='pattern_classifier'
    )
