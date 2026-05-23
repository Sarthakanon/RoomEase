import numpy as np
from datetime import date, timedelta
from typing import Dict, List, Tuple
from config import GroupType, GROUP_TYPE_PARAMS


def generate_group_birthdays(
    start_date: date, end_date: date, num_groups: int, rng: np.random.Generator
) -> List[date]:
    total_days = (end_date - start_date).days
    growth_pattern = np.zeros(total_days)
    for i in range(total_days):
        t = i / total_days
        growth_pattern[i] = np.exp(-3 * (t - 0.2) ** 2) + 0.3 * np.exp(-5 * (t - 0.6) ** 2) + 0.1
    growth_pattern = growth_pattern / growth_pattern.sum()
    days_offset = rng.choice(total_days, size=num_groups, p=growth_pattern)
    return [start_date + timedelta(days=int(d)) for d in days_offset]


def generate_group_type(rng: np.random.Generator) -> GroupType:
    weights = {
        GroupType.HOUSEHOLD: 0.22, GroupType.FRIENDS: 0.25,
        GroupType.OFFICE: 0.20, GroupType.TRAVEL: 0.10,
        GroupType.FAMILY: 0.13, GroupType.PROJECT: 0.10,
    }
    types = list(weights.keys())
    probs = list(weights.values())
    return rng.choice(types, p=probs)


def assign_group_members(
    group_type: GroupType, user_ids: List[str], rng: np.random.Generator
) -> List[str]:
    params = GROUP_TYPE_PARAMS[group_type]
    min_size, max_size = params["size_range"]
    size = rng.integers(min_size, max_size + 1)
    size = min(size, len(user_ids))
    return list(rng.choice(user_ids, size=size, replace=False))


def compute_group_activity_probability(
    group_type: GroupType, d: date, rng: np.random.Generator
) -> float:
    params = GROUP_TYPE_PARAMS[group_type]
    base_prob = params["activity_freq"]

    if d.weekday() >= 5:
        if group_type in [GroupType.FRIENDS, GroupType.TRAVEL, GroupType.FAMILY]:
            base_prob *= 1.4
        elif group_type == GroupType.OFFICE:
            base_prob *= 0.3
        elif group_type == GroupType.PROJECT:
            base_prob *= 0.5

    month_modifiers = {
        12: 1.3, 11: 1.15, 7: 1.2, 6: 1.15, 8: 1.1, 1: 0.85,
    }
    base_prob *= month_modifiers.get(d.month, 1.0)

    noise = rng.normal(1.0, 0.1)
    base_prob *= max(0.5, noise)

    return min(0.95, max(0.01, base_prob))


def determine_group_split_method(
    group_type: GroupType, rng: np.random.Generator
) -> str:
    params = GROUP_TYPE_PARAMS[group_type]
    methods = list(params["split_methods"].keys())
    probs = list(params["split_methods"].values())
    return rng.choice(methods, p=probs)


def compute_group_dormancy(
    created_date: date, group_type: GroupType, rng: np.random.Generator
) -> Tuple[int, bool]:
    params = GROUP_TYPE_PARAMS[group_type]
    min_months, max_months = params["lifespan_months"]
    lifespan_months = rng.integers(min_months, max_months + 1)
    becomes_dormant = rng.random() < 0.15
    return lifespan_months, becomes_dormant


GROUP_NAMES = {
    GroupType.HOUSEHOLD: [
        "Apartment {n}", "{name} Household", "Home Sweet Home {n}",
        "Room {n} Crew", "The Residents {n}",
    ],
    GroupType.FRIENDS: [
        "Weekend Warriors", "Foodie Friends", "The Squad {n}",
        "{name}'s Crew", "Good Times {n}", "Brunch Bunch",
        "Movie Night Gang", "Game Night Regulars",
    ],
    GroupType.OFFICE: [
        "Lunch Crew {n}", "Office Snacks", "Team {n}", "Coffee Fund",
        "{name} Team", "Floor {n} Gang",
    ],
    GroupType.TRAVEL: [
        "Trip to {dest} {n}", "Vacation Fund {n}", "{dest} Adventure",
        "{dest} Crew {n}", "Wanderlust {n}",
    ],
    GroupType.FAMILY: [
        "{name} Family", "Family Matters {n}", "The {name}s",
        "Family Fund {n}", "Home Base {n}",
    ],
    GroupType.PROJECT: [
        "Project {name} {n}", "Sprint {n} Team", "Collab {n}",
        "Task Force {n}", "Working Group {n}",
    ],
}

DESTINATIONS = [
    "Goa", "Bali", "Paris", "Thailand", "Japan", "Dubai",
    "Hawaii", "Italy", "Spain", "London", "NYC", "Vegas",
]


def generate_group_name(
    group_type: GroupType, rng: np.random.Generator, names_pool: List[str] = None
) -> str:
    templates = GROUP_NAMES[group_type]
    template = rng.choice(templates)
    n = rng.integers(1, 100)
    if names_pool:
        name = rng.choice(names_pool)
    else:
        name = f"Group{n}"
    dest = rng.choice(DESTINATIONS)
    return template.format(n=n, name=name, dest=dest)


def compute_split_shares(
    members: List[str], split_method: str, amounts_paid: Dict[str, float],
    total_amount: float, rng: np.random.Generator,
) -> Dict[str, float]:
    num_members = len(members)
    if num_members == 0:
        return {}

    if split_method == "equal":
        share = round(total_amount / num_members, 2)
        remainder = round(total_amount - share * num_members, 2)
        shares = {m: share for m in members}
        shares[members[0]] = round(shares[members[0]] + remainder, 2)
        return shares

    elif split_method == "percentage":
        raw = rng.dirichlet(np.ones(num_members))
        percentages = raw / raw.sum()
        shares = {}
        for i, m in enumerate(members):
            shares[m] = round(total_amount * percentages[i], 2)
        total = sum(shares.values())
        diff = round(total_amount - total, 2)
        shares[members[0]] = round(shares[members[0]] + diff, 2)
        return shares

    else:
        weights = rng.exponential(1, size=num_members)
        weights = weights / weights.sum()
        shares = {}
        for i, m in enumerate(members):
            shares[m] = round(total_amount * weights[i], 2)
        total = sum(shares.values())
        diff = round(total_amount - total, 2)
        shares[members[0]] = round(shares[members[0]] + diff, 2)
        return shares