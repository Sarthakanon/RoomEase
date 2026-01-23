#!/usr/bin/env python3
"""
Inspect external datasets to understand their structure
"""
import os
import pandas as pd
from pathlib import Path

def inspect_dataset(filepath):
    """Inspect a single dataset file"""
    print(f"\n{'='*80}")
    print(f"Inspecting: {filepath}")
    print('='*80)
    
    try:
        # Try reading with different encodings
        try:
            df = pd.read_csv(filepath)
        except UnicodeDecodeError:
            df = pd.read_csv(filepath, encoding='latin-1')
        
        print(f"\n📊 Shape: {df.shape[0]:,} rows × {df.shape[1]} columns")
        
        print(f"\n📋 Columns:")
        for i, col in enumerate(df.columns, 1):
            print(f"  {i}. {col} ({df[col].dtype})")
        
        print(f"\n🔍 First 3 rows:")
        print(df.head(3).to_string())
        
        print(f"\n📈 Missing values:")
        missing = df.isnull().sum()
        missing_pct = (missing / len(df) * 100).round(2)
        for col in df.columns:
            if missing[col] > 0:
                print(f"  {col}: {missing[col]:,} ({missing_pct[col]}%)")
        
        print(f"\n🎯 Potential key columns:")
        # Look for date columns
        date_cols = [col for col in df.columns if any(word in col.lower() 
                     for word in ['date', 'time', 'timestamp', 'day', 'month', 'year'])]
        if date_cols:
            print(f"  Date columns: {', '.join(date_cols)}")
        
        # Look for amount columns
        amount_cols = [col for col in df.columns if any(word in col.lower() 
                       for word in ['amount', 'price', 'cost', 'value', 'total', 'spend'])]
        if amount_cols:
            print(f"  Amount columns: {', '.join(amount_cols)}")
        
        # Look for category columns
        category_cols = [col for col in df.columns if any(word in col.lower() 
                         for word in ['category', 'type', 'class', 'group'])]
        if category_cols:
            print(f"  Category columns: {', '.join(category_cols)}")
            # Show unique categories
            for col in category_cols:
                unique_vals = df[col].nunique()
                print(f"    {col}: {unique_vals} unique values")
                if unique_vals < 20:
                    print(f"      Values: {df[col].unique().tolist()}")
        
        # Look for description/merchant columns
        desc_cols = [col for col in df.columns if any(word in col.lower() 
                     for word in ['description', 'merchant', 'vendor', 'name', 'detail'])]
        if desc_cols:
            print(f"  Description columns: {', '.join(desc_cols)}")
        
        print(f"\n✅ Dataset looks usable!")
        return True
        
    except Exception as e:
        print(f"\n❌ Error reading file: {e}")
        return False

def main():
    """Inspect all datasets in external folder"""
    external_dir = Path(__file__).parent.parent / 'data' / 'external'
    
    print("🔍 External Dataset Inspector")
    print("="*80)
    
    # Create external directory if it doesn't exist
    external_dir.mkdir(parents=True, exist_ok=True)
    
    # Find all CSV files
    csv_files = list(external_dir.glob('*.csv'))
    
    if not csv_files:
        print(f"\n⚠️  No CSV files found in {external_dir}")
        print("\n📥 Please download datasets and place them in:")
        print(f"   {external_dir}")
        print("\n💡 Recommended sources:")
        print("   - Kaggle: https://www.kaggle.com/datasets?search=expense")
        print("   - UCI: https://archive.ics.uci.edu/")
        print("   - GitHub: Search 'expense tracking dataset'")
        return
    
    print(f"\n✅ Found {len(csv_files)} dataset(s)")
    
    results = {}
    for csv_file in csv_files:
        success = inspect_dataset(csv_file)
        results[csv_file.name] = success
    
    # Summary
    print(f"\n{'='*80}")
    print("📊 SUMMARY")
    print('='*80)
    successful = sum(results.values())
    print(f"✅ Successfully inspected: {successful}/{len(csv_files)} datasets")
    
    if successful > 0:
        print(f"\n✨ Next step: Run clean_and_merge_datasets.py")
    else:
        print(f"\n⚠️  Please check the datasets and fix any issues")

if __name__ == '__main__':
    main()
