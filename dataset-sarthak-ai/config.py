import numpy as np
from dataclasses import dataclass, field
from typing import Dict, List, Optional, Tuple
from enum import Enum


class Persona(Enum):
    FRUGAL = "frugal"
    CONSERVATIVE = "conservative"
    MODERATE = "moderate"
    LIFESTYLE = "lifestyle"
    SPENDER = "spender"
    OCCASIONAL_SPLURGER = "occasional_splurger"


class GroupType(Enum):
    HOUSEHOLD = "household"
    FRIENDS = "friends"
    OFFICE = "office"
    TRAVEL = "travel"
    FAMILY = "family"
    PROJECT = "project"


class Category(Enum):
    FOOD_DINING = "food_dining"
    TRANSPORTATION = "transportation"
    HOUSING = "housing"
    ENTERTAINMENT = "entertainment"
    SHOPPING = "shopping"
    HEALTH = "health"
    TRAVEL = "travel"
    EDUCATION = "education"
    SUBSCRIPTIONS = "subscriptions"
    GIFTS_DONATIONS = "gifts_donations"


class Subcategory(Enum):
    GROCERIES = "groceries"
    RESTAURANTS = "restaurants"
    CAFES = "cafes"
    DELIVERY = "delivery"
    FUEL = "fuel"
    RIDESHARE = "rideshare"
    PUBLIC_TRANSIT = "public_transit"
    PARKING = "parking"
    RENT = "rent"
    UTILITIES = "utilities"
    MAINTENANCE = "maintenance"
    MOVIES = "movies"
    CONCERTS = "concerts"
    STREAMING = "streaming"
    GAMING = "gaming"
    CLOTHING = "clothing"
    ELECTRONICS = "electronics"
    PERSONAL_CARE = "personal_care"
    HOME_GOODS = "home_goods"
    PHARMACY = "pharmacy"
    DOCTOR = "doctor"
    GYM = "gym"
    WELLNESS = "wellness"
    FLIGHTS = "flights"
    HOTELS = "hotels"
    ACTIVITIES = "activities"
    INSURANCE = "insurance"
    COURSES = "courses"
    BOOKS = "books"
    SUPPLIES = "supplies"
    SOFTWARE = "software"
    MEMBERSHIPS = "memberships"
    NEWS = "news"
    GIFTS = "gifts"
    CHARITY = "charity"


class LocationTier(Enum):
    METRO = "metro"
    TIER2 = "tier2"
    TIER3 = "tier3"


CATEGORY_SUBCATEGORIES = {
    Category.FOOD_DINING: [Subcategory.GROCERIES, Subcategory.RESTAURANTS, Subcategory.CAFES, Subcategory.DELIVERY],
    Category.TRANSPORTATION: [Subcategory.FUEL, Subcategory.RIDESHARE, Subcategory.PUBLIC_TRANSIT, Subcategory.PARKING],
    Category.HOUSING: [Subcategory.RENT, Subcategory.UTILITIES, Subcategory.MAINTENANCE],
    Category.ENTERTAINMENT: [Subcategory.MOVIES, Subcategory.CONCERTS, Subcategory.STREAMING, Subcategory.GAMING],
    Category.SHOPPING: [Subcategory.CLOTHING, Subcategory.ELECTRONICS, Subcategory.PERSONAL_CARE, Subcategory.HOME_GOODS],
    Category.HEALTH: [Subcategory.PHARMACY, Subcategory.DOCTOR, Subcategory.GYM, Subcategory.WELLNESS],
    Category.TRAVEL: [Subcategory.FLIGHTS, Subcategory.HOTELS, Subcategory.ACTIVITIES, Subcategory.INSURANCE],
    Category.EDUCATION: [Subcategory.COURSES, Subcategory.BOOKS, Subcategory.SUPPLIES],
    Category.SUBSCRIPTIONS: [Subcategory.STREAMING, Subcategory.SOFTWARE, Subcategory.MEMBERSHIPS, Subcategory.NEWS],
    Category.GIFTS_DONATIONS: [Subcategory.GIFTS, Subcategory.CHARITY],
}

CATEGORY_WEIGHTS_DEFAULT = {
    Category.FOOD_DINING: 0.30,
    Category.TRANSPORTATION: 0.12,
    Category.HOUSING: 0.15,
    Category.ENTERTAINMENT: 0.10,
    Category.SHOPPING: 0.10,
    Category.HEALTH: 0.07,
    Category.TRAVEL: 0.06,
    Category.EDUCATION: 0.04,
    Category.SUBSCRIPTIONS: 0.04,
    Category.GIFTS_DONATIONS: 0.02,
}

