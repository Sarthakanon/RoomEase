import numpy as np
from datetime import date, timedelta
from typing import Dict, List, Optional, Tuple
from config import (
    Persona, Category, Subcategory, CATEGORY_SUBCATEGORIES,
    CATEGORY_AMOUNT_PARAMS, PERSONA_PARAMS,
)
from algorithms.temporal import compute_temporal_modifier, get_time_of_day


DESCRIPTION_TEMPLATES = {
    (Category.FOOD_DINING, Subcategory.GROCERIES): [
        "Weekly groceries", "Grocery shopping at {store}", "Fresh produce from farmers market",
        "Stocking up on groceries", "Grocery run", "Supermarket haul",
        "Organic groceries", "Monthly grocery shopping", "Quick grocery stop",
        "Household groceries", "Weekend grocery shopping", "Grocery essentials",
    ],
    (Category.FOOD_DINING, Subcategory.RESTAURANTS): [
        "Dinner at {restaurant}", "Lunch at {restaurant}", "Date night at {restaurant}",
        "Trying out {restaurant}", "Birthday dinner", "Anniversary dinner",
        "Weekend brunch", "Team lunch at {restaurant}", "Nice dinner out",
        "Family dinner", "Celebrating at {restaurant}", "Casual dinner",
    ],
    (Category.FOOD_DINING, Subcategory.CAFES): [
        "Morning coffee", "Coffee at {cafe}", "Afternoon latte", "Espresso fix",
        "Coffee break", "Cafe hopping", "Iced coffee", "Flat white at {cafe}",
        "Cappuccino", "Coffee with friends at {cafe}", "Weekend coffee",
        "Mid-day coffee run",
    ],
    (Category.FOOD_DINING, Subcategory.DELIVERY): [
        "Food delivery - {cuisine}", "Ordered in {cuisine}", "Late night delivery",
        "Pizza delivery", "Sushi delivery", "Takeout order", "UberEats order",
        "DoorDash dinner", "Foodpanda order", "Weekend delivery treat",
        "Lazy night delivery", "Quick delivery lunch",
    ],
    (Category.TRANSPORTATION, Subcategory.FUEL): [
        "Gas fill-up", "Fuel for the car", "Gas station stop", "Full tank refill",
        "Fuel expense", "Monthly gas", "Petrol for road trip", "Gas at {station}",
        "Diesel fill", "Regular fuel top-up",
    ],
    (Category.TRANSPORTATION, Subcategory.RIDESHARE): [
        "Uber to {place}", "Lyft ride", "Cab to {place}", "Ride-share to {place}",
        "Uber ride home", "Late night Uber", "Airport Uber", "Ride to meeting",
    ],
    (Category.TRANSPORTATION, Subcategory.PUBLIC_TRANSIT): [
        "Monthly transit pass", "Bus fare", "Subway reload", "Train ticket",
        "Metro card top-up", "Public transport day pass", "Commuter rail pass",
    ],
    (Category.TRANSPORTATION, Subcategory.PARKING): [
        "Parking fee", "Parking garage", "Street parking", "Valet parking",
        "Monthly parking pass", "Airport parking",
    ],
    (Category.HOUSING, Subcategory.RENT): [
        "Monthly rent", "Apartment rent", "House rent payment", "Rent deposit",
        "Room rent", "Rent for the month",
    ],
    (Category.HOUSING, Subcategory.UTILITIES): [
        "Electricity bill", "Water bill", "Internet bill", "Gas bill",
        "Phone bill", "Utility bills_combined", "Electricity and water",
        "Monthly utilities",
    ],
    (Category.HOUSING, Subcategory.MAINTENANCE): [
        "Plumber visit", "AC repair", "Home maintenance", "Cleaning service",
        "Pest control", "Lock replacement", "Appliance repair", "Paint touch-up",
    ],
    (Category.ENTERTAINMENT, Subcategory.MOVIES): [
        "Movie tickets", "Date night movie", "New release - {movie}", "IMAX experience",
        "Weekend movie", "Family movie outing",
    ],
    (Category.ENTERTAINMENT, Subcategory.CONCERTS): [
        "{artist} concert", "Live music event", "Music festival ticket", "Concert night",
        "Local gig", "Jazz night",
    ],
    (Category.ENTERTAINMENT, Subcategory.STREAMING): [
        "Netflix subscription", "Spotify premium", "Disney+ subscription", "HBO Max",
        "Streaming services", "YouTube Premium", "Amazon Prime",
    ],
    (Category.ENTERTAINMENT, Subcategory.GAMING): [
        "New game purchase", "Steam sale pickup", "Gaming subscription", "In-game purchase",
        "Console game", "Xbox Game Pass",
    ],
    (Category.SHOPPING, Subcategory.CLOTHING): [
        "New {item}", "Shopping at {store}", "Seasonal wardrobe update", "Shoes",
        "Jacket shopping", "Clothing haul", "Basics restock",
    ],
    (Category.SHOPPING, Subcategory.ELECTRONICS): [
        "New {device}", "Electronics purchase", "Accessory for {device}", "Replacement {item}",
        "Tech upgrade", "Gadget buy",
    ],
    (Category.SHOPPING, Subcategory.PERSONAL_CARE): [
        "Haircut", "Skincare restock", "Personal care items", "Grooming products",
        "Dental care", "Spa day", "Wellness products", "Cosmetics",
    ],
    (Category.SHOPPING, Subcategory.HOME_GOODS): [
        "Home decor", "Kitchen supplies", "New {furniture}", "Home improvement",
        "Curtains and blinds", "Bedding", "Organization supplies",
    ],
    (Category.HEALTH, Subcategory.PHARMACY): [
        "Prescription refill", "Pharmacy visit", "Medicine purchase", "OTC medicine",
        "Vitamins", "First aid supplies",
    ],
    (Category.HEALTH, Subcategory.DOCTOR): [
        "Doctor visit", "Specialist appointment", "Annual checkup", "Dental cleaning",
        "Eye exam", "Therapy session", "Lab work",
    ],
    (Category.HEALTH, Subcategory.GYM): [
        "Gym membership", "Personal training", "Yoga class pass", "Fitness class",
        "Gym monthly fee", "CrossFit membership",
    ],
    (Category.HEALTH, Subcategory.WELLNESS): [
        "Massage session", "Wellness retreat", "Meditation app subscription",
        "Acupuncture", "Chiropractic visit",
    ],
    (Category.TRAVEL, Subcategory.FLIGHTS): [
        "Flight to {dest}", "Return flight", "Domestic flight", "International flight",
        "Budget airline ticket", "Flight booking",
    ],
    (Category.TRAVEL, Subcategory.HOTELS): [
        "Hotel stay - {dest}", "Airbnb - {dest}", "Resort booking", "Hostel stay",
        "Weekend hotel", "Accommodation in {dest}",
    ],
    (Category.TRAVEL, Subcategory.ACTIVITIES): [
        "City tour - {dest}", "Adventure activity", "Museum pass", "Guided tour",
        "Excursion", "Day trip activities", "Snorkeling",
    ],
    (Category.TRAVEL, Subcategory.INSURANCE): [
        "Travel insurance", "Trip protection plan", "Insurance premium",
    ],
    (Category.EDUCATION, Subcategory.COURSES): [
        "Online course - {topic}", "Workshop fee", "Certification program",
        "Course enrollment", "Skill development class",
    ],
    (Category.EDUCATION, Subcategory.BOOKS): [
        "Book purchase - {title}", "E-book", "Reference material", "Study guides",
        "Textbook", "Audiobook subscription",
    ],
    (Category.EDUCATION, Subcategory.SUPPLIES): [
        "Stationery purchase", "Art supplies", "Study materials", "Notebooks and pens",
        "Backpack", "Learning tools",
    ],
    (Category.SUBSCRIPTIONS, Subcategory.STREAMING): [
        "Streaming bundle", "Music subscription", "Video streaming service",
    ],
    (Category.SUBSCRIPTIONS, Subcategory.SOFTWARE): [
        "Software subscription", "App subscription", "Cloud storage plan",
        "Productivity tool", "Design tool subscription",
    ],
    (Category.SUBSCRIPTIONS, Subcategory.MEMBERSHIPS): [
        "Club membership", "Professional association fee", "Warehouse club membership",
        "Gym membership renewal", "Loyalty program",
    ],
    (Category.SUBSCRIPTIONS, Subcategory.NEWS): [
        "News subscription", "Magazine subscription", "Newspaper delivery",
    ],
    (Category.GIFTS_DONATIONS, Subcategory.GIFTS): [
        "Birthday gift for {person}", "Wedding gift", "Holiday gift",
        "Anniversary gift", "Baby shower gift", "Housewarming gift",
        "Thank you gift", "Graduation gift",
    ],
    (Category.GIFTS_DONATIONS, Subcategory.CHARITY): [
        "Charity donation - {cause}", "Monthly donation", "Fundraiser contribution",
        "NGO contribution", "Disaster relief donation",
    ],
}

