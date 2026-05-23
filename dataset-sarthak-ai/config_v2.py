"""
File: config_v2.py
What does this file do?
    Defines Nepal-first finance dataset settings, categories, personas, payment
    methods, currencies, festivals, and generation defaults for V2.
Methods/functions this file contains:
    NepalFinanceConfig, weighted_choice.
Date and Day of last modification:
    2026-05-16, Saturday.
"""

from __future__ import annotations

from dataclasses import dataclass, field
from datetime import date
from typing import Dict, List, Sequence, Tuple

import numpy as np


CATEGORIES: Dict[str, Dict[str, object]] = {
    "rent": {"essential": True, "monthly": True, "base": (8000, 35000)},
    "groceries": {"essential": True, "monthly": False, "base": (250, 2500)},
    "restaurants_cafes": {"essential": False, "monthly": False, "base": (120, 2500)},
    "transport_public": {"essential": True, "monthly": False, "base": (25, 250)},
    "transport_ride_hailing": {"essential": False, "monthly": False, "base": (120, 1200)},
    "fuel": {"essential": True, "monthly": False, "base": (500, 5000)},
    "internet_mobile": {"essential": True, "monthly": True, "base": (100, 3500)},
    "utilities": {"essential": True, "monthly": True, "base": (500, 6000)},
    "education": {"essential": True, "monthly": False, "base": (800, 30000)},
    "health": {"essential": True, "monthly": False, "base": (300, 15000)},
    "family_support": {"essential": True, "monthly": True, "base": (1500, 22000)},
    "loan_emi": {"essential": True, "monthly": True, "base": (2500, 28000)},
    "festivals_gifts": {"essential": False, "monthly": False, "base": (500, 25000)},
    "clothing": {"essential": False, "monthly": False, "base": (500, 15000)},
    "travel": {"essential": False, "monthly": False, "base": (1000, 30000)},
    "subscriptions": {"essential": False, "monthly": True, "base": (150, 4000)},
    "savings_investment": {"essential": True, "monthly": True, "base": (1000, 60000)},
    "entertainment": {"essential": False, "monthly": False, "base": (200, 4500)},
    "miscellaneous": {"essential": False, "monthly": False, "base": (100, 5000)},
}

DAILY_CATEGORY_WEIGHTS = {
    "rent": 0.02,
    "groceries": 1.35,
    "restaurants_cafes": 1.15,
    "transport_public": 1.25,
    "transport_ride_hailing": 0.70,
    "fuel": 0.45,
    "internet_mobile": 0.12,
    "utilities": 0.10,
    "education": 0.07,
    "health": 0.18,
    "family_support": 0.05,
    "loan_emi": 0.03,
    "festivals_gifts": 0.07,
    "clothing": 0.28,
    "travel": 0.035,
    "subscriptions": 0.08,
    "savings_investment": 0.04,
    "entertainment": 0.55,
    "miscellaneous": 0.50,
}

RECURRING_CATEGORY_SCHEDULE = {
    "rent": {"day": 1, "probability": 0.82},
    "utilities": {"day": 8, "probability": 0.72},
    "internet_mobile": {"day": 12, "probability": 0.78},
    "family_support": {"day": 5, "probability": 0.45},
    "loan_emi": {"day": 15, "probability": 0.30},
    "subscriptions": {"day": 18, "probability": 0.52},
    "savings_investment": {"day": 3, "probability": 0.40},
}


