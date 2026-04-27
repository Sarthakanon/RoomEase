"""
Main orchestrator to generate complete dataset
"""

import pandas as pd
import time
import sys
from pathlib import Path

# Add project root to path
project_root = Path(__file__).parent.parent
sys.path.insert(0, str(project_root))

from generators.user_generator import generate_users
from generators.expense_generator import generate_all_expenses
from generators.split_generator import generate_all_splits


def generate_complete_dataset(
        num_users=10000,
        num_expenses=5000000,
        save_to_csv=True
):
    """
    Generate complete dataset with users, expenses, and splits

    Args:
        num_users: Number of users to generate
        num_expenses: Target number of total expenses
        save_to_csv: Whether to save to CSV files

    Returns:
        dict: Dictionary containing all dataframes
    """

    print("\n" + "=" * 60)
    print("🚀 ROOMEASE ML DATASET GENERATOR")
    print("=" * 60)
    print(f"Configuration:")
    print(f"  - Users: {num_users:,}")
    print(f"  - Target Expenses: {num_expenses:,}")
    print(f"  - Timespan: Jan 2023 - Dec 2023")
    print("=" * 60)

    start_time = time.time()

    # Step 1: Generate users
    users_df = generate_users(num_users)

    # Step 2: Generate expenses
    shared_expenses_df, personal_expenses_df = generate_all_expenses(
        users_df,
        target_count=num_expenses
    )

    # Step 3: Generate splits
    splits_df = generate_all_splits(users_df, shared_expenses_df)

    # Calculate totals
    total_expenses = len(shared_expenses_df) + len(personal_expenses_df)

    elapsed_time = time.time() - start_time

    print("\n" + "=" * 60)
    print("✅ GENERATION COMPLETE!")
    print("=" * 60)
    print(f"📊 Summary:")
    print(f"  - Users: {len(users_df):,}")
    print(f"  - Shared Expenses: {len(shared_expenses_df):,}")
    print(f"  - Personal Expenses: {len(personal_expenses_df):,}")
    print(f"  - Total Expenses: {total_expenses:,}")
    print(f"  - Expense Splits: {len(splits_df):,}")
    print(f"  - Time Taken: {elapsed_time / 60:.1f} minutes")
    print(f"  - Speed: {total_expenses / (elapsed_time / 60):.0f} expenses/minute")
    print("=" * 60)

    # Save to CSV
    if save_to_csv:
        print("\n💾 Saving to CSV files...")

        data_dir = Path('data/raw')
        data_dir.mkdir(parents=True, exist_ok=True)

        users_df.to_csv(data_dir / 'users.csv', index=False)
        shared_expenses_df.to_csv(data_dir / 'expenses.csv', index=False)
        personal_expenses_df.to_csv(data_dir / 'personal_expenses.csv', index=False)
        splits_df.to_csv(data_dir / 'expense_splits.csv', index=False)

        print(f"✅ Saved to {data_dir}/")
        print(f"  - users.csv ({len(users_df):,} rows)")
        print(f"  - expenses.csv ({len(shared_expenses_df):,} rows)")
        print(f"  - personal_expenses.csv ({len(personal_expenses_df):,} rows)")
        print(f"  - expense_splits.csv ({len(splits_df):,} rows)")

    return {
        'users': users_df,
        'shared_expenses': shared_expenses_df,
        'personal_expenses': personal_expenses_df,
        'splits': splits_df
    }


if __name__ == "__main__":
    # Generate full dataset
    dataset = generate_complete_dataset(
            num_users=1000,
            num_expenses=500000,
            save_to_csv=True
        )
    print("\n🎉 Dataset ready for ML training!")
    print("📁 Files saved in: data/raw/")