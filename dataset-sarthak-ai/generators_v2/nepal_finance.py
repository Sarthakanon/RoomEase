"""
File: generators_v2/nepal_finance.py
What does this file do?
    Generates Nepal-focused personal finance, income, budget, recurring payment,
    group, shared expense, and currency-rate datasets for V2 model training.
Methods/functions this file contains:
    _date_range, _festival_multiplier, _month_key, _sample_lognormal_between,
    _category_weights_for_persona, generate_users, generate_income_events,
    generate_budgets_and_goals, generate_groups, generate_expenses,
    write_dataset.
Date and Day of last modification:
    2026-05-16, Saturday.
"""

from __future__ import annotations

from datetime import date, datetime, timedelta
from pathlib import Path
from typing import Dict, Iterable, List, Tuple

import numpy as np
import pandas as pd

from config_v2 import (
    CATEGORIES,
    CITY_TIERS,
    CURRENCY_RATES_TO_NPR,
    DAILY_CATEGORY_WEIGHTS,
    FESTIVAL_WINDOWS,
    GROUP_TYPES,
    NepalFinanceConfig,
    PAYMENT_METHODS,
    PERSONAS,
    RECURRING_CATEGORY_SCHEDULE,
    weighted_choice,
)


def _date_range(start: date, end: date) -> Iterable[date]:
    current = start
    while current <= end:
        yield current
        current += timedelta(days=1)


def _festival_multiplier(day: date) -> Tuple[float, str]:
    for window in FESTIVAL_WINDOWS:
        if day.month == window["month"] and window["start_day"] <= day.day <= window["end_day"]:
            return float(window["multiplier"]), str(window["name"])
    return 1.0, ""


def _month_key(day: date) -> str:
    return f"{day.year}-{day.month:02d}"


def _sample_lognormal_between(rng: np.random.Generator, low: float, high: float) -> float:
    median = (low + high) / 2
    sigma = 0.55
    value = rng.lognormal(mean=np.log(max(median, 1)), sigma=sigma)
    return float(np.clip(value, low, high * 1.7))


def _category_weights_for_persona(persona: str) -> Dict[str, float]:
    weights = {category: float(DAILY_CATEGORY_WEIGHTS.get(category, 1.0)) for category in CATEGORIES}
    for category, multiplier in PERSONAS[persona]["category_bias"].items():
        weights[category] = weights.get(category, 1.0) * float(multiplier)
    return weights


def generate_users(config: NepalFinanceConfig, rng: np.random.Generator) -> pd.DataFrame:
    persona_weights = {name: float(data["weight"]) for name, data in PERSONAS.items()}
    city_weights = {name: float(data["weight"]) for name, data in CITY_TIERS.items()}

    rows = []
    for idx in range(1, config.num_users + 1):
        persona = weighted_choice(rng, persona_weights)
        city_tier = weighted_choice(rng, city_weights)
        persona_data = PERSONAS[persona]
        low, high = persona_data["income"]
        monthly_income = round(_sample_lognormal_between(rng, low, high), -2)
        income_type = "fixed"
        if persona == "freelancer_irregular_income":
            income_type = "irregular"
        elif persona == "business_owner_cash_heavy":
            income_type = "mixed"

        rows.append(
            {
                "user_id": f"NPU_{idx:05d}",
                "age": int(rng.integers(18, 66)),
                "occupation_type": persona.split("_")[0] if not persona.startswith("business") else "business_owner",
                "city_tier": city_tier,
                "monthly_income_npr": float(monthly_income),
                "income_type": income_type,
                "family_dependency_count": int(rng.choice([0, 1, 2, 3, 4], p=[0.28, 0.24, 0.22, 0.16, 0.10])),
                "rent_status": str(rng.choice(["renter", "family_home", "owner"], p=[0.48, 0.36, 0.16])),
                "financial_persona": persona,
                "activity_rate": float(persona_data["activity"]),
                "spend_multiplier": float(persona_data["spend_multiplier"]),
                "saving_rate": float(persona_data["saving_rate"]),
                "shared_tendency": float(persona_data["shared_tendency"]),
                "city_price_multiplier": float(CITY_TIERS[city_tier]["price_multiplier"]),
            }
        )
    return pd.DataFrame(rows)