PERSONAS: Dict[str, Dict[str, object]] = {
    "student_low_budget": {
        "weight": 0.14,
        "income": (8000, 30000),
        "activity": 0.46,
        "spend_multiplier": 0.55,
        "saving_rate": 0.04,
        "shared_tendency": 0.45,
        "category_bias": {
            "transport_public": 2.0,
            "restaurants_cafes": 1.2,
            "education": 1.8,
            "internet_mobile": 1.3,
        },
    },
    "salaried_balanced": {
        "weight": 0.22,
        "income": (35000, 95000),
        "activity": 0.62,
        "spend_multiplier": 1.0,
        "saving_rate": 0.14,
        "shared_tendency": 0.35,
        "category_bias": {"groceries": 1.3, "transport_public": 1.2, "internet_mobile": 1.2},
    },
    "salaried_family_support": {
        "weight": 0.14,
        "income": (45000, 130000),
        "activity": 0.58,
        "spend_multiplier": 1.06,
        "saving_rate": 0.08,
        "shared_tendency": 0.28,
        "category_bias": {"family_support": 2.8, "education": 1.4, "health": 1.2},
    },
    "freelancer_irregular_income": {
        "weight": 0.12,
        "income": (25000, 160000),
        "activity": 0.55,
        "spend_multiplier": 0.95,
        "saving_rate": 0.10,
        "shared_tendency": 0.32,
        "category_bias": {"internet_mobile": 1.5, "subscriptions": 1.6, "restaurants_cafes": 1.2},
    },
    "business_owner_cash_heavy": {
        "weight": 0.10,
        "income": (60000, 250000),
        "activity": 0.72,
        "spend_multiplier": 1.55,
        "saving_rate": 0.12,
        "shared_tendency": 0.30,
        "category_bias": {"fuel": 1.9, "restaurants_cafes": 1.4, "miscellaneous": 1.5},
    },
    "high_social_spender": {
        "weight": 0.10,
        "income": (40000, 150000),
        "activity": 0.76,
        "spend_multiplier": 1.35,
        "saving_rate": 0.05,
        "shared_tendency": 0.70,
        "category_bias": {"restaurants_cafes": 2.4, "entertainment": 1.9, "travel": 1.5},
    },
    "rent_pressure_user": {
        "weight": 0.08,
        "income": (28000, 80000),
        "activity": 0.52,
        "spend_multiplier": 0.90,
        "saving_rate": 0.03,
        "shared_tendency": 0.40,
        "category_bias": {"rent": 2.2, "utilities": 1.4, "transport_public": 1.3},
    },
    "festival_spike_user": {
        "weight": 0.06,
        "income": (30000, 120000),
        "activity": 0.58,
        "spend_multiplier": 1.02,
        "saving_rate": 0.08,
        "shared_tendency": 0.48,
        "category_bias": {"festivals_gifts": 2.5, "clothing": 1.7, "travel": 1.4},
    },
    "debt_repayment_user": {
        "weight": 0.04,
        "income": (35000, 120000),
        "activity": 0.50,
        "spend_multiplier": 0.82,
        "saving_rate": 0.02,
        "shared_tendency": 0.22,
        "category_bias": {"loan_emi": 2.8, "groceries": 1.2},
    },
}


PAYMENT_METHODS = {
    "cash": 0.42,
    "esewa": 0.18,
    "khalti": 0.10,
    "bank_transfer": 0.13,
    "debit_card": 0.08,
    "credit_card": 0.04,
    "fonepay_qr": 0.05,
}

CURRENCY_RATES_TO_NPR = {
    "NPR": 1.0,
    "USD": 133.5,
    "INR": 1.6,
}

CITY_TIERS = {
    "kathmandu_valley": {"weight": 0.36, "price_multiplier": 1.25},
    "major_city": {"weight": 0.28, "price_multiplier": 1.05},
    "town": {"weight": 0.24, "price_multiplier": 0.88},
    "rural": {"weight": 0.12, "price_multiplier": 0.72},
}

GROUP_TYPES = {
    "flatmates": {"weight": 0.22, "size": (2, 5), "activity": 0.28},
    "friends": {"weight": 0.30, "size": (3, 8), "activity": 0.22},
    "family": {"weight": 0.18, "size": (3, 8), "activity": 0.16},
    "travel": {"weight": 0.12, "size": (2, 7), "activity": 0.06},
    "office": {"weight": 0.12, "size": (3, 10), "activity": 0.12},
    "event": {"weight": 0.06, "size": (4, 12), "activity": 0.04},
}

FESTIVAL_WINDOWS = [
    {"name": "dashain", "month": 10, "start_day": 1, "end_day": 20, "multiplier": 1.65},
    {"name": "tihar", "month": 11, "start_day": 1, "end_day": 12, "multiplier": 1.45},
    {"name": "teej", "month": 9, "start_day": 1, "end_day": 10, "multiplier": 1.20},
    {"name": "new_year", "month": 4, "start_day": 10, "end_day": 18, "multiplier": 1.18},
]


@dataclass(frozen=True)
class NepalFinanceConfig:
    seed: int = 42
    num_users: int = 500
    num_groups: int = 180
    start_date: date = date(2023, 1, 1)
    end_date: date = date(2025, 12, 31)
    output_dir: str = "output_v2"
    base_currency: str = "NPR"
    dataset_version: str = "nepal_finance_v2"
    privacy_fields_to_exclude: List[str] = field(default_factory=lambda: ["name", "email", "phone"])


def weighted_choice(rng: np.random.Generator, weighted_items: Dict[str, float]) -> str:
    items: Sequence[str] = list(weighted_items.keys())
    weights = np.array(list(weighted_items.values()), dtype=float)
    weights = weights / weights.sum()
    return str(rng.choice(items, p=weights))
