"""
File: feature_engineering_v2.py
What does this file do?
    Builds leak-free monthly, daily anomaly, budget risk, and shared expense
    features from the Nepal finance V2 dataset.
Methods/functions this file contains:
    _load_csv, _add_user_dummies, _safe_divide, build_monthly_features,
    build_daily_anomaly_features, build_shared_features, main.
Date and Day of last modification:
    2026-05-16, Saturday.
"""

from __future__ import annotations

import argparse
import json
from pathlib import Path
from typing import Dict, List

import numpy as np
import pandas as pd

from config_v2 import CATEGORIES, FESTIVAL_WINDOWS


def _load_csv(input_dir: Path, filename: str) -> pd.DataFrame:
    return pd.read_csv(input_dir / filename, keep_default_na=False)


def _add_user_dummies(frame: pd.DataFrame) -> pd.DataFrame:
    result = frame.copy()
    persona = pd.get_dummies(result["financial_persona"], prefix="persona")
    city = pd.get_dummies(result["city_tier"], prefix="city")
    income_type = pd.get_dummies(result["income_type"], prefix="income_type")
    rent = pd.get_dummies(result["rent_status"], prefix="rent_status")
    return pd.concat([result.drop(columns=["financial_persona", "city_tier", "income_type", "rent_status"]), persona, city, income_type, rent], axis=1)


def _safe_divide(numerator: pd.Series, denominator: pd.Series) -> pd.Series:
    return numerator / denominator.replace(0, np.nan)


def _to_bool(series: pd.Series) -> pd.Series:
    if series.dtype == bool:
        return series
    return series.astype(str).str.lower().isin(["true", "1", "yes"])