def generate_income_events(users: pd.DataFrame, config: NepalFinanceConfig, rng: np.random.Generator) -> pd.DataFrame:
    rows = []
    for user in users.to_dict("records"):
        for month_start in pd.date_range(config.start_date, config.end_date, freq="MS"):
            base_income = float(user["monthly_income_npr"])
            income_type = user["income_type"]
            if income_type == "fixed":
                amount = base_income * rng.normal(1.0, 0.02)
                day_offset = int(rng.choice([0, 1, 2, 3, 4], p=[0.40, 0.24, 0.16, 0.12, 0.08]))
                source = "salary"
            elif income_type == "irregular":
                amount = base_income * rng.lognormal(0.0, 0.45)
                day_offset = int(rng.integers(0, 24))
                source = "freelance"
                if rng.random() < 0.18:
                    amount *= 0.35
            else:
                amount = base_income * rng.lognormal(0.0, 0.30)
                day_offset = int(rng.choice([0, 5, 10, 15, 20]))
                source = "business"

            income_date = (month_start + pd.Timedelta(days=day_offset)).date()
            rows.append(
                {
                    "income_id": f"INC_{user['user_id']}_{month_start.strftime('%Y%m')}",
                    "user_id": user["user_id"],
                    "income_date": income_date.isoformat(),
                    "income_amount_npr": round(max(amount, 0), 2),
                    "income_source": source,
                    "is_expected": True,
                }
            )
    return pd.DataFrame(rows)


def generate_budgets_and_goals(users: pd.DataFrame, config: NepalFinanceConfig, rng: np.random.Generator) -> Tuple[pd.DataFrame, pd.DataFrame]:
    budgets = []
    goals = []
    for user in users.to_dict("records"):
        disposable = float(user["monthly_income_npr"])
        budget_total = disposable * rng.uniform(0.82, 1.35)
        category_weights = _category_weights_for_persona(str(user["financial_persona"]))
        weight_sum = sum(category_weights.values())
        for category, weight in category_weights.items():
            budgets.append(
                {
                    "budget_id": f"BUD_{user['user_id']}_{category}",
                    "user_id": user["user_id"],
                    "category": category,
                    "monthly_budget_npr": round(budget_total * weight / weight_sum, 2),
                }
            )
        goals.append(
            {
                "goal_id": f"GOAL_{user['user_id']}",
                "user_id": user["user_id"],
                "goal_type": str(rng.choice(["emergency_fund", "education", "travel", "debt_reduction", "device_purchase"])),
                "target_amount_npr": round(disposable * rng.uniform(1.5, 8.0), 2),
                "monthly_target_npr": round(disposable * float(user["saving_rate"]), 2),
            }
        )
    return pd.DataFrame(budgets), pd.DataFrame(goals)


def generate_groups(users: pd.DataFrame, config: NepalFinanceConfig, rng: np.random.Generator) -> Tuple[pd.DataFrame, pd.DataFrame]:
    group_weights = {name: float(data["weight"]) for name, data in GROUP_TYPES.items()}
    groups = []
    memberships = []
    user_ids = users["user_id"].tolist()
    for idx in range(1, config.num_groups + 1):
        group_type = weighted_choice(rng, group_weights)
        min_size, max_size = GROUP_TYPES[group_type]["size"]
        size = int(rng.integers(min_size, max_size + 1))
        members = rng.choice(user_ids, size=min(size, len(user_ids)), replace=False)
        group_id = f"NPG_{idx:05d}"
        groups.append(
            {
                "group_id": group_id,
                "group_type": group_type,
                "created_date": config.start_date.isoformat(),
                "default_split_method": str(rng.choice(["equal", "custom", "percentage"], p=[0.72, 0.18, 0.10])),
                "activity_rate": float(GROUP_TYPES[group_type]["activity"]),
            }
        )
        for member in members:
            memberships.append(
                {
                    "membership_id": f"MEM_{group_id}_{member}",
                    "group_id": group_id,
                    "user_id": member,
                    "joined_date": config.start_date.isoformat(),
                    "role": "member",
                }
            )
    return pd.DataFrame(groups), pd.DataFrame(memberships)