STORE_NAMES = [
    "Whole Foods", "Trader Joe's", "Costco", "Walmart", "Target",
    "Kroger", "Safeway", "Aldi", "Publix", "Wegmans",
]
RESTAURANT_NAMES = [
    "Olive Garden", "Cheesecake Factory", "Chipotle", "Panera", "Chili's",
    "Local Bistro", "Sushi Place", "Thai Kitchen", "Pizza Corner", "The Grill",
]
CAFE_NAMES = [
    "Starbucks", "Dunkin'", "Blue Bottle", "Local Cafe", "Peet's Coffee",
    "Caribou Coffee", "Philz Coffee", "La Colombe",
]
CUISINE_TYPES = [
    "Italian", "Indian", "Chinese", "Mexican", "Thai", "Japanese",
    "Mediterranean", "American", "Korean", "Vietnamese",
]
PLACE_NAMES = [
    "office", "home", "airport", "downtown", "mall", "station",
    "hotel", "friend's place", "gym", "park",
]
DEVICE_NAMES = ["laptop", "phone", "tablet", "headphones", "camera", "speaker"]
FURNITURE_NAMES = ["desk", "chair", "shelf", "lamp", "table", "sofa"]
CLOTHING_ITEMS = ["shirt", "dress", "jeans", "jacket", "sweater", "pants"]
MOVIE_NAMES = ["latest release", "blockbuster", "indie film", "comedy", "action movie"]
ARTIST_NAMES = ["local band", "DJ", "popular artist", "indie musician"]
BOOK_TITLES = ["bestseller", "self-help book", "novel", "biography", "guide"]
TOPIC_NAMES = ["Python", "design", "marketing", "data science", "photography"]
PERSON_NAMES = ["mom", "dad", "sister", "friend", "colleague", "partner"]
CAUSE_NAMES = ["education", "healthcare", "environment", "animals", "hunger relief"]
DEST_NAMES = [
    "Goa", "Bali", "Paris", "Tokyo", "NYC", "London", "Dubai",
    "Thailand", "Italy", "Barcelona", "Sydney", "Hawaii",
]


