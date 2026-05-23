"""
File: assistant_v2/finance_assistant.py
What does this file do?
    Provides the app-facing V2 finance assistant that loads saved models,
    accepts normalized or raw app payloads, and returns secure insight responses.
Methods/functions this file contains:
    FinanceAssistantV2, FinanceAssistantV2.generate_insights,
    FinanceAssistantV2._forecast, FinanceAssistantV2._budget_risk,
    FinanceAssistantV2._anomaly, FinanceAssistantV2._shared_settlement_risk,
    FinanceAssistantV2._summaries, FinanceAssistantV2._make_monthly_feature_row.
Date and Day of last modification:
    2026-05-16, Saturday.
"""

from __future__ import annotations

import json
from pathlib import Path
from typing import Any, Dict

import joblib
import numpy as np
import pandas as pd

from assistant_v2.insight_engine import build_insights
from assistant_v2.middleware_schema import normalize_payload
from config_v2 import CATEGORIES


class FinanceAssistantV2:
    def __init__(self, models_dir: str | Path = "models_v2_nepal") -> None:
        self.models_dir = Path(models_dir)
        self.monthly_model = joblib.load(self.models_dir / "monthly_forecast_v2.pkl")
        self.monthly_features = joblib.load(self.models_dir / "monthly_forecast_features_v2.pkl")
        self.budget_model = joblib.load(self.models_dir / "budget_risk_v2.pkl")
        self.budget_features = joblib.load(self.models_dir / "budget_risk_features_v2.pkl")
        self.anomaly_model = joblib.load(self.models_dir / "anomaly_detector_v2.pkl")
        self.anomaly_features = joblib.load(self.models_dir / "anomaly_features_v2.pkl")
        self.shared_model = joblib.load(self.models_dir / "shared_settlement_risk_v2.pkl")
        self.shared_features = joblib.load(self.models_dir / "shared_settlement_features_v2.pkl")
        thresholds_path = self.models_dir / "classification_thresholds_v2.json"
        if thresholds_path.exists():
            with open(thresholds_path, encoding="utf-8") as file:
                self.thresholds = json.load(file)
        else:
            self.thresholds = {"budget_risk": 0.5, "anomaly_detection": 0.5, "shared_settlement": 0.5}

    def generate_insights(self, payload: Dict[str, Any]) -> Dict[str, Any]:
        data = normalize_payload(payload)
        expenses = data["expenses"]
        if expenses.empty:
            return {"status": "insufficient_data", "insights": [], "privacy": {"raw_identity_fields_used": False}}

        forecast = self._forecast(data)
        budget_risk = self._budget_risk(data, forecast)
        anomaly = self._anomaly(data)
        category_summary, shared_summary = self._summaries(data)
        shared_settlement = self._shared_settlement_risk(data)
        summary = {
            "forecast": forecast,
            "budget_risk": budget_risk,
            "anomaly": anomaly,
            "category_summary": category_summary,
            "shared_summary": shared_summary,
            "shared_settlement": shared_settlement,
        }
        return {
            "status": "ok",
            "currency": "NPR",
            "summary": summary,
            "insights": build_insights(summary),
            "privacy": {
                "raw_identity_fields_used": False,
                "model_input_uses_normalized_finance_fields": True,
            },
        }

    def _forecast(self, data: Dict[str, pd.DataFrame]) -> Dict[str, Any]:
        row = self._make_monthly_feature_row(data)
        frame = pd.DataFrame([row])
        for column in self.monthly_features:
            if column not in frame.columns:
                frame[column] = 0
        prediction = float(np.expm1(self.monthly_model.predict(frame[self.monthly_features])[0]))
        recent_avg = float(row.get("recent_3m_avg", 0))
        change_pct = ((prediction - recent_avg) / recent_avg * 100) if recent_avg else 0
        return {
            "predicted_next_month_spend_npr": round(max(prediction, 0), 2),
            "recent_average_npr": round(recent_avg, 2),
            "change_vs_recent_avg_pct": round(change_pct, 2),
        }

    def _budget_risk(self, data: Dict[str, pd.DataFrame], forecast: Dict[str, Any]) -> Dict[str, Any]:
        row = self._make_monthly_feature_row(data)
        frame = pd.DataFrame([row])
        for column in self.budget_features:
            if column not in frame.columns:
                frame[column] = 0
        probability = float(self.budget_model.predict_proba(frame[self.budget_features])[0, 1])
        threshold = float(self.thresholds.get("budget_risk", 0.5))
        monthly_budget = float(data["budgets"]["monthly_budget_npr"].sum()) if not data["budgets"].empty else 0
        exceed_amount = max(0.0, forecast["predicted_next_month_spend_npr"] - monthly_budget) if monthly_budget else 0.0
        return {
            "risk_probability": round(probability, 4),
            "risk_threshold": round(threshold, 4),
            "is_budget_risk": bool(probability >= threshold or exceed_amount > 0),
            "monthly_budget_npr": round(monthly_budget, 2),
            "projected_exceed_amount_npr": round(exceed_amount, 2),
        }

    def _anomaly(self, data: Dict[str, pd.DataFrame]) -> Dict[str, Any]:
        expenses = data["expenses"].copy()
        expenses["date"] = pd.to_datetime(expenses["date"])
        expenses["amount_npr"] = expenses["amount_npr"].astype(float)
        latest_date = expenses["date"].max()
        daily = expenses.groupby("date").agg(daily_total_npr=("amount_npr", "sum"), daily_count=("expense_id", "count")).sort_index()
        current_total = float(daily.loc[latest_date, "daily_total_npr"])
        history = daily[daily.index < latest_date]
        baseline = float(history["daily_total_npr"].tail(30).mean()) if len(history) else 0
        spend_ratio = current_total / (baseline + 1)

        row = {
            "weekday": latest_date.dayofweek,
            "is_weekend": int(latest_date.dayofweek >= 5),
            "day_of_month": latest_date.day,
            "month": latest_date.month,
            "is_payday_window": int(latest_date.day in [1, 2, 3, 15, 16]),
            "is_festival_window": 0,
            "prev_daily_total_npr_1d": float(history["daily_total_npr"].iloc[-1]) if len(history) else 0,
            "prev_daily_total_npr_7d_avg": float(history["daily_total_npr"].tail(7).mean()) if len(history) else 0,
            "prev_daily_total_npr_30d_avg": baseline,
        }
        frame = pd.DataFrame([row])
        for column in self.anomaly_features:
            if column not in frame.columns:
                frame[column] = 0
        probability = float(self.anomaly_model.predict_proba(frame[self.anomaly_features])[0, 1])
        threshold = float(self.thresholds.get("anomaly_detection", 0.5))
        is_anomaly = bool(probability >= threshold or (baseline > 0 and current_total > baseline * 2.8))
        return {
            "latest_date": latest_date.strftime("%Y-%m-%d"),
            "latest_day_total_npr": round(current_total, 2),
            "prior_30_day_avg_npr": round(baseline, 2),
            "spend_ratio": round(spend_ratio, 2),
            "model_probability": round(probability, 4),
            "model_threshold": round(threshold, 4),
            "is_anomaly": is_anomaly,
            "severity": "high" if spend_ratio >= 4 else "medium" if is_anomaly else "normal",
        }

    def _shared_settlement_risk(self, data: Dict[str, pd.DataFrame]) -> Dict[str, Any]:
        shared = data["shared_expenses"].copy()
        expenses = data["expenses"].copy()
        if shared.empty or expenses.empty:
            return {
                "has_shared_activity": False,
                "risk_probability": 0.0,
                "risk_threshold": round(float(self.thresholds.get("shared_settlement", 0.5)), 4),
                "is_settlement_risk": False,
            }

        expenses["date"] = pd.to_datetime(expenses["date"])
        expenses["amount_npr"] = expenses["amount_npr"].astype(float)
        merged = shared.merge(
            expenses[["expense_id", "date", "amount_npr", "category"]],
            on="expense_id",
            how="left",
        ).dropna(subset=["date", "amount_npr"])
        if merged.empty:
            estimated_amount = 0.0
            if "amount_npr" in shared.columns:
                estimated_amount = float(pd.to_numeric(shared["amount_npr"], errors="coerce").dropna().tail(1).sum())
            return {
                "has_shared_activity": True,
                "risk_probability": 0.0,
                "risk_threshold": round(float(self.thresholds.get("shared_settlement", 0.5)), 4),
                "is_settlement_risk": False,
                "status": "missing_matching_expense_details",
                "estimated_latest_shared_amount_npr": round(estimated_amount, 2),
            }

        merged["date"] = pd.to_datetime(merged["date"])
        latest = merged.sort_values("date").iloc[-1]
        historical = merged[merged["date"] < latest["date"]]
        group_history = historical[historical["group_id"] == latest.get("group_id", "")]
        payer_history = historical[historical["paid_by_user_id"] == latest.get("paid_by_user_id", "")]
        amount_per_person = float(latest["amount_npr"]) / max(float(latest.get("participant_count", 1) or 1), 1.0)

        group_prior_avg = float(group_history["amount_npr"].mean()) if not group_history.empty else 0.0
        payer_prior_avg = float(payer_history["amount_npr"].mean()) if not payer_history.empty else 0.0
        group_prior_late = (
            (group_history["days_to_settle"].astype(float) > 14).mean()
            if "days_to_settle" in group_history and not group_history.empty
            else 0.0
        )
        payer_prior_late = (
            (payer_history["days_to_settle"].astype(float) > 14).mean()
            if "days_to_settle" in payer_history and not payer_history.empty
            else 0.0
        )

        row = {
            "participant_count": float(latest.get("participant_count", 1) or 1),
            "amount_npr": float(latest["amount_npr"]),
            "month": float(latest["date"].month),
            "is_festival_month": float(latest["date"].month in [4, 9, 10, 11]),
            "amount_per_person_npr": amount_per_person,
            "group_prior_shared_count": float(len(group_history)),
            "payer_prior_shared_count": float(len(payer_history)),
            "group_prior_late_rate": float(group_prior_late),
            "payer_prior_late_rate": float(payer_prior_late),
            "group_prior_avg_amount_per_person": group_prior_avg,
            "payer_prior_avg_amount_per_person": payer_prior_avg,
            "amount_vs_group_history": amount_per_person / group_prior_avg if group_prior_avg else 0.0,
            "amount_vs_payer_history": amount_per_person / payer_prior_avg if payer_prior_avg else 0.0,
            f"split_{latest.get('split_type', 'equal')}": 1.0,
            f"category_{latest.get('category', '')}": 1.0,
        }
        frame = pd.DataFrame([row])
        for column in self.shared_features:
            if column not in frame.columns:
                frame[column] = 0

        probability = float(self.shared_model.predict_proba(frame[self.shared_features])[0, 1])
        threshold = float(self.thresholds.get("shared_settlement", 0.5))
        return {
            "has_shared_activity": True,
            "latest_shared_expense_id": str(latest.get("shared_expense_id", "")),
            "risk_probability": round(probability, 4),
            "risk_threshold": round(threshold, 4),
            "is_settlement_risk": bool(probability >= threshold),
            "participant_count": int(latest.get("participant_count", 1) or 1),
            "amount_per_person_npr": round(amount_per_person, 2),
        }

    def _summaries(self, data: Dict[str, pd.DataFrame]) -> tuple[Dict[str, Any], Dict[str, Any]]:
        expenses = data["expenses"].copy()
        expenses["date"] = pd.to_datetime(expenses["date"])
        expenses["amount_npr"] = expenses["amount_npr"].astype(float)
        category_totals = expenses.groupby("category")["amount_npr"].sum().sort_values(ascending=False)
        total = float(expenses["amount_npr"].sum())
        top_category = str(category_totals.index[0]) if len(category_totals) else ""
        shared_total = float(expenses[expenses["is_shared"].astype(bool)]["amount_npr"].sum()) if "is_shared" in expenses else 0
        expenses["year_month"] = expenses["date"].dt.to_period("M")
        monthly_category = expenses.pivot_table(
            index="year_month",
            columns="category",
            values="amount_npr",
            aggfunc="sum",
            fill_value=0,
        ).sort_index()
        top_category_change_pct = 0.0
        flexible_total = float(expenses[~expenses["is_essential"].astype(bool)]["amount_npr"].sum()) if "is_essential" in expenses else 0.0
        if top_category and len(monthly_category) >= 2 and top_category in monthly_category:
            latest_value = float(monthly_category[top_category].iloc[-1])
            previous_average = float(monthly_category[top_category].iloc[:-1].tail(3).mean())
            top_category_change_pct = ((latest_value - previous_average) / previous_average * 100) if previous_average else 0.0
        return (
            {
                "top_category": top_category,
                "top_category_amount_npr": round(float(category_totals.iloc[0]), 2) if len(category_totals) else 0,
                "top_category_change_pct": round(top_category_change_pct, 2),
                "flexible_spend_npr": round(flexible_total, 2),
                "flexible_spend_ratio": round(flexible_total / total, 4) if total else 0,
            },
            {
                "shared_total_npr": round(shared_total, 2),
                "shared_ratio": round(shared_total / total, 4) if total else 0,
            },
        )

    def _make_monthly_feature_row(self, data: Dict[str, pd.DataFrame]) -> Dict[str, float]:
        expenses = data["expenses"].copy()
        users = data["users"]
        budgets = data["budgets"]
        expenses["date"] = pd.to_datetime(expenses["date"])
        expenses["year_month"] = expenses["date"].dt.to_period("M")
        expenses["amount_npr"] = expenses["amount_npr"].astype(float)
        latest_period = expenses["year_month"].max()
        next_period = latest_period + 1
        monthly = expenses.groupby("year_month").agg(
            total_spend_npr=("amount_npr", "sum"),
            essential_spend_npr=("amount_npr", lambda values: values[expenses.loc[values.index, "is_essential"].astype(bool)].sum()),
            flexible_spend_npr=("amount_npr", lambda values: values[~expenses.loc[values.index, "is_essential"].astype(bool)].sum()),
            transaction_count=("expense_id", "count"),
            shared_paid_npr=("amount_npr", lambda values: values[expenses.loc[values.index, "is_shared"].astype(bool)].sum()),
            cash_spend_npr=("amount_npr", lambda values: values[expenses.loc[values.index, "payment_method"].eq("cash")].sum()),
        ).sort_index()
        category_monthly = expenses.pivot_table(
            index="year_month",
            columns="category",
            values="amount_npr",
            aggfunc="sum",
            fill_value=0,
        ).sort_index()
        observed_income = 0.0
        if "income" in data and not data["income"].empty:
            income = data["income"].copy()
            income["income_date"] = pd.to_datetime(income["income_date"])
            income["year_month"] = income["income_date"].dt.to_period("M")
            observed_income = float(income[income["year_month"] == latest_period]["income_amount_npr"].sum())

        user = users.iloc[0]
        row: Dict[str, float] = {
            "month_num": float((next_period.year - 2023) * 12 + next_period.month),
            "month": float(next_period.month),
            "is_festival_month": float(next_period.month in [4, 9, 10, 11]),
            "observed_monthly_income_npr": observed_income,
            "profile_monthly_income_npr": float(user.get("monthly_income_npr", 0)),
            "effective_monthly_income_npr": observed_income or float(user.get("monthly_income_npr", 0)),
            "monthly_budget_npr": float(budgets["monthly_budget_npr"].sum()) if not budgets.empty else 0,
            "age": float(user.get("age", 0)),
            "family_dependency_count": float(user.get("family_dependency_count", 0)),
            "activity_rate": float(user.get("activity_rate", 0)),
            "spend_multiplier": float(user.get("spend_multiplier", 1)),
            "saving_rate": float(user.get("saving_rate", 0)),
            "shared_tendency": float(user.get("shared_tendency", 0)),
            "city_price_multiplier": float(user.get("city_price_multiplier", 1)),
            "recent_3m_avg": float(monthly["total_spend_npr"].tail(3).mean()) if len(monthly) else 0,
        }
        for prefix, value in [
            ("persona", user.get("financial_persona", "")),
            ("city", user.get("city_tier", "")),
            ("income_type", user.get("income_type", "")),
            ("rent_status", user.get("rent_status", "")),
        ]:
            row[f"{prefix}_{value}"] = 1.0

        for source in [
            "total_spend_npr",
            "essential_spend_npr",
            "flexible_spend_npr",
            "transaction_count",
            "shared_paid_npr",
            "cash_spend_npr",
        ]:
            series = monthly[source] if source in monthly else pd.Series(dtype=float)
            row[f"prev_{source}_1m"] = float(series.iloc[-1]) if len(series) else 0
            row[f"prev_{source}_3m_avg"] = float(series.tail(3).mean()) if len(series) else 0

        for category in CATEGORIES:
            series = category_monthly[category] if category in category_monthly else pd.Series(dtype=float)
            row[f"prev_cat_{category}_1m"] = float(series.iloc[-1]) if len(series) else 0
            row[f"prev_cat_{category}_3m_avg"] = float(series.tail(3).mean()) if len(series) else 0

        row["prev_shared_owed_npr_1m"] = row["prev_shared_paid_npr_1m"]
        row["prev_shared_owed_npr_3m_avg"] = row["prev_shared_paid_npr_3m_avg"]
        row["prev_pending_shared_npr_1m"] = 0
        row["prev_pending_shared_npr_3m_avg"] = 0
        row["income_spend_ratio_prev"] = row["prev_total_spend_npr_1m"] / row["effective_monthly_income_npr"] if row["effective_monthly_income_npr"] else 0
        row["budget_utilization_prev"] = row["prev_total_spend_npr_1m"] / row["monthly_budget_npr"] if row["monthly_budget_npr"] else 0
        row["shared_burden_ratio_prev"] = 0
        return row
