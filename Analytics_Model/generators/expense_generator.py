"""
Generate realistic expense records with temporal patterns
"""

import pandas as pd
import random
import numpy as np
from datetime import datetime, timedelta
from tqdm import tqdm
import sys
from pathlib import Path

# Add project root to path
project_root = Path(__file__).parent.parent
sys.path.insert(0, str(project_root))

from generators.config import (
    EXPENSE_CATEGORIES, SPENDING_PERSONALITIES,
    TEMPORAL_PATTERNS, SEASONAL_PATTERNS,
    GENERATION_CONFIG, ANOMALY_TYPES,
    get_category_weights, get_random_description
)

random.seed(GENERATION_CONFIG['random_seed'])
np.random.seed(GENERATION_CONFIG['random_seed'])


class ExpenseGenerator:
    def __init__(self, users_df):
        self.users_df = users_df
        self.start_date = GENERATION_CONFIG['start_date']
        self.end_date = GENERATION_CONFIG['end_date']
        self.shared_ratio = GENERATION_CONFIG['shared_expense_ratio']
        self.anomaly_rate = GENERATION_CONFIG['anomaly_rate']

    def generate_expenses(self, target_count=5000000):
        """
        Generate realistic expenses for all users

        Args:
            target_count: Target number of total expenses (shared + personal)

        Returns:
            tuple: (shared_expenses_df, personal_expenses_df)
        """
        print(f"\n💰 Generating expenses...") # Removed target_count from print

        # Generate shared expenses
        shared_expenses = self._generate_shared_expenses()

        # Generate personal expenses
        personal_expenses = self._generate_personal_expenses()
        
        print(f"   Total expenses generated: {len(shared_expenses) + len(personal_expenses):,}")

        return shared_expenses, personal_expenses

    def _generate_dates_for_frequency(self, frequency, start_date_gen, end_date_gen, target_events_per_period_multiplier=1.0):
        """
        Generates a chronologically sorted list of dates based on frequency by spacing them out.
        `target_events_per_period_multiplier` adjusts the average number of events per period.
        """
        dates = []
        current_date = start_date_gen
        
        # Determine average interval based on frequency and multiplier
        if frequency == 'daily':
            avg_interval_days = 1 / target_events_per_period_multiplier
        elif frequency == 'weekly':
            avg_interval_days = 7 / target_events_per_period_multiplier
        elif frequency == 'monthly':
            avg_interval_days = 30 / target_events_per_period_multiplier # Approx
        else: # irregular
            avg_interval_days = 90 / target_events_per_period_multiplier # Approx

        # Ensure a minimum interval to avoid too many events
        avg_interval_days = max(1, avg_interval_days)

        while current_date <= end_date_gen:
            dates.append(current_date)
            # Add some randomness to the interval
            interval_with_randomness = avg_interval_days * random.uniform(0.8, 1.2)
            current_date += timedelta(days=interval_with_randomness)
            
            # Prevent infinite loops in case of very small intervals
            if len(dates) > 10000: # Cap to prevent generating too many dates for testing
                break
        
        # Ensure at least one date if the period was valid and no dates were generated
        if not dates and (end_date_gen - start_date_gen).days > 0:
            dates.append(start_date_gen + timedelta(days=random.randint(0, (end_date_gen - start_date_gen).days)))

        return sorted(dates)


    def _generate_shared_expenses(self): # Removed 'count' parameter
        """Generate shared roomspace expenses"""
        print(f"\n🏠 Generating shared expenses...")

        all_shared_expenses = []
        expense_id_counter = 0

        # Get users with roommates
        users_with_roommates = self.users_df[
            self.users_df['roommate_count'] > 0
        ].copy()

        if len(users_with_roommates) == 0:
            print("   ⚠️  No users with roommates found!")
            return pd.DataFrame()
        
        # Group by roomspace
        roomspaces = users_with_roommates.groupby('roomspace_id')

        for roomspace_id, roomspace_users in tqdm(
                roomspaces,
                desc="Generating shared expenses for roomspaces"
        ):
            payer_uids = roomspace_users['user_uid'].tolist()

            for category, config in EXPENSE_CATEGORIES['shared'].items():
                frequency = config.get('frequency', 'monthly')
                
                # Assume a 'moderate' personality for roomspace-level shared expenses for multiplier
                target_events_per_period_multiplier = SPENDING_PERSONALITIES['moderate'].get('frequency_multiplier', 1.0) * config.get('frequency_multiplier', 1.0)
                target_events_per_period_multiplier *= random.uniform(0.8, 1.2) # Add some random variation

                dates_for_category = self._generate_dates_for_frequency(
                    frequency,
                    self.start_date,
                    self.end_date,
                    target_events_per_period_multiplier=target_events_per_period_multiplier
                )

                for date in dates_for_category:
                    payer = users_with_roommates[users_with_roommates['user_uid'] == random.choice(payer_uids)].iloc[0]

                    expense = self._create_single_expense_record(
                        expense_id_counter,
                        'shared',
                        category,
                        config,
                        payer,
                        date,
                        roomspace_id=roomspace_id
                    )
                    all_shared_expenses.append(expense)
                    expense_id_counter += 1
        
        df = pd.DataFrame(all_shared_expenses)
        return df

    def _generate_personal_expenses(self): # Removed 'count' parameter
        """Generate personal expenses"""
        print(f"\n👤 Generating personal expenses...")

        all_personal_expenses = []
        expense_id_counter = 0

        for _, user in tqdm(
                self.users_df.iterrows(),
                total=len(self.users_df),
                desc="Generating personal expenses for users"
        ):
            spending_personality_config = SPENDING_PERSONALITIES[user['spending_personality']]
            freq_multiplier_user = spending_personality_config.get('frequency_multiplier', 1.0)

            for category, config in EXPENSE_CATEGORIES['personal'].items():
                frequency = config.get('frequency', 'irregular')

                target_events_per_period_multiplier = freq_multiplier_user * config.get('frequency_multiplier', 1.0)
                target_events_per_period_multiplier *= random.uniform(0.8, 1.2) # Add some random variation

                dates_for_category = self._generate_dates_for_frequency(
                    frequency,
                    self.start_date,
                    self.end_date,
                    target_events_per_period_multiplier=target_events_per_period_multiplier
                )

                for date in dates_for_category:
                    expense = self._create_single_expense_record(
                        expense_id_counter,
                        'personal',
                        category,
                        config,
                        user,
                        date,
                        user_uid=user['user_uid']
                    )
                    all_personal_expenses.append(expense)
                    expense_id_counter += 1

        df = pd.DataFrame(all_personal_expenses)
        return df


    def _create_single_expense_record(self, expense_id, expense_type, category, category_config, user, date, roomspace_id=None, user_uid=None):
        """Helper to create a single expense dictionary based on type."""
        
        # Generate amount
        amount = self._generate_amount(
            category_config['amount_range'],
            category_config['variation'],
            user['spending_personality'],
            date
        )

        # Apply seasonal patterns
        amount = self._apply_seasonal_multiplier(amount, category, date)

        # Apply temporal patterns (time of day for certain categories)
        if 'peak_hours' in category_config:
            date = self._add_time_to_date(date, category_config['peak_hours'])

        # Apply temporal patterns (weekend, payday, etc.)
        amount = self._apply_temporal_multiplier(amount, category, date)

        # Generate description
        description = get_random_description(category)

        # Check if anomaly
        is_anomaly = random.random() < self.anomaly_rate
        if is_anomaly:
            amount, description = self._make_anomaly(amount, description, category)

        record = {
            'id': f'{expense_type[0]}exp_{expense_id:08d}',
            'title': category,
            'description': description,
            'amount': round(amount, 2),
            'category': category,
            'created_at': date,
            'updated_at': date,
            'deleted_at': None,
            'is_anomaly': is_anomaly
        }

        if expense_type == 'shared':
            # Select split type
            split_type = random.choices(
                list(category_config['split_type_weights'].keys()),
                weights=list(category_config['split_type_weights'].values())
            )[0]
            record.update({
                'roomspace_id': roomspace_id,
                'paid_by': user['user_uid'],
                'split_type': split_type
            })
        else: # personal
            # Randomly remove description (10% missing)
            if random.random() < GENERATION_CONFIG['missing_description_rate']:
                description = None
            record.update({
                'user_uid': user_uid if user_uid else user['user_uid'],
                'description': description # Corrected: use local description variable
            })
        return record


    def _add_time_to_date(self, date, peak_hours):
        """Add time component to date"""
        if peak_hours:
            hour = random.choice(peak_hours)
            minute = random.randint(0, 59)
            return date.replace(hour=hour, minute=minute, second=0)
        return date

    def _generate_amount(self, amount_range, variation, personality, date):
        """Generate expense amount with variations"""

        # Base amount
        min_amount, max_amount = amount_range
        base_amount = random.uniform(min_amount, max_amount)

        # Apply personality multiplier
        personality_config = SPENDING_PERSONALITIES[personality]
        base_amount *= personality_config['amount_multiplier']

        # Apply random variation
        variation_factor = 1 + random.uniform(-variation, variation)
        amount = base_amount * variation_factor

        # Ensure minimum amount
        return max(amount, min_amount * 0.5)

    def _apply_seasonal_multiplier(self, amount, category, date):
        """Apply seasonal spending patterns"""

        month = date.month

        for season, config in SEASONAL_PATTERNS.items():
            if month in config['months'] and category in config['categories']:
                amount *= config['multiplier']

        return amount

    def _apply_temporal_multiplier(self, amount, category, date):
        """Apply temporal patterns (payday, weekend, etc.)"""

        day_of_month = date.day
        day_of_week = date.weekday()

        # Payday spike
        if day_of_month in TEMPORAL_PATTERNS['payday_spike']['days']:
            if category in TEMPORAL_PATTERNS['payday_spike']['categories']:
                amount *= TEMPORAL_PATTERNS['payday_spike']['multiplier']

        # Weekend effect
        if day_of_week in TEMPORAL_PATTERNS['weekend_effect']['days']:
            if category in TEMPORAL_PATTERNS['weekend_effect']['categories']:
                amount *= TEMPORAL_PATTERNS['weekend_effect']['multiplier']

        # End of month frugality
        if day_of_month in TEMPORAL_PATTERNS['end_of_month_frugality']['days']:
            if category in TEMPORAL_PATTERNS['end_of_month_frugality']['categories']:
                amount *= TEMPORAL_PATTERNS['end_of_month_frugality']['multiplier']

        return amount

    def _make_anomaly(self, amount, description, category):
        """Convert normal expense into anomaly"""

        anomaly_types = list(ANOMALY_TYPES.keys())
        anomaly_weights = [ANOMALY_TYPES[t]['probability'] for t in anomaly_types]
        anomaly_type = random.choices(anomaly_types, weights=anomaly_weights)[0]

        anomaly_config = ANOMALY_TYPES[anomaly_type]

        if anomaly_type == 'high_amount':
            multiplier = random.uniform(*anomaly_config['multiplier_range'])
            amount *= multiplier

        # Add prefix to description
        if description:
            description = anomaly_config['description_prefix'] + description

        return amount, description


