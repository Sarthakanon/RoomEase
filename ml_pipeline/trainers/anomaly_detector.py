"""Anomaly detection model trainer using Isolation Forest.

This module trains a model to detect unusual spending patterns:
- Expenses that exceed 2 standard deviations from category average
- Unusual amounts for specific categories
- Unexpected spending behavior

The model uses Isolation Forest, which is particularly effective for
anomaly detection in high-dimensional data without requiring labeled anomalies.
"""

import pandas as pd
import numpy as np
from sklearn.ensemble import IsolationForest
from sklearn.metrics import (
    precision_score,
    recall_score,
    f1_score,
    confusion_matrix,
    classification_report
)
from typing import Tuple, Dict, Optional, List
import pickle
import json
from pathlib import Path
from datetime import datetime


class AnomalyDetector:
    """
    Isolation Forest model for detecting anomalous spending patterns.
    
    This model identifies expenses that deviate significantly from normal
    spending behavior, flagging potential errors, fraud, or unusual purchases.
    
    The model flags expenses as anomalies if they exceed 2 standard deviations
    from the category average.
    """
    
    def __init__(
        self,
        contamination: float = 0.05,
        n_estimators: int = 100,
        max_samples: int = 256,
        random_state: int = 42
    ):
        """
        Initialize the anomaly detector.
        
        Args:
            contamination: Expected proportion of anomalies (default: 0.05 = 5%)
            n_estimators: Number of isolation trees (default: 100)
            max_samples: Number of samples to draw for each tree (default: 256)
            random_state: Random seed for reproducibility (default: 42)
        """
        self.contamination = contamination
        self.n_estimators = n_estimators
        self.max_samples = max_samples
        self.random_state = random_state
        
        self.model = IsolationForest(
            contamination=contamination,
            n_estimators=n_estimators,
            max_samples=max_samples,
            random_state=random_state,
            n_jobs=-1  # Use all CPU cores
        )
        
        self.is_fitted = False
        self.feature_names = None
        self.category_stats = {}  # Store mean and std for each category
        self.training_metrics = {}
    
    def _calculate_category_statistics(self, df: pd.DataFrame) -> Dict:
        """
        Calculate mean and standard deviation for each category.
        
        Args:
            df: DataFrame with expense data
        
        Returns:
            Dictionary mapping category to {mean, std}
        """
        stats = {}
        
        for category in df['category'].unique():
            category_amounts = df[df['category'] == category]['amount']
            stats[category] = {
                'mean': category_amounts.mean(),
                'std': category_amounts.std(),
                'count': len(category_amounts)
            }
        
        return stats
    
    def _engineer_anomaly_features(self, df: pd.DataFrame) -> pd.DataFrame:
        """
        Engineer features for anomaly detection.
        
        Args:
            df: DataFrame with expense data
        
        Returns:
            DataFrame with anomaly-specific features
        """
        # Create copy to avoid modifying original
        df = df.copy()
        
        # Parse datetime
        df['date_time'] = pd.to_datetime(df['date_time'])
        df = df.sort_values(['user_id', 'category', 'date_time']).reset_index(drop=True)
        
        features = pd.DataFrame()
        
        # === Amount Features ===
        features['amount'] = df['amount']
        features['amount_log'] = np.log1p(df['amount'])
        
        # === Category-Relative Features ===
        # Calculate how far each expense deviates from category average
        for category in df['category'].unique():
            mask = df['category'] == category
            category_amounts = df.loc[mask, 'amount']
            
            # Rolling statistics (30-day window)
            rolling_mean = category_amounts.rolling(window=30, min_periods=1).mean()
            rolling_std = category_amounts.rolling(window=30, min_periods=1).std().fillna(1.0)
            
            # Z-score: how many standard deviations from mean
            z_score = (category_amounts - rolling_mean) / (rolling_std + 1e-6)
            
            # Deviation ratio: amount / category_mean
            deviation_ratio = category_amounts / (rolling_mean + 1e-6)
            
            features.loc[mask, 'category_mean'] = rolling_mean.values
            features.loc[mask, 'category_std'] = rolling_std.values
            features.loc[mask, 'z_score'] = z_score.values
            features.loc[mask, 'deviation_ratio'] = deviation_ratio.values
        
        # === Time-Based Features ===
        # Days since last expense in same category
        df['days_since_last'] = df.groupby(['user_id', 'category'])['date_time'].diff().dt.days.fillna(0)
        features['days_since_last'] = df['days_since_last']
        
        # Time of month (some anomalies might be timing-related)
        features['day_of_month'] = df['date_time'].dt.day
        features['is_month_start'] = (features['day_of_month'] <= 5).astype(int)
        features['is_month_end'] = (features['day_of_month'] >= 25).astype(int)
        
        # === Frequency Features ===
        # Count of expenses in last 7 and 30 days
        features['count_7d'] = df.groupby(['user_id', 'category'])['amount'].transform(
            lambda x: x.rolling(window=7, min_periods=1).count()
        )
        features['count_30d'] = df.groupby(['user_id', 'category'])['amount'].transform(
            lambda x: x.rolling(window=30, min_periods=1).count()
        )
        
        # === Category Encoding ===
        # One-hot encode category
        category_dummies = pd.get_dummies(df['category'], prefix='cat')
        features = pd.concat([features, category_dummies], axis=1)
        
        # Fill any remaining NaN values
        features = features.fillna(0)
        
        return features
    
    def fit(
        self,
        X_train: pd.DataFrame,
        y_train: Optional[pd.Series] = None,
        verbose: bool = True
    ) -> 'AnomalyDetector':
        """
        Train the anomaly detection model.
        
        Note: Isolation Forest is unsupervised, so y_train is optional.
        If provided, it will be used for evaluation metrics only.
        
        Args:
            X_train: Training features
            y_train: Training labels (optional, for evaluation only)
            verbose: Print training progress (default: True)
        
        Returns:
            Self (fitted model)
        """
        if verbose:
            print("Training Anomaly Detector...")
            print(f"  Training samples: {len(X_train):,}")
            print(f"  Features: {X_train.shape[1]}")
            print(f"  Contamination: {self.contamination*100:.1f}%")
        
        # Store feature names
        self.feature_names = list(X_train.columns)
        
        # Train model
        if verbose:
            print("\n  Training Isolation Forest...")
        self.model.fit(X_train)
        
        self.is_fitted = True
        
        # Evaluate on training set if labels provided
        if y_train is not None:
            train_pred = self.model.predict(X_train)
            # Convert Isolation Forest output (-1 for anomaly, 1 for normal) to binary (1 for anomaly, 0 for normal)
            train_pred_binary = (train_pred == -1).astype(int)
            
            # Calculate metrics
            train_precision = precision_score(y_train, train_pred_binary, zero_division=0)
            train_recall = recall_score(y_train, train_pred_binary, zero_division=0)
            train_f1 = f1_score(y_train, train_pred_binary, zero_division=0)
            
            self.training_metrics['train_precision'] = train_precision
            self.training_metrics['train_recall'] = train_recall
            self.training_metrics['train_f1'] = train_f1
            
            # Calculate anomaly rate
            anomaly_rate = train_pred_binary.mean()
            self.training_metrics['train_anomaly_rate'] = anomaly_rate
            
            if verbose:
                print(f"\n  Training Metrics:")
                print(f"    Precision: {train_precision:.4f}")
                print(f"    Recall:    {train_recall:.4f}")
                print(f"    F1 Score:  {train_f1:.4f}")
                print(f"    Anomaly Rate: {anomaly_rate*100:.2f}%")
        else:
            # Just report anomaly rate
            train_pred = self.model.predict(X_train)
            train_pred_binary = (train_pred == -1).astype(int)
            anomaly_rate = train_pred_binary.mean()
            self.training_metrics['train_anomaly_rate'] = anomaly_rate
            
            if verbose:
                print(f"\n  Training Metrics:")
                print(f"    Anomaly Rate: {anomaly_rate*100:.2f}%")
        
        if verbose:
            print("\n✓ Training complete!")
        
        return self
    
    def predict(
        self,
        X: pd.DataFrame,
        return_scores: bool = True
    ) -> pd.DataFrame:
        """
        Predict anomalies in expense data.
        
        Args:
            X: Feature DataFrame
            return_scores: Include anomaly scores (default: True)
        
        Returns:
            DataFrame with columns:
                - is_anomaly: Binary flag (1 = anomaly, 0 = normal)
                - anomaly_score: Anomaly score (lower = more anomalous)
                - reason: Explanation for why flagged as anomaly
        """
        if not self.is_fitted:
            raise ValueError("Model must be fitted before prediction")
        
        # Ensure features match training
        if list(X.columns) != self.feature_names:
            raise ValueError(
                f"Feature mismatch. Expected {self.feature_names}, "
                f"got {list(X.columns)}"
            )
        
        # Predict anomalies
        predictions = self.model.predict(X)
        # Convert -1 (anomaly) to 1, and 1 (normal) to 0
        is_anomaly = (predictions == -1).astype(int)
        
        results = pd.DataFrame({
            'is_anomaly': is_anomaly
        })
        
        # Add anomaly scores if requested
        if return_scores:
            # decision_function returns anomaly scores
            # Lower scores = more anomalous
            scores = self.model.decision_function(X)
            results['anomaly_score'] = scores
            
            # Generate explanations based on features
            results['reason'] = self._generate_explanations(X, is_anomaly)
        
        return results
    
    def _generate_explanations(
        self,
        X: pd.DataFrame,
        is_anomaly: np.ndarray
    ) -> List[str]:
        """
        Generate human-readable explanations for anomalies.
        
        Args:
            X: Feature DataFrame
            is_anomaly: Binary array indicating anomalies
        
        Returns:
            List of explanation strings
        """
        explanations = []
        
        for idx, row in X.iterrows():
            if is_anomaly[idx] == 0:
                explanations.append("Normal spending pattern")
            else:
                # Analyze features to determine reason
                reasons = []
                
                # Check z-score (if available)
                if 'z_score' in X.columns:
                    z_score = row['z_score']
                    if abs(z_score) > 2:
                        reasons.append(f"Amount is {abs(z_score):.1f} std deviations from category average")
                
                # Check deviation ratio
                if 'deviation_ratio' in X.columns:
                    deviation = row['deviation_ratio']
                    if deviation > 2:
                        reasons.append(f"Amount is {deviation:.1f}x the category average")
                    elif deviation < 0.5:
                        reasons.append(f"Amount is unusually low ({deviation:.1f}x category average)")
                
                # Check time gaps
                if 'days_since_last' in X.columns:
                    days = row['days_since_last']
                    if days > 60:
                        reasons.append(f"Unusual time gap ({int(days)} days since last expense)")
                
                # Combine reasons or use default
                if reasons:
                    explanations.append("; ".join(reasons))
                else:
                    explanations.append("Unusual spending pattern detected")
        
        return explanations
    
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
            y_test: Test labels (1 = anomaly, 0 = normal)
            verbose: Print evaluation results (default: True)
        
        Returns:
            Dictionary of evaluation metrics
        """
        if not self.is_fitted:
            raise ValueError("Model must be fitted before evaluation")
        
        # Make predictions
        predictions = self.predict(X_test, return_scores=True)
        y_pred = predictions['is_anomaly']
        
        # Calculate metrics
        precision = precision_score(y_test, y_pred, zero_division=0)
        recall = recall_score(y_test, y_pred, zero_division=0)
        f1 = f1_score(y_test, y_pred, zero_division=0)
        
        # Confusion matrix
        conf_matrix = confusion_matrix(y_test, y_pred)
        
        # Anomaly rate
        anomaly_rate = y_pred.mean()
        true_anomaly_rate = y_test.mean()
        
        metrics = {
            'test_precision': precision,
            'test_recall': recall,
            'test_f1': f1,
            'predicted_anomaly_rate': anomaly_rate,
            'true_anomaly_rate': true_anomaly_rate,
            'confusion_matrix': conf_matrix.tolist()
        }
        
        if verbose:
            print("Test Set Evaluation:")
            print(f"  Precision: {precision:.4f}")
            print(f"  Recall:    {recall:.4f}")
            print(f"  F1 Score:  {f1:.4f}")
            print(f"  Predicted Anomaly Rate: {anomaly_rate*100:.2f}%")
            print(f"  True Anomaly Rate:      {true_anomaly_rate*100:.2f}%")
            
            print("\n  Confusion Matrix:")
            print(f"    [[TN={conf_matrix[0,0]:4d}, FP={conf_matrix[0,1]:4d}]")
            print(f"     [FN={conf_matrix[1,0]:4d}, TP={conf_matrix[1,1]:4d}]]")
        
        return metrics
    
    def save(self, output_dir: str, model_name: str = 'anomaly_detector') -> None:
        """
        Save the trained model to disk.
        
        Args:
            output_dir: Directory to save model files
            model_name: Base name for model files (default: 'anomaly_detector')
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
            'contamination': self.contamination,
            'n_estimators': self.n_estimators,
            'max_samples': self.max_samples,
            'feature_names': self.feature_names,
            'category_stats': self.category_stats,
            'training_metrics': self.training_metrics
        }
        
        metadata_file = output_path / f'{model_name}_metadata.json'
        with open(metadata_file, 'w') as f:
            json.dump(metadata, f, indent=2)
        
        print(f"\n✓ Model saved to {output_dir}/")
        print(f"  - {model_file.name}")
        print(f"  - {metadata_file.name}")
    
    @classmethod
    def load(cls, model_dir: str, model_name: str = 'anomaly_detector') -> 'AnomalyDetector':
        """
        Load a trained model from disk.
        
        Args:
            model_dir: Directory containing model files
            model_name: Base name of model files (default: 'anomaly_detector')
        
        Returns:
            Loaded AnomalyDetector instance
        """
        model_path = Path(model_dir)
        
        # Load metadata
        metadata_file = model_path / f'{model_name}_metadata.json'
        with open(metadata_file, 'r') as f:
            metadata = json.load(f)
        
        # Create instance
        detector = cls(
            contamination=metadata['contamination'],
            n_estimators=metadata['n_estimators'],
            max_samples=metadata['max_samples']
        )
        
        # Load model
        model_file = model_path / f'{model_name}.pkl'
        with open(model_file, 'rb') as f:
            detector.model = pickle.load(f)
        
        # Restore metadata
        detector.is_fitted = True
        detector.feature_names = metadata['feature_names']
        detector.category_stats = metadata['category_stats']
        detector.training_metrics = metadata['training_metrics']
        
        print(f"✓ Model loaded from {model_dir}/")
        print(f"  Trained at: {metadata['trained_at']}")
        
        return detector


