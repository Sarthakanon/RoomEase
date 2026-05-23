import numpy as np
from typing import Dict, List, Tuple
from config import (
    Persona, Category, Subcategory, LocationTier, PERSONA_PARAMS,
    CATEGORY_SUBCATEGORIES, CATEGORY_WEIGHTS_DEFAULT, SUBCATEGORY_WEIGHTS,
    LOCATION_MULTIPLIER, GenerationConfig,
)


def generate_user_persona(rng: np.random.Generator, config: GenerationConfig) -> Persona:
    personas = list(config.person_distribution.keys())
    probs = list(config.person_distribution.values())
    return rng.choice(personas, p=probs)


def compute_category_weights(
    persona: Persona, age: int, rng: np.random.Generator
) -> Dict[Category, float]:
    base = PERSONA_PARAMS[persona]["category_bias"].copy()
    if age < 25:
        base[Category.ENTERTAINMENT] *= 1.3
        base[Category.SHOPPING] *= 1.2
        base[Category.EDUCATION] *= 1.4
        base[Category.HOUSING] *= 0.7
    elif age > 50:
        base[Category.HEALTH] *= 1.5
        base[Category.GIFTS_DONATIONS] *= 1.3
        base[Category.ENTERTAINMENT] *= 0.7
        base[Category.EDUCATION] *= 0.6

    total = sum(base.values())
    normalized = {k: v / total for k, v in base.items()}
    noise = rng.normal(0, 0.01, size=len(normalized))
    final = {}
    for i, (k, v) in enumerate(normalized.items()):
        final[k] = max(0.01, v + noise[i])
    total = sum(final.values())
    return {k: v / total for k, v in final.items()}


def compute_subcategory_weights(
    category_weights: Dict[Category, float], rng: np.random.Generator
) -> Dict[Category, Dict[Subcategory, float]]:
    result = {}
    for cat in category_weights:
        sub_weights = SUBCATEGORY_WEIGHTS[cat].copy()
        noise = rng.normal(0, 0.02, size=len(sub_weights))
        final = {}
        for i, (sub, w) in enumerate(sub_weights.items()):
            final[sub] = max(0.01, w + noise[i])
        total = sum(final.values())
        result[cat] = {k: v / total for k, v in final.items()}
    return result


def compute_spending_multiplier(
    persona: Persona, income: float, location_tier: LocationTier, rng: np.random.Generator
) -> float:
    base_multiplier = PERSONA_PARAMS[persona]["daily_spend_base"] / 50.0
    income_factor = np.log1p(income) / np.log1p(50000)
    location_factor = LOCATION_MULTIPLIER[location_tier]
    noise = 1 + rng.normal(0, 0.1)
    return base_multiplier * income_factor * location_factor * noise


def generate_churn_periods(
    join_date, config: GenerationConfig, rng: np.random.Generator
) -> List[Tuple[int, int]]:
    if rng.random() > config.tracking_gap_rate:
        return []
    from datetime import date as date_cls
    end_date = date_cls.fromisoformat(config.end_date) if isinstance(config.end_date, str) else config.end_date
    join_year = join_date if isinstance(join_date, int) else join_date.year
    span = end_date.year - join_year
    if span < 1:
        return []
    num_gaps = rng.integers(1, 4)
    gaps = []
    for _ in range(num_gaps):
        gap_year = rng.integers(join_year, end_date.year)
        gap_start_month = rng.integers(1, 12)
        gap_duration = rng.integers(1, 4)
        gap_end_month = min(gap_start_month + gap_duration, 12)
        if gap_year < end_date.year or gap_end_month <= 12:
            gaps.append((gap_year, gap_start_month, gap_end_month))
    return gaps


def is_in_churn_period(date_obj, churn_periods) -> bool:
    for year, start_month, end_month in churn_periods:
        if date_obj.year == year and start_month <= date_obj.month <= end_month:
            return True
    return False


def generate_income(persona: Persona, rng: np.random.Generator) -> float:
    base_incomes = {
        Persona.FRUGAL: 30000,
        Persona.CONSERVATIVE: 45000,
        Persona.MODERATE: 55000,
        Persona.LIFESTYLE: 70000,
        Persona.SPENDER: 65000,
        Persona.OCCASIONAL_SPLURGER: 50000,
    }
    base = base_incomes[persona]
    noise_factor = np.exp(rng.normal(0, 0.4))
    return round(base * noise_factor, -3)