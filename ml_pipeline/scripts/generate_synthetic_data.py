"""Generate synthetic expense data for ML model training."""

import pandas as pd
import numpy as np
from datetime import datetime, timedelta
import argparse
from pathlib import Path
from typing import List, Tuple


class SyntheticExpenseGenerator:
    """Generate realistic synthetic expense data with patterns and seasonality."""
    
    # Expense categories with typical spending ranges (min, max, mean, std)
    CATEGORIES = {
        'Food': (50, 2000, 400, 150),
        'Transport': (20, 1500, 300, 100),
        'Utilities': (500, 5000, 1500, 400),
        'Entertainment': (100, 3000, 600, 250),
        'Healthcare': (200, 10000, 1000, 800),
        'Shopping': (100, 5000, 800, 400),
        'Rent': (5000, 50000, 15000, 5000),
        'Education': (500, 20000, 3000, 2000),
        'Personal Care': (100, 2000, 400, 150),
        'Other': (50, 3000, 500, 300),
    }
    
    # Pattern types and their characteristics
    PATTERN_TYPES = {
        'daily': {'frequency_days': 1, 'variance': 0.2},
        'weekly': {'frequency_days': 7, 'variance': 0.3},
        'monthly': {'frequency_days': 30, 'variance': 0.15},
        'irregular': {'frequency_days': None, 'variance': 0.8},
    }
    
    # Category-to-pattern mapping (most common pattern for each category)
    CATEGORY_PATTERNS = {
        'Food': ['daily', 'weekly'],
        'Transport': ['daily', 'weekly'],
        'Utilities': ['monthly'],
        'Entertainment': ['weekly', 'irregular'],
        'Healthcare': ['irregular'],
        'Shopping': ['weekly', 'irregular'],
        'Rent': ['monthly'],
        'Education': ['monthly', 'irregular'],
        'Personal Care': ['weekly', 'monthly'],
        'Other': ['irregular'],
    }
    
    def __init__(self, seed: int = 42):
        """
        Initialize generator with random seed for reproducibility.
        
        Args:
            seed: Random seed
        """
        self.seed = seed
        np.random.seed(seed)
        self.rng = np.random.default_rng(seed)
    
    def generate_user_profile(self, user_id: int) -> dict:
        """
        Generate a user spending profile.
        
        Args:
            user_id: Unique user identifier
        
        Returns:
            Dictionary with user spending characteristics
        """
        # Income level affects spending (low, medium, high)
        income_level = self.rng.choice(['low', 'medium', 'high'], p=[0.3, 0.5, 0.2])
        
        income_multipliers = {
            'low': 0.6,
            'medium': 1.0,
            'high': 1.8,
        }
        
        # Spending habits (frugal, moderate, lavish)
        spending_habit = self.rng.choice(['frugal', 'moderate', 'lavish'], p=[0.25, 0.55, 0.2])
        
        habit_multipliers = {
            'frugal': 0.7,
            'moderate': 1.0,
            'lavish': 1.4,
        }
        
        return {
            'user_id': f'user_{user_id:06d}',
            'income_level': income_level,
            'spending_habit': spending_habit,
            'income_multiplier': income_multipliers[income_level],
            'habit_multiplier': habit_multipliers[spending_habit],
        }
    
    def apply_seasonal_adjustment(
        self,
        amount: float,
        date: datetime,
        category: str
    ) -> float:
        """
        Apply seasonal adjustments to expense amounts.
        
        Args:
            amount: Base amount
            date: Date of expense
            category: Expense category
        
        Returns:
            Adjusted amount
        """
        month = date.month
        
        # Holiday season (November-December): increased spending
        if month in [11, 12]:
            if category in ['Shopping', 'Entertainment', 'Food']:
                amount *= self.rng.uniform(1.2, 1.5)
        
        # Summer (June-August): increased travel and entertainment
        if month in [6, 7, 8]:
            if category in ['Entertainment', 'Transport']:
                amount *= self.rng.uniform(1.1, 1.3)
        
        # Back to school (August-September): increased education spending
        if month in [8, 9]:
            if category == 'Education':
                amount *= self.rng.uniform(1.3, 1.6)
        
        # Winter (January-February): increased utilities
        if month in [1, 2]:
            if category == 'Utilities':
                amount *= self.rng.uniform(1.1, 1.25)
        
        # End of month: rent and utilities
        if date.day >= 25:
            if category in ['Rent', 'Utilities']:
                amount *= self.rng.uniform(0.95, 1.05)
        
        return amount
    
    def generate_recurring_expenses(
        self,
        user_profile: dict,
        start_date: datetime,
        end_date: datetime,
        category: str,
        pattern_type: str
    ) -> List[dict]:
        """
        Generate recurring expenses for a category.
        
        Args:
            user_profile: User spending profile
            start_date: Start date for generation
            end_date: End date for generation
            category: Expense category
            pattern_type: Pattern type (daily, weekly, monthly, irregular)
        
        Returns:
            List of expense records
        """
        expenses = []
        
        # Get category spending parameters
        min_amt, max_amt, mean_amt, std_amt = self.CATEGORIES[category]
        
        # Apply user multipliers
        mean_amt *= user_profile['income_multiplier'] * user_profile['habit_multiplier']
        std_amt *= user_profile['habit_multiplier']
        
        # Get pattern characteristics
        pattern = self.PATTERN_TYPES[pattern_type]
        frequency_days = pattern['frequency_days']
        variance = pattern['variance']
        
        if pattern_type == 'irregular':
            # Irregular expenses: random occurrences
            num_expenses = int(self.rng.integers(1, 10))
            total_days = (end_date - start_date).days
            dates = [
                start_date + timedelta(days=int(self.rng.integers(0, total_days)))
                for _ in range(num_expenses)
            ]
        else:
            # Regular pattern: generate based on frequency
            current_date = start_date
            dates = []
            
            # Add some jitter to start date
            current_date += timedelta(days=int(self.rng.integers(0, frequency_days)))
            
            while current_date <= end_date:
                dates.append(current_date)
                
                # Add jitter to frequency (±20% variance)
                jitter_days = int(frequency_days * self.rng.uniform(-0.2, 0.2))
                current_date += timedelta(days=frequency_days + jitter_days)
        
        # Generate expenses for each date
        for date in sorted(dates):
            # Generate amount with variance
            amount = self.rng.normal(mean_amt, std_amt * variance)
            
            # Ensure amount is within bounds
            amount = np.clip(amount, min_amt, max_amt)
            
            # Apply seasonal adjustments
            amount = self.apply_seasonal_adjustment(amount, date, category)
            
            # Round to 2 decimal places
            amount = round(amount, 2)
            
            expenses.append({
                'user_id': user_profile['user_id'],
                'date_time': date.strftime('%Y-%m-%d %H:%M:%S'),
                'category': category,
                'amount': amount,
                'currency': 'USD',
                'pattern_type': pattern_type,
            })
        
        return expenses
    
    def generate_user_expenses(
        self,
        user_id: int,
        start_date: datetime,
        end_date: datetime,
        num_categories: int = None
    ) -> List[dict]:
        """
        Generate all expenses for a single user.
        
        Args:
            user_id: User identifier
            start_date: Start date for generation
            end_date: End date for generation
            num_categories: Number of categories to generate (None = random)
        
        Returns:
            List of expense records
        """
        user_profile = self.generate_user_profile(user_id)
        all_expenses = []
        
        # Determine which categories this user spends on
        if num_categories is None:
            num_categories = int(self.rng.integers(4, len(self.CATEGORIES) + 1))
        
        selected_categories = self.rng.choice(
            list(self.CATEGORIES.keys()),
            size=min(num_categories, len(self.CATEGORIES)),
            replace=False
        )
        
        # Generate expenses for each category
        for category in selected_categories:
            # Choose pattern type for this category
            possible_patterns = self.CATEGORY_PATTERNS[category]
            pattern_type = self.rng.choice(possible_patterns)
            
            # Generate recurring expenses
            expenses = self.generate_recurring_expenses(
                user_profile,
                start_date,
                end_date,
                category,
                pattern_type
            )
            
            all_expenses.extend(expenses)
        
        return all_expenses
    
    def generate_dataset(
        self,
        num_users: int,
        start_date: datetime,
        end_date: datetime,
        target_records: int = 100000
    ) -> pd.DataFrame:
        """
        Generate complete synthetic dataset.
        
        Args:
            num_users: Number of users to generate
            start_date: Start date for expenses
            end_date: End date for expenses
            target_records: Target number of expense records
        
        Returns:
            DataFrame with synthetic expenses
        """
        print(f"Generating synthetic expense data...")
        print(f"  Users: {num_users}")
        print(f"  Date range: {start_date.date()} to {end_date.date()}")
        print(f"  Target records: {target_records}")
        
        all_expenses = []
        
        for user_id in range(num_users):
            if (user_id + 1) % 100 == 0:
                print(f"  Generated expenses for {user_id + 1}/{num_users} users...")
            
            user_expenses = self.generate_user_expenses(
                user_id,
                start_date,
                end_date
            )
            all_expenses.extend(user_expenses)
            
            # Check if we've reached target
            if len(all_expenses) >= target_records:
                print(f"  Reached target of {target_records} records")
                break
        
        # Convert to DataFrame
        df = pd.DataFrame(all_expenses)
        
        # Sort by date
        df['date_time'] = pd.to_datetime(df['date_time'])
        df = df.sort_values('date_time').reset_index(drop=True)
        
        print(f"\n✓ Generated {len(df)} expense records")
        print(f"\nDataset statistics:")
        print(f"  Date range: {df['date_time'].min()} to {df['date_time'].max()}")
        print(f"  Unique users: {df['user_id'].nunique()}")
        print(f"  Categories: {df['category'].nunique()}")
        print(f"  Total amount: ${df['amount'].sum():,.2f}")
        print(f"  Average expense: ${df['amount'].mean():.2f}")
        print(f"\nCategory distribution:")
        print(df['category'].value_counts())
        print(f"\nPattern distribution:")
        print(df['pattern_type'].value_counts())
        
        return df