def generate_expenses(
    users: pd.DataFrame,
    groups: pd.DataFrame,
    memberships: pd.DataFrame,
    config: NepalFinanceConfig,
    rng: np.random.Generator,
) -> Tuple[pd.DataFrame, pd.DataFrame, pd.DataFrame, pd.DataFrame]:
    expense_rows: List[Dict[str, object]] = []
    shared_rows: List[Dict[str, object]] = []
    split_rows: List[Dict[str, object]] = []
    recurring_rows: List[Dict[str, object]] = []
    expense_index = 1

    user_lookup = {row["user_id"]: row for row in users.to_dict("records")}
    group_members = memberships.groupby("group_id")["user_id"].apply(list).to_dict()

    for day in _date_range(config.start_date, config.end_date):
        weekend_multiplier = 1.25 if day.weekday() >= 5 else 1.0
        payday_multiplier = 1.12 if day.day in [1, 2, 3, 15, 16] else 1.0
        festival_multiplier, festival_name = _festival_multiplier(day)

        for user in users.to_dict("records"):
            for recurring_category, schedule in RECURRING_CATEGORY_SCHEDULE.items():
                if day.day != int(schedule["day"]):
                    continue
                probability = float(schedule["probability"])
                if recurring_category == "rent" and user["rent_status"] != "renter":
                    probability *= 0.12
                if recurring_category == "family_support":
                    probability *= 1 + 0.16 * int(user["family_dependency_count"])
                if recurring_category == "loan_emi" and user["financial_persona"] == "debt_repayment_user":
                    probability *= 2.2
                if recurring_category == "savings_investment":
                    probability *= max(float(user["saving_rate"]) / 0.10, 0.15)
                if rng.random() > min(probability, 0.95):
                    continue

                low, high = CATEGORIES[recurring_category]["base"]
                amount_npr = _sample_lognormal_between(rng, float(low), float(high))
                amount_npr *= float(user["city_price_multiplier"])
                if recurring_category == "savings_investment":
                    amount_npr = max(float(user["monthly_income_npr"]) * float(user["saving_rate"]) * rng.uniform(0.70, 1.25), 250)
                if recurring_category == "family_support":
                    amount_npr *= 1 + 0.22 * int(user["family_dependency_count"])

                expense_id = f"NPE_{expense_index:08d}"
                expense_index += 1
                payment_method = weighted_choice(rng, PAYMENT_METHODS)
                expense_rows.append(
                    {
                        "expense_id": expense_id,
                        "user_id": user["user_id"],
                        "date": day.isoformat(),
                        "amount_original": round(amount_npr, 2),
                        "currency_code": "NPR",
                        "exchange_rate_to_npr": 1.0,
                        "amount_npr": round(amount_npr, 2),
                        "category": recurring_category,
                        "subcategory": recurring_category,
                        "merchant_name": f"{recurring_category}_provider",
                        "payment_method": payment_method,
                        "is_shared": False,
                        "group_id": "",
                        "is_recurring": True,
                        "is_essential": bool(CATEGORIES[recurring_category]["essential"]),
                        "note_quality": "clear",
                        "logged_delay_hours": int(rng.choice([0, 1, 3, 24], p=[0.45, 0.25, 0.20, 0.10])),
                        "festival_context": festival_name,
                        "created_at": datetime.combine(day, datetime.min.time()).isoformat(),
                    }
                )

            if rng.random() > float(user["activity_rate"]) * weekend_multiplier:
                continue

            category_weights = _category_weights_for_persona(str(user["financial_persona"]))
            if festival_name:
                category_weights["festivals_gifts"] *= 4.0
                category_weights["clothing"] *= 2.0
                category_weights["travel"] *= 1.7

            num_expenses = int(rng.poisson(0.55) + 1)
            for _ in range(num_expenses):
                category = weighted_choice(rng, category_weights)
                low, high = CATEGORIES[category]["base"]
                amount_npr = _sample_lognormal_between(rng, float(low), float(high))
                amount_npr *= float(user["spend_multiplier"])
                amount_npr *= float(user["city_price_multiplier"])
                amount_npr *= payday_multiplier
                amount_npr *= festival_multiplier if category in ["festivals_gifts", "clothing", "travel", "restaurants_cafes"] else 1.0
                amount_npr *= 0.58

                if rng.random() < 0.012:
                    amount_npr *= rng.uniform(3.0, 8.0)
                if rng.random() < 0.004:
                    amount_npr *= -0.4

                currency = "NPR"
                if category == "subscriptions" and rng.random() < 0.10:
                    currency = "USD"
                elif category in ["travel", "education"] and rng.random() < 0.06:
                    currency = "INR"
                rate = CURRENCY_RATES_TO_NPR[currency]
                amount_original = amount_npr / rate

                logged_delay_hours = int(rng.choice([0, 1, 3, 8, 24, 72, 168], p=[0.36, 0.20, 0.15, 0.10, 0.10, 0.06, 0.03]))
                note_quality = str(rng.choice(["clear", "short", "missing", "wrong_category"], p=[0.58, 0.27, 0.10, 0.05]))
                payment_method = weighted_choice(rng, PAYMENT_METHODS)
                expense_id = f"NPE_{expense_index:08d}"
                expense_index += 1

                expense_rows.append(
                    {
                        "expense_id": expense_id,
                        "user_id": user["user_id"],
                        "date": day.isoformat(),
                        "amount_original": round(amount_original, 2),
                        "currency_code": currency,
                        "exchange_rate_to_npr": rate,
                        "amount_npr": round(amount_npr, 2),
                        "category": category,
                        "subcategory": category,
                        "merchant_name": "" if rng.random() < 0.35 else f"{category}_merchant",
                        "payment_method": payment_method,
                        "is_shared": False,
                        "group_id": "",
                        "is_recurring": False,
                        "is_essential": bool(CATEGORIES[category]["essential"]),
                        "note_quality": note_quality,
                        "logged_delay_hours": logged_delay_hours,
                        "festival_context": festival_name,
                        "created_at": datetime.combine(day, datetime.min.time()).isoformat(),
                    }
                )

        for group in groups.to_dict("records"):
            if rng.random() > float(group["activity_rate"]) * weekend_multiplier * (1.6 if festival_name else 1.0):
                continue
            members = group_members.get(group["group_id"], [])
            if len(members) < 2:
                continue
            payer = str(rng.choice(members))
            payer_user = user_lookup[payer]
            category = str(
                rng.choice(
                    ["restaurants_cafes", "groceries", "travel", "festivals_gifts", "entertainment", "utilities"],
                    p=[0.30, 0.22, 0.08, 0.10, 0.18, 0.12],
                )
            )
            low, high = CATEGORIES[category]["base"]
            amount_npr = _sample_lognormal_between(rng, float(low), float(high)) * len(members) * 0.32
            amount_npr *= float(payer_user["city_price_multiplier"])
            if festival_name and category in ["festivals_gifts", "travel", "restaurants_cafes"]:
                amount_npr *= festival_multiplier

            expense_id = f"NPE_{expense_index:08d}"
            shared_id = f"SHR_{expense_index:08d}"
            expense_index += 1
            split_type = str(group["default_split_method"])
            amount_per_person = amount_npr / max(len(members), 1)
            settlement_pressure = (
                2.5
                + amount_per_person / 3500
                + len(members) * 0.45
                + (3.0 if split_type == "custom" else 0.0)
                + (2.0 if split_type == "percentage" else 0.0)
                + (4.0 if festival_name else 0.0)
            )
            days_to_settle = int(max(0, rng.normal(settlement_pressure, 4.5) + rng.gamma(1.3, 1.8)))
            settlement_status = "settled" if days_to_settle <= 21 else "pending"

            expense_rows.append(
                {
                    "expense_id": expense_id,
                    "user_id": payer,
                    "date": day.isoformat(),
                    "amount_original": round(amount_npr, 2),
                    "currency_code": "NPR",
                    "exchange_rate_to_npr": 1.0,
                    "amount_npr": round(amount_npr, 2),
                    "category": category,
                    "subcategory": category,
                    "merchant_name": f"group_{category}",
                    "payment_method": weighted_choice(rng, PAYMENT_METHODS),
                    "is_shared": True,
                    "group_id": group["group_id"],
                    "is_recurring": False,
                    "is_essential": bool(CATEGORIES[category]["essential"]),
                    "note_quality": "clear",
                    "logged_delay_hours": int(rng.choice([0, 3, 24, 72])),
                    "festival_context": festival_name,
                    "created_at": datetime.combine(day, datetime.min.time()).isoformat(),
                }
            )
            shared_rows.append(
                {
                    "shared_expense_id": shared_id,
                    "expense_id": expense_id,
                    "group_id": group["group_id"],
                    "paid_by_user_id": payer,
                    "split_type": split_type,
                    "participant_count": len(members),
                    "settlement_status": settlement_status,
                    "days_to_settle": days_to_settle,
                }
            )
            for member in members:
                split_rows.append(
                    {
                        "split_id": f"SPL_{expense_id}_{member}",
                        "expense_id": expense_id,
                        "group_id": group["group_id"],
                        "user_id": member,
                        "owed_amount_npr": round(amount_npr / len(members), 2),
                        "paid_by_user_id": payer,
                        "settlement_status": settlement_status if member != payer else "paid_by_self",
                    }
                )

    expenses = pd.DataFrame(expense_rows)
    recurring = expenses[expenses["is_recurring"]].copy()
    if not recurring.empty:
        recurring_rows = [
            {
                "recurring_id": f"REC_{row.expense_id}",
                "user_id": row.user_id,
                "category": row.category,
                "expected_amount_npr": row.amount_npr,
                "frequency": "monthly",
                "payment_method": row.payment_method,
            }
            for row in recurring.itertuples()
        ]
    return expenses, pd.DataFrame(shared_rows), pd.DataFrame(split_rows), pd.DataFrame(recurring_rows)


