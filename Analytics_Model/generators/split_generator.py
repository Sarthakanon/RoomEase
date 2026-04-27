"""
Generate expense splits for shared expenses
"""

import pandas as pd
import random
from tqdm import tqdm
import sys
from pathlib import Path

# Add project root to path
project_root = Path(__file__).parent.parent
sys.path.insert(0, str(project_root))

from generators.config import GENERATION_CONFIG

random.seed(GENERATION_CONFIG['random_seed'])


class SplitGenerator:
    def __init__(self, users_df, shared_expenses_df):
        self.users_df = users_df
        self.shared_expenses_df = shared_expenses_df

    def generate_splits(self):
        """
        Generate splits for all shared expenses

        Returns:
            pd.DataFrame: Expense splits
        """
        print(f"\n✂️  Generating splits for {len(self.shared_expenses_df):,} shared expenses...")

        splits = []
        split_id = 0

        for _, expense in tqdm(
                self.shared_expenses_df.iterrows(),
                total=len(self.shared_expenses_df),
                desc="Creating splits"
        ):
            expense_splits = self._create_splits_for_expense(
                split_id,
                expense
            )
            splits.extend(expense_splits)
            split_id += len(expense_splits)

        df = pd.DataFrame(splits)

        print(f"✅ Generated {len(df):,} expense splits")
        print(f"   Average splits per expense: {len(df) / len(self.shared_expenses_df):.1f}")

        return df

    def _create_splits_for_expense(self, start_id, expense):
        """Create splits for a single expense"""

        # Get roommates in this roomspace
        roomspace_users = self.users_df[
            self.users_df['roomspace_id'] == expense['roomspace_id']
            ]

        if len(roomspace_users) == 0:
            return []

        splits = []
        split_type = expense['split_type']
        total_amount = expense['amount']

        if split_type == 'EQUAL':
            splits = self._create_equal_splits(
                start_id,
                expense['id'],
                roomspace_users,
                total_amount
            )

        elif split_type == 'PERCENTAGE':
            splits = self._create_percentage_splits(
                start_id,
                expense['id'],
                roomspace_users,
                total_amount
            )

        elif split_type == 'EXACT':
            splits = self._create_exact_splits(
                start_id,
                expense['id'],
                roomspace_users,
                total_amount
            )

        return splits

    def _create_equal_splits(self, start_id, expense_id, users, total_amount):
        """Create equal splits among all users"""

        num_users = len(users)
        amount_per_person = total_amount / num_users
        percentage_per_person = 100.0 / num_users

        splits = []

        for idx, (_, user) in enumerate(users.iterrows()):
            # Handle rounding for last person
            if idx == num_users - 1:
                # Last person gets remainder to ensure total matches
                amount = total_amount - sum(s['amount'] for s in splits)
            else:
                amount = amount_per_person

            split = {
                'id': f'split_{start_id + idx:010d}',
                'expense_id': expense_id,
                'user_uid': user['user_uid'],
                'amount': round(amount, 2),
                'percentage': round(percentage_per_person, 2),
                'created_at': None,  # Will be set from expense
                'updated_at': None
            }
            splits.append(split)

        return splits

    def _create_percentage_splits(self, start_id, expense_id, users, total_amount):
        """Create percentage-based splits (unequal)"""

        num_users = len(users)
        splits = []

        # Generate random percentages that sum to 100
        percentages = self._generate_random_percentages(num_users)

        for idx, (_, user) in enumerate(users.iterrows()):
            percentage = percentages[idx]

            # Handle rounding for last person
            if idx == num_users - 1:
                amount = total_amount - sum(s['amount'] for s in splits)
            else:
                amount = (total_amount * percentage) / 100.0

            split = {
                'id': f'split_{start_id + idx:010d}',
                'expense_id': expense_id,
                'user_uid': user['user_uid'],
                'amount': round(amount, 2),
                'percentage': round(percentage, 2),
                'created_at': None,
                'updated_at': None
            }
            splits.append(split)

        return splits

    def _create_exact_splits(self, start_id, expense_id, users, total_amount):
        """Create exact amount splits (custom amounts)"""

        num_users = len(users)
        splits = []

        # Generate random amounts that sum to total
        amounts = self._generate_random_amounts(num_users, total_amount)

        for idx, (_, user) in enumerate(users.iterrows()):
            amount = amounts[idx]
            percentage = (amount / total_amount) * 100.0

            split = {
                'id': f'split_{start_id + idx:010d}',
                'expense_id': expense_id,
                'user_uid': user['user_uid'],
                'amount': round(amount, 2),
                'percentage': round(percentage, 2),
                'created_at': None,
                'updated_at': None
            }
            splits.append(split)

        return splits

    def _generate_random_percentages(self, num_users):
        """Generate random percentages that sum to 100"""

        if num_users == 1:
            return [100.0]

        # Generate random splits
        splits = [random.uniform(10, 50) for _ in range(num_users - 1)]
        splits.append(100 - sum(splits))

        # Ensure all positive
        splits = [max(s, 5) for s in splits]

        # Normalize to 100
        total = sum(splits)
        percentages = [(s / total) * 100 for s in splits]

        return percentages

    def _generate_random_amounts(self, num_users, total_amount):
        """Generate random amounts that sum to total"""

        if num_users == 1:
            return [total_amount]

        # Generate random proportions
        proportions = [random.uniform(0.1, 0.5) for _ in range(num_users - 1)]
        proportions.append(1 - sum(proportions))

        # Ensure all positive
        proportions = [max(p, 0.05) for p in proportions]

        # Normalize
        total_prop = sum(proportions)
        proportions = [p / total_prop for p in proportions]

        # Convert to amounts
        amounts = [total_amount * p for p in proportions]

        # Adjust last amount for rounding
        amounts[-1] = total_amount - sum(amounts[:-1])

        return amounts