def build_monthly_features(input_dir: Path, output_dir: Path) -> Dict[str, int]:
    expenses = _load_csv(input_dir, "expenses.csv")
    users = _add_user_dummies(_load_csv(input_dir, "users.csv")).rename(columns={"monthly_income_npr": "profile_monthly_income_npr"})
    budgets = _load_csv(input_dir, "budgets.csv")
    income = _load_csv(input_dir, "income_events.csv")
    splits = _load_csv(input_dir, "expense_splits.csv")

    expenses["date"] = pd.to_datetime(expenses["date"])
    expenses["year_month"] = expenses["date"].dt.to_period("M").astype(str)
    expenses["amount_npr"] = expenses["amount_npr"].astype(float)
    expenses["is_essential"] = _to_bool(expenses["is_essential"])
    expenses["is_shared"] = _to_bool(expenses["is_shared"])
    income["income_date"] = pd.to_datetime(income["income_date"])
    income["year_month"] = income["income_date"].dt.to_period("M").astype(str)

    monthly = expenses.groupby(["user_id", "year_month"]).agg(
        total_spend_npr=("amount_npr", "sum"),
        essential_spend_npr=("amount_npr", lambda values: values[expenses.loc[values.index, "is_essential"].astype(bool)].sum()),
        flexible_spend_npr=("amount_npr", lambda values: values[~expenses.loc[values.index, "is_essential"].astype(bool)].sum()),
        transaction_count=("expense_id", "count"),
        shared_paid_npr=("amount_npr", lambda values: values[expenses.loc[values.index, "is_shared"].astype(bool)].sum()),
        cash_spend_npr=("amount_npr", lambda values: values[expenses.loc[values.index, "payment_method"].eq("cash")].sum()),
    ).reset_index()

    category = expenses.pivot_table(
        index=["user_id", "year_month"],
        columns="category",
        values="amount_npr",
        aggfunc="sum",
        fill_value=0,
    ).reset_index()
    category.columns = [f"cat_{col}" if col in CATEGORIES else col for col in category.columns]
    monthly = monthly.merge(category, on=["user_id", "year_month"], how="left")

    income_monthly = income.groupby(["user_id", "year_month"]).agg(observed_monthly_income_npr=("income_amount_npr", "sum")).reset_index()
    budget_total = budgets.groupby("user_id").agg(monthly_budget_npr=("monthly_budget_npr", "sum")).reset_index()

    if not splits.empty:
        splits = splits.merge(expenses[["expense_id", "date"]], on="expense_id", how="left")
        splits["date"] = pd.to_datetime(splits["date"])
        splits["year_month"] = splits["date"].dt.to_period("M").astype(str)
        shared_burden = splits.groupby(["user_id", "year_month"]).agg(
            shared_owed_npr=("owed_amount_npr", "sum"),
            pending_shared_npr=("owed_amount_npr", lambda values: values[splits.loc[values.index, "settlement_status"].eq("pending")].sum()),
        ).reset_index()
        monthly = monthly.merge(shared_burden, on=["user_id", "year_month"], how="left")
    else:
        monthly["shared_owed_npr"] = 0
        monthly["pending_shared_npr"] = 0

    monthly = monthly.merge(income_monthly, on=["user_id", "year_month"], how="left")
    monthly = monthly.merge(budget_total, on="user_id", how="left")
    monthly = monthly.merge(users, on="user_id", how="left")
    monthly = monthly.fillna(0)

    monthly["period"] = pd.PeriodIndex(monthly["year_month"], freq="M")
    monthly["month_num"] = monthly["period"].apply(lambda period: (period.year - 2023) * 12 + period.month)
    monthly["month"] = monthly["period"].apply(lambda period: period.month)
    monthly["is_festival_month"] = monthly["month"].isin([window["month"] for window in FESTIVAL_WINDOWS]).astype(int)
    monthly = monthly.sort_values(["user_id", "month_num"]).reset_index(drop=True)

    lag_sources = [
        "total_spend_npr",
        "essential_spend_npr",
        "flexible_spend_npr",
        "transaction_count",
        "shared_paid_npr",
        "shared_owed_npr",
        "pending_shared_npr",
        "cash_spend_npr",
    ] + [f"cat_{category}" for category in CATEGORIES]

    for column in lag_sources:
        if column not in monthly.columns:
            monthly[column] = 0
        monthly[f"prev_{column}_1m"] = monthly.groupby("user_id")[column].shift(1).fillna(0)
        monthly[f"prev_{column}_3m_avg"] = (
            monthly.groupby("user_id")[column]
            .shift(1)
            .rolling(3, min_periods=1)
            .mean()
            .reset_index(0, drop=True)
            .fillna(0)
        )

    monthly["effective_monthly_income_npr"] = monthly["observed_monthly_income_npr"].where(
        monthly["observed_monthly_income_npr"] > 0,
        monthly["profile_monthly_income_npr"],
    )
    monthly["income_spend_ratio_prev"] = _safe_divide(monthly["prev_total_spend_npr_1m"], monthly["effective_monthly_income_npr"]).fillna(0)
    monthly["budget_utilization_prev"] = _safe_divide(monthly["prev_total_spend_npr_1m"], monthly["monthly_budget_npr"]).fillna(0)
    monthly["shared_burden_ratio_prev"] = _safe_divide(monthly["prev_shared_owed_npr_1m"], monthly["effective_monthly_income_npr"]).fillna(0)
    monthly["target_next_month_spend_npr"] = monthly.groupby("user_id")["total_spend_npr"].shift(-1)
    monthly["target_budget_risk"] = (monthly["total_spend_npr"] > monthly["monthly_budget_npr"]).astype(int)
    monthly = monthly.dropna(subset=["target_next_month_spend_npr"])

    exclude = {
        "period",
        "year_month",
        "user_id",
        "total_spend_npr",
        "essential_spend_npr",
        "flexible_spend_npr",
        "transaction_count",
        "shared_paid_npr",
        "shared_owed_npr",
        "pending_shared_npr",
        "cash_spend_npr",
        "target_next_month_spend_npr",
        "target_budget_risk",
    } | {f"cat_{category}" for category in CATEGORIES}

    feature_cols = [column for column in monthly.columns if column not in exclude and pd.api.types.is_numeric_dtype(monthly[column])]
    output_dir.mkdir(parents=True, exist_ok=True)
    monthly.to_parquet(output_dir / "monthly_features.parquet", index=False)
    with open(output_dir / "monthly_feature_cols.json", "w", encoding="utf-8") as file:
        json.dump(feature_cols, file, indent=2)
    return {"monthly_rows": len(monthly), "monthly_features": len(feature_cols)}