SUBCATEGORY_WEIGHTS = {
    Category.FOOD_DINING: {Subcategory.GROCERIES: 0.35, Subcategory.RESTAURANTS: 0.40, Subcategory.CAFES: 0.15, Subcategory.DELIVERY: 0.10},
    Category.TRANSPORTATION: {Subcategory.FUEL: 0.30, Subcategory.RIDESHARE: 0.25, Subcategory.PUBLIC_TRANSIT: 0.30, Subcategory.PARKING: 0.15},
    Category.HOUSING: {Subcategory.RENT: 0.50, Subcategory.UTILITIES: 0.30, Subcategory.MAINTENANCE: 0.20},
    Category.ENTERTAINMENT: {Subcategory.MOVIES: 0.25, Subcategory.CONCERTS: 0.15, Subcategory.STREAMING: 0.35, Subcategory.GAMING: 0.25},
    Category.SHOPPING: {Subcategory.CLOTHING: 0.35, Subcategory.ELECTRONICS: 0.25, Subcategory.PERSONAL_CARE: 0.25, Subcategory.HOME_GOODS: 0.15},
    Category.HEALTH: {Subcategory.PHARMACY: 0.35, Subcategory.DOCTOR: 0.25, Subcategory.GYM: 0.25, Subcategory.WELLNESS: 0.15},
    Category.TRAVEL: {Subcategory.FLIGHTS: 0.30, Subcategory.HOTELS: 0.35, Subcategory.ACTIVITIES: 0.20, Subcategory.INSURANCE: 0.15},
    Category.EDUCATION: {Subcategory.COURSES: 0.40, Subcategory.BOOKS: 0.30, Subcategory.SUPPLIES: 0.30},
    Category.SUBSCRIPTIONS: {Subcategory.STREAMING: 0.30, Subcategory.SOFTWARE: 0.25, Subcategory.MEMBERSHIPS: 0.25, Subcategory.NEWS: 0.20},
    Category.GIFTS_DONATIONS: {Subcategory.GIFTS: 0.70, Subcategory.CHARITY: 0.30},
}

