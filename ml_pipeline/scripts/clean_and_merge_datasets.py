#!/usr/bin/env python3
"""
Clean and merge multiple expense datasets into a unified format
"""
import pandas as pd
import numpy as np
from pathlib import Path
from datetime import datetime
import re

# Standard category mapping
CATEGORY_MAPPING = {
    # Food & Dining
    'food': 'Food', 'grocery': 'Food', 'groceries': 'Food', 'restaurant': 'Food',
    'dining': 'Food', 'cafe': 'Food', 'coffee': 'Food', 'lunch': 'Food',
    'dinner': 'Food', 'breakfast': 'Food', 'fast food': 'Food',
    
    # Transport
    'transport': 'Transport', 'transportation': 'Transport', 'travel': 'Transport',
    'gas': 'Transport', 'fuel': 'Transport', 'uber': 'Transport', 'taxi': 'Transport',
    'bus': 'Transport', 'train': 'Transport', 'car': 'Transport', 'parking': 'Transport',
    'vehicle': 'Transport', 'auto': 'Transport',
    
    # Rent & Housing
    'rent': 'Rent', 'housing': 'Rent', 'mortgage': 'Rent', 'home': 'Rent',
    
    # Healthcare
    'health': 'Healthcare', 'healthcare': 'Healthcare', 'medical': 'Healthcare',
    'doctor': 'Healthcare', 'hospital': 'Healthcare', 'pharmacy': 'Healthcare',
    'medicine': 'Healthcare', 'dental': 'Healthcare',
    
    # Personal Care
    'personal': 'Personal Care', 'personal care': 'Personal Care', 'beauty': 'Personal Care',
    'salon': 'Personal Care', 'haircut': 'Personal Care', 'cosmetics': 'Personal Care',
    'hygiene': 'Personal Care',
    
    # Shopping
    'shopping': 'Shopping', 'retail': 'Shopping', 'clothes': 'Shopping',
    'clothing': 'Shopping', 'fashion': 'Shopping', 'electronics': 'Shopping',
    'furniture': 'Shopping', 'appliances': 'Shopping',
    
    # Entertainment
    'entertainment': 'Entertainment', 'fun': 'Entertainment', 'movie': 'Entertainment',
    'movies': 'Entertainment', 'cinema': 'Entertainment', 'games': 'Entertainment',
    'gaming': 'Entertainment', 'sports': 'Entertainment', 'hobby': 'Entertainment',
    'recreation': 'Entertainment', 'leisure': 'Entertainment',
    
    # Education
    'education': 'Education', 'school': 'Education', 'tuition': 'Education',
    'books': 'Education', 'course': 'Education', 'training': 'Education',
    'learning': 'Education',
    
    # Utilities
    'utilities': 'Utilities', 'utility': 'Utilities', 'electricity': 'Utilities',
    'water': 'Utilities', 'internet': 'Utilities', 'phone': 'Utilities',
    'mobile': 'Utilities', 'cable': 'Utilities', 'subscription': 'Utilities',
    
    # Other
    'other': 'Other', 'misc': 'Other', 'miscellaneous': 'Other', 'general': 'Other',
}

def detect_columns(df):
    """Detect which columns contain date, amount, category, description"""
    columns = df.columns.str.lower()
    
    detected = {
        'date': None,
        'amount': None,
        'category': None,
        'description': None,
        'user_id': None
    }
    
    # Detect date column
    date_keywords = ['date', 'time', 'timestamp', 'day', 'when']
    for col in df.columns:
        if any(kw in col.lower() for kw in date_keywords):
            detected['date'] = col
            break
    
    # Detect amount column
    amount_keywords = ['amount', 'price', 'cost', 'value', 'total', 'spend', 'sum']
    for col in df.columns:
        if any(kw in col.lower() for kw in amount_keywords):
            detected['amount'] = col
            break
    
    # Detect category column
    category_keywords = ['category', 'type', 'class', 'group', 'tag']
    for col in df.columns:
        if any(kw in col.lower() for kw in category_keywords):
            detected['category'] = col
            break
    
    # Detect description column
    desc_keywords = ['description', 'merchant', 'vendor', 'name', 'detail', 'memo', 'note']
    for col in df.columns:
        if any(kw in col.lower() for kw in desc_keywords):
            detected['description'] = col
            break
    
    # Detect user/account ID
    user_keywords = ['user', 'account', 'customer', 'member', 'id']
    for col in df.columns:
        if any(kw in col.lower() for kw in user_keywords) and 'id' in col.lower():
            detected['user_id'] = col
            break
    
    return detected