def build_daily_anomaly_features(input_dir: Path, output_dir: Path) -> Dict[str, int]:
    expenses = _load_csv(input_dir, "expenses.csv")
    users = _add_user_dummies(_load_csv(input_dir, "users.csv"))
    expenses["date"] = pd.to_datetime(expenses["date"])
    expenses["amount_npr"] = expenses["amount_npr"].astype(float)
    expenses["is_essential"] = _to_bool(expenses["is_essential"])
    expenses["is_shared"] = _to_bool(expenses["is_shared"])

    daily = expenses.groupby(["user_id", "date"]).agg(
        daily_total_npr=("amount_npr", "sum"),
        daily_count=("expense_id", "count"),
        daily_shared_npr=("amount_npr", lambda values: values[expenses.loc[values.index, "is_shared"].astype(bool)].sum()),
        daily_flexible_npr=("amount_npr", lambda values: values[~expenses.loc[values.index, "is_essential"].astype(bool)].sum()),
    ).reset_index()
    daily["weekday"] = daily["date"].dt.dayofweek
    daily["is_weekend"] = (daily["weekday"] >= 5).astype(int)
    daily["day_of_month"] = daily["date"].dt.day
    daily["month"] = daily["date"].dt.month
    daily["is_payday_window"] = daily["day_of_month"].isin([1, 2, 3, 15, 16]).astype(int)
    daily["is_festival_window"] = daily["date"].apply(lambda value: int(any(value.month == w["month"] and w["start_day"] <= value.day <= w["end_day"] for w in FESTIVAL_WINDOWS)))
    daily = daily.sort_values(["user_id", "date"]).reset_index(drop=True)

    for column in ["daily_total_npr", "daily_count", "daily_shared_npr", "daily_flexible_npr"]:
        shifted = daily.groupby("user_id")[column].shift(1)
        daily[f"prev_{column}_1d"] = shifted.fillna(0)
        for window in [7, 30]:
            daily[f"prev_{column}_{window}d_avg"] = shifted.rolling(window, min_periods=1).mean().reset_index(0, drop=True).fillna(0)
            daily[f"prev_{column}_{window}d_std"] = shifted.rolling(window, min_periods=1).std().reset_index(0, drop=True).fillna(0)

    daily["baseline_30d"] = daily.groupby("user_id")["daily_total_npr"].shift(1).rolling(30, min_periods=7).mean().reset_index(0, drop=True)
    daily["target_is_anomaly"] = ((daily["baseline_30d"] > 0) & (daily["daily_total_npr"] > daily["baseline_30d"] * 2.8)).astype(int)
    daily = daily.merge(users, on="user_id", how="left").fillna(0)
    daily = daily[daily["baseline_30d"] > 0].copy()

    exclude = {"user_id", "date", "daily_total_npr", "daily_count", "daily_shared_npr", "daily_flexible_npr", "baseline_30d", "target_is_anomaly"}
    feature_cols = [column for column in daily.columns if column not in exclude and pd.api.types.is_numeric_dtype(daily[column])]
    daily.to_parquet(output_dir / "daily_anomaly_features.parquet", index=False)
    with open(output_dir / "daily_anomaly_feature_cols.json", "w", encoding="utf-8") as file:
        json.dump(feature_cols, file, indent=2)
    return {"daily_rows": len(daily), "daily_features": len(feature_cols)}