PERSONA_PARAMS = {
    Persona.FRUGAL: {
        "daily_spend_base": 20, "spend_variance": 0.3, "activity_rate": 0.45,
        "social_tendency": 0.2, "category_bias": {
            Category.FOOD_DINING: 0.35, Category.TRANSPORTATION: 0.12, Category.HOUSING: 0.18,
            Category.ENTERTAINMENT: 0.05, Category.SHOPPING: 0.08, Category.HEALTH: 0.10,
            Category.TRAVEL: 0.02, Category.EDUCATION: 0.04, Category.SUBSCRIPTIONS: 0.04,
            Category.GIFTS_DONATIONS: 0.02,
        },
        "expenses_per_day_lambda": 1.2, "consistency": 0.85, "splurge_probability": 0.02,
    },
    Persona.CONSERVATIVE: {
        "daily_spend_base": 35, "spend_variance": 0.35, "activity_rate": 0.55,
        "social_tendency": 0.35, "category_bias": {
            Category.FOOD_DINING: 0.30, Category.TRANSPORTATION: 0.12, Category.HOUSING: 0.16,
            Category.ENTERTAINMENT: 0.08, Category.SHOPPING: 0.10, Category.HEALTH: 0.09,
            Category.TRAVEL: 0.04, Category.EDUCATION: 0.05, Category.SUBSCRIPTIONS: 0.04,
            Category.GIFTS_DONATIONS: 0.02,
        },
        "expenses_per_day_lambda": 1.5, "consistency": 0.80, "splurge_probability": 0.04,
    },
    Persona.MODERATE: {
        "daily_spend_base": 50, "spend_variance": 0.45, "activity_rate": 0.65,
        "social_tendency": 0.50, "category_bias": {
            Category.FOOD_DINING: 0.28, Category.TRANSPORTATION: 0.12, Category.HOUSING: 0.14,
            Category.ENTERTAINMENT: 0.10, Category.SHOPPING: 0.12, Category.HEALTH: 0.07,
            Category.TRAVEL: 0.06, Category.EDUCATION: 0.04, Category.SUBSCRIPTIONS: 0.05,
            Category.GIFTS_DONATIONS: 0.02,
        },
        "expenses_per_day_lambda": 1.8, "consistency": 0.70, "splurge_probability": 0.06,
    },
    Persona.LIFESTYLE: {
        "daily_spend_base": 70, "spend_variance": 0.55, "activity_rate": 0.70,
        "social_tendency": 0.70, "category_bias": {
            Category.FOOD_DINING: 0.27, Category.TRANSPORTATION: 0.10, Category.HOUSING: 0.12,
            Category.ENTERTAINMENT: 0.15, Category.SHOPPING: 0.14, Category.HEALTH: 0.05,
            Category.TRAVEL: 0.08, Category.EDUCATION: 0.03, Category.SUBSCRIPTIONS: 0.04,
            Category.GIFTS_DONATIONS: 0.02,
        },
        "expenses_per_day_lambda": 2.0, "consistency": 0.55, "splurge_probability": 0.08,
    },
    Persona.SPENDER: {
        "daily_spend_base": 100, "spend_variance": 0.70, "activity_rate": 0.75,
        "social_tendency": 0.80, "category_bias": {
            Category.FOOD_DINING: 0.25, Category.TRANSPORTATION: 0.10, Category.HOUSING: 0.10,
            Category.ENTERTAINMENT: 0.17, Category.SHOPPING: 0.16, Category.HEALTH: 0.04,
            Category.TRAVEL: 0.10, Category.EDUCATION: 0.02, Category.SUBSCRIPTIONS: 0.04,
            Category.GIFTS_DONATIONS: 0.02,
        },
        "expenses_per_day_lambda": 2.3, "consistency": 0.40, "splurge_probability": 0.12,
    },
    Persona.OCCASIONAL_SPLURGER: {
        "daily_spend_base": 40, "spend_variance": 0.90, "activity_rate": 0.60,
        "social_tendency": 0.45, "category_bias": {
            Category.FOOD_DINING: 0.26, Category.TRANSPORTATION: 0.10, Category.HOUSING: 0.14,
            Category.ENTERTAINMENT: 0.10, Category.SHOPPING: 0.12, Category.HEALTH: 0.08,
            Category.TRAVEL: 0.08, Category.EDUCATION: 0.04, Category.SUBSCRIPTIONS: 0.06,
            Category.GIFTS_DONATIONS: 0.02,
        },
        "expenses_per_day_lambda": 1.6, "consistency": 0.45, "splurge_probability": 0.15,
    },
}

GROUP_TYPE_PARAMS = {
    GroupType.HOUSEHOLD: {
        "size_range": (2, 5), "activity_freq": 0.85, "avg_expense": 55,
        "split_methods": {"equal": 0.50, "percentage": 0.35, "custom": 0.15},
        "lifespan_months": (36, 120), "categories": [Category.FOOD_DINING, Category.HOUSING, Category.TRANSPORTATION],
    },
    GroupType.FRIENDS: {
        "size_range": (3, 8), "activity_freq": 0.35, "avg_expense": 45,
        "split_methods": {"equal": 0.70, "percentage": 0.20, "custom": 0.10},
        "lifespan_months": (12, 84), "categories": [Category.FOOD_DINING, Category.ENTERTAINMENT, Category.TRAVEL],
    },
    GroupType.OFFICE: {
        "size_range": (3, 10), "activity_freq": 0.55, "avg_expense": 20,
        "split_methods": {"equal": 0.80, "percentage": 0.15, "custom": 0.05},
        "lifespan_months": (12, 60), "categories": [Category.FOOD_DINING, Category.TRANSPORTATION, Category.SUBSCRIPTIONS],
    },
    GroupType.TRAVEL: {
        "size_range": (2, 6), "activity_freq": 0.08, "avg_expense": 250,
        "split_methods": {"equal": 0.40, "percentage": 0.30, "custom": 0.30},
        "lifespan_months": (1, 18), "categories": [Category.TRAVEL, Category.FOOD_DINING, Category.ENTERTAINMENT],
    },
    GroupType.FAMILY: {
        "size_range": (3, 10), "activity_freq": 0.15, "avg_expense": 120,
        "split_methods": {"equal": 0.30, "percentage": 0.50, "custom": 0.20},
        "lifespan_months": (60, 120), "categories": [Category.FOOD_DINING, Category.GIFTS_DONATIONS, Category.HEALTH, Category.SHOPPING],
    },
    GroupType.PROJECT: {
        "size_range": (3, 7), "activity_freq": 0.30, "avg_expense": 35,
        "split_methods": {"equal": 0.75, "percentage": 0.15, "custom": 0.10},
        "lifespan_months": (3, 24), "categories": [Category.FOOD_DINING, Category.TRANSPORTATION, Category.EDUCATION],
    },
}

