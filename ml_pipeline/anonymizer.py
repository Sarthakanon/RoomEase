"""Data anonymization module to protect user privacy."""

import pandas as pd
import hashlib
from typing import List, Optional


class DataAnonymizer:
    """Anonymize sensitive user data while preserving spending patterns."""
    
    def __init__(self, salt: str = "roomease_ml_salt_2025"):
        """
        Initialize anonymizer with a salt for hashing.
        
        Args:
            salt: Salt string for hashing (should be kept secret in production)
        """
        self.salt = salt
    
    def hash_identifier(self, identifier: str) -> str:
        """
        Hash a user identifier (email, UID, etc.) using SHA-256.
        
        Args:
            identifier: The identifier to hash
        
        Returns:
            Hashed identifier as hex string
        """
        if pd.isna(identifier) or identifier == '':
            return 'anonymous'
        
        # Combine with salt and hash
        salted = f"{identifier}{self.salt}"
        hashed = hashlib.sha256(salted.encode()).hexdigest()
        return hashed[:16]  # Use first 16 characters for brevity
    
    def anonymize_dataframe(
        self,
        df: pd.DataFrame,
        user_id_columns: Optional[List[str]] = None,
        pii_columns: Optional[List[str]] = None,
        keep_columns: Optional[List[str]] = None
    ) -> pd.DataFrame:
        """
        Anonymize a dataframe by hashing user IDs and removing PII.
        
        Args:
            df: Input dataframe
            user_id_columns: Columns containing user identifiers to hash
            pii_columns: Columns containing PII to remove completely
            keep_columns: Columns to keep (if None, keeps all except PII)
        
        Returns:
            Anonymized dataframe
        """
        df = df.copy()
        
        # Default columns to anonymize
        if user_id_columns is None:
            user_id_columns = ['user_id', 'firebase_uid', 'account', 'email']
        
        if pii_columns is None:
            pii_columns = ['name', 'email', 'phone', 'address', 'ip_address']
        
        # Hash user identifiers
        for col in user_id_columns:
            if col in df.columns:
                df[f'{col}_hashed'] = df[col].apply(self.hash_identifier)
                df = df.drop(columns=[col])
        
        # Remove PII columns
        for col in pii_columns:
            if col in df.columns:
                df = df.drop(columns=[col])
        
        # If keep_columns specified, only keep those
        if keep_columns is not None:
            available_cols = [col for col in keep_columns if col in df.columns]
            df = df[available_cols]
        
        return df
    
    def anonymize_expenses(self, df: pd.DataFrame) -> pd.DataFrame:
        """
        Anonymize expense data specifically.
        
        Keeps: date_time, category, amount, currency
        Hashes: account
        Removes: tags (may contain personal info)
        """
        df = df.copy()
        
        # Hash account identifiers
        if 'account' in df.columns:
            df['account_hashed'] = df['account'].apply(self.hash_identifier)
            df = df.drop(columns=['account'])
        
        # Remove potentially sensitive tags
        if 'tags' in df.columns:
            df = df.drop(columns=['tags'])
        
        # Keep only necessary columns
        keep_cols = ['date_time', 'category', 'amount', 'currency']
        if 'account_hashed' in df.columns:
            keep_cols.append('account_hashed')
        
        available_cols = [col for col in keep_cols if col in df.columns]
        df = df[available_cols]
        
        return df
    
    def verify_anonymization(self, df: pd.DataFrame) -> dict:
        """
        Verify that dataframe is properly anonymized.
        
        Returns:
            Dictionary with verification results
        """
        results = {
            'is_anonymized': True,
            'issues': [],
            'warnings': []
        }
        
        # Check for common PII column names
        pii_indicators = [
            'email', 'phone', 'name', 'address', 'ssn', 'firebase_uid',
            'user_id', 'ip_address', 'credit_card', 'account_number'
        ]
        
        for col in df.columns:
            col_lower = col.lower()
            for indicator in pii_indicators:
                if indicator in col_lower and 'hashed' not in col_lower:
                    results['is_anonymized'] = False
                    results['issues'].append(f"Column '{col}' may contain PII")
        
        # Check for email patterns in string columns
        for col in df.select_dtypes(include=['object']).columns:
            sample = df[col].dropna().head(100)
            if sample.str.contains('@', na=False).any():
                results['warnings'].append(f"Column '{col}' contains '@' symbol - may be emails")
        
        # Check for phone number patterns
        for col in df.select_dtypes(include=['object']).columns:
            sample = df[col].dropna().head(100)
            if sample.str.contains(r'\d{10}', na=False, regex=True).any():
                results['warnings'].append(f"Column '{col}' contains 10-digit numbers - may be phone numbers")
        
        return results


def anonymize_training_data(
    input_path: str,
    output_path: str,
    anonymizer: Optional[DataAnonymizer] = None
) -> pd.DataFrame:
    """
    Load, anonymize, and save training data.
    
    Args:
        input_path: Path to input CSV
        output_path: Path to save anonymized CSV
        anonymizer: DataAnonymizer instance (creates new if None)
    
    Returns:
        Anonymized dataframe
    """
    if anonymizer is None:
        anonymizer = DataAnonymizer()
    
    # Load data
    df = pd.read_csv(input_path)
    print(f"Loaded {len(df)} records from {input_path}")
    
    # Anonymize
    df_anon = anonymizer.anonymize_expenses(df)
    print(f"Anonymized data shape: {df_anon.shape}")
    
    # Verify
    verification = anonymizer.verify_anonymization(df_anon)
    if verification['is_anonymized']:
        print("✓ Data is properly anonymized")
    else:
        print("✗ Anonymization issues found:")
        for issue in verification['issues']:
            print(f"  - {issue}")
    
    if verification['warnings']:
        print("⚠ Warnings:")
        for warning in verification['warnings']:
            print(f"  - {warning}")
    
    # Save
    df_anon.to_csv(output_path, index=False)
    print(f"Saved anonymized data to {output_path}")
    
    return df_anon


if __name__ == "__main__":
    # Test anonymization
    from pathlib import Path
    
    data_dir = Path(__file__).parent / "data"
    input_file = data_dir / "raw" / "Expenses_clean.csv"
    output_file = data_dir / "processed" / "Expenses_anonymized.csv"
    
    if input_file.exists():
        print("Testing anonymization...")
        
        # Create output directory
        output_file.parent.mkdir(parents=True, exist_ok=True)
        
        # Anonymize
        df_anon = anonymize_training_data(str(input_file), str(output_file))
        
        print(f"\nAnonymized columns: {list(df_anon.columns)}")
        print(f"\nSample anonymized data:")
        print(df_anon.head())
        
        print("\n✓ Anonymization test successful!")
    else:
        print(f"Data file not found: {input_file}")
