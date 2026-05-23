"""
File: expense_assistant.py
What does this file do?
    Loads the saved expense assistant models and exposes app-friendly prediction,
    anomaly, profile, and insight methods for an expense recorder application.
Methods/functions this file contains:
    _read_table, _month_index, _ensure_columns, _last_values, ExpenseAssistant,
    ExpenseAssistant.forecast_next_month, ExpenseAssistant.detect_anomaly,
    ExpenseAssistant.get_spending_profile, ExpenseAssistant.generate_user_insights.
Date and Day of last modification:
    2026-05-15, Friday.
"""

from __future__ import annotations

from dataclasses import dataclass
from pathlib import Path
from typing import Any, Dict, Iterable, List, Optional

import joblib
import numpy as np
import pandas as pd


DEFAULT_PERSONA_COLUMNS = [
    "persona_conservative",
    "persona_frugal",
    "persona_lifestyle",
    "persona_moderate",
    "persona_occasional_splurger",
    "persona_spender",
]

DEFAULT_LOCATION_COLUMNS = ["loc_metro", "loc_tier2", "loc_tier3"]

USER_PROFILE_COLUMNS = [
    "age",
    "income",
    "spending_multiplier",
    "activity_rate",
    "social_tendency",
    "consistency",
    "splurge_probability",
    "daily_lambda",
]


def _read_table(data: pd.DataFrame | str | Path) -> pd.DataFrame:
    if isinstance(data, pd.DataFrame):
        return data.copy()

    path = Path(data)
    if path.suffix.lower() == ".parquet":
        return pd.read_parquet(path)
    return pd.read_csv(path, keep_default_na=False)


def _month_index(period: pd.Period) -> int:
    return (period.year - 2016) * 12 + period.month


def _ensure_columns(frame: pd.DataFrame, columns: Iterable[str]) -> pd.DataFrame:
    result = frame.copy()
    for column in columns:
        if column not in result.columns:
            result[column] = 0
    return result


def _last_values(series: pd.Series, count: int) -> List[float]:
    values = series.tail(count).astype(float).tolist()
    if len(values) < count:
        values = [0.0] * (count - len(values)) + values
    return values


