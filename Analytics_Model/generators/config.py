"""
Configuration for realistic expense data generation
"""

import random
from datetime import datetime

# ==================== USER PERSONAS ====================

USER_PERSONAS = {
    'student': {
        'weight': 0.40,  # 40% of users
        'age_range': (18, 25),
        'monthly_budget_range': (800, 1500),
        'roommate_count_range': (2, 4),
        'spending_personality': ['frugal', 'moderate', 'impulsive'],
        'personality_weights': [0.4, 0.4, 0.2]
    },
    'young_professional': {
        'weight': 0.30,  # 30% of users
        'age_range': (25, 35),
        'monthly_budget_range': (2000, 4000),
        'roommate_count_range': (1, 3),
        'spending_personality': ['moderate', 'comfortable', 'lavish'],
        'personality_weights': [0.3, 0.5, 0.2]
    },
    'family': {
        'weight': 0.15,  # 15% of users
        'age_range': (30, 50),
        'monthly_budget_range': (3500, 6000),
        'roommate_count_range': (2, 5),  # Family members
        'spending_personality': ['moderate', 'comfortable'],
        'personality_weights': [0.6, 0.4]
    },
    'freelancer': {
        'weight': 0.10,  # 10% of users
        'age_range': (25, 40),
        'monthly_budget_range': (1500, 3500),
        'roommate_count_range': (0, 2),
        'spending_personality': ['frugal', 'moderate', 'impulsive'],
        'personality_weights': [0.3, 0.4, 0.3]
    },
    'budget_conscious': {
        'weight': 0.05,  # 5% of users
        'age_range': (20, 60),
        'monthly_budget_range': (600, 1200),
        'roommate_count_range': (1, 3),
        'spending_personality': ['frugal'],
        'personality_weights': [1.0]
    }
}

# ==================== EXPENSE CATEGORIES ====================

EXPENSE_CATEGORIES = {
    # Shared expenses (usually split among roommates)
    'shared': {
        'Rent': {
            'weight': 0.25,
            'amount_range': (800, 3000),
            'frequency': 'monthly',
            'frequency_multiplier': 0.9,
            'split_type_weights': {'EQUAL': 0.6, 'PERCENTAGE': 0.3, 'EXACT': 0.1},
            'day_of_month': 1,  # Usually paid on 1st
            'variation': 0.02  # Very consistent
        },
        'Utilities': {
            'weight': 0.20,
            'amount_range': (80, 250),
            'frequency': 'monthly',
            'frequency_multiplier': 0.8,
            'split_type_weights': {'EQUAL': 0.7, 'PERCENTAGE': 0.2, 'EXACT': 0.1},
            'day_of_month': 5,
            'variation': 0.15
        },
        'Internet': {
            'weight': 0.10,
            'amount_range': (40, 100),
            'frequency': 'monthly',
            'frequency_multiplier': 0.95,
            'split_type_weights': {'EQUAL': 0.8, 'PERCENTAGE': 0.1, 'EXACT': 0.1},
            'day_of_month': 10,
            'variation': 0.05
        },
        'Groceries': {
            'weight': 0.30,
            'amount_range': (50, 200),
            'frequency': 'weekly',
            'frequency_multiplier': 0.8,
            'split_type_weights': {'EQUAL': 0.7, 'PERCENTAGE': 0.2, 'EXACT': 0.1},
            'variation': 0.3
        },
        'Household Items': {
            'weight': 0.15,
            'amount_range': (20, 100),
            'frequency': 'irregular',
            'frequency_multiplier': 0.3,
            'split_type_weights': {'EQUAL': 0.8, 'PERCENTAGE': 0.1, 'EXACT': 0.1},
            'variation': 0.4
        }
    },

    # Personal expenses (not split)
    'personal': {
        'Food & Dining': {
            'weight': 0.30,
            'amount_range': (8, 50),
            'frequency': 'daily',
            'frequency_multiplier': 0.6,
            'variation': 0.4,
            'peak_days': [5, 6],  # Friday, Saturday
            'peak_hours': [12, 13, 18, 19, 20]  # Lunch and dinner
        },
        'Transport': {
            'weight': 0.25,
            'amount_range': (3, 30),
            'frequency': 'daily',
            'frequency_multiplier': 0.7,
            'variation': 0.3,
            'peak_days': [0, 1, 2, 3, 4]  # Weekdays
        },
        'Entertainment': {
            'weight': 0.15,
            'amount_range': (15, 100),
            'frequency': 'weekly',
            'frequency_multiplier': 0.5,
            'variation': 0.5,
            'peak_days': [5, 6]  # Weekends
        },
        'Shopping': {
            'weight': 0.15,
            'amount_range': (20, 200),
            'frequency': 'irregular',
            'frequency_multiplier': 0.2,
            'variation': 0.6
        },
        'Health & Fitness': {
            'weight': 0.08,
            'amount_range': (30, 150),
            'frequency': 'monthly',
            'frequency_multiplier': 0.7,
            'variation': 0.3
        },
        'Personal Care': {
            'weight': 0.05,
            'amount_range': (10, 80),
            'frequency': 'irregular',
            'frequency_multiplier': 0.15,
            'variation': 0.4
        },
        'Other': {
            'weight': 0.02,
            'amount_range': (5, 100),
            'frequency': 'irregular',
            'frequency_multiplier': 0.1,
            'variation': 0.7
        }
    }
}