def create_anomaly_labels(df: pd.DataFrame, threshold_std: float = 2.0) -> pd.Series:
    """
    Create ground truth anomaly labels based on statistical threshold.
    
    An expense is labeled as an anomaly if it exceeds threshold_std standard
    deviations from the category mean.
    
    Args:
        df: DataFrame with expense data
        threshold_std: Number of standard deviations for anomaly threshold (default: 2.0)
    
    Returns:
        Series of binary labels (1 = anomaly, 0 = normal)
    """
    df = df.copy()
    labels = pd.Series(0, index=df.index)
    
    # Calculate z-scores for each category
    for category in df['category'].unique():
        mask = df['category'] == category
        category_amounts = df.loc[mask, 'amount']
        
        # Calculate mean and std
        mean = category_amounts.mean()
        std = category_amounts.std()
        
        # Calculate z-scores
        z_scores = np.abs((category_amounts - mean) / (std + 1e-6))
        
        # Mark as anomaly if exceeds threshold
        anomalies = z_scores > threshold_std
        labels.loc[mask] = anomalies.astype(int)
    
    return labels


def train_anomaly_detector(
    train_data_path: str,
    val_data_path: str,
    test_data_path: str,
    output_dir: str,
    model_name: str = 'anomaly_detector',
    contamination: float = 0.05
) -> AnomalyDetector:
    """
    Complete training pipeline for anomaly detector.
    
    Args:
        train_data_path: Path to training data CSV
        val_data_path: Path to validation data CSV
        test_data_path: Path to test data CSV
        output_dir: Directory to save trained model
        model_name: Name for the model (default: 'anomaly_detector')
        contamination: Expected proportion of anomalies (default: 0.05)
    
    Returns:
        Trained AnomalyDetector instance
    """
    print("=" * 70)
    print("ANOMALY DETECTOR TRAINING PIPELINE")
    print("=" * 70)
    
    # Load data
    print("\n1. Loading data...")
    train_df = pd.read_csv(train_data_path)
    val_df = pd.read_csv(val_data_path)
    test_df = pd.read_csv(test_data_path)
    
    print(f"   Train: {len(train_df):,} records")
    print(f"   Val:   {len(val_df):,} records")
    print(f"   Test:  {len(test_df):,} records")
    
    # Initialize detector
    detector = AnomalyDetector(
        contamination=contamination,
        n_estimators=100,
        max_samples=256,
        random_state=42
    )
    
    # Feature engineering
    print("\n2. Engineering anomaly detection features...")
    X_train = detector._engineer_anomaly_features(train_df)
    X_val = detector._engineer_anomaly_features(val_df)
    X_test = detector._engineer_anomaly_features(test_df)
    
    print(f"   Feature shape: {X_train.shape}")
    
    # Create ground truth labels (expenses > 2 std dev from category mean)
    print("\n3. Creating ground truth anomaly labels...")
    y_train = create_anomaly_labels(train_df, threshold_std=2.0)
    y_val = create_anomaly_labels(val_df, threshold_std=2.0)
    y_test = create_anomaly_labels(test_df, threshold_std=2.0)
    
    print(f"   Train anomalies: {y_train.sum():,} ({y_train.mean()*100:.2f}%)")
    print(f"   Val anomalies:   {y_val.sum():,} ({y_val.mean()*100:.2f}%)")
    print(f"   Test anomalies:  {y_test.sum():,} ({y_test.mean()*100:.2f}%)")
    
    # Calculate category statistics
    print("\n4. Calculating category statistics...")
    detector.category_stats = detector._calculate_category_statistics(train_df)
    print(f"   Categories: {len(detector.category_stats)}")
    
    # Train model
    print("\n5. Training model...")
    detector.fit(X_train, y_train, verbose=True)
    
    # Evaluate on validation set
    print("\n6. Evaluating on validation set...")
    val_metrics = detector.evaluate(X_val, y_val, verbose=True)
    
    # Evaluate on test set
    print("\n7. Evaluating on test set...")
    test_metrics = detector.evaluate(X_test, y_test, verbose=True)
    
    # Show example anomalies
    print("\n8. Example Anomalies Detected:")
    test_predictions = detector.predict(X_test, return_scores=True)
    anomaly_indices = test_predictions[test_predictions['is_anomaly'] == 1].head(5).index
    
    for idx in anomaly_indices:
        row = test_df.iloc[idx]
        pred_row = test_predictions.iloc[idx]
        print(f"   - {row['category']:12s} ${row['amount']:8.2f} | {pred_row['reason']}")
    
    # Save model
    print("\n9. Saving model...")
    detector.save(output_dir, model_name)
    
    print("\n" + "=" * 70)
    print("TRAINING COMPLETE!")
    print("=" * 70)
    
    return detector


if __name__ == '__main__':
    """Train the anomaly detector model."""
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
    detector = train_anomaly_detector(
        train_data_path=str(train_file),
        val_data_path=str(val_file),
        test_data_path=str(test_file),
        output_dir=str(output_dir),
        model_name='anomaly_detector',
        contamination=0.05  # Expect 5% anomalies
    )
