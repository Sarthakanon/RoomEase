"""Data preprocessing and feature engineering for expense analytics."""

import pandas as pd
import numpy as np
from sklearn.preprocessing import LabelEncoder, StandardScaler
from datetime import datetime, timedelta
from typing import Tuple, Dict


class ExpenseFeatureEngineer:
    """Transform raw expense data into ML-ready feature vectors."""
    
    def __init__(self):
        self.category_encoder = LabelEncoder()
        self.amount_scaler = StandardScaler()
        self.is_fitted = False
        self.category_mapping = {}
    
    def fit(self, df: pd.DataFrame) -> 'ExpenseFeatureEngineer':
        """Fit encoders and scalers on training data."""
        # Fit category encoder
        self.category_encoder.fit(df['category'])
        self.category_mapping = dict(enumerate(self.category_encoder.classes_))
        
        # Fit amount scaler
        self.amount_scaler.fit(df[['amount']])
        
        self.is_fitted = True
        return self
    
    def transform(self, df: pd.DataFrame) -> pd.DataFrame:
        """Transform raw expenses into feature vectors."""
        if not self.is_fitted:
            raise ValueError("FeatureEngineer must be fitted before transform")
        
        # Create copy to avoid modifying original
        df = df.copy()
        
        # Parse datetime
        df['date_time'] = pd.to_datetime(df['date_time'])
        df = df.sort_values('date_time').reset_index(drop=True)
        
        features = pd.DataFrame()
        
        # === Time Features ===
        features['day_of_week'] = df['date_time'].dt.dayofweek  # 0=Monday, 6=Sunday
        features['day_of_month'] = df['date_time'].dt.day
        features['month'] = df['date_time'].dt.month
        features['is_weekend'] = features['day_of_week'].isin([5, 6]).astype(int)
        features['is_month_start'] = (features['day_of_month'] <= 5).astype(int)
        features['is_month_end'] = (features['day_of_month'] >= 25).astype(int)
        
        # === Amount Features ===
        features['amount'] = df['amount'].values
        features['amount_normalized'] = self.amount_scaler.transform(df[['amount']]).flatten()
        features['amount_log'] = np.log1p(df['amount'])  # log(1 + amount) to handle zeros
        
        # === Category Features ===
        features['category_encoded'] = self.category_encoder.transform(df['category'])
        
        # === Rolling Statistics (30-day window) ===
        # Group by category for rolling stats
        for category in df['category'].unique():
            mask = df['category'] == category
            category_amounts = df.loc[mask, 'amount']
            
            # Calculate rolling mean and std
            rolling_mean = category_amounts.rolling(window=30, min_periods=1).mean()
            rolling_std = category_amounts.rolling(window=30, min_periods=1).std().fillna(0)
            
            # Assign to features
            features.loc[mask, 'category_avg_30d'] = rolling_mean.values
            features.loc[mask, 'category_std_30d'] = rolling_std.values
        
        # Fill any remaining NaN values
        features['category_avg_30d'] = features['category_avg_30d'].fillna(df['amount'])
        features['category_std_30d'] = features['category_std_30d'].fillna(0)
        
        # === Frequency Features ===
        # Days since last expense
        features['days_since_last'] = df['date_time'].diff().dt.days.fillna(0)
        
        # Expense count in last 30 days (rolling)
        features['expense_count_30d'] = df.groupby('category')['amount'].transform(
            lambda x: x.rolling(window=30, min_periods=1).count()
        )
        
        # === Monthly Aggregates ===
        df['year_month'] = df['date_time'].dt.to_period('M')
        monthly_totals = df.groupby('year_month')['amount'].sum()
        features['total_monthly_spend'] = df['year_month'].map(monthly_totals).values
        
        return features
    
    def fit_transform(self, df: pd.DataFrame) -> pd.DataFrame:
        """Fit and transform in one step."""
        self.fit(df)
        return self.transform(df)


def load_and_preprocess_expenses(
    expenses_path: str,
    train_ratio: float = 0.8,
    val_ratio: float = 0.1,
    test_ratio: float = 0.1
) -> Tuple[pd.DataFrame, pd.DataFrame, pd.DataFrame]:
    """
    Load expense data and split into train/val/test sets.
    
    This function now uses the data_splitting module for consistent splitting.
    
    Args:
        expenses_path: Path to expenses CSV file
        train_ratio: Proportion for training set (default 0.8 = 80%)
        val_ratio: Proportion for validation set (default 0.1 = 10%)
        test_ratio: Proportion for test set (default 0.1 = 10%)
    
    Returns:
        Tuple of (train_df, val_df, test_df)
    """
    from .data_splitting import split_temporal_data
    
    # Load data
    df = pd.read_csv(expenses_path)
    
    # Use the data_splitting utility
    train_df, val_df, test_df = split_temporal_data(
        df,
        train_ratio=train_ratio,
        val_ratio=val_ratio,
        test_ratio=test_ratio,
        date_column='date_time',
        sort_by_date=True
    )
    
    return train_df, val_df, test_df


def normalize_currency(df: pd.DataFrame, target_currency: str = 'USD') -> pd.DataFrame:
    """
    Normalize all amounts to a standard currency.
    
    For now, this is a placeholder. In production, you'd use exchange rate APIs.
    """
    df = df.copy()
    
    # Placeholder conversion rates (BYN to USD as of example)
    conversion_rates = {
        'BYN': 0.31,  # Belarusian Ruble to USD
        'USD': 1.0,
        'EUR': 1.08,
        'INR': 0.012,
        'Rs': 0.012,  # Indian Rupee
    }
    
    # Apply conversion
    df['amount_usd'] = df.apply(
        lambda row: row['amount'] * conversion_rates.get(row['currency'], 1.0),
        axis=1
    )
    
    return df


if __name__ == "__main__":
    # Test the preprocessing pipeline
    from pathlib import Path
    
    data_path = Path(__file__).parent / "data" / "raw" / "Expenses_clean.csv"
    
    if data_path.exists():
        print("Testing preprocessing pipeline...")
        
        # Load and split data
        train_df, val_df, test_df = load_and_preprocess_expenses(str(data_path))
        
        # Initialize feature engineer
        engineer = ExpenseFeatureEngineer()
        
        # Fit on training data
        engineer.fit(train_df)
        
        # Transform all sets
        train_features = engineer.transform(train_df)
        val_features = engineer.transform(val_df)
        test_features = engineer.transform(test_df)
        
        print(f"\nFeature shape: {train_features.shape}")
        print(f"\nFeature columns:")
        for col in train_features.columns:
            print(f"  - {col}")
        
        print(f"\nSample features (first row):")
        print(train_features.iloc[0])
        
        print("\n✓ Preprocessing pipeline test successful!")
    else:
        print(f"Data file not found: {data_path}")
