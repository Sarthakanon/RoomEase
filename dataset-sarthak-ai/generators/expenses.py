import numpy as np
import pandas as pd
from datetime import date, timedelta, datetime
from typing import List, Dict, Tuple
from collections import defaultdict

from config import (
    GenerationConfig, Category, Subcategory, CATEGORY_SUBCATEGORIES,
    CATEGORY_AMOUNT_PARAMS, PERSONA_PARAMS, CATEGORY_WEIGHTS_DEFAULT,
    LOCATION_MULTIPLIER, GroupType, GROUP_TYPE_PARAMS,
)
from models import User, Group, GroupMembership, Expense, ExpenseSplit
from algorithms.personas import is_in_churn_period
from algorithms.temporal import compute_temporal_modifier, get_time_of_day
from algorithms.groups import (
    compute_group_activity_probability, compute_split_shares,
    compute_group_dormancy,
)
from algorithms.expenses import (
    generate_amount, generate_description, apply_typo, should_generate_expense,
    determine_num_expenses, pick_category, pick_subcategory,
    generate_group_expense_description, RECURRING_EXPENSES,
)


def _precompute_temporal_modifiers(
    start_date: date, end_date: date, inflation_rate: float
) -> Dict[str, float]:
    from algorithms.temporal import (
        get_day_of_week_modifier, get_day_of_month_modifier,
        get_month_modifier, get_year_modifier, get_festival_modifier,
    )
    modifiers = {}
    current = start_date
    while current <= end_date:
        dow = get_day_of_week_modifier(current)
        dom = get_day_of_month_modifier(current)
        moy = get_month_modifier(current)
        year = get_year_modifier(current, start_date.year, inflation_rate)
        festival = get_festival_modifier(current)
        base_mod = dow * dom * moy * year * festival
        modifiers[current.isoformat()] = base_mod
        current += timedelta(days=1)
    return modifiers


