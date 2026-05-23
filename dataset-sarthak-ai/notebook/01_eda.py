"""
01_eda.py - Exploratory Data Analysis
Analyzes distributions, temporal patterns, user behavior, and group dynamics
across the group expense dataset to inform model design.
"""
import pandas as pd
import numpy as np
import matplotlib
matplotlib.use('Agg')
import matplotlib.pyplot as plt
import seaborn as sns
import os
from pathlib import Path

plt.rcParams['figure.figsize'] = (14, 6)
plt.rcParams['figure.dpi'] = 150
sns.set_style("whitegrid")

OUTPUT_DIR = Path("../output")
NOTEBOOK_DIR = Path("figs")
NOTEBOOK_DIR.mkdir(exist_ok=True)


def load_data():
    print("Loading data...")
    users = pd.read_csv(OUTPUT_DIR / "users.csv")
    groups = pd.read_csv(OUTPUT_DIR / "groups.csv", keep_default_na=False)
    memberships = pd.read_csv(OUTPUT_DIR / "group_memberships.csv", keep_default_na=False)
    expenses = pd.read_csv(OUTPUT_DIR / "expenses.csv", keep_default_na=False)
    splits = pd.read_csv(OUTPUT_DIR / "expense_splits.csv", keep_default_na=False)
    settlements = pd.read_csv(OUTPUT_DIR / "settlements.csv", keep_default_na=False)

    expenses['date'] = pd.to_datetime(expenses['date'])
    expenses['amount'] = expenses['amount'].astype(float)
    expenses['is_group_expense'] = expenses['is_group_expense'].astype(bool)
    expenses['is_recurring'] = expenses['is_recurring'].astype(bool)
    expenses['year'] = expenses['date'].dt.year
    expenses['month'] = expenses['date'].dt.month
    expenses['day_of_week'] = expenses['date'].dt.dayofweek
    expenses['day_of_month'] = expenses['date'].dt.day
    expenses['is_weekend'] = expenses['day_of_week'].isin([5, 6]).astype(int)

    users['join_date'] = pd.to_datetime(users['join_date'])

    print(f"  Users: {len(users):,}")
    print(f"  Expenses: {len(expenses):,}")
    print(f"  Groups: {len(groups):,}")
    print(f"  Splits: {len(splits):,}")
    print(f"  Settlements: {len(settlements):,}")
    return users, groups, memberships, expenses, splits, settlements


def analyze_user_distributions(users):
    print("\n" + "=" * 60)
    print("USER DISTRIBUTIONS")
    print("=" * 60)

    fig, axes = plt.subplots(2, 3, figsize=(18, 10))
    axes = axes.flatten()

    users['persona'].value_counts().plot(kind='bar', ax=axes[0], color='steelblue')
    axes[0].set_title('Persona Distribution')
    axes[0].tick_params(axis='x', rotation=45)

    users['income'].hist(bins=50, ax=axes[1], color='coral')
    axes[1].set_title('Income Distribution')
    axes[1].set_xlabel('Income ($)')

    users['age'].hist(bins=30, ax=axes[2], color='seagreen')
    axes[2].set_title('Age Distribution')

    users['location_tier'].value_counts().plot(kind='bar', ax=axes[3], color='mediumpurple')
    axes[3].set_title('Location Tier')

    users['spending_multiplier'].hist(bins=50, ax=axes[4], color='goldenrod')
    axes[4].set_title('Spending Multiplier Distribution')

    users['join_date'].hist(bins=50, ax=axes[5], color='teal')
    axes[5].set_title('User Join Date Distribution')

    plt.tight_layout()
    plt.savefig(NOTEBOOK_DIR / "01_user_distributions.png", bbox_inches='tight')
    plt.close()

    print(f"  Income: mean=${users['income'].mean():,.0f}, median=${users['income'].median():,.0f}")
    print(f"  Age: mean={users['age'].mean():.1f}, median={users['age'].median():.0f}")
    print(f"  Spending multiplier: mean={users['spending_multiplier'].mean():.2f}, std={users['spending_multiplier'].std():.2f}")