@dataclass
class ExpenseAssistant:
    models_dir: Path | str = Path("models_v3")

    def __post_init__(self) -> None:
        self.models_dir = Path(self.models_dir)
        self.monthly_model = joblib.load(self.models_dir / "monthly_forecast.pkl")
        self.monthly_features = joblib.load(self.models_dir / "monthly_forecast_features.pkl")
        self.anomaly_model = joblib.load(self.models_dir / "anomaly_detector.pkl")
        self.anomaly_features = joblib.load(self.models_dir / "anomaly_features.pkl")
        self.profile_model = joblib.load(self.models_dir / "spending_profile_kmeans.pkl")
        self.profile_scaler = joblib.load(self.models_dir / "spending_profile_scaler.pkl")
        self.profile_features = joblib.load(self.models_dir / "spending_profile_features.pkl")

    def forecast_next_month(
        self,
        user_id: str,
        expenses: pd.DataFrame | str | Path,
        users: pd.DataFrame | str | Path,
        target_month: Optional[str] = None,
    ) -> Dict[str, Any]:
        expenses_df = _read_table(expenses)
        users_df = _read_table(users)
        user_row = self._get_user(users_df, user_id)

        expenses_df["date"] = pd.to_datetime(expenses_df["date"])
        expenses_df["amount"] = expenses_df["amount"].astype(float)
        user_expenses = expenses_df[expenses_df["user_id"] == user_id].copy()
        if user_expenses.empty:
            raise ValueError(f"No expenses found for user_id={user_id}")

        user_expenses["year_month"] = user_expenses["date"].dt.to_period("M")
        latest_month = user_expenses["year_month"].max()
        forecast_period = pd.Period(target_month, freq="M") if target_month else latest_month + 1

        monthly_category = user_expenses.pivot_table(
            index="year_month",
            columns="category",
            values="amount",
            aggfunc="sum",
            fill_value=0,
        ).sort_index()
        monthly_total = user_expenses.groupby("year_month").agg(
            monthly_total=("amount", "sum"),
            monthly_count=("amount", "count"),
            monthly_mean=("amount", "mean"),
        ).sort_index()

        row: Dict[str, float] = {
            "month_num": float(_month_index(forecast_period)),
            "month_of_year": float(forecast_period.month),
        }
        row.update(self._encoded_user_profile(user_row))

        feature_bases = set()
        for feature in self.monthly_features:
            for suffix in ["_lag1", "_lag2", "_lag3", "_rolling3", "_rolling6"]:
                if feature.endswith(suffix):
                    feature_bases.add(feature[: -len(suffix)])

        combined = monthly_category.join(monthly_total, how="outer").fillna(0)
        for base in feature_bases:
            series = combined[base] if base in combined.columns else pd.Series(dtype=float)
            lag1, lag2, lag3 = reversed(_last_values(series, 3))
            row[f"{base}_lag1"] = float(lag1)
            row[f"{base}_lag2"] = float(lag2)
            row[f"{base}_lag3"] = float(lag3)
            row[f"{base}_rolling3"] = float(series.tail(3).mean()) if len(series) else 0.0
            row[f"{base}_rolling6"] = float(series.tail(6).mean()) if len(series) else 0.0

        features = _ensure_columns(pd.DataFrame([row]), self.monthly_features)
        predicted_log = self.monthly_model.predict(features[self.monthly_features])[0]
        predicted_amount = max(0.0, float(np.expm1(predicted_log)))

        recent_months = monthly_total["monthly_total"].tail(3)
        recent_average = float(recent_months.mean()) if len(recent_months) else 0.0
        change_pct = ((predicted_amount - recent_average) / recent_average * 100) if recent_average else 0.0

        return {
            "user_id": user_id,
            "target_month": str(forecast_period),
            "predicted_monthly_spend": round(predicted_amount, 2),
            "recent_3_month_average": round(recent_average, 2),
            "predicted_change_pct": round(change_pct, 2),
        }

    def detect_anomaly(
        self,
        user_id: str,
        expenses: pd.DataFrame | str | Path,
        users: pd.DataFrame | str | Path,
        target_date: Optional[str] = None,
    ) -> Dict[str, Any]:
        expenses_df = _read_table(expenses)
        users_df = _read_table(users)
        user_row = self._get_user(users_df, user_id)

        expenses_df["date"] = pd.to_datetime(expenses_df["date"])
        expenses_df["amount"] = expenses_df["amount"].astype(float)
        user_expenses = expenses_df[expenses_df["user_id"] == user_id].copy()
        if user_expenses.empty:
            raise ValueError(f"No expenses found for user_id={user_id}")

        date_value = pd.Timestamp(target_date) if target_date else user_expenses["date"].max()
        daily = user_expenses.groupby("date").agg(
            daily_total=("amount", "sum"),
            daily_count=("amount", "count"),
        ).sort_index()

        current_total = float(daily.loc[date_value, "daily_total"]) if date_value in daily.index else 0.0
        history = daily[daily.index < date_value]
        baseline = float(history["daily_total"].tail(30).mean()) if len(history) else 0.0
        spend_ratio = current_total / (baseline + 1.0)

        row = self._daily_context_features(date_value, history, user_row)
        features = _ensure_columns(pd.DataFrame([row]), self.anomaly_features)
        model_probability = float(self.anomaly_model.predict_proba(features[self.anomaly_features])[0, 1])

        is_anomaly = bool((baseline > 0 and current_total > baseline * 3) or spend_ratio > 5)
        severity = "normal"
        if is_anomaly and spend_ratio >= 5:
            severity = "high"
        elif is_anomaly or spend_ratio >= 2:
            severity = "medium"

        return {
            "user_id": user_id,
            "date": date_value.strftime("%Y-%m-%d"),
            "daily_total": round(current_total, 2),
            "prior_30_day_average": round(baseline, 2),
            "spend_ratio": round(float(spend_ratio), 2),
            "model_probability": round(model_probability, 4),
            "is_anomaly": is_anomaly,
            "severity": severity,
        }

    def get_spending_profile(
        self,
        user_id: str,
        expenses: pd.DataFrame | str | Path,
    ) -> Dict[str, Any]:
        expenses_df = _read_table(expenses)
        expenses_df["date"] = pd.to_datetime(expenses_df["date"])
        expenses_df["amount"] = expenses_df["amount"].astype(float)
        user_expenses = expenses_df[expenses_df["user_id"] == user_id].copy()
        if user_expenses.empty:
            raise ValueError(f"No expenses found for user_id={user_id}")

        feature_row = self._profile_feature_row(user_expenses)
        feature_frame = _ensure_columns(pd.DataFrame([feature_row]), self.profile_features)
        scaled = self.profile_scaler.transform(feature_frame[self.profile_features])
        cluster = int(self.profile_model.predict(scaled)[0])

        top_categories = (
            user_expenses.groupby("category")["amount"]
            .sum()
            .sort_values(ascending=False)
            .head(3)
            .round(2)
            .to_dict()
        )

        return {
            "user_id": user_id,
            "spending_cluster": cluster,
            "avg_daily_spend": round(float(feature_row["avg_daily_spend"]), 2),
            "activity_frequency": round(float(feature_row["activity_freq"]), 4),
            "top_categories": top_categories,
        }

    def generate_user_insights(
        self,
        user_id: str,
        expenses: pd.DataFrame | str | Path,
        users: pd.DataFrame | str | Path,
        target_month: Optional[str] = None,
        target_date: Optional[str] = None,
    ) -> Dict[str, Any]:
        forecast = self.forecast_next_month(user_id, expenses, users, target_month)
        anomaly = self.detect_anomaly(user_id, expenses, users, target_date)
        profile = self.get_spending_profile(user_id, expenses)

        suggestions = []
        if forecast["predicted_change_pct"] > 20:
            suggestions.append(
                "Projected monthly spending is meaningfully above the recent average; review flexible categories before the month starts."
            )
        if anomaly["is_anomaly"]:
            suggestions.append(
                f"{anomaly['date']} spending is unusually high compared with the user's prior 30-day average."
            )
        if profile["top_categories"]:
            top_category = next(iter(profile["top_categories"]))
            suggestions.append(f"The largest long-term category is {top_category}; budget guidance should start there.")

        return {
            "forecast": forecast,
            "anomaly": anomaly,
            "profile": profile,
            "suggestions": suggestions,
        }

    def _get_user(self, users_df: pd.DataFrame, user_id: str) -> pd.Series:
        matches = users_df[users_df["user_id"] == user_id]
        if matches.empty:
            raise ValueError(f"No user found for user_id={user_id}")
        return matches.iloc[0]

    def _encoded_user_profile(self, user_row: pd.Series) -> Dict[str, float]:
        row = {column: float(user_row.get(column, 0) or 0) for column in USER_PROFILE_COLUMNS}
        row.update({column: 0.0 for column in DEFAULT_PERSONA_COLUMNS})
        row.update({column: 0.0 for column in DEFAULT_LOCATION_COLUMNS})

        persona_column = f"persona_{user_row.get('persona', '')}"
        location_column = f"loc_{user_row.get('location_tier', '')}"
        if persona_column in row:
            row[persona_column] = 1.0
        if location_column in row:
            row[location_column] = 1.0
        return row

    def _daily_context_features(
        self,
        date_value: pd.Timestamp,
        history: pd.DataFrame,
        user_row: pd.Series,
    ) -> Dict[str, float]:
        row = {
            "weekday": float(date_value.dayofweek),
            "is_weekend": float(date_value.dayofweek >= 5),
            "day_of_month": float(date_value.day),
            "month": float(date_value.month),
            "is_payday": float(date_value.day in [1, 2, 3, 15, 16]),
            "quarter": float(date_value.quarter),
        }
        row.update(self._encoded_user_profile(user_row))

        total_history = history["daily_total"] if "daily_total" in history else pd.Series(dtype=float)
        count_history = history["daily_count"] if "daily_count" in history else pd.Series(dtype=float)
        row["prev_day_daily_total"] = float(total_history.iloc[-1]) if len(total_history) else 0.0
        row["prev_day_daily_count"] = float(count_history.iloc[-1]) if len(count_history) else 0.0

        for window in [7, 14, 30]:
            recent_total = total_history.tail(window)
            row[f"prev_daily_total_rolling_{window}d_mean"] = float(recent_total.mean()) if len(recent_total) else 0.0
            row[f"prev_daily_total_rolling_{window}d_std"] = float(recent_total.std()) if len(recent_total) > 1 else 0.0

            recent_count = count_history.tail(window)
            row[f"prev_daily_count_rolling_{window}d_mean"] = float(recent_count.mean()) if len(recent_count) else 0.0
        return row

    def _profile_feature_row(self, user_expenses: pd.DataFrame) -> Dict[str, float]:
        total_spent = float(user_expenses["amount"].sum())
        active_days = int(user_expenses["date"].nunique())
        first_date = user_expenses["date"].min()
        last_date = user_expenses["date"].max()
        tenure_days = max(int((last_date - first_date).days), 0)

        row = {
            "avg_daily_spend": total_spent / max(active_days, 1),
            "spend_variance": float(user_expenses["amount"].std() or 0) / (float(user_expenses["amount"].mean()) + 1),
            "activity_freq": active_days / (tenure_days + 1),
            "neg_pct": float((user_expenses["amount"] < 0).sum()) / (len(user_expenses) + 1),
            "pct_group": float(user_expenses.get("is_group_expense", pd.Series([0])).astype(float).mean()),
            "pct_recurring": float(user_expenses.get("is_recurring", pd.Series([0])).astype(float).mean()),
        }

        category_totals = user_expenses.groupby("category")["amount"].sum()
        category_sum = float(category_totals.sum())
        for category, amount in category_totals.items():
            row[f"cat_pct_{category}"] = float(amount) / category_sum if category_sum else 0.0
        return row
