"""
File: assistant_v2/middleware_schema.py
What does this file do?
    Normalizes arbitrary app payloads into the stable V2 finance assistant schema
    while excluding sensitive identity fields from model inputs.
Methods/functions this file contains:
    normalize_payload, _normalize_user, _normalize_expenses, _normalize_income,
    _normalize_shared_expenses, _normalize_budgets.
Date and Day of last modification:
    2026-05-16, Saturday.
"""

from __future__ import annotations

from typing import Any, Dict, List

import pandas as pd

from config_v2 import CURRENCY_RATES_TO_NPR


SENSITIVE_KEYS = {"name", "email", "phone", "address", "note", "description", "device_id", "token"}


def _clean_dict(values: Dict[str, Any]) -> Dict[str, Any]:
    return {key: value for key, value in values.items() if key not in SENSITIVE_KEYS}


def _normalize_user(payload: Dict[str, Any]) -> pd.DataFrame:
    user = _clean_dict(payload.get("user", {}))
    return pd.DataFrame(
        [
            {
                "user_id": str(user.get("user_id", user.get("id", "app_user"))),
                "age": int(user.get("age", 30) or 30),
                "occupation_type": str(user.get("occupation_type", "salaried")),
                "city_tier": str(user.get("city_tier", "kathmandu_valley")),
                "monthly_income_npr": float(user.get("monthly_income_npr", user.get("income", 0)) or 0),
                "income_type": str(user.get("income_type", "fixed")),
                "family_dependency_count": int(user.get("family_dependency_count", 0) or 0),
                "rent_status": str(user.get("rent_status", "renter")),
                "financial_persona": str(user.get("financial_persona", "salaried_balanced")),
                "activity_rate": float(user.get("activity_rate", 0.6) or 0.6),
                "spend_multiplier": float(user.get("spend_multiplier", 1.0) or 1.0),
                "saving_rate": float(user.get("saving_rate", 0.1) or 0.1),
                "shared_tendency": float(user.get("shared_tendency", 0.3) or 0.3),
                "city_price_multiplier": float(user.get("city_price_multiplier", 1.0) or 1.0),
            }
        ]
    )


def _normalize_expenses(payload: Dict[str, Any]) -> pd.DataFrame:
    rows: List[Dict[str, Any]] = []
    user_id = str(payload.get("user", {}).get("user_id", payload.get("user", {}).get("id", "app_user")))
    for index, item in enumerate(payload.get("expenses", []), start=1):
        expense = _clean_dict(item)
        currency = str(expense.get("currency_code", expense.get("currency", "NPR"))).upper()
        rate = float(expense.get("exchange_rate_to_npr", CURRENCY_RATES_TO_NPR.get(currency, 1.0)) or 1.0)
        amount_original = float(expense.get("amount_original", expense.get("amount", 0)) or 0)
        category = str(expense.get("category", "miscellaneous"))
        rows.append(
            {
                "expense_id": str(expense.get("expense_id", expense.get("id", f"APP_EXP_{index:06d}"))),
                "user_id": str(expense.get("user_id", user_id)),
                "date": str(expense.get("date")),
                "amount_original": amount_original,
                "currency_code": currency,
                "exchange_rate_to_npr": rate,
                "amount_npr": float(expense.get("amount_npr", amount_original * rate) or 0),
                "category": category,
                "subcategory": str(expense.get("subcategory", category)),
                "merchant_name": str(expense.get("merchant_name", ""))[:64],
                "payment_method": str(expense.get("payment_method", "cash")),
                "is_shared": bool(expense.get("is_shared", False)),
                "group_id": str(expense.get("group_id", "")),
                "is_recurring": bool(expense.get("is_recurring", False)),
                "is_essential": bool(expense.get("is_essential", category in {"rent", "groceries", "utilities", "education", "health", "loan_emi"})),
                "note_quality": str(expense.get("note_quality", "unknown")),
                "logged_delay_hours": int(expense.get("logged_delay_hours", 0) or 0),
                "festival_context": str(expense.get("festival_context", "")),
                "created_at": str(expense.get("created_at", expense.get("date"))),
            }
        )
    return pd.DataFrame(rows)


def _normalize_income(payload: Dict[str, Any]) -> pd.DataFrame:
    rows = []
    user_id = str(payload.get("user", {}).get("user_id", payload.get("user", {}).get("id", "app_user")))
    for index, item in enumerate(payload.get("income", []), start=1):
        income = _clean_dict(item)
        currency = str(income.get("currency_code", income.get("currency", "NPR"))).upper()
        rate = CURRENCY_RATES_TO_NPR.get(currency, 1.0)
        amount = float(income.get("income_amount_npr", income.get("amount", 0)) or 0)
        rows.append(
            {
                "income_id": str(income.get("income_id", f"APP_INC_{index:06d}")),
                "user_id": str(income.get("user_id", user_id)),
                "income_date": str(income.get("income_date", income.get("date"))),
                "income_amount_npr": amount if currency == "NPR" else amount * rate,
                "income_source": str(income.get("income_source", "unknown")),
                "is_expected": bool(income.get("is_expected", True)),
            }
        )
    return pd.DataFrame(rows)


def _normalize_shared_expenses(payload: Dict[str, Any]) -> pd.DataFrame:
    rows = []
    for index, item in enumerate(payload.get("shared_expenses", []), start=1):
        shared = _clean_dict(item)
        rows.append(
            {
                "shared_expense_id": str(shared.get("shared_expense_id", f"APP_SHR_{index:06d}")),
                "expense_id": str(shared.get("expense_id", "")),
                "group_id": str(shared.get("group_id", "")),
                "paid_by_user_id": str(shared.get("paid_by_user_id", "")),
                "split_type": str(shared.get("split_type", "equal")),
                "participant_count": int(shared.get("participant_count", 1) or 1),
                "settlement_status": str(shared.get("settlement_status", "pending")),
                "days_to_settle": int(shared.get("days_to_settle", 0) or 0),
            }
        )
    return pd.DataFrame(rows)


def _normalize_budgets(payload: Dict[str, Any]) -> pd.DataFrame:
    rows = []
    user_id = str(payload.get("user", {}).get("user_id", payload.get("user", {}).get("id", "app_user")))
    for index, item in enumerate(payload.get("budgets", []), start=1):
        budget = _clean_dict(item)
        rows.append(
            {
                "budget_id": str(budget.get("budget_id", f"APP_BUD_{index:06d}")),
                "user_id": str(budget.get("user_id", user_id)),
                "category": str(budget.get("category", "total")),
                "monthly_budget_npr": float(budget.get("monthly_budget_npr", budget.get("amount", 0)) or 0),
            }
        )
    return pd.DataFrame(rows)


def normalize_payload(payload: Dict[str, Any]) -> Dict[str, pd.DataFrame]:
    return {
        "users": _normalize_user(payload),
        "expenses": _normalize_expenses(payload),
        "income": _normalize_income(payload),
        "shared_expenses": _normalize_shared_expenses(payload),
        "budgets": _normalize_budgets(payload),
    }
