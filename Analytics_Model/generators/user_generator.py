"""
Generate realistic user profiles
"""

import pandas as pd
import random
from faker import Faker
from tqdm import tqdm
from datetime import datetime, timedelta
import sys
from pathlib import Path

# Add project root to path
project_root = Path(__file__).parent.parent
sys.path.insert(0, str(project_root))

from generators.config import (
    USER_PERSONAS, SPENDING_PERSONALITIES,
    GENERATION_CONFIG, get_persona_weights
)

fake = Faker()
random.seed(GENERATION_CONFIG['random_seed'])
Faker.seed(GENERATION_CONFIG['random_seed'])


def generate_users(num_users=10000):
    """
    Generate realistic user profiles

    Returns:
        pd.DataFrame: User profiles with personas and attributes
    """
    print(f"\n🧑 Generating {num_users} user profiles...")

    users = []
    personas, weights = get_persona_weights()

    # Calculate join date range (2 years before start_date)
    start_date = GENERATION_CONFIG['start_date']
    earliest_join = start_date - timedelta(days=730)  # 2 years before

    for i in tqdm(range(num_users), desc="Creating users"):
        # Select persona based on weights
        persona = random.choices(personas, weights=weights)[0]
        persona_config = USER_PERSONAS[persona]

        # Generate user attributes
        age = random.randint(*persona_config['age_range'])
        monthly_budget = random.randint(*persona_config['monthly_budget_range'])
        roommate_count = random.randint(*persona_config['roommate_count_range'])

        # Select spending personality
        personality = random.choices(
            persona_config['spending_personality'],
            weights=persona_config['personality_weights']
        )[0]

        # Generate roomspace_id (users with roommates share roomspace)
        if roommate_count > 0:
            # Group users into roomspaces
            roomspace_id = f"roomspace_{i // (roommate_count + 1)}"
        else:
            roomspace_id = None  # Solo user

        user = {
            'user_uid': f'user_{i:06d}',
            'name': fake.name(),
            'email': fake.email(),
            'age': age,
            'persona': persona,
            'spending_personality': personality,
            'monthly_budget': monthly_budget,
            'roommate_count': roommate_count,
            'roomspace_id': roomspace_id,
            'city': fake.city(),
            'join_date': fake.date_between(
                start_date=earliest_join,
                end_date=start_date
            )
        }

        users.append(user)

    df = pd.DataFrame(users)

    # Statistics
    print("\n✅ User generation complete!")
    print(f"   Total users: {len(df):,}")
    print(f"   Personas distribution:")
    for persona in df['persona'].value_counts().items():
        print(f"      {persona[0]}: {persona[1]:,} ({persona[1] / len(df) * 100:.1f}%)")

    print(f"\n   Spending personalities:")
    for personality in df['spending_personality'].value_counts().items():
        print(f"      {personality[0]}: {personality[1]:,} ({personality[1] / len(df) * 100:.1f}%)")

    print(f"\n   Roommate distribution:")
    print(f"      Solo users: {len(df[df['roommate_count'] == 0]):,}")
    print(f"      With roommates: {len(df[df['roommate_count'] > 0]):,}")
    print(f"      Total roomspaces: {df['roomspace_id'].nunique()}")

    return df


if __name__ == "__main__":
    # Test generation
    users_df = generate_users(1000)  # Test with 1000 users

    print("\n" + "=" * 60)
    print("SAMPLE USERS:")
    print("=" * 60)
    print(users_df.head(10))

    print("\n" + "=" * 60)
    print("STATISTICS:")
    print("=" * 60)
    print(users_df[['age', 'monthly_budget', 'roommate_count']].describe())

    print(f"\n✅ Generated {len(users_df):,} users successfully!")