def generate_all_expenses(
    config: GenerationConfig,
    users: List[User],
    groups: List[Group],
    memberships: List[GroupMembership],
) -> Tuple[List[Expense], List[ExpenseSplit]]:
    master_rng = np.random.default_rng(config.seed + 10000)
    start_date = date.fromisoformat(config.start_date)
    end_date = date.fromisoformat(config.end_date)
    total_days = (end_date - start_date).days + 1

    print("  Pre-computing temporal modifiers...")
    temporal_modifiers = _precompute_temporal_modifiers(start_date, end_date, config.inflation_rate)

    user_dict = {u.user_id: u for u in users}
    group_dict = {g.group_id: g for g in groups}

    group_members: Dict[str, List[str]] = defaultdict(list)
    for m in memberships:
        group_members[m.group_id].append(m.user_id)

    all_dates = [start_date + timedelta(days=i) for i in range(total_days)]

    all_expenses = []
    all_splits = []
    expense_id_counter = [0]
    split_id_counter = [0]

    user_avg_daily = {}
    for u in users:
        base = PERSONA_PARAMS[u.persona]["daily_spend_base"]
        user_avg_daily[u.user_id] = base * u.spending_multiplier * LOCATION_MULTIPLIER[u.location_tier]

    print(f"  Generating individual expenses for {len(users)} users...")
    for user_idx, user in enumerate(users):
        if user_idx % 100 == 0 and user_idx > 0:
            print(f"    Users processed: {user_idx}/{len(users)}, "
                  f"expenses so far: {expense_id_counter[0]}")

        user_rng = np.random.default_rng(config.seed + user_idx * 137)
        join_day_idx = max(0, (user.join_date - start_date).days)

        day_indices = np.arange(join_day_idx, total_days)
        if len(day_indices) == 0:
            continue

        activity_probs = np.array([
            user.activity_rate * min(temporal_modifiers[all_dates[i].isoformat()], 2.0)
            for i in day_indices
        ])

        is_weekend = np.array([all_dates[i].weekday() >= 5 for i in day_indices])
        activity_probs[is_weekend] *= 1.15
        activity_probs = np.clip(activity_probs, 0.01, 0.95)

        churn_mask = np.array([
            is_in_churn_period(all_dates[i], user.churn_periods)
            for i in day_indices
        ])
        churn_indices = set(day_indices[churn_mask])

        active_mask = user_rng.random(len(day_indices)) < activity_probs
        active_day_indices = day_indices[active_mask]

        day_rng_base = np.random.default_rng(config.seed + user_idx * 137 + 7)
        yesterday_total = 0.0
        avg_daily = user_avg_daily[user.user_id]
        location_mult = LOCATION_MULTIPLIER[user.location_tier]

        for idx in active_day_indices:
            if idx in churn_indices:
                yesterday_total = 0.0
                continue

            current_date = all_dates[idx]
            temporal_mod = temporal_modifiers[current_date.isoformat()]

            autocorr_factor = 1.0
            if day_rng_base.random() < 0.6 and avg_daily > 0:
                ratio = yesterday_total / avg_daily
                if ratio > 2.0:
                    autocorr_factor = 0.8
                elif ratio > 1.5:
                    autocorr_factor = 0.9
                elif ratio < 0.5:
                    autocorr_factor = 1.15
                elif ratio < 0.3:
                    autocorr_factor = 1.25

            final_mod = temporal_mod * autocorr_factor

            num_expenses = determine_num_expenses(user.persona, day_rng_base)
            day_total = 0.0

            for _ in range(num_expenses):
                is_splurge = day_rng_base.random() < user.splurge_probability
                wrong_cat = day_rng_base.random() < config.wrong_category_rate
                category, subs = pick_category(user.category_weights, day_rng_base, wrong_cat)
                subcategory = pick_subcategory(category, user.subcategory_weights, day_rng_base)

                amount = generate_amount(
                    category, user.persona, final_mod,
                    location_mult, day_rng_base, is_splurge,
                )

                desc = generate_description(category, subcategory, amount, day_rng_base)

                if day_rng_base.random() < config.suspicious_amount_rate:
                    amount *= day_rng_base.uniform(10, 50)

                if day_rng_base.random() < config.typo_rate:
                    desc = apply_typo(desc, day_rng_base)

                if day_rng_base.random() < config.missing_description_rate:
                    if day_rng_base.random() < 0.5:
                        desc = ""
                    else:
                        desc = str(day_rng_base.choice(["expense", "purchase", "payment", "misc"]))

                if day_rng_base.random() < config.negative_rate:
                    amount = -abs(amount) * 0.3

                time_minutes = get_time_of_day(category, day_rng_base)
                if day_rng_base.random() < config.time_anomaly_rate:
                    hour = int(day_rng_base.choice([2, 3, 4]))
                    minute = int(day_rng_base.integers(0, 60))
                    time_minutes = hour * 60 + minute

                created_at = datetime(
                    current_date.year, current_date.month, current_date.day,
                    time_minutes // 60, time_minutes % 60, int(day_rng_base.integers(0, 60)),
                )

                expense = Expense(
                    expense_id=f"EXP_{expense_id_counter[0]+1:08d}",
                    user_id=user.user_id,
                    group_id=None,
                    date=current_date,
                    category=category,
                    subcategory=subcategory,
                    amount=round(amount, 2),
                    description=desc,
                    is_group_expense=False,
                    created_at=created_at,
                )
                all_expenses.append(expense)
                expense_id_counter[0] += 1
                day_total += amount

            yesterday_total = day_total

    print(f"    Individual expenses: {expense_id_counter[0]}")

    print(f"  Generating group expenses for {len(groups)} groups...")
    for group_idx, group in enumerate(groups):
        if group_idx % 50 == 0 and group_idx > 0:
            print(f"    Groups processed: {group_idx}/{len(groups)}, "
                  f"expenses so far: {expense_id_counter[0]}")

        group_rng = np.random.default_rng(config.seed + 20000 + group_idx * 89)
        join_day_idx = max(0, (group.created_date - start_date).days)

        members = group_members.get(group.group_id, [])
        if len(members) < 2:
            continue

        group_params = GROUP_TYPE_PARAMS[group.group_type]

        day_indices = np.arange(join_day_idx, total_days)
        if len(day_indices) == 0:
            continue

        activity_probs = np.array([
            compute_group_activity_probability(
                group.group_type, all_dates[i], group_rng
            ) for i in day_indices
        ])

        active_mask = group_rng.random(len(day_indices)) < activity_probs
        active_day_indices = day_indices[active_mask]

        for idx in active_day_indices:
            current_date = all_dates[idx]

            active_members = []
            for mid in members:
                mu = user_dict.get(mid)
                if mu and current_date >= mu.join_date:
                    if not is_in_churn_period(current_date, mu.churn_periods):
                        active_members.append(mid)

            if len(active_members) < 2:
                continue

            num_group_expenses = int(group_rng.integers(1, min(4, len(active_members))))

            for ge_idx in range(num_group_expenses):
                payer_idx = int(group_rng.integers(0, len(active_members)))
                payer_id = active_members[payer_idx]

                group_cats = group_params["categories"]
                category = group_rng.choice(group_cats)
                subs = CATEGORY_SUBCATEGORIES[category]
                subcategory = group_rng.choice(subs)

                base_amount = group_params["avg_expense"]
                size_factor = 1 + 0.3 * np.log(len(active_members))
                temporal_for_group = temporal_modifiers[current_date.isoformat()]
                amount = base_amount * size_factor * temporal_for_group * float(group_rng.lognormal(0, 0.4))

                rounding_choice = group_rng.random()
                if rounding_choice < 0.4:
                    amount = round(amount)
                elif rounding_choice < 0.55:
                    amount = round(amount * 2) / 2

                amount = round(max(5.0, amount), 2)

                desc = generate_group_expense_description(
                    category, subcategory, group.name, len(active_members), group_rng,
                )

                if group_rng.random() < config.typo_rate:
                    desc = apply_typo(desc, group_rng)

                time_minutes = get_time_of_day(category, group_rng)
                created_at = datetime(
                    current_date.year, current_date.month, current_date.day,
                    time_minutes // 60, time_minutes % 60, int(group_rng.integers(0, 60)),
                )

                expense = Expense(
                    expense_id=f"EXP_{expense_id_counter[0]+1:08d}",
                    user_id=payer_id,
                    group_id=group.group_id,
                    date=current_date,
                    category=category,
                    subcategory=subcategory,
                    amount=amount,
                    description=desc,
                    is_group_expense=True,
                    created_at=created_at,
                )
                all_expenses.append(expense)
                expense_id_counter[0] += 1

                split_method = group.default_split_method
                split_shares = compute_split_shares(
                    active_members, split_method, {}, amount, group_rng,
                )

                for member_id, share_amount in split_shares.items():
                    split = ExpenseSplit(
                        split_id=f"SPL_{split_id_counter[0]+1:08d}",
                        expense_id=expense.expense_id,
                        user_id=member_id,
                        amount=round(share_amount, 2),
                        percentage=round(share_amount / amount * 100, 2) if amount > 0 else 0,
                        is_settled=bool(group_rng.random() < 0.7),
                    )
                    all_splits.append(split)
                    split_id_counter[0] += 1

    print(f"    Total expenses: {expense_id_counter[0]}, Total splits: {split_id_counter[0]}")
    return all_expenses, all_splits