def standardize_category(category):
    """Map category to standard format"""
    if pd.isna(category):
        return 'Other'
    
    category_lower = str(category).lower().strip()
    
    # Direct mapping
    if category_lower in CATEGORY_MAPPING:
        return CATEGORY_MAPPING[category_lower]
    
    # Partial matching
    for key, value in CATEGORY_MAPPING.items():
        if key in category_lower or category_lower in key:
            return value
    
    return 'Other'

def parse_date(date_str):
    """Try multiple date formats"""
    if pd.isna(date_str):
        return None
    
    # Common date formats
    formats = [
        '%Y-%m-%d', '%Y/%m/%d', '%d-%m-%Y', '%d/%m/%Y',
        '%m-%d-%Y', '%m/%d/%Y', '%Y-%m-%d %H:%M:%S',
        '%d-%b-%Y', '%d %b %Y', '%Y%m%d'
    ]
    
    for fmt in formats:
        try:
            return pd.to_datetime(date_str, format=fmt)
        except:
            continue
    
    # Let pandas try to infer
    try:
        return pd.to_datetime(date_str)
    except:
        return None

def clean_dataset(filepath, dataset_name):
    """Clean a single dataset"""
    print(f"\n{'='*80}")
    print(f"Cleaning: {dataset_name}")
    print('='*80)
    
    try:
        # Read file
        try:
            df = pd.read_csv(filepath)
        except UnicodeDecodeError:
            df = pd.read_csv(filepath, encoding='latin-1')
        
        print(f"📊 Original shape: {df.shape}")
        
        # Detect columns
        detected = detect_columns(df)
        print(f"🔍 Detected columns: {detected}")
        
        # Create standardized DataFrame
        cleaned = pd.DataFrame()
        
        # Date
        if detected['date']:
            cleaned['date'] = df[detected['date']].apply(parse_date)
            cleaned = cleaned.dropna(subset=['date'])
            print(f"✅ Date column: {detected['date']}")
        else:
            print(f"⚠️  No date column found, skipping dataset")
            return None
        
        # Amount
        if detected['amount']:
            # Remove currency symbols and convert to float
            amount_col = df[detected['amount']].astype(str)
            amount_col = amount_col.str.replace('$', '').str.replace(',', '').str.replace('€', '')
            amount_col = amount_col.str.replace('£', '').str.replace('₹', '')
            cleaned['amount'] = pd.to_numeric(amount_col, errors='coerce')
            cleaned = cleaned[cleaned['amount'] > 0]  # Remove negative/zero amounts
            print(f"✅ Amount column: {detected['amount']}")
        else:
            print(f"⚠️  No amount column found, skipping dataset")
            return None
        
        # Category
        if detected['category']:
            cleaned['category'] = df[detected['category']].apply(standardize_category)
            print(f"✅ Category column: {detected['category']}")
        else:
            cleaned['category'] = 'Other'
            print(f"⚠️  No category column, using 'Other'")
        
        # Description
        if detected['description']:
            cleaned['description'] = df[detected['description']].fillna('Unknown')
            print(f"✅ Description column: {detected['description']}")
        else:
            cleaned['description'] = 'Unknown'
        
        # User ID
        if detected['user_id']:
            cleaned['user_id'] = df[detected['user_id']]
        else:
            # Generate unique user IDs based on dataset
            cleaned['user_id'] = f"{dataset_name}_user_" + (df.index // 100).astype(str)
        
        # Add source dataset
        cleaned['source'] = dataset_name
        
        # Remove duplicates
        before_dedup = len(cleaned)
        cleaned = cleaned.drop_duplicates(subset=['date', 'amount', 'category'], keep='first')
        after_dedup = len(cleaned)
        print(f"🗑️  Removed {before_dedup - after_dedup} duplicates")
        
        # Remove outliers (amounts > 99th percentile or < 1st percentile)
        q1 = cleaned['amount'].quantile(0.01)
        q99 = cleaned['amount'].quantile(0.99)
        before_outliers = len(cleaned)
        cleaned = cleaned[(cleaned['amount'] >= q1) & (cleaned['amount'] <= q99)]
        after_outliers = len(cleaned)
        print(f"🗑️  Removed {before_outliers - after_outliers} outliers")
        
        print(f"✅ Final shape: {cleaned.shape}")
        print(f"📅 Date range: {cleaned['date'].min()} to {cleaned['date'].max()}")
        print(f"💰 Amount range: ${cleaned['amount'].min():.2f} to ${cleaned['amount'].max():.2f}")
        print(f"📊 Categories: {cleaned['category'].nunique()} unique")
        
        return cleaned
        
    except Exception as e:
        print(f"❌ Error: {e}")
        return None

def main():
    """Main cleaning and merging pipeline"""
    print("🧹 Dataset Cleaning and Merging Pipeline")
    print("="*80)
    
    external_dir = Path(__file__).parent.parent / 'data' / 'external'
    output_dir = Path(__file__).parent.parent / 'data' / 'processed'
    output_dir.mkdir(parents=True, exist_ok=True)
    
    # Find all CSV files
    csv_files = list(external_dir.glob('*.csv'))
    
    if not csv_files:
        print(f"\n❌ No CSV files found in {external_dir}")
        print("Please download datasets first!")
        return
    
    print(f"\n✅ Found {len(csv_files)} dataset(s)")
    
    # Clean each dataset
    cleaned_datasets = []
    for csv_file in csv_files:
        dataset_name = csv_file.stem
        cleaned = clean_dataset(csv_file, dataset_name)
        if cleaned is not None:
            cleaned_datasets.append(cleaned)
    
    if not cleaned_datasets:
        print(f"\n❌ No datasets could be cleaned successfully")
        return
    
    # Merge all datasets
    print(f"\n{'='*80}")
    print("🔗 Merging Datasets")
    print('='*80)
    
    merged = pd.concat(cleaned_datasets, ignore_index=True)
    print(f"📊 Total records: {len(merged):,}")
    
    # Sort by date
    merged = merged.sort_values('date').reset_index(drop=True)
    
    # Final statistics
    print(f"\n📈 Final Dataset Statistics:")
    print(f"  Total records: {len(merged):,}")
    print(f"  Date range: {merged['date'].min()} to {merged['date'].max()}")
    print(f"  Unique users: {merged['user_id'].nunique():,}")
    print(f"  Amount range: ${merged['amount'].min():.2f} to ${merged['amount'].max():.2f}")
    print(f"  Average amount: ${merged['amount'].mean():.2f}")
    print(f"  Median amount: ${merged['amount'].median():.2f}")
    print(f"\n📊 Category Distribution:")
    print(merged['category'].value_counts())
    
    # Save merged dataset
    output_file = output_dir / 'merged_expenses.csv'
    merged.to_csv(output_file, index=False)
    print(f"\n✅ Saved merged dataset to: {output_file}")
    print(f"📦 File size: {output_file.stat().st_size / 1024 / 1024:.2f} MB")
    
    print(f"\n✨ Next step: Run verify_data_quality.py")

if __name__ == '__main__':
    main()
