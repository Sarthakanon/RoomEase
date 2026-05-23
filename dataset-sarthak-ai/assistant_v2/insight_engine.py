"""
File: assistant_v2/insight_engine.py
What does this file do?
    Converts V2 model outputs and user spending summaries into clear,
    explainable finance insights for mobile applications.
Methods/functions this file contains:
    build_insights.
Date and Day of last modification:
    2026-05-16, Saturday.
"""

from __future__ import annotations

from typing import Any, Dict, List


def build_insights(summary: Dict[str, Any]) -> List[Dict[str, Any]]:
    insights: List[Dict[str, Any]] = []

    forecast = summary.get("forecast", {})
    budget = summary.get("budget_risk", {})
    anomaly = summary.get("anomaly", {})
    category = summary.get("category_summary", {})
    shared = summary.get("shared_summary", {})
    settlement = summary.get("shared_settlement", {})

    if forecast.get("predicted_next_month_spend_npr", 0) > 0:
        change_pct = forecast.get("change_vs_recent_avg_pct", 0)
        if change_pct > 15:
            insights.append(
                {
                    "type": "forecast_warning",
                    "severity": "medium",
                    "title": "Spending may increase next month",
                    "message": f"Your next month spending is projected to be about NPR {forecast['predicted_next_month_spend_npr']:,.0f}, which is {change_pct:.0f}% above your recent average.",
                    "action": "Review flexible categories before the month starts.",
                }
            )
        else:
            insights.append(
                {
                    "type": "forecast",
                    "severity": "low",
                    "title": "Next month spending forecast",
                    "message": f"Your projected next month spending is about NPR {forecast['predicted_next_month_spend_npr']:,.0f}.",
                    "action": "Use this as a planning baseline.",
                }
            )

    if budget.get("is_budget_risk") or budget.get("risk_probability", 0) >= 0.65 or budget.get("projected_exceed_amount_npr", 0) > 0:
        insights.append(
            {
                "type": "budget_risk",
                "severity": "high",
                "title": "Budget risk is high",
                "message": f"Your projected spending is above budget by about NPR {budget.get('projected_exceed_amount_npr', 0):,.0f}.",
                "action": "Reduce optional spending or adjust category budgets.",
            }
        )

    if anomaly.get("is_anomaly"):
        insights.append(
            {
                "type": "anomaly",
                "severity": anomaly.get("severity", "medium"),
                "title": "Unusual spending detected",
                "message": f"Recent spending is {anomaly.get('spend_ratio', 0):.1f}x your prior baseline.",
                "action": "Check if this was planned, shared, or one-time spending.",
            }
        )

    if category:
        top_category = category.get("top_category")
        if top_category:
            change_pct = category.get("top_category_change_pct", 0)
            message = f"Your largest recent category is {top_category}, totaling NPR {category.get('top_category_amount_npr', 0):,.0f}."
            if change_pct > 20:
                message = f"{top_category} is your largest category and is {change_pct:.0f}% above its recent pattern."
            insights.append(
                {
                    "type": "category_focus",
                    "severity": "medium" if change_pct > 20 else "low",
                    "title": "Largest spending category",
                    "message": message,
                    "action": "Start optimization from the largest controllable category.",
                }
            )

        if category.get("flexible_spend_ratio", 0) > 0.45:
            insights.append(
                {
                    "type": "flexible_spend",
                    "severity": "medium",
                    "title": "Flexible spending is high",
                    "message": f"Flexible spending is {category['flexible_spend_ratio'] * 100:.0f}% of recent expenses.",
                    "action": "Set a weekly limit for restaurants, entertainment, shopping, and travel.",
                }
            )

    if shared.get("shared_ratio", 0) > 0.25:
        insights.append(
            {
                "type": "shared_expense",
                "severity": "medium",
                "title": "Shared expenses are significant",
                "message": f"Shared expenses are {shared['shared_ratio'] * 100:.0f}% of recent spending.",
                "action": "Track pending settlements separately from personal spending.",
            }
        )

    if settlement.get("is_settlement_risk"):
        insights.append(
            {
                "type": "shared_settlement_risk",
                "severity": "medium",
                "title": "Shared settlement may be delayed",
                "message": f"The latest shared expense has a {settlement['risk_probability'] * 100:.0f}% settlement delay risk.",
                "action": "Send a settlement reminder or confirm split details early.",
            }
        )

    return insights