def main():
    """Main function to generate synthetic data from command line."""
    parser = argparse.ArgumentParser(
        description='Generate synthetic expense data for ML training'
    )
    parser.add_argument(
        '--output',
        type=str,
        required=True,
        help='Output CSV file path'
    )
    parser.add_argument(
        '--count',
        type=int,
        default=100000,
        help='Target number of expense records (default: 100000)'
    )
    parser.add_argument(
        '--users',
        type=int,
        default=1000,
        help='Number of users to generate (default: 1000)'
    )
    parser.add_argument(
        '--start-date',
        type=str,
        default='2022-01-01',
        help='Start date (YYYY-MM-DD, default: 2022-01-01)'
    )
    parser.add_argument(
        '--end-date',
        type=str,
        default='2024-12-31',
        help='End date (YYYY-MM-DD, default: 2024-12-31)'
    )
    parser.add_argument(
        '--seed',
        type=int,
        default=42,
        help='Random seed for reproducibility (default: 42)'
    )
    
    args = parser.parse_args()
    
    # Parse dates
    start_date = datetime.strptime(args.start_date, '%Y-%m-%d')
    end_date = datetime.strptime(args.end_date, '%Y-%m-%d')
    
    # Create output directory if needed
    output_path = Path(args.output)
    output_path.parent.mkdir(parents=True, exist_ok=True)
    
    # Generate data
    generator = SyntheticExpenseGenerator(seed=args.seed)
    df = generator.generate_dataset(
        num_users=args.users,
        start_date=start_date,
        end_date=end_date,
        target_records=args.count
    )
    
    # Save to CSV
    df.to_csv(args.output, index=False)
    print(f"\n✓ Saved synthetic data to {args.output}")
    
    # Display sample
    print(f"\nSample records:")
    print(df.head(10))


if __name__ == '__main__':
    main()