def generate_all_splits(users_df, shared_expenses_df):
    """
    Main function to generate all splits

    Args:
        users_df: DataFrame of users
        shared_expenses_df: DataFrame of shared expenses

    Returns:
        pd.DataFrame: Expense splits
    """
    generator = SplitGenerator(users_df, shared_expenses_df)
    return generator.generate_splits()


if __name__ == "__main__":
    # Test
    from generators.user_generator import generate_users
    from generators.expense_generator import generate_all_expenses

    print("=" * 60)
    print("TESTING SPLIT GENERATION")
    print("=" * 60)

    # Generate test data
    users_df = generate_users(100)
    shared_df, personal_df = generate_all_expenses(users_df, target_count=10000)

    # Generate splits
    splits_df = generate_all_splits(users_df, shared_df)

    print("\n" + "=" * 60)
    print("SPLITS SAMPLE:")
    print("=" * 60)
    print(splits_df.head(20))

    print("\n" + "=" * 60)
    print("SPLIT VALIDATION:")
    print("=" * 60)

    # Validate: splits should sum to expense amount
    sample_expense = shared_df.iloc[0]
    sample_splits = splits_df[splits_df['expense_id'] == sample_expense['id']]

    print(f"\nExpense ID: {sample_expense['id']}")
    print(f"Expense Amount: ${sample_expense['amount']:.2f}")
    print(f"Split Type: {sample_expense['split_type']}")
    print(f"\nSplits:")
    print(sample_splits[['user_uid', 'amount', 'percentage']])
    print(f"\nTotal from splits: ${sample_splits['amount'].sum():.2f}")
    print(f"Difference: ${abs(sample_expense['amount'] - sample_splits['amount'].sum()):.2f}")

    if abs(sample_expense['amount'] - sample_splits['amount'].sum()) < 0.01:
        print("✅ Splits sum correctly!")
    else:
        print("❌ Splits don't sum correctly!")