CATEGORY_AMOUNT_PARAMS = {
    Category.FOOD_DINING: {"mu": 3.5, "sigma": 0.8},
    Category.TRANSPORTATION: {"mu": 2.8, "sigma": 0.7},
    Category.HOUSING: {"mu": 5.5, "sigma": 0.5},
    Category.ENTERTAINMENT: {"mu": 3.2, "sigma": 0.9},
    Category.SHOPPING: {"mu": 3.8, "sigma": 1.0},
    Category.HEALTH: {"mu": 3.5, "sigma": 0.9},
    Category.TRAVEL: {"mu": 5.5, "sigma": 1.2},
    Category.EDUCATION: {"mu": 3.3, "sigma": 0.9},
    Category.SUBSCRIPTIONS: {"mu": 2.8, "sigma": 0.6},
    Category.GIFTS_DONATIONS: {"mu": 3.8, "sigma": 1.1},
}

LOCATION_MULTIPLIER = {
    LocationTier.METRO: 1.2,
    LocationTier.TIER2: 0.95,
    LocationTier.TIER3: 0.75,
}

TIME_OF_DAY_PROFILES = {
    Category.FOOD_DINING: {"morning": 0.15, "lunch": 0.35, "afternoon": 0.15, "dinner": 0.30, "night": 0.05},
    Category.TRANSPORTATION: {"morning": 0.30, "lunch": 0.10, "afternoon": 0.15, "dinner": 0.30, "night": 0.15},
    Category.HOUSING: {"morning": 0.50, "lunch": 0.10, "afternoon": 0.10, "dinner": 0.20, "night": 0.10},
    Category.ENTERTAINMENT: {"morning": 0.05, "lunch": 0.10, "afternoon": 0.25, "dinner": 0.40, "night": 0.20},
    Category.SHOPPING: {"morning": 0.10, "lunch": 0.15, "afternoon": 0.40, "dinner": 0.25, "night": 0.10},
    Category.HEALTH: {"morning": 0.25, "lunch": 0.10, "afternoon": 0.35, "dinner": 0.25, "night": 0.05},
    Category.TRAVEL: {"morning": 0.35, "lunch": 0.15, "afternoon": 0.20, "dinner": 0.20, "night": 0.10},
    Category.EDUCATION: {"morning": 0.15, "lunch": 0.10, "afternoon": 0.30, "dinner": 0.35, "night": 0.10},
    Category.SUBSCRIPTIONS: {"morning": 0.20, "lunch": 0.15, "afternoon": 0.25, "dinner": 0.30, "night": 0.10},
    Category.GIFTS_DONATIONS: {"morning": 0.20, "lunch": 0.15, "afternoon": 0.30, "dinner": 0.25, "night": 0.10},
}


@dataclass
class GenerationConfig:
    seed: int = 42
    num_users: int = 1000
    start_date: str = "2016-01-01"
    end_date: str = "2025-12-31"
    inflation_rate: float = 0.035
    person_distribution: Dict[Persona, float] = field(default_factory=lambda: {
        Persona.FRUGAL: 0.15, Persona.CONSERVATIVE: 0.20, Persona.MODERATE: 0.25,
        Persona.LIFESTYLE: 0.20, Persona.SPENDER: 0.10, Persona.OCCASIONAL_SPLURGER: 0.10,
    })
    location_distribution: Dict[LocationTier, float] = field(default_factory=lambda: {
        LocationTier.METRO: 0.45, LocationTier.TIER2: 0.35, LocationTier.TIER3: 0.20,
    })
    num_groups_target: int = 350
    avg_groups_per_user: float = 2.5
    typo_rate: float = 0.02
    wrong_category_rate: float = 0.03
    suspicious_amount_rate: float = 0.005
    missing_description_rate: float = 0.05
    tracking_gap_rate: float = 0.15
    duplicate_rate: float = 0.003
    negative_rate: float = 0.001
    time_anomaly_rate: float = 0.01
    output_dir: str = "output"