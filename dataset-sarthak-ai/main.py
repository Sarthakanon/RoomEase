#!/usr/bin/env python3
"""
Group Expense Dataset Generator

Generates a realistic dataset for 1000 users over 10 years (2016-2025)
simulating group expense tracking behavior with algorithmic user personas,
temporal patterns, and group dynamics.

Usage:
    python main.py [--users N] [--seed S] [--output-dir DIR]

Output files:
    - users.csv, groups.csv, group_memberships.csv
    - expenses.csv, expense_splits.csv
    - settlements.csv, dataset_stats.txt
"""

import argparse
import os
import sys
import time

from config import GenerationConfig
from generators.users import generate_users, users_to_dataframe
from generators.groups import generate_groups_and_memberships, groups_to_dataframe, memberships_to_dataframe
from generators.expenses import generate_all_expenses, generate_recurring_expenses, expenses_to_dataframe, splits_to_dataframe
from generators.settlements import generate_settlements, settlements_to_dataframe


def main():
    parser = argparse.ArgumentParser(description="Generate group expense dataset")
    parser.add_argument("--users", type=int, default=1000, help="Number of users")
    parser.add_argument("--seed", type=int, default=42, help="Random seed")
    parser.add_argument("--output-dir", type=str, default="output", help="Output directory")
    parser.add_argument("--num-groups", type=int, default=350, help="Target number of groups")
    parser.add_argument("--inflation-rate", type=float, default=0.035, help="Annual inflation rate")
    parser.add_argument("--no-recurring", action="store_true", help="Skip recurring expenses")
    parser.add_argument("--no-settlements", action="store_true", help="Skip settlements")
    args = parser.parse_args()

    config = GenerationConfig(
        seed=args.seed,
        num_users=args.users,
        output_dir=args.output_dir,
        num_groups_target=args.num_groups,
        inflation_rate=args.inflation_rate,
    )

    os.makedirs(config.output_dir, exist_ok=True)

    print(f"{'='*60}")
    print(f"  Group Expense Dataset Generator")
    print(f"{'='*60}")
    print(f"  Users:       {config.num_users}")
    print(f"  Groups:      {config.num_groups_target}")
    print(f"  Date range:  {config.start_date} to {config.end_date}")
    print(f"  Inflation:   {config.inflation_rate*100:.1f}%/yr")
    print(f"  Seed:        {config.seed}")
    print(f"  Output:      {config.output_dir}/")
    print(f"{'='*60}\n")

    start_time = time.time()

    print("[1/6] Generating user profiles...")
    t0 = time.time()
    users = generate_users(config)
    df_users = users_to_dataframe(users)
    df_users.to_csv(os.path.join(config.output_dir, "users.csv"), index=False)
    print(f"      {len(users)} users in {time.time()-t0:.1f}s")

    print("[2/6] Generating groups and memberships...")
    t0 = time.time()
    user_ids = [u.user_id for u in users]
    groups, memberships = generate_groups_and_memberships(config, user_ids)
    df_groups = groups_to_dataframe(groups)
    df_memberships = memberships_to_dataframe(memberships)
    df_groups.to_csv(os.path.join(config.output_dir, "groups.csv"), index=False)
    df_memberships.to_csv(os.path.join(config.output_dir, "group_memberships.csv"), index=False)
    print(f"      {len(groups)} groups, {len(memberships)} memberships in {time.time()-t0:.1f}s")

    print("[3/6] Generating expenses (this takes the longest)...")
    t0 = time.time()
    expenses, splits = generate_all_expenses(config, users, groups, memberships)
    print(f"      Base: {len(expenses)} expenses, {len(splits)} splits")

    if not args.no_recurring:
        print("[3b/6] Generating recurring expenses...")
        t1 = time.time()
        recurring = generate_recurring_expenses(config, users)
        expenses.extend(recurring)
        print(f"      {len(recurring)} recurring in {time.time()-t1:.1f}s")

    expenses.sort(key=lambda e: (e.date, e.created_at))
    print(f"      Total: {len(expenses)} expenses in {time.time()-t0:.1f}s")

    print("[3c/6] Writing expenses to CSV...")
    t1 = time.time()
    df_expenses = expenses_to_dataframe(expenses)
    df_expenses.to_csv(os.path.join(config.output_dir, "expenses.csv"), index=False)
    df_splits = splits_to_dataframe(splits)
    df_splits.to_csv(os.path.join(config.output_dir, "expense_splits.csv"), index=False)
    print(f"      Written in {time.time()-t1:.1f}s")

    if not args.no_settlements:
        print("[4/6] Generating settlements...")
        t0 = time.time()
        settlements = generate_settlements(config, groups, expenses, splits)
        df_settlements = settlements_to_dataframe(settlements)
        df_settlements.to_csv(os.path.join(config.output_dir, "settlements.csv"), index=False)
        print(f"      {len(settlements)} settlements in {time.time()-t0:.1f}s")
        del settlements
    else:
        print("[4/6] Skipped settlements")

    del expenses, splits

    print("[5/6] Generating statistics...")
    import pandas as pd
    df_users = pd.read_csv(os.path.join(config.output_dir, "users.csv"))
    df_groups = pd.read_csv(os.path.join(config.output_dir, "groups.csv"))
    df_memberships = pd.read_csv(os.path.join(config.output_dir, "group_memberships.csv"))
    df_expenses = pd.read_csv(os.path.join(config.output_dir, "expenses.csv"), keep_default_na=False)
    df_splits = pd.read_csv(os.path.join(config.output_dir, "expense_splits.csv"), keep_default_na=False)

    stats = generate_stats(df_users, df_groups, df_memberships, df_expenses, df_splits)
    stats_path = os.path.join(config.output_dir, "dataset_stats.txt")
    with open(stats_path, "w") as f:
        f.write(stats)
    print(f"      Stats written to {stats_path}")

    print("[6/6] Generating summary...")
    summary = generate_data_summary(df_expenses, df_users, config)
    summary_path = os.path.join(config.output_dir, "data_summary.csv")
    summary.to_csv(summary_path, index=False)
    print(f"      Summary written to {summary_path}")

    total_time = time.time() - start_time
    print(f"\n{'='*60}")
    print(f"  Generation complete in {total_time:.1f}s ({total_time/60:.1f} min)")
    print(f"{'='*60}")
    for fname in ["users.csv", "groups.csv", "group_memberships.csv",
                  "expenses.csv", "expense_splits.csv", "settlements.csv",
                  "dataset_stats.txt", "data_summary.csv"]:
        fpath = os.path.join(config.output_dir, fname)
        if os.path.exists(fpath):
            size_mb = os.path.getsize(fpath) / (1024 * 1024)
            print(f"  {fname:30s} {size_mb:8.2f} MB")
    print(f"{'='*60}")


