"""Data splitting utilities for ML training with temporal ordering preservation."""

import pandas as pd
import numpy as np
from typing import Tuple, Optional
from pathlib import Path


def split_temporal_data(
    df: pd.DataFrame,
    train_ratio: float = 0.8,
    val_ratio: float = 0.1,
    test_ratio: float = 0.1,
    date_column: str = 'date_time',
    sort_by_date: bool = True
) -> Tuple[pd.DataFrame, pd.DataFrame, pd.DataFrame]:
    """
    Split time-series data into train/validation/test sets while preserving temporal ordering.
    
    This function ensures no data leakage by splitting based on time:
    - Training data comes from the earliest time period
    - Validation data comes from the middle period
    - Test data comes from the most recent period
    
    Args:
        df: Input DataFrame with time-series data
        train_ratio: Proportion for training set (default: 0.8)
        val_ratio: Proportion for validation set (default: 0.1)
        test_ratio: Proportion for test set (default: 0.1)
        date_column: Name of the datetime column (default: 'date_time')
        sort_by_date: Whether to sort by date before splitting (default: True)
    
    Returns:
        Tuple of (train_df, val_df, test_df)
    
    Raises:
        ValueError: If ratios don't sum to 1.0 or if date_column doesn't exist
    """
    # Validate ratios
    total_ratio = train_ratio + val_ratio + test_ratio
    if not np.isclose(total_ratio, 1.0, atol=0.01):
        raise ValueError(
            f"Ratios must sum to 1.0, got {total_ratio:.3f} "
            f"(train={train_ratio}, val={val_ratio}, test={test_ratio})"
        )
    
    # Validate date column exists
    if date_column not in df.columns:
        raise ValueError(f"Date column '{date_column}' not found in DataFrame")
    
    # Create a copy to avoid modifying original
    df = df.copy()
    
    # Ensure date column is datetime
    if not pd.api.types.is_datetime64_any_dtype(df[date_column]):
        df[date_column] = pd.to_datetime(df[date_column])
    
    # Sort by date if requested (important for temporal ordering)
    if sort_by_date:
        df = df.sort_values(date_column).reset_index(drop=True)
    
    # Calculate split indices
    n = len(df)
    train_end_idx = int(n * train_ratio)
    val_end_idx = int(n * (train_ratio + val_ratio))
    
    # Split data
    train_df = df.iloc[:train_end_idx].copy()
    val_df = df.iloc[train_end_idx:val_end_idx].copy()
    test_df = df.iloc[val_end_idx:].copy()
    
    # Calculate actual ratios (may differ slightly due to rounding)
    actual_train_ratio = len(train_df) / n
    actual_val_ratio = len(val_df) / n
    actual_test_ratio = len(test_df) / n
    
    # Print split information
    print(f"Data split completed:")
    print(f"  Total records: {n:,}")
    print(f"  Train: {len(train_df):,} samples ({actual_train_ratio*100:.1f}%)")
    print(f"  Val:   {len(val_df):,} samples ({actual_val_ratio*100:.1f}%)")
    print(f"  Test:  {len(test_df):,} samples ({actual_test_ratio*100:.1f}%)")
    
    # Print date ranges to verify temporal ordering
    if len(train_df) > 0:
        print(f"\nTemporal ranges:")
        print(f"  Train: {train_df[date_column].min()} to {train_df[date_column].max()}")
    if len(val_df) > 0:
        print(f"  Val:   {val_df[date_column].min()} to {val_df[date_column].max()}")
    if len(test_df) > 0:
        print(f"  Test:  {test_df[date_column].min()} to {test_df[date_column].max()}")
    
    # Verify no temporal overlap (test for data leakage)
    if len(train_df) > 0 and len(val_df) > 0:
        if train_df[date_column].max() > val_df[date_column].min():
            print("\n⚠ WARNING: Temporal overlap detected between train and validation sets!")
    
    if len(val_df) > 0 and len(test_df) > 0:
        if val_df[date_column].max() > test_df[date_column].min():
            print("\n⚠ WARNING: Temporal overlap detected between validation and test sets!")
    
    return train_df, val_df, test_df


def split_by_user(
    df: pd.DataFrame,
    train_ratio: float = 0.8,
    val_ratio: float = 0.1,
    test_ratio: float = 0.1,
    user_column: str = 'user_id',
    date_column: str = 'date_time',
    seed: Optional[int] = 42
) -> Tuple[pd.DataFrame, pd.DataFrame, pd.DataFrame]:
    """
    Split data by users (each user's data goes entirely into one set).
    
    This is useful when you want to test model generalization to new users.
    Within each user's data, temporal ordering is preserved.
    
    Args:
        df: Input DataFrame
        train_ratio: Proportion for training set (default: 0.8)
        val_ratio: Proportion for validation set (default: 0.1)
        test_ratio: Proportion for test set (default: 0.1)
        user_column: Name of the user identifier column (default: 'user_id')
        date_column: Name of the datetime column (default: 'date_time')
        seed: Random seed for user assignment (default: 42)
    
    Returns:
        Tuple of (train_df, val_df, test_df)
    """
    # Validate ratios
    total_ratio = train_ratio + val_ratio + test_ratio
    if not np.isclose(total_ratio, 1.0, atol=0.01):
        raise ValueError(f"Ratios must sum to 1.0, got {total_ratio:.3f}")
    
    # Get unique users
    users = df[user_column].unique()
    n_users = len(users)
    
    # Shuffle users
    rng = np.random.default_rng(seed)
    rng.shuffle(users)
    
    # Split users
    train_end_idx = int(n_users * train_ratio)
    val_end_idx = int(n_users * (train_ratio + val_ratio))
    
    train_users = users[:train_end_idx]
    val_users = users[train_end_idx:val_end_idx]
    test_users = users[val_end_idx:]
    
    # Split data by user assignment
    train_df = df[df[user_column].isin(train_users)].copy()
    val_df = df[df[user_column].isin(val_users)].copy()
    test_df = df[df[user_column].isin(test_users)].copy()
    
    # Sort each set by date
    train_df = train_df.sort_values(date_column).reset_index(drop=True)
    val_df = val_df.sort_values(date_column).reset_index(drop=True)
    test_df = test_df.sort_values(date_column).reset_index(drop=True)
    
    # Print split information
    n = len(df)
    print(f"User-based split completed:")
    print(f"  Total users: {n_users}")
    print(f"  Train: {len(train_users)} users, {len(train_df):,} records ({len(train_df)/n*100:.1f}%)")
    print(f"  Val:   {len(val_users)} users, {len(val_df):,} records ({len(val_df)/n*100:.1f}%)")
    print(f"  Test:  {len(test_users)} users, {len(test_df):,} records ({len(test_df)/n*100:.1f}%)")
    
    return train_df, val_df, test_df


