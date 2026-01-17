"""Explore and analyze the financial transactions dataset."""

import pandas as pd
from pathlib import Path

def explore_dataset(data_path):
    """Explore the dataset structure and contents."""
    data_path = Path(data_path)
    
    print("=" * 80)
    print("FINANCIAL TRANSACTIONS DATASET EXPLORATION")
    print("=" * 80)
    
    # Find CSV files
    csv_files = list(data_path.glob("*.csv"))
    
    if not csv_files:
        print(f"\nNo CSV files found in {data_path}")
        print("Please download the dataset and place it in ml_pipeline/data/raw/")
        return
    
    print(f"\nFound {len(csv_files)} CSV file(s):")
    for f in csv_files:
        print(f"  - {f.name}")
    
    # Load and explore each file
    for csv_file in csv_files:
        print(f"\n{'=' * 80}")
        print(f"FILE: {csv_file.name}")
        print("=" * 80)
        
        try:
            df = pd.read_csv(csv_file)
            
            print(f"\nShape: {df.shape[0]} rows × {df.shape[1]} columns")
            
            print("\nColumns:")
            for col in df.columns:
                print(f"  - {col} ({df[col].dtype})")
            
            print("\nFirst 5 rows:")
            print(df.head())
            
            print("\nData types:")
            print(df.dtypes)
            
            print("\nMissing values:")
            missing = df.isnull().sum()
            if missing.sum() > 0:
                print(missing[missing > 0])
            else:
                print("  No missing values")
            
            print("\nBasic statistics:")
            print(df.describe())
            
            # Check for expense-related columns
            expense_cols = [col for col in df.columns if any(
                keyword in col.lower() 
                for keyword in ['amount', 'expense', 'category', 'date', 'merchant', 'description']
            )]
            
            if expense_cols:
                print(f"\nExpense-related columns found: {expense_cols}")
            
            # Check unique categories if category column exists
            category_cols = [col for col in df.columns if 'category' in col.lower()]
            if category_cols:
                for cat_col in category_cols:
                    print(f"\nUnique values in '{cat_col}':")
                    print(df[cat_col].value_counts())
            
        except Exception as e:
            print(f"Error reading {csv_file.name}: {e}")
    
    print("\n" + "=" * 80)
    print("EXPLORATION COMPLETE")
    print("=" * 80)

if __name__ == "__main__":
    # Default path
    data_dir = Path(__file__).parent.parent / "data" / "raw"
    
    if not data_dir.exists():
        print(f"Creating data directory: {data_dir}")
        data_dir.mkdir(parents=True, exist_ok=True)
        print("\nPlease download the Kaggle dataset and place CSV files in:")
        print(f"  {data_dir.absolute()}")
    else:
        explore_dataset(data_dir)