# ==================== SPENDING PERSONALITIES ====================

SPENDING_PERSONALITIES = {
    'frugal': {
        'amount_multiplier': 0.7,
        'frequency_multiplier': 0.8,
        'anomaly_rate': 0.02,
        'budget_adherence': 0.95
    },
    'moderate': {
        'amount_multiplier': 1.0,
        'frequency_multiplier': 1.0,
        'anomaly_rate': 0.05,
        'budget_adherence': 0.85
    },
    'comfortable': {
        'amount_multiplier': 1.3,
        'frequency_multiplier': 1.2,
        'anomaly_rate': 0.08,
        'budget_adherence': 0.70
    },
    'impulsive': {
        'amount_multiplier': 1.5,
        'frequency_multiplier': 1.4,
        'anomaly_rate': 0.15,
        'budget_adherence': 0.50
    },
    'lavish': {
        'amount_multiplier': 2.0,
        'frequency_multiplier': 1.5,
        'anomaly_rate': 0.10,
        'budget_adherence': 0.60
    }
}

# ==================== TEMPORAL PATTERNS ====================

TEMPORAL_PATTERNS = {
    'payday_spike': {
        'days': [1, 2, 3],  # First 3 days of month
        'multiplier': 1.8,
        'categories': ['Shopping', 'Entertainment', 'Food & Dining']
    },
    'weekend_effect': {
        'days': [5, 6],  # Sat, Sun
        'multiplier': 1.5,
        'categories': ['Food & Dining', 'Entertainment']
    },
    'end_of_month_frugality': {
        'days': [27, 28, 29, 30, 31],
        'multiplier': 0.6,
        'categories': ['Food & Dining', 'Entertainment', 'Shopping']
    },
    'lunch_hours': {
        'hours': [12, 13],
        'multiplier': 1.0,
        'categories': ['Food & Dining']
    },
    'dinner_hours': {
        'hours': [18, 19, 20],
        'multiplier': 1.0,
        'categories': ['Food & Dining']
    }
}

# ==================== SEASONAL PATTERNS ====================

SEASONAL_PATTERNS = {
    'holidays': {
        'months': [11, 12],  # Nov, Dec
        'multiplier': 1.8,
        'categories': ['Shopping', 'Food & Dining', 'Entertainment']
    },
    'summer': {
        'months': [6, 7, 8],
        'multiplier': 1.4,
        'categories': ['Entertainment', 'Transport']
    },
    'back_to_school': {
        'months': [8, 9],
        'multiplier': 1.6,
        'categories': ['Shopping', 'Household Items']
    },
    'new_year_resolutions': {
        'months': [1, 2],
        'multiplier': 1.3,
        'categories': ['Health & Fitness']
    }
}

