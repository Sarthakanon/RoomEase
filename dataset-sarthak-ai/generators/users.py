import numpy as np
import pandas as pd
from datetime import date, timedelta
from typing import List, Dict
from config import (
    GenerationConfig, Persona, LocationTier, CATEGORY_SUBCATEGORIES,
    CATEGORY_WEIGHTS_DEFAULT, PERSONA_PARAMS,
)
from models import User
from algorithms.personas import (
    generate_user_persona, compute_category_weights, compute_subcategory_weights,
    compute_spending_multiplier, generate_income, generate_churn_periods,
)


def generate_users(config: GenerationConfig) -> List[User]:
    rng = np.random.default_rng(config.seed)
    users = []
    first_names = [
        "Aarav", "Priya", "Rahul", "Ananya", "Vikram", "Neha", "Arjun", "Meera",
        "Karan", "Riya", "Aditya", "Simran", "Rohan", "Kavya", "Dev", "Isha",
        "Varun", "Anita", "Nikhil", "Pooja", "Suresh", "Divya", "Amit", "Swati",
        "Raj", "Nisha", "Sanjay", "Ritu", "Manish", "Sneha", "James", "Sarah",
        "Michael", "Emily", "David", "Jessica", "Robert", "Ashley", "William", "Amanda",
        "Chris", "Megan", "Daniel", "Lauren", "Alex", "Sam", "Taylor", "Jordan",
        "Morgan", "Casey", "Riley", "Quinn", "Avery", "Blake", "Reese", "Dakota",
        "Sage", "Rowan", "Emerson", "Finley", "Drew", "Hayden", "Jamie", "Kai",
    ]
    last_names = [
        "Sharma", "Patel", "Kumar", "Singh", "Gupta", "Agarwal", "Verma", "Reddy",
        "Joshi", "Mehta", "Smith", "Johnson", "Williams", "Brown", "Jones", "Davis",
        "Miller", "Wilson", "Moore", "Taylor", "Anderson", "Thomas", "Jackson", "White",
        "Harris", "Martin", "Thompson", "Garcia", "Martinez", "Robinson",
    ]

    start_date = date.fromisoformat(config.start_date)
    end_date = date.fromisoformat(config.end_date)
    total_days = (end_date - start_date).days

    join_weights = np.zeros(total_days)
    for i in range(total_days):
        t = i / total_days
        join_weights[i] = np.exp(-2.5 * t) + 0.05 * np.exp(-0.5 * t)
    join_weights /= join_weights.sum()

    for i in range(config.num_users):
        user_seed = config.seed + i * 1000 + 7
        user_rng = np.random.default_rng(user_seed)

        persona = generate_user_persona(rng, config)

        location_choices = list(config.location_distribution.keys())
        location_probs = list(config.location_distribution.values())
        location_tier = rng.choice(location_choices, p=location_probs)

        age = int(rng.integers(18, 65))
        income = generate_income(persona, rng)

        first = rng.choice(first_names)
        last = rng.choice(last_names)
        name = f"{first} {last}"
        email = f"{first.lower()}.{last.lower()}{rng.integers(1, 999)}@{rng.choice(['gmail.com', 'yahoo.com', 'outlook.com', 'hotmail.com'])}"

        join_day_offset = rng.choice(total_days, p=join_weights)
        join_date = start_date + timedelta(days=int(join_day_offset))

        category_weights = compute_category_weights(persona, age, user_rng)
        subcategory_weights = compute_subcategory_weights(category_weights, user_rng)
        spending_multiplier = compute_spending_multiplier(persona, income, location_tier, user_rng)

        churn_periods_raw = generate_churn_periods(
            join_date.year, config, user_rng
        )
        churn_periods = churn_periods_raw

        user = User(
            user_id=f"USR_{i+1:04d}",
            name=name,
            email=email,
            age=age,
            income=income,
            persona=persona,
            location_tier=location_tier,
            join_date=join_date,
            spending_multiplier=spending_multiplier,
            category_weights=category_weights,
            subcategory_weights=subcategory_weights,
            activity_rate=PERSONA_PARAMS[persona]["activity_rate"],
            social_tendency=PERSONA_PARAMS[persona]["social_tendency"],
            consistency=PERSONA_PARAMS[persona]["consistency"],
            splurge_probability=PERSONA_PARAMS[persona]["splurge_probability"],
            churn_periods=churn_periods,
            daily_lambda=PERSONA_PARAMS[persona]["expenses_per_day_lambda"],
        )
        users.append(user)

    return users


def users_to_dataframe(users: List[User]) -> pd.DataFrame:
    rows = []
    for u in users:
        rows.append({
            "user_id": u.user_id,
            "name": u.name,
            "email": u.email,
            "age": u.age,
            "income": u.income,
            "persona": u.persona.value,
            "location_tier": u.location_tier.value,
            "join_date": u.join_date.isoformat(),
            "spending_multiplier": round(u.spending_multiplier, 4),
            "activity_rate": u.activity_rate,
            "social_tendency": u.social_tendency,
            "consistency": u.consistency,
            "splurge_probability": u.splurge_probability,
            "daily_lambda": u.daily_lambda,
            "churn_periods": str(u.churn_periods),
        })
    return pd.DataFrame(rows)