def generate_recurring_expenses(
    config: GenerationConfig, users: List[User]
) -> List[Expense]:
    rng = np.random.default_rng(config.seed + 20000)
    start_date = date.fromisoformat(config.start_date)
    end_date = date.fromisoformat(config.end_date)

    recurring_expenses = []
    expense_id_counter = 90000000

    for user in users:
        num_recurring = int(rng.integers(1, 4))
        selected_indices = rng.choice(len(RECURRING_EXPENSES), size=min(num_recurring, len(RECURRING_EXPENSES)), replace=False)

        for idx in selected_indices:
            idx = int(idx)
            rec_template = RECURRING_EXPENSES[idx]
            amount_range = rec_template["amount_range"]

            if user.location_tier.value == "metro":
                base_amount = float(rng.uniform(amount_range[0] * 1.2, amount_range[1] * 1.2))
            elif user.location_tier.value == "tier2":
                base_amount = float(rng.uniform(amount_range[0], amount_range[1]))
            else:
                base_amount = float(rng.uniform(amount_range[0] * 0.7, amount_range[1] * 0.7))

            current = max(start_date, user.join_date)
            day_of_month = rec_template["day_of_month"]

            while current <= end_date:
                if is_in_churn_period(current, user.churn_periods):
                    if current.month == 12:
                        current = date(current.year + 1, 1, 1)
                    else:
                        current = date(current.year, current.month + 1, 1)
                    continue

                try:
                    expense_date = current.replace(day=day_of_month)
                except ValueError:
                    expense_date = current.replace(day=28)

                if expense_date < user.join_date or expense_date > end_date:
                    if current.month == 12:
                        current = date(current.year + 1, 1, 1)
                    else:
                        current = date(current.year, current.month + 1, 1)
                    continue

                inflation_factor = (1 + config.inflation_rate) ** (expense_date.year - start_date.year)
                month_amount = round(base_amount * inflation_factor, 2)

                if rng.random() < 0.1:
                    month_amount = round(month_amount * float(rng.uniform(0.95, 1.05)), 2)

                time_minutes = int(rng.integers(480, 600))
                created_at = datetime(
                    expense_date.year, expense_date.month, expense_date.day,
                    time_minutes // 60, time_minutes % 60, 0,
                )

                expense = Expense(
                    expense_id=f"EXP_{expense_id_counter+1:08d}",
                    user_id=user.user_id,
                    group_id=None,
                    date=expense_date,
                    category=rec_template["category"],
                    subcategory=rec_template["subcategory"],
                    amount=month_amount,
                    description=rec_template["description"],
                    is_group_expense=False,
                    created_at=created_at,
                    is_recurring=True,
                    recurrence_type=rec_template["frequency"],
                )
                recurring_expenses.append(expense)
                expense_id_counter += 1

                if current.month == 12:
                    current = date(current.year + 1, 1, 1)
                else:
                    current = date(current.year, current.month + 1, 1)

    return recurring_expenses


def expenses_to_dataframe(expenses: List[Expense]) -> pd.DataFrame:
    rows = []
    for e in expenses:
        rows.append({
            "expense_id": e.expense_id,
            "user_id": e.user_id,
            "group_id": e.group_id if e.group_id else "",
            "date": e.date.isoformat(),
            "category": e.category.value,
            "subcategory": e.subcategory.value,
            "amount": e.amount,
            "description": e.description,
            "is_group_expense": e.is_group_expense,
            "created_at": e.created_at.isoformat(),
            "is_recurring": e.is_recurring,
            "recurrence_type": e.recurrence_type if e.recurrence_type else "",
        })
    return pd.DataFrame(rows)


def splits_to_dataframe(splits: List[ExpenseSplit]) -> pd.DataFrame:
    rows = []
    for s in splits:
        rows.append({
            "split_id": s.split_id,
            "expense_id": s.expense_id,
            "user_id": s.user_id,
            "amount": s.amount,
            "percentage": s.percentage,
            "is_settled": s.is_settled,
        })
    return pd.DataFrame(rows)