def build_shared_features(input_dir: Path, output_dir: Path) -> Dict[str, int]:
    shared = _load_csv(input_dir, "shared_expenses.csv")
    expenses = _load_csv(input_dir, "expenses.csv")
    if shared.empty:
        shared.to_parquet(output_dir / "shared_features.parquet", index=False)
        return {"shared_rows": 0, "shared_features": 0}

    frame = shared.merge(expenses[["expense_id", "date", "amount_npr", "category"]], on="expense_id", how="left")
    frame["date"] = pd.to_datetime(frame["date"])
    frame = frame.sort_values(["date", "shared_expense_id"]).reset_index(drop=True)
    frame["month"] = frame["date"].dt.month
    frame["is_festival_month"] = frame["month"].isin([window["month"] for window in FESTIVAL_WINDOWS]).astype(int)
    frame["amount_per_person_npr"] = frame["amount_npr"] / frame["participant_count"].clip(lower=1)
    frame["target_late_settlement"] = (frame["days_to_settle"].astype(float) > 14).astype(int)

    group_history = frame.groupby("group_id")["target_late_settlement"]
    payer_history = frame.groupby("paid_by_user_id")["target_late_settlement"]
    group_amount = frame.groupby("group_id")["amount_per_person_npr"]
    payer_amount = frame.groupby("paid_by_user_id")["amount_per_person_npr"]

    frame["group_prior_shared_count"] = group_history.cumcount()
    frame["payer_prior_shared_count"] = payer_history.cumcount()
    frame["group_prior_late_rate"] = (
        group_history.shift(1)
        .groupby(frame["group_id"])
        .expanding()
        .mean()
        .reset_index(level=0, drop=True)
        .fillna(0)
    )
    frame["payer_prior_late_rate"] = (
        payer_history.shift(1)
        .groupby(frame["paid_by_user_id"])
        .expanding()
        .mean()
        .reset_index(level=0, drop=True)
        .fillna(0)
    )
    frame["group_prior_avg_amount_per_person"] = (
        group_amount.shift(1)
        .groupby(frame["group_id"])
        .expanding()
        .mean()
        .reset_index(level=0, drop=True)
        .fillna(0)
    )
    frame["payer_prior_avg_amount_per_person"] = (
        payer_amount.shift(1)
        .groupby(frame["paid_by_user_id"])
        .expanding()
        .mean()
        .reset_index(level=0, drop=True)
        .fillna(0)
    )
    frame["amount_vs_group_history"] = _safe_divide(
        frame["amount_per_person_npr"],
        frame["group_prior_avg_amount_per_person"],
    ).replace([np.inf, -np.inf], 0).fillna(0)
    frame["amount_vs_payer_history"] = _safe_divide(
        frame["amount_per_person_npr"],
        frame["payer_prior_avg_amount_per_person"],
    ).replace([np.inf, -np.inf], 0).fillna(0)

    split_dummies = pd.get_dummies(frame["split_type"], prefix="split")
    category_dummies = pd.get_dummies(frame["category"], prefix="category")
    frame = pd.concat([frame, split_dummies, category_dummies], axis=1)
    exclude = {
        "shared_expense_id",
        "expense_id",
        "group_id",
        "paid_by_user_id",
        "split_type",
        "settlement_status",
        "days_to_settle",
        "date",
        "category",
        "target_late_settlement",
    }
    feature_cols = [column for column in frame.columns if column not in exclude and pd.api.types.is_numeric_dtype(frame[column])]
    frame.to_parquet(output_dir / "shared_features.parquet", index=False)
    with open(output_dir / "shared_feature_cols.json", "w", encoding="utf-8") as file:
        json.dump(feature_cols, file, indent=2)
    return {"shared_rows": len(frame), "shared_features": len(feature_cols)}


def main() -> None:
    parser = argparse.ArgumentParser(description="Build Nepal finance V2 features")
    parser.add_argument("--input-dir", type=str, default="output_v2")
    parser.add_argument("--output-dir", type=str, default="features_v2_nepal")
    args = parser.parse_args()

    input_dir = Path(args.input_dir)
    output_dir = Path(args.output_dir)
    output_dir.mkdir(parents=True, exist_ok=True)

    counts = {}
    counts.update(build_monthly_features(input_dir, output_dir))
    counts.update(build_daily_anomaly_features(input_dir, output_dir))
    counts.update(build_shared_features(input_dir, output_dir))
    print("Nepal finance V2 features generated")
    for key, value in counts.items():
        print(f"  {key}: {value:,}")


if __name__ == "__main__":
    main()