def analyze_expense_patterns(expenses, users):
    print("\n" + "=" * 60)
    print("EXPENSE PATTERNS")
    print("=" * 60)

    fig, axes = plt.subplots(2, 3, figsize=(18, 10))
    axes = axes.flatten()

    cat_counts = expenses['category'].value_counts()
    cat_counts.plot(kind='barh', ax=axes[0], color='steelblue')
    axes[0].set_title('Expense Count by Category')

    cat_totals = expenses.groupby('category')['amount'].sum().sort_values(ascending=False)
    cat_totals.plot(kind='barh', ax=axes[1], color='coral')
    axes[1].set_title('Total Spend by Category')

    expenses['amount'].clip(upper=500).hist(bins=100, ax=axes[2], color='seagreen')
    axes[2].set_title('Amount Distribution (capped at $500)')
    axes[2].set_xlabel('Amount ($)')

    monthly = expenses.groupby(expenses['date'].dt.to_period('M'))['amount'].agg(['sum', 'count'])
    monthly['sum'].plot(ax=axes[3], color='mediumpurple')
    axes[3].set_title('Monthly Total Spend')
    axes[3].set_xlabel('Month')

    monthly['count'].plot(ax=axes[4], color='goldenrod')
    axes[4].set_title('Monthly Transaction Count')
    axes[4].set_xlabel('Month')

    dow_spend = expenses.groupby('day_of_week')['amount'].mean()
    dow_labels = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun']
    dow_spend.index = dow_labels
    dow_spend.plot(kind='bar', ax=axes[5], color='teal')
    axes[5].set_title('Average Spend by Day of Week')

    plt.tight_layout()
    plt.savefig(NOTEBOOK_DIR / "02_expense_patterns.png", bbox_inches='tight')
    plt.close()

    print(f"  Total expenses: {len(expenses):,}")
    print(f"  Total amount: ${expenses['amount'].sum():,.0f}")
    print(f"  Mean expense: ${expenses['amount'].mean():.2f}")
    print(f"  Median expense: ${expenses['amount'].median():.2f}")
    print(f"  Individual: {(~expenses['is_group_expense']).sum():,}, Group: {expenses['is_group_expense'].sum():,}")
    print(f"  Negative amounts: {(expenses['amount'] < 0).sum():,}")


def analyze_temporal_trends(expenses):
    print("\n" + "=" * 60)
    print("TEMPORAL TRENDS")
    print("=" * 60)

    fig, axes = plt.subplots(2, 2, figsize=(16, 10))
    axes = axes.flatten()

    yearly = expenses.groupby('year').agg(
        total_spend=('amount', 'sum'),
        avg_spend=('amount', 'mean'),
        count=('amount', 'count'),
    )
    yearly['total_spend'].plot(ax=axes[0], marker='o', color='steelblue')
    axes[0].set_title('Yearly Total Spend (Inflation Effect)')
    axes[0].set_ylabel('Total ($)')

    yearly['avg_spend'].plot(ax=axes[1], marker='o', color='coral')
    axes[1].set_title('Yearly Average Expense')
    axes[1].set_ylabel('Avg ($)')

    monthly_cat = expenses.groupby(['year', 'month', 'category'])['amount'].sum().reset_index()
    monthly_cat['yearmonth'] = monthly_cat['year'].astype(str) + '-' + monthly_cat['month'].astype(str).str.zfill(2)
    top_cats = expenses['category'].value_counts().head(5).index
    for cat in top_cats:
        cat_data = monthly_cat[monthly_cat['category'] == cat].sort_values('yearmonth')
        cat_data.plot(x='yearmonth', y='amount', ax=axes[2], label=cat)
    axes[2].set_title('Top 5 Categories - Monthly Spend Trend')
    axes[2].get_xaxis().set_ticks([])
    axes[2].set_ylabel('Monthly Spend ($)')

    dom_spend = expenses.groupby('day_of_month')['amount'].mean()
    dom_spend.plot(ax=axes[3], color='teal')
    axes[3].set_title('Average Spend by Day of Month (Payday Effect)')
    axes[3].set_ylabel('Avg ($)')
    axes[3].axvline(x=3, color='red', linestyle='--', alpha=0.5, label='Post-payday')
    axes[3].legend()

    plt.tight_layout()
    plt.savefig(NOTEBOOK_DIR / "03_temporal_trends.png", bbox_inches='tight')
    plt.close()

    print(f"  Year-over-year growth in avg spend:")
    for yr in sorted(expenses['year'].unique()):
        avg = expenses[expenses['year'] == yr]['amount'].mean()
        print(f"    {yr}: ${avg:.2f}")