def generate_all_expenses(users_df, target_count=5000000):
    """
    Main function to generate all expenses

    Args:
        users_df: DataFrame of users
        target_count: Target total number of expenses

    Returns:
        tuple: (shared_expenses_df, personal_expenses_df)
    """
    generator = ExpenseGenerator(users_df)
    # The target_count parameter is now an estimate and not strictly enforced
    # due to the frequency-based generation logic.
    return generator.generate_expenses(target_count=0) # Pass 0 or None as target_count is not used for exact count anymore


if __name__ == "__main__":
    # Test with sample data
    from generators.user_generator import generate_users

    print("=" * 60)
    print("TESTING EXPENSE GENERATION")
    print("=" * 60)

    # Generate 100 users
    users_df = generate_users(100)

    # Generate 10,000 expenses (test)
    shared_df, personal_df = generate_all_expenses(users_df, target_count=10000)

    print("\n" + "=" * 60)
    print("SHARED EXPENSES SAMPLE:")
    print("=" * 60)
    print(shared_df.head(10))
    print(f"\nTotal shared: {len(shared_df):,}")
    print(f"Categories: {shared_df['category'].value_counts()}")

    print("\n" + "=" * 60)
    print("PERSONAL EXPENSES SAMPLE:")
    print("=" * 60)
    print(personal_df.head(10))
    print(f"\nTotal personal: {len(personal_df):,}")
    print(f"Categories: {personal_df['category'].value_counts()}")

    print("\n" + "=" * 60)
    print("ANOMALY DETECTION:")
    print("=" * 60)
    total_anomalies = (
            shared_df['is_anomaly'].sum() +
            personal_df['is_anomaly'].sum()
    )
    print(f"Total anomalies: {total_anomalies:,} ({total_anomalies / (len(shared_df) + len(personal_df)) * 100:.2f}%)")