def write_dataset(config: NepalFinanceConfig) -> Dict[str, int]:
    rng = np.random.default_rng(config.seed)
    output_dir = Path(config.output_dir)
    output_dir.mkdir(parents=True, exist_ok=True)

    users = generate_users(config, rng)
    incomes = generate_income_events(users, config, rng)
    budgets, goals = generate_budgets_and_goals(users, config, rng)
    groups, memberships = generate_groups(users, config, rng)
    expenses, shared_expenses, splits, recurring = generate_expenses(users, groups, memberships, config, rng)

    currency_rates = pd.DataFrame(
        [{"currency_code": code, "rate_to_npr": rate, "effective_date": config.start_date.isoformat()} for code, rate in CURRENCY_RATES_TO_NPR.items()]
    )
    festival_calendar = pd.DataFrame(FESTIVAL_WINDOWS)

    tables = {
        "users.csv": users,
        "income_events.csv": incomes,
        "budgets.csv": budgets,
        "goals.csv": goals,
        "groups.csv": groups,
        "group_memberships.csv": memberships,
        "expenses.csv": expenses,
        "shared_expenses.csv": shared_expenses,
        "expense_splits.csv": splits,
        "recurring_payments.csv": recurring,
        "currency_rates.csv": currency_rates,
        "festival_calendar.csv": festival_calendar,
    }
    for filename, frame in tables.items():
        frame.to_csv(output_dir / filename, index=False)

    return {filename: len(frame) for filename, frame in tables.items()}