def analyze_persona_spending(expenses, users):
    print("\n" + "=" * 60)
    print("PERSONA-LEVEL SPENDING")
    print("=" * 60)

    merged = expenses.merge(users[['user_id', 'persona', 'income', 'location_tier', 'age']], on='user_id', how='left')

    fig, axes = plt.subplots(2, 2, figsize=(16, 10))
    axes = axes.flatten()

    persona_spend = merged.groupby('persona').agg(
        avg_per_txn=('amount', 'mean'),
        total=('amount', 'sum'),
        count=('amount', 'count'),
        std=('amount', 'std'),
    ).sort_values('avg_per_txn', ascending=True)

    persona_spend['avg_per_txn'].plot(kind='barh', ax=axes[0], color='steelblue')
    axes[0].set_title('Avg Expense by Persona')

    for i, persona in enumerate(persona_spend.index):
        p_data = merged[merged['persona'] == persona]
        daily = p_data.groupby('date')['amount'].sum()
        axes[1].hist(daily.clip(upper=500), bins=50, alpha=0.5, label=persona)
    axes[1].set_title('Daily Spending Distribution by Persona')
    axes[1].legend(fontsize=8)
    axes[1].set_xlabel('Daily Spend ($)')

    persona_cat = merged.groupby(['persona', 'category'])['amount'].sum().groupby(level=0).apply(
        lambda x: 100 * x / x.sum()
    ).unstack(fill_value=0)
    persona_cat.plot(kind='bar', stacked=True, ax=axes[2], colormap='tab20')
    axes[2].set_title('Category Mix by Persona (%)')
    axes[2].legend(fontsize=6, bbox_to_anchor=(1.05, 1))
    axes[2].tick_params(axis='x', rotation=45)

    loc_spend = merged.groupby('location_tier')['amount'].mean()
    loc_spend.plot(kind='bar', ax=axes[3], color=['coral', 'seagreen', 'mediumpurple'])
    axes[3].set_title('Average Expense by Location Tier')
    axes[3].tick_params(axis='x', rotation=0)

    plt.tight_layout()
    plt.savefig(NOTEBOOK_DIR / "04_persona_spending.png", bbox_inches='tight')
    plt.close()

    print("\n  Persona Summary:")
    print(persona_spend.to_string())


