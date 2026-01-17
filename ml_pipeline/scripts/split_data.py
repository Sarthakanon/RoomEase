"""Script to split synthetic data into train/val/test sets."""

import argparse
from pathlib import Path
import sys

# Add parent directory to path to import modules
sys.path.insert(0, str(Path(__file__).parent.parent))

from data_splitting import split_temporal_data, save_splits
import pandas as pd


def main():
    """Split synthetic data into train/val/test sets."""
    parser = argparse.ArgumentParser(
        description='Split expense data into train/val/test sets'
    )
    parser.add_argument(
        '--input',
        type=str,
        required=True,
        help='Input CSV file path'
    )
    parser.add_argument(
        '--output-dir',
        type=str,
        required=True,
        help='Output directory for split files'
    )
    parser.add_argument(
        '--train-ratio',
        type=float,
        default=0.8,
        help='Training set ratio (default: 0.8)'
    )
    parser.add_argument(
        '--val-ratio',
        type=float,
        default=0.1,
        help='Validation set ratio (default: 0.1)'
    )
    parser.add_argument(
        '--test-ratio',
        type=float,
        default=0.1,
        help='Test set ratio (default: 0.1)'
    )
    parser.add_argument(
        '--prefix',
        type=str,
        default='expenses',
        help='Prefix for output files (default: expenses)'
    )
    
    args = parser.parse_args()
    
    # Load data
    print(f"Loading data from {args.input}...")
    df = pd.read_csv(args.input)
    print(f"Loaded {len(df):,} records\n")
    
    # Split data
    train_df, val_df, test_df = split_temporal_data(
        df,
        train_ratio=args.train_ratio,
        val_ratio=args.val_ratio,
        test_ratio=args.test_ratio,
        date_column='date_time',
        sort_by_date=True
    )
    
    # Save splits
    save_splits(train_df, val_df, test_df, args.output_dir, args.prefix)
    
    print("\n✓ Data splitting completed successfully!")


if __name__ == '__main__':
    main()
