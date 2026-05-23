#!/usr/bin/env python3
"""
V2 analytics ML bridge for RoomEase.

Exposes compatibility endpoints used by the Go backend:
- POST /api/ml/predictions
- POST /api/ml/recommendations
- POST /api/ml/anomalies
- GET  /health
"""

from __future__ import annotations

import json
import os
from http.server import BaseHTTPRequestHandler, HTTPServer
from typing import Any, Dict, List

from assistant_v2.finance_assistant import FinanceAssistantV2


def _safe_float(value: Any, default: float = 0.0) -> float:
    try:
        return float(value)
    except (TypeError, ValueError):
        return default


def _safe_int(value: Any, default: int = 0) -> int:
    try:
        return int(value)
    except (TypeError, ValueError):
        return default


def _build_payload(request_data: Dict[str, Any]) -> Dict[str, Any]:
    user_id = str(request_data.get("user_id", "app_user"))
    expenses_input = request_data.get("expenses", []) or []

    expenses: List[Dict[str, Any]] = []
    shared_expenses: List[Dict[str, Any]] = []
    total_amount = 0.0

    for index, raw in enumerate(expenses_input, start=1):
        amount = _safe_float(raw.get("amount", 0.0))
        total_amount += amount
        category = str(raw.get("category", "miscellaneous") or "miscellaneous")
        expense_id = str(raw.get("id", f"exp_{index}"))
        date_value = str(raw.get("date", "2026-01-01"))
        group_id = str(raw.get("roomspace_id", request_data.get("roomspace_id", "")))
        is_shared = bool(group_id)

        expenses.append(
            {
                "expense_id": expense_id,
                "user_id": user_id,
                "date": date_value,
                "amount": amount,
                "currency": "NPR",
                "category": category,
                "payment_method": "cash",
                "is_shared": is_shared,
                "group_id": group_id,
                "is_recurring": False,
                "is_essential": category in {"rent", "groceries", "utilities", "education", "health"},
            }
        )

        if is_shared:
            shared_expenses.append(
                {
                    "shared_expense_id": f"shr_{expense_id}",
                    "expense_id": expense_id,
                    "group_id": group_id,
                    "paid_by_user_id": user_id,
                    "split_type": "equal",
                    "participant_count": max(_safe_int(raw.get("participant_count", 2), 2), 1),
                    "settlement_status": "pending",
                    "days_to_settle": 7,
                }
            )

    monthly_budget = total_amount * 0.9 if total_amount > 0 else 0.0

    return {
        "user": {
            "user_id": user_id,
            "age": 28,
            "monthly_income_npr": max(total_amount * 2.0, 50000.0),
            "city_tier": "kathmandu_valley",
            "income_type": "fixed",
            "rent_status": "renter",
            "financial_persona": "salaried_balanced",
            "family_dependency_count": 0,
        },
        "expenses": expenses,
        "income": [],
        "budgets": [{"category": "total", "monthly_budget_npr": monthly_budget}],
        "shared_expenses": shared_expenses,
    }


def _as_predictions(response: Dict[str, Any], payload: Dict[str, Any]) -> Dict[str, Any]:
    summary = response.get("summary", {})
    forecast = summary.get("forecast", {})
    category_summary = summary.get("category_summary", {})
    predicted_total = _safe_float(forecast.get("predicted_next_month_spend_npr", 0.0))
    top_category = str(category_summary.get("top_category", "miscellaneous") or "miscellaneous")
    top_amount = _safe_float(category_summary.get("top_category_amount_npr", 0.0))
    if top_amount <= 0:
        top_amount = predicted_total

    return {
        "success": True,
        "insufficient_data": response.get("status") != "ok",
        "predictions": [
            {
                "category": top_category,
                "predicted_amount": round(max(top_amount, predicted_total, 0.0), 2),
                "confidence_low": round(max(predicted_total * 0.85, 0.0), 2),
                "confidence_high": round(max(predicted_total * 1.15, 0.0), 2),
                "historical_avg": round(_safe_float(forecast.get("recent_average_npr", 0.0)), 2),
                "ml_confidence": round(min(max(1.0 - abs(_safe_float(forecast.get("change_vs_recent_avg_pct", 0.0))) / 100.0, 0.3), 0.95), 2),
            }
        ],
    }