def analyze_group_dynamics(expenses, groups, memberships):
    print("\n" + "=" * 60)
    print("GROUP DYNAMICS")
    print("=" * 60)

    group_expenses = expenses[expenses['is_group_expense']].copy()

    fig, axes = plt.subplots(2, 2, figsize=(16, 10))
    axes = axes.flatten()

    group_type_counts = groups['group_type'].value_counts()
    group_type_counts.plot(kind='bar', ax=axes[0], color='steelblue')
    axes[0].set_title('Group Type Distribution')
    axes[0].tick_params(axis='x', rotation=45)

    if len(group_expenses) > 0:
        group_cat = group_expenses.merge(groups[['group_id', 'group_type']], on='group_id', how='left')
        type_spend = group_cat.groupby('group_type')['amount'].mean().sort_values(ascending=True)
        type_spend.plot(kind='barh', ax=axes[1], color='coral')
        axes[1].set_title('Avg Group Expense by Type')

        type_count = group_cat.groupby('group_type')['amount'].count()
        type_count.plot(kind='bar', ax=axes[2], color='seagreen')
        axes[2].set_title('Group Transaction Count by Type')
        axes[2].tick_params(axis='x', rotation=45)

    members_per_group = memberships.groupby('group_id')['user_id'].count()
    members_per_group.hist(bins=30, ax=axes[3], color='mediumpurple')
    axes[3].set_title('Members Per Group Distribution')
    axes[3].set_xlabel('Number of Members')

    plt.tight_layout()
    plt.savefig(NOTEBOOK_DIR / "05_group_dynamics.png", bbox_inches='tight')
    plt.close()

    print(f"  Group expenses: {len(group_expenses):,} ({len(group_expenses)/len(expenses)*100:.1f}%)")
    print(f"  Individual expenses: {(~expenses['is_group_expense']).sum():,}")
    print(f"  Avg group size: {members_per_group.mean():.1f}")
    print(f"  Group size range: {members_per_group.min()} to {members_per_group.max()}")


def analyze_data_quality(expenses):
    print("\n" + "=" * 60)
    print("DATA QUALITY (for cleaning)")
    print("=" * 60)

    total = len(expenses)
    empty_desc = (expenses['description'] == '').sum()
    vague_words = ['expense', 'purchase', 'payment', 'misc']
    vague_desc = expenses['description'].isin(vague_words).sum()
    negative = (expenses['amount'] < 0).sum()
    outliers = (expenses['amount'] > expenses['amount'].quantile(0.99)).sum()
    recurring = expenses['is_recurring'].sum()

    print(f"  Total records: {total:,}")
    print(f"  Empty descriptions: {empty_desc:,} ({empty_desc/total*100:.1f}%)")
    print(f"  Vague descriptions: {vague_desc:,} ({vague_desc/total*100:.1f}%)")
    print(f"  Negative amounts: {negative:,} ({negative/total*100:.2f}%)")
    print(f"  Outliers (>99th pctl): {outliers:,}")
    print(f"  Recurring: {recurring:,} ({recurring/total*100:.1f}%)")
    print(f"  Group expenses: {expenses['is_group_expense'].sum():,}")

    pct_99 = expenses['amount'].quantile(0.99)
    pct_95 = expenses['amount'].quantile(0.95)
    print(f"\n  Amount Percentiles:")
    for p in [10, 25, 50, 75, 90, 95, 99]:
        print(f"    {p}th: ${expenses['amount'].quantile(p/100):.2f}")


def analyze_spending_hour(expenses):
    expenses['hour'] = pd.to_datetime(expenses['created_at'], errors='coerce').dt.hour

    fig, axes = plt.subplots(1, 2, figsize=(16, 6))

    hourly_count = expenses.groupby('hour')['amount'].count()
    hourly_count.plot(kind='bar', ax=axes[0], color='steelblue')
    axes[0].set_title('Transaction Count by Hour')
    axes[0].set_xlabel('Hour of Day')

    hourly_avg = expenses.groupby('hour')['amount'].mean()
    hourly_avg.plot(kind='bar', ax=axes[1], color='coral')
    axes[1].set_title('Average Amount by Hour')
    axes[1].set_xlabel('Hour of Day')

    plt.tight_layout()
    plt.savefig(NOTEBOOK_DIR / "06_hourly_patterns.png", bbox_inches='tight')
    plt.close()


def main():
    users, groups, memberships, expenses, splits, settlements = load_data()

    analyze_user_distributions(users)
    analyze_expense_patterns(expenses, users)
    analyze_temporal_trends(expenses)
    analyze_persona_spending(expenses, users)
    analyze_group_dynamics(expenses, groups, memberships)
    analyze_data_quality(expenses)
    analyze_spending_hour(expenses)

    print("\n" + "=" * 60)
    print("EDA COMPLETE - Figures saved to notebook/figs/")
    print("=" * 60)


if __name__ == "__main__":
    main()