def save_splits(
    train_df: pd.DataFrame,
    val_df: pd.DataFrame,
    test_df: pd.DataFrame,
    output_dir: str,
    prefix: str = 'expenses'
) -> None:
    """
    Save train/val/test splits to separate CSV files.
    
    Args:
        train_df: Training DataFrame
        val_df: Validation DataFrame
        test_df: Test DataFrame
        output_dir: Directory to save files
        prefix: Prefix for filenames (default: 'expenses')
    """
    output_path = Path(output_dir)
    output_path.mkdir(parents=True, exist_ok=True)
    
    train_file = output_path / f'{prefix}_train.csv'
    val_file = output_path / f'{prefix}_val.csv'
    test_file = output_path / f'{prefix}_test.csv'
    
    train_df.to_csv(train_file, index=False)
    val_df.to_csv(val_file, index=False)
    test_df.to_csv(test_file, index=False)
    
    print(f"\n✓ Saved splits to {output_dir}:")
    print(f"  {train_file.name}: {len(train_df):,} records")
    print(f"  {val_file.name}: {len(val_df):,} records")
    print(f"  {test_file.name}: {len(test_df):,} records")


def load_splits(
    input_dir: str,
    prefix: str = 'expenses'
) -> Tuple[pd.DataFrame, pd.DataFrame, pd.DataFrame]:
    """
    Load train/val/test splits from CSV files.
    
    Args:
        input_dir: Directory containing split files
        prefix: Prefix for filenames (default: 'expenses')
    
    Returns:
        Tuple of (train_df, val_df, test_df)
    """
    input_path = Path(input_dir)
    
    train_file = input_path / f'{prefix}_train.csv'
    val_file = input_path / f'{prefix}_val.csv'
    test_file = input_path / f'{prefix}_test.csv'
    
    train_df = pd.read_csv(train_file)
    val_df = pd.read_csv(val_file)
    test_df = pd.read_csv(test_file)
    
    print(f"Loaded splits from {input_dir}:")
    print(f"  Train: {len(train_df):,} records")
    print(f"  Val:   {len(val_df):,} records")
    print(f"  Test:  {len(test_df):,} records")
    
    return train_df, val_df, test_df


if __name__ == '__main__':
    """Test the data splitting utilities."""
    
    # Test with synthetic data
    print("Testing data splitting utilities...\n")
    
    # Create sample data
    dates = pd.date_range('2022-01-01', '2024-12-31', freq='D')
    n_samples = len(dates)
    
    sample_df = pd.DataFrame({
        'date_time': dates,
        'user_id': [f'user_{i % 100:03d}' for i in range(n_samples)],
        'category': np.random.choice(['Food', 'Transport', 'Utilities'], n_samples),
        'amount': np.random.uniform(10, 1000, n_samples),
    })
    
    print(f"Sample data: {len(sample_df)} records")
    print(f"Date range: {sample_df['date_time'].min()} to {sample_df['date_time'].max()}")
    print(f"Unique users: {sample_df['user_id'].nunique()}\n")
    
    # Test temporal split
    print("=" * 60)
    print("Testing temporal split (80/10/10)...")
    print("=" * 60)
    train_df, val_df, test_df = split_temporal_data(
        sample_df,
        train_ratio=0.8,
        val_ratio=0.1,
        test_ratio=0.1
    )
    
    print("\n" + "=" * 60)
    print("Testing user-based split (80/10/10)...")
    print("=" * 60)
    train_df_user, val_df_user, test_df_user = split_by_user(
        sample_df,
        train_ratio=0.8,
        val_ratio=0.1,
        test_ratio=0.1
    )
    
    # Test save/load
    print("\n" + "=" * 60)
    print("Testing save/load functionality...")
    print("=" * 60)
    
    test_dir = Path(__file__).parent / 'data' / 'test_splits'
    save_splits(train_df, val_df, test_df, str(test_dir), prefix='test')
    
    loaded_train, loaded_val, loaded_test = load_splits(str(test_dir), prefix='test')
    
    # Verify loaded data matches
    assert len(loaded_train) == len(train_df), "Train data mismatch after load"
    assert len(loaded_val) == len(val_df), "Val data mismatch after load"
    assert len(loaded_test) == len(test_df), "Test data mismatch after load"
    
    print("\n✓ All data splitting tests passed!")