def _as_recommendations(response: Dict[str, Any], payload: Dict[str, Any]) -> Dict[str, Any]:
    summary = response.get("summary", {})
    budget = summary.get("budget_risk", {})
    category = summary.get("category_summary", {})
    insights = response.get("insights", []) or []

    recommendations: List[Dict[str, Any]] = []
    projected_exceed = _safe_float(budget.get("projected_exceed_amount_npr", 0.0))
    if projected_exceed > 0:
        recommendations.append(
            {
                "id": "ml_budget_risk_1",
                "type": "budget_risk",
                "category": str(category.get("top_category", "total")),
                "current_spending": round(_safe_float(category.get("top_category_amount_npr", 0.0)), 2),
                "suggested_limit": round(max(_safe_float(budget.get("monthly_budget_npr", 0.0)), 0.0), 2),
                "potential_savings": round(projected_exceed, 2),
                "description": "Projected spending may exceed budget. Reduce flexible expenses this month.",
                "priority": 1,
                "ml_confidence": round(_safe_float(budget.get("risk_probability", 0.0)), 2),
            }
        )

    for idx, item in enumerate(insights[:3], start=1):
        recommendations.append(
            {
                "id": f"ml_insight_{idx}",
                "type": str(item.get("type", "insight")),
                "category": str(category.get("top_category", "general")),
                "current_spending": round(_safe_float(category.get("top_category_amount_npr", 0.0)), 2),
                "suggested_limit": round(max(_safe_float(category.get("top_category_amount_npr", 0.0)) * 0.85, 0.0), 2),
                "potential_savings": round(max(_safe_float(category.get("top_category_amount_npr", 0.0)) * 0.15, 0.0), 2),
                "description": str(item.get("message", "Review spending pattern and optimize.")),
                "priority": 2 if str(item.get("severity", "low")) == "medium" else 3,
                "ml_confidence": 0.7,
            }
        )

    return {"success": True, "recommendations": recommendations}


def _as_anomalies(response: Dict[str, Any], payload: Dict[str, Any]) -> Dict[str, Any]:
    summary = response.get("summary", {})
    anomaly = summary.get("anomaly", {})
    expenses = payload.get("expenses", []) or []

    if not expenses:
        return {"success": True, "anomalies": []}

    latest = expenses[0]
    if len(expenses) > 1:
        latest = max(expenses, key=lambda e: str(e.get("date", "")))

    is_anomaly = bool(anomaly.get("is_anomaly", False))
    if not is_anomaly:
        return {"success": True, "anomalies": []}

    return {
        "success": True,
        "anomalies": [
            {
                "expense_id": _safe_int(latest.get("id", 0)),
                "amount": round(_safe_float(latest.get("amount", 0.0)), 2),
                "category": str(latest.get("category", "miscellaneous")),
                "anomaly_score": round(_safe_float(anomaly.get("spend_ratio", 0.0)), 2),
                "reason": f"Model detected unusual spending (probability {_safe_float(anomaly.get('model_probability', 0.0)):.2f}).",
                "category_average": round(_safe_float(anomaly.get("prior_30_day_avg_npr", 0.0)), 2),
                "date": str(anomaly.get("latest_date", latest.get("date", ""))),
                "ml_confidence": round(_safe_float(anomaly.get("model_probability", 0.0)), 2),
            }
        ],
    }


class _Handler(BaseHTTPRequestHandler):
    assistant: FinanceAssistantV2

    def _send_json(self, code: int, payload: Dict[str, Any]) -> None:
        body = json.dumps(payload).encode("utf-8")
        self.send_response(code)
        self.send_header("Content-Type", "application/json")
        self.send_header("Content-Length", str(len(body)))
        self.end_headers()
        self.wfile.write(body)

    def do_GET(self) -> None:  # noqa: N802
        if self.path == "/health":
            self._send_json(
                200,
                {
                    "status": "ok",
                    "service": "analytics-ml-v2-bridge",
                    "model_loaded": True,
                },
            )
            return
        self._send_json(404, {"success": False, "error": "Not found"})

    def do_POST(self) -> None:  # noqa: N802
        if self.path not in ("/api/ml/predictions", "/api/ml/recommendations", "/api/ml/anomalies"):
            self._send_json(404, {"success": False, "error": "Not found"})
            return

        try:
            content_len = int(self.headers.get("Content-Length", "0"))
            raw = self.rfile.read(content_len) if content_len > 0 else b"{}"
            request_data = json.loads(raw.decode("utf-8"))
            payload = _build_payload(request_data)
            model_response = self.assistant.generate_insights(payload)

            if self.path == "/api/ml/predictions":
                out = _as_predictions(model_response, request_data)
            elif self.path == "/api/ml/recommendations":
                out = _as_recommendations(model_response, request_data)
            else:
                out = _as_anomalies(model_response, request_data)

            self._send_json(200, out)
        except Exception as exc:  # pragma: no cover
            self._send_json(500, {"success": False, "error": f"{exc}"})


def main() -> None:
    port = int(os.getenv("ML_API_PORT", "5001"))
    host = os.getenv("ML_API_HOST", "0.0.0.0")
    models_dir = os.getenv("V2_MODELS_DIR", "models_v2_nepal")
    _Handler.assistant = FinanceAssistantV2(models_dir)
    print(f"Loaded FinanceAssistantV2 from {models_dir}")
    server = HTTPServer((host, port), _Handler)
    print(f"ML bridge listening on http://{host}:{port}")
    server.serve_forever()


if __name__ == "__main__":
    main()
