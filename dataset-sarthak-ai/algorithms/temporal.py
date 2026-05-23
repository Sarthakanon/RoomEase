import numpy as np
from datetime import date, timedelta
from typing import Dict


DAY_OF_WEEK_MODIFIERS = {
    0: 0.85, 1: 0.82, 2: 0.85, 3: 0.95,
    4: 1.15, 5: 1.35, 6: 1.10,
}

DAY_OF_MONTH_MODIFIERS = {}
for d in range(1, 32):
    if d <= 3:
        DAY_OF_MONTH_MODIFIERS[d] = 1.25
    elif d <= 24:
        DAY_OF_MONTH_MODIFIERS[d] = 1.0
    else:
        DAY_OF_MONTH_MODIFIERS[d] = 0.85

MONTH_OF_YEAR_MODIFIERS = {
    1: 0.90, 2: 0.95, 3: 1.0, 4: 1.0, 5: 1.05, 6: 1.15,
    7: 1.15, 8: 1.10, 9: 0.95, 10: 1.0, 11: 1.10, 12: 1.30,
}

FESTIVAL_DATES: Dict[int, Dict] = {
    1: {"new_years": [(1, 1)], "mlk": [(1, 18)]},
    2: {"valentines": [(2, 14)], "presidents": [(2, 15)]},
    3: {"st_patricks": [(3, 17)]},
    4: {"easter_range": [(4, 5), (4, 12)]},
    5: {"memorial": [(5, 25)], "mothers": [(5, 10)]},
    6: {"fathers": [(6, 21)]},
    7: {"independence": [(7, 4)]},
    9: {"labor": [(9, 7)]},
    10: {"halloween": [(10, 31)]},
    11: {"thanksgiving": [(11, 26)], "black_friday": [(11, 27)]},
    12: {"christmas": [(12, 25)], "new_years_eve": [(12, 31)]},
}

FESTIVAL_BOOST = {
    "christmas": 1.60, "black_friday": 1.70, "thanksgiving": 1.45,
    "new_years": 1.40, "new_years_eve": 1.55, "valentines": 1.35,
    "halloween": 1.25, "independence": 1.20, "memorial": 1.15,
    "st_patricks": 1.15, "easter_range": 1.20, "mothers": 1.20,
    "fathers": 1.15, "labor": 1.10, "mlk": 1.05, "presidents": 1.05,
}


def get_day_of_week_modifier(d: date) -> float:
    return DAY_OF_WEEK_MODIFIERS.get(d.weekday(), 1.0)


def get_day_of_month_modifier(d: date) -> float:
    return DAY_OF_MONTH_MODIFIERS.get(d.day, 0.85)


def get_month_modifier(d: date) -> float:
    return MONTH_OF_YEAR_MODIFIERS.get(d.month, 1.0)


def get_year_modifier(d: date, base_year: int = 2016, inflation_rate: float = 0.035) -> float:
    years_elapsed = d.year - base_year
    return (1 + inflation_rate) ** years_elapsed


def get_festival_modifier(d: date) -> float:
    month_data = FESTIVAL_DATES.get(d.month, {})
    max_boost = 1.0
    for festival_name, dates_list in month_data.items():
        for fest_month, fest_day in dates_list:
            days_diff = abs(d.day - fest_day)
            if d.month == fest_month:
                if days_diff == 0:
                    max_boost = max(max_boost, FESTIVAL_BOOST.get(festival_name, 1.05))
                elif days_diff == 1:
                    max_boost = max(max_boost, FESTIVAL_BOOST.get(festival_name, 1.05) * 0.7)
                elif days_diff <= 3:
                    max_boost = max(max_boost, FESTIVAL_BOOST.get(festival_name, 1.05) * 0.4)
    return max_boost


def get_autocorrelation_modifier(
    yesterday_total: float, user_avg_daily: float, rng: np.random.Generator
) -> float:
    if user_avg_daily <= 0:
        return 1.0
    ratio = yesterday_total / user_avg_daily
    if rng.random() > 0.6:
        return 1.0
    if ratio > 2.0:
        return 0.8
    elif ratio > 1.5:
        return 0.9
    elif ratio < 0.5:
        return 1.15
    elif ratio < 0.3:
        return 1.25
    return 1.0


def compute_temporal_modifier(
    d: date,
    base_year: int = 2016,
    inflation_rate: float = 0.035,
    yesterday_total: float = 0,
    user_avg_daily: float = 50,
    rng: np.random.Generator = None,
) -> float:
    dow = get_day_of_week_modifier(d)
    dom = get_day_of_month_modifier(d)
    moy = get_month_modifier(d)
    year = get_year_modifier(d, base_year, inflation_rate)
    festival = get_festival_modifier(d)
    autocorr = 1.0
    if rng is not None:
        autocorr = get_autocorrelation_modifier(yesterday_total, user_avg_daily, rng)
    return dow * dom * moy * year * festival * autocorr


def get_time_of_day(category, rng: np.random.Generator) -> int:
    from config import TIME_OF_DAY_PROFILES, Category
    profile = TIME_OF_DAY_PROFILES.get(category, TIME_OF_DAY_PROFILES[Category.FOOD_DINING])
    periods = list(profile.keys())
    probs = list(profile.values())
    period = rng.choice(periods, p=probs)
    ranges = {
        "morning": (6, 10), "lunch": (11, 14), "afternoon": (14, 17),
        "dinner": (17, 21), "night": (21, 2),
    }
    start, end = ranges[period]
    if start > end:
        hour = rng.choice(list(range(start, 24)) + list(range(0, end)))
    else:
        hour = rng.integers(start, end)
    minute = rng.integers(0, 60)
    return hour * 60 + minute