def generate_amount(
    category: Category, persona: Persona, temporal_modifier: float,
    location_multiplier: float, rng: np.random.Generator,
    is_splurge: bool = False,
) -> float:
    params = CATEGORY_AMOUNT_PARAMS[category]
    mu = params["mu"]
    sigma = params["sigma"]

    persona_spend_ratio = PERSONA_PARAMS[persona]["daily_spend_base"] / 50.0

    base_amount = np.exp(rng.normal(mu, sigma))
    base_amount *= persona_spend_ratio * temporal_modifier * location_multiplier

    if is_splurge:
        base_amount *= rng.uniform(3, 8)

    rounded = round(base_amount, 2)

    rounding_choice = rng.random()
    if rounding_choice < 0.40:
        rounded = round(rounded)
    elif rounding_choice < 0.55:
        rounded = round(rounded * 2) / 2
    elif rounding_choice < 0.65:
        rounded = round(rounded) - 0.01
    elif rounding_choice < 0.70:
        rounded = round(rounded) + 0.50

    return max(1.0, rounded)


def generate_description(
    category: Category, subcategory: Subcategory, amount: float,
    rng: np.random.Generator,
) -> str:
    key = (category, subcategory)
    templates = DESCRIPTION_TEMPLATES.get(key, ["Expense"])
    template = rng.choice(templates)

    template = template.replace("{store}", rng.choice(STORE_NAMES))
    template = template.replace("{restaurant}", rng.choice(RESTAURANT_NAMES))
    template = template.replace("{cafe}", rng.choice(CAFE_NAMES))
    template = template.replace("{cuisine}", rng.choice(CUISINE_TYPES))
    template = template.replace("{place}", rng.choice(PLACE_NAMES))
    template = template.replace("{device}", rng.choice(DEVICE_NAMES))
    template = template.replace("{furniture}", rng.choice(FURNITURE_NAMES))
    template = template.replace("{item}", rng.choice(CLOTHING_ITEMS))
    template = template.replace("{movie}", rng.choice(MOVIE_NAMES))
    template = template.replace("{artist}", rng.choice(ARTIST_NAMES))
    template = template.replace("{title}", rng.choice(BOOK_TITLES))
    template = template.replace("{topic}", rng.choice(TOPIC_NAMES))
    template = template.replace("{person}", rng.choice(PERSON_NAMES))
    template = template.replace("{cause}", rng.choice(CAUSE_NAMES))
    template = template.replace("{dest}", rng.choice(DEST_NAMES))

    return template