# ==================== EXPENSE DESCRIPTIONS ====================

EXPENSE_DESCRIPTIONS = {
    'Rent': ['Monthly rent', 'Rent payment', 'Apartment rent'],
    'Utilities': ['Electricity bill', 'Water bill', 'Gas bill', 'Utility payment'],
    'Internet': ['Internet bill', 'WiFi payment', 'Broadband'],
    'Groceries': [
        'Walmart groceries', 'Costco shopping', 'Whole Foods',
        'Target groceries', 'Local supermarket', 'Weekly groceries'
    ],
    'Household Items': [
        'Cleaning supplies', 'Bathroom essentials', 'Kitchen items',
        'Paper towels', 'Laundry detergent'
    ],
    'Food & Dining': [
        'Starbucks', 'McDonald\'s', 'Chipotle', 'Subway',
        'Local restaurant', 'Pizza delivery', 'Coffee shop',
        'Lunch', 'Dinner', 'Breakfast', 'Snacks'
    ],
    'Transport': [
        'Uber', 'Lyft', 'Gas', 'Parking', 'Bus fare',
        'Metro card', 'Taxi', 'Car wash'
    ],
    'Entertainment': [
        'Movie tickets', 'Concert', 'Netflix', 'Spotify',
        'Gaming', 'Bar', 'Club', 'Sports event'
    ],
    'Shopping': [
        'Amazon', 'Clothing', 'Shoes', 'Electronics',
        'Online shopping', 'Mall shopping', 'Books'
    ],
    'Health & Fitness': [
        'Gym membership', 'Yoga class', 'Pharmacy',
        'Doctor visit', 'Vitamins', 'Fitness equipment'
    ],
    'Personal Care': [
        'Haircut', 'Salon', 'Cosmetics', 'Toiletries'
    ],
    'Other': [
        'Miscellaneous', 'Other expense', 'General'
    ]
}

# ==================== ANOMALY TYPES ====================

ANOMALY_TYPES = {
    'high_amount': {
        'multiplier_range': (3, 8),
        'probability': 0.40,
        'description_prefix': '[UNUSUAL] '
    },
    'unusual_time': {
        'probability': 0.20,
        'description_prefix': '[LATE NIGHT] '
    },
    'duplicate_pattern': {
        'probability': 0.15,
        'description_prefix': '[DUPLICATE?] '
    },
    'unusual_category': {
        'probability': 0.15,
        'description_prefix': '[RARE CATEGORY] '
    },
    'rapid_succession': {
        'probability': 0.10,
        'description_prefix': '[RAPID] '
    }
}

# ==================== GENERATION SETTINGS ====================

GENERATION_CONFIG = {
    'total_users': 1000,
    'start_date': datetime(2023, 1, 1),
    'end_date': datetime(2023, 12, 31),
    'shared_expense_ratio': 0.40,  # 40% shared, 60% personal
    'anomaly_rate': 0.05,  # 5% of expenses are anomalies
    'missing_description_rate': 0.10,  # 10% missing descriptions
    'duplicate_rate': 0.02,  # 2% potential duplicates
    'random_seed': 42
}


# ==================== HELPER FUNCTIONS ====================

def get_persona_weights():
    """Returns list of personas and their weights for random selection"""
    personas = list(USER_PERSONAS.keys())
    weights = [USER_PERSONAS[p]['weight'] for p in personas]
    return personas, weights


def get_category_weights(category_type='personal'):
    """Returns categories and weights for random selection"""
    categories = list(EXPENSE_CATEGORIES[category_type].keys())
    weights = [EXPENSE_CATEGORIES[category_type][c]['weight'] for c in categories]
    return categories, weights


def get_random_description(category):
    """Returns random description for a category"""
    return random.choice(EXPENSE_DESCRIPTIONS.get(category, ['Expense']))