def generate_stats(df_users, df_groups, df_memberships, df_expenses, df_splits):
    lines = []
    lines.append("=" * 60)
    lines.append("DATASET STATISTICS")
    lines.append("=" * 60)
    lines.append("")

    lines.append("--- Users ---")
    lines.append(f"Total users: {len(df_users)}")
    for persona, count in df_users['persona'].value_counts().items():
        lines.append(f"  {persona}: {count} ({count/len(df_users)*100:.1f}%)")
    for loc, count in df_users['location_tier'].value_counts().items():
        lines.append(f"  {loc}: {count}")
    lines.append(f"Average income: ${df_users['income'].mean():,.0f}")
    lines.append(f"Average age: {df_users['age'].mean():.1f}")
    lines.append("")

    lines.append("--- Groups ---")
    lines.append(f"Total groups: {len(df_groups)}")
    for gtype, count in df_groups['group_type'].value_counts().items():
        lines.append(f"  {gtype}: {count}")
    lines.append(f"Total memberships: {len(df_memberships)}")
    lines.append("")

    lines.append("--- Expenses ---")
    lines.append(f"Total expenses: {len(df_expenses):,}")
    total_amount = df_expenses['amount'].sum()
    lines.append(f"Total amount: ${total_amount:,.2f}")
    lines.append(f"Average: ${df_expenses['amount'].mean():,.2f}")
    lines.append(f"Median: ${df_expenses['amount'].median():,.2f}")
    lines.append(f"Date range: {df_expenses['date'].min()} to {df_expenses['date'].max()}")

    cat_stats = df_expenses.groupby('category').agg(
        count=('amount', 'count'), total=('amount', 'sum'), avg=('amount', 'mean'),
    )
    lines.append("\n--- By Category ---")
    for cat, row in cat_stats.iterrows():
        lines.append(f"  {cat:20s}: {int(row['count']):6d} | ${row['total']:12,.2f} | avg ${row['avg']:8.2f}")

    lines.append("\n--- Data Quality ---")
    total = len(df_expenses)
    empty = (df_expenses['description'] == '').sum()
    vague = df_expenses['description'].isin(['expense', 'purchase', 'payment', 'misc']).sum()
    neg = (df_expenses['amount'] < 0).sum()
    lines.append(f"Empty descriptions: {empty} ({empty/total*100:.1f}%)")
    lines.append(f"Vague descriptions: {vague} ({vague/total*100:.1f}%)")
    lines.append(f"Negative amounts: {neg} ({neg/total*100:.2f}%)")

    lines.append("\n--- Splits ---")
    lines.append(f"Total: {len(df_splits):,}")
    lines.append(f"Settled: {df_splits['is_settled'].sum():,}")
    lines.append("=" * 60)
    return "\n".join(lines)


def generate_data_summary(df_expenses, df_users, config):
    import pandas as pd
    df_expenses['date'] = pd.to_datetime(df_expenses['date'])
    df_expenses['year_month'] = df_expenses['date'].dt.to_period('M')
    summary = df_expenses.groupby('year_month').agg(
        total_expenses=('amount', 'count'),
        total_amount=('amount', 'sum'),
        avg_amount=('amount', 'mean'),
        unique_users=('user_id', 'nunique'),
    ).reset_index()
    summary['year_month'] = summary['year_month'].astype(str)
    return summary


if __name__ == "__main__":
    main()