def apply_typo(text: str, rng: np.random.Generator) -> str:
    if rng.random() > 0.5 or len(text) < 5:
        return text

    typo_type = rng.choice(["swap", "delete", "duplicate", "replace"])
    words = text.split()
    if not words:
        return text
    word_idx = rng.integers(0, len(words))
    word = words[word_idx]
    if len(word) < 2:
        return text

    char_idx = rng.integers(0, len(word))
    if typo_type == "swap" and char_idx < len(word) - 1:
        word = word[:char_idx] + word[char_idx + 1] + word[char_idx] + word[char_idx + 2:]
    elif typo_type == "delete":
        word = word[:char_idx] + word[char_idx + 1:]
    elif typo_type == "duplicate" and char_idx < len(word) - 1:
        word = word[:char_idx] + word[char_idx] + word[char_idx:]
    elif typo_type == "replace":
        replacement = chr(rng.integers(97, 123))
        word = word[:char_idx] + replacement + word[char_idx + 1:]

    words[word_idx] = word
    return " ".join(words)


def should_generate_expense(
    persona: Persona, activity_rate: float, temporal_modifier: float,
    is_weekend: bool, rng: np.random.Generator,
) -> bool:
    effective_rate = activity_rate * min(temporal_modifier, 2.0)
    if is_weekend:
        effective_rate *= 1.15
    effective_rate = min(0.95, effective_rate)
    return rng.random() < effective_rate


def determine_num_expenses(
    persona: Persona, rng: np.random.Generator,
) -> int:
    lam = PERSONA_PARAMS[persona]["expenses_per_day_lambda"]
    n = rng.poisson(lam)
    return max(1, min(n, 8))


def pick_category(
    category_weights: dict, rng: np.random.Generator,
    wrong_category: bool = False,
) -> Tuple:
    from config import Category, Subcategory, CATEGORY_SUBCATEGORIES
    cats = list(category_weights.keys())
    probs = list(category_weights.values())
    total = sum(probs)
    probs = [p / total for p in probs]

    category = rng.choice(cats, p=probs)

    if wrong_category:
        other_cats = [c for c in cats if c != category]
        category = rng.choice(other_cats)

    subs = CATEGORY_SUBCATEGORIES[category]
    return category, subs


def pick_subcategory(
    category: Category, subcategory_weights: dict, rng: np.random.Generator,
) -> Subcategory:
    subs = list(subcategory_weights[category].keys())
    probs = list(subcategory_weights[category].values())
    total = sum(probs)
    probs = [p / total for p in probs]
    return rng.choice(subs, p=probs)


RECURRING_EXPENSES = [
    {
        "category": Category.HOUSING, "subcategory": Subcategory.RENT,
        "description": "Monthly rent", "amount_range": (800, 2500),
        "frequency": "monthly", "day_of_month": 1,
    },
    {
        "category": Category.HOUSING, "subcategory": Subcategory.UTILITIES,
        "description": "Electricity bill", "amount_range": (50, 200),
        "frequency": "monthly", "day_of_month": 5,
    },
    {
        "category": Category.SUBSCRIPTIONS, "subcategory": Subcategory.STREAMING,
        "description": "Streaming subscription", "amount_range": (10, 25),
        "frequency": "monthly", "day_of_month": 15,
    },
    {
        "category": Category.HEALTH, "subcategory": Subcategory.GYM,
        "description": "Gym membership", "amount_range": (30, 80),
        "frequency": "monthly", "day_of_month": 1,
    },
]


def generate_group_expense_description(
    category: Category, subcategory: Subcategory,
    group_name: str, num_members: int, rng: np.random.Generator,
) -> str:
    base = generate_description(category, subcategory, 0, rng)
    group_suffixes = [
        f" - {group_name}",
        f" ({group_name} outing)",
        f" with {group_name}",
        f" - {group_name} ({num_members} people)",
        f" ({group_name} split)",
    ]
    return base + rng.choice(group_suffixes)