"""
File: validate_model_bundle_v2.py
What does this file do?
    Validates the final Nepal finance V2 model bundle, required artifacts,
    minimum metric quality, thresholds, and app-facing assistant response.
Methods/functions this file contains:
    _load_json, _assert_required_files, _assert_metrics, _sample_payload,
    _assert_runtime_response, main.
Date and Day of last modification:
    2026-05-16, Saturday.
"""

from __future__ import annotations

import argparse
import json
from pathlib import Path
from typing import Any, Dict

import pandas as pd

from assistant_v2.finance_assistant import FinanceAssistantV2


REQUIRED_MODEL_FILES = [
    "monthly_forecast_v2.pkl",
    "monthly_forecast_features_v2.pkl",
    "budget_risk_v2.pkl",
    "budget_risk_features_v2.pkl",
    "anomaly_detector_v2.pkl",
    "anomaly_features_v2.pkl",
    "shared_settlement_risk_v2.pkl",
    "shared_settlement_features_v2.pkl",
    "spending_profile_kmeans_v2.pkl",
    "spending_profile_scaler_v2.pkl",
    "spending_profile_features_v2.pkl",
    "classification_thresholds_v2.json",
    "training_summary_v2_nepal.json",
]


def _load_json(path: Path) -> Dict[str, Any]:
    with open(path, encoding="utf-8") as file:
        return json.load(file)


def _assert_required_files(models_dir: Path) -> None:
    missing = [name for name in REQUIRED_MODEL_FILES if not (models_dir / name).exists()]
    if missing:
        raise AssertionError(f"Missing model bundle files: {missing}")


def _assert_metrics(summary: Dict[str, Any]) -> None:
    checks = {
        "monthly_forecast.r2": summary["monthly_forecast"]["r2"] >= 0.35,
        "monthly_forecast.mae_beats_baseline": summary["monthly_forecast"]["mae_npr"] < summary["monthly_forecast"]["baseline_mae_npr"],
        "budget_risk.auc": summary["budget_risk"]["auc"] >= 0.85,
        "budget_risk.f1": summary["budget_risk"]["f1"] >= 0.80,
        "anomaly_detection.auc": summary["anomaly_detection"]["auc"] >= 0.70,
        "anomaly_detection.f1": summary["anomaly_detection"]["f1"] >= 0.35,
        "shared_settlement.auc": summary["shared_settlement"]["auc"] >= 0.65,
        "shared_settlement.f1": summary["shared_settlement"]["f1"] >= 0.25,
    }
    failed = [name for name, passed in checks.items() if not passed]
    if failed:
        raise AssertionError(f"Metric validation failed: {failed}")


def _sample_payload(data_dir: Path) -> Dict[str, Any]:
    users = pd.read_csv(data_dir / "users.csv")
    expenses = pd.read_csv(data_dir / "expenses.csv", low_memory=False)
    income = pd.read_csv(data_dir / "income_events.csv")
    budgets = pd.read_csv(data_dir / "budgets.csv")
    shared = pd.read_csv(data_dir / "shared_expenses.csv")

    shared_expenses = expenses[expenses["is_shared"].astype(str).str.lower().eq("true")]
    user_id = str(shared_expenses.iloc[0]["user_id"]) if not shared_expenses.empty else str(users.iloc[0]["user_id"])
    user_expenses = expenses[expenses.user_id == user_id].tail(500)
    matching_shared = shared[shared["expense_id"].isin(user_expenses["expense_id"])].tail(50)

    return {
        "user": users[users.user_id == user_id].iloc[0].to_dict(),
        "expenses": user_expenses.to_dict("records"),
        "income": income[income.user_id == user_id].tail(12).to_dict("records"),
        "budgets": budgets[budgets.user_id == user_id].to_dict("records"),
        "shared_expenses": matching_shared.to_dict("records"),
    }


def _assert_runtime_response(models_dir: Path, data_dir: Path) -> Dict[str, Any]:
    response = FinanceAssistantV2(models_dir).generate_insights(_sample_payload(data_dir))
    if response.get("status") != "ok":
        raise AssertionError(f"Unexpected assistant status: {response.get('status')}")

    summary = response.get("summary", {})
    required_sections = [
        "forecast",
        "budget_risk",
        "anomaly",
        "category_summary",
        "shared_summary",
        "shared_settlement",
    ]
    missing = [section for section in required_sections if section not in summary]
    if missing:
        raise AssertionError(f"Missing response sections: {missing}")
    if "risk_threshold" not in summary["budget_risk"]:
        raise AssertionError("Budget threshold was not exposed in runtime response")
    if "model_threshold" not in summary["anomaly"]:
        raise AssertionError("Anomaly threshold was not exposed in runtime response")
    if "risk_threshold" not in summary["shared_settlement"]:
        raise AssertionError("Shared settlement threshold was not exposed in runtime response")
    if response.get("privacy", {}).get("raw_identity_fields_used") is not False:
        raise AssertionError("Privacy metadata is missing or unsafe")
    return response


def main() -> None:
    parser = argparse.ArgumentParser(description="Validate Nepal finance V2 model bundle")
    parser.add_argument("--models-dir", type=str, default="models_v2_nepal")
    parser.add_argument("--data-dir", type=str, default="output_v2")
    args = parser.parse_args()

    models_dir = Path(args.models_dir)
    data_dir = Path(args.data_dir)
    _assert_required_files(models_dir)
    summary = _load_json(models_dir / "training_summary_v2_nepal.json")
    _assert_metrics(summary)
    response = _assert_runtime_response(models_dir, data_dir)

    print("Finance Assistant V2 bundle validation passed")
    print(f"  Monthly forecast R2: {summary['monthly_forecast']['r2']:.3f}")
    print(f"  Budget risk F1/AUC: {summary['budget_risk']['f1']:.3f}/{summary['budget_risk']['auc']:.3f}")
    print(f"  Anomaly F1/AUC: {summary['anomaly_detection']['f1']:.3f}/{summary['anomaly_detection']['auc']:.3f}")
    print(f"  Shared settlement F1/AUC: {summary['shared_settlement']['f1']:.3f}/{summary['shared_settlement']['auc']:.3f}")
    print(f"  Runtime insight count: {len(response.get('insights', []))}")


if __name__ == "__main__":
    main()
