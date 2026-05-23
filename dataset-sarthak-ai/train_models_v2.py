"""
File: train_models_v2.py
What does this file do?
    Trains and saves V2 Nepal finance assistant models for monthly forecasting,
    budget risk, anomaly detection, spending profile clustering, and shared
    settlement risk.
Methods/functions this file contains:
    _load_features, _time_split, train_monthly_forecast, train_budget_risk,
    train_anomaly_detector, train_spending_profiles, train_shared_settlement,
    main.
Date and Day of last modification:
    2026-05-16, Saturday.
"""

from __future__ import annotations

import argparse
import json
from pathlib import Path
from typing import Dict, List, Tuple

import joblib
import numpy as np
import pandas as pd
from sklearn.cluster import KMeans
from sklearn.ensemble import HistGradientBoostingClassifier, HistGradientBoostingRegressor, RandomForestClassifier
from sklearn.metrics import (
    accuracy_score,
    f1_score,
    mean_absolute_error,
    mean_squared_error,
    precision_score,
    r2_score,
    recall_score,
    roc_auc_score,
)
from sklearn.preprocessing import StandardScaler


def _load_features(features_dir: Path, name: str) -> Tuple[pd.DataFrame, List[str]]:
    frame = pd.read_parquet(features_dir / f"{name}.parquet")
    with open(features_dir / f"{name.replace('_features', '')}_feature_cols.json", encoding="utf-8") as file:
        columns = json.load(file)
    return frame, columns


def _time_split(frame: pd.DataFrame, time_column: str = "month_num") -> Tuple[pd.DataFrame, pd.DataFrame]:
    cutoff = frame[time_column].quantile(0.72)
    return frame[frame[time_column] <= cutoff], frame[frame[time_column] > cutoff]


def _best_threshold(y_true: pd.Series, probabilities: np.ndarray, min_precision: float = 0.0) -> float:
    best_threshold = 0.5
    best_f1 = -1.0
    for threshold in np.linspace(0.05, 0.95, 91):
        predictions = (probabilities >= threshold).astype(int)
        precision = precision_score(y_true, predictions, zero_division=0)
        if precision < min_precision:
            continue
        score = f1_score(y_true, predictions, zero_division=0)
        if score > best_f1:
            best_f1 = score
            best_threshold = float(threshold)
    return best_threshold


def _classification_metrics(y_true: pd.Series, probabilities: np.ndarray, threshold: float) -> Dict[str, float]:
    predictions = (probabilities >= threshold).astype(int)
    metrics = {
        "threshold": float(threshold),
        "accuracy": float(accuracy_score(y_true, predictions)),
        "precision": float(precision_score(y_true, predictions, zero_division=0)),
        "recall": float(recall_score(y_true, predictions, zero_division=0)),
        "f1": float(f1_score(y_true, predictions, zero_division=0)),
    }
    if y_true.nunique() > 1:
        metrics["auc"] = float(roc_auc_score(y_true, probabilities))
    return metrics


def train_monthly_forecast(features_dir: Path, models_dir: Path) -> Dict[str, float]:
    frame, feature_cols = _load_features(features_dir, "monthly_features")
    train, test = _time_split(frame, "month_num")
    model = HistGradientBoostingRegressor(max_iter=220, learning_rate=0.06, max_leaf_nodes=31, random_state=42)
    model.fit(train[feature_cols], np.log1p(train["target_next_month_spend_npr"]))
    predictions = np.expm1(model.predict(test[feature_cols]))
    actual = test["target_next_month_spend_npr"]
    mae = mean_absolute_error(actual, predictions)
    rmse = float(np.sqrt(mean_squared_error(actual, predictions)))
    baseline = np.full(len(test), train["target_next_month_spend_npr"].median())
    baseline_mae = mean_absolute_error(actual, baseline)
    joblib.dump(model, models_dir / "monthly_forecast_v2.pkl")
    joblib.dump(feature_cols, models_dir / "monthly_forecast_features_v2.pkl")
    return {
        "mae_npr": float(mae),
        "rmse_npr": rmse,
        "r2": float(r2_score(actual, predictions)),
        "baseline_mae_npr": float(baseline_mae),
        "train_rows": int(len(train)),
        "test_rows": int(len(test)),
    }


def train_budget_risk(features_dir: Path, models_dir: Path) -> Dict[str, float]:
    frame, feature_cols = _load_features(features_dir, "monthly_features")
    train, test = _time_split(frame, "month_num")
    model = HistGradientBoostingClassifier(max_iter=180, learning_rate=0.06, max_leaf_nodes=31, random_state=42)
    model.fit(train[feature_cols], train["target_budget_risk"])
    probabilities = model.predict_proba(test[feature_cols])[:, 1]
    threshold = _best_threshold(test["target_budget_risk"], probabilities)
    joblib.dump(model, models_dir / "budget_risk_v2.pkl")
    joblib.dump(feature_cols, models_dir / "budget_risk_features_v2.pkl")
    return _classification_metrics(test["target_budget_risk"], probabilities, threshold)


def train_anomaly_detector(features_dir: Path, models_dir: Path) -> Dict[str, float]:
    frame, feature_cols = _load_features(features_dir, "daily_anomaly_features")
    cutoff = frame["date"].quantile(0.72)
    train = frame[frame["date"] <= cutoff]
    test = frame[frame["date"] > cutoff]
    model = RandomForestClassifier(n_estimators=120, max_depth=10, min_samples_leaf=30, class_weight="balanced", random_state=42, n_jobs=1)
    model.fit(train[feature_cols], train["target_is_anomaly"])
    probabilities = model.predict_proba(test[feature_cols])[:, 1]
    threshold = _best_threshold(test["target_is_anomaly"], probabilities, min_precision=0.35)
    joblib.dump(model, models_dir / "anomaly_detector_v2.pkl")
    joblib.dump(feature_cols, models_dir / "anomaly_features_v2.pkl")
    return _classification_metrics(test["target_is_anomaly"], probabilities, threshold)


def train_spending_profiles(input_dir: Path, models_dir: Path) -> Dict[str, object]:
    expenses = pd.read_csv(input_dir / "expenses.csv", keep_default_na=False)
    expenses["date"] = pd.to_datetime(expenses["date"])
    expenses["amount_npr"] = expenses["amount_npr"].astype(float)
    users = pd.read_csv(input_dir / "users.csv", keep_default_na=False)
    user_features = expenses.groupby("user_id").agg(
        total_spend_npr=("amount_npr", "sum"),
        avg_transaction_npr=("amount_npr", "mean"),
        std_transaction_npr=("amount_npr", "std"),
        active_days=("date", "nunique"),
        transaction_count=("expense_id", "count"),
        shared_ratio=("is_shared", "mean"),
        essential_ratio=("is_essential", "mean"),
        cash_ratio=("payment_method", lambda values: values.eq("cash").mean()),
    ).reset_index()
    category = expenses.pivot_table(index="user_id", columns="category", values="amount_npr", aggfunc="sum", fill_value=0)
    category = category.div(category.sum(axis=1), axis=0).fillna(0)
    category.columns = [f"cat_pct_{column}" for column in category.columns]
    user_features = user_features.merge(category, on="user_id", how="left").merge(
        users[["user_id", "monthly_income_npr", "family_dependency_count", "saving_rate"]], on="user_id", how="left"
    )
    user_features["avg_daily_spend_npr"] = user_features["total_spend_npr"] / user_features["active_days"].clip(lower=1)
    user_features["spend_income_ratio"] = user_features["avg_daily_spend_npr"] * 30 / user_features["monthly_income_npr"].replace(0, np.nan)
    user_features = user_features.fillna(0)
    feature_cols = [column for column in user_features.columns if column != "user_id" and pd.api.types.is_numeric_dtype(user_features[column])]
    scaler = StandardScaler()
    scaled = scaler.fit_transform(user_features[feature_cols])
    kmeans = KMeans(n_clusters=7, random_state=42, n_init=10)
    user_features["spending_cluster"] = kmeans.fit_predict(scaled)
    user_features[["user_id", "spending_cluster"]].to_csv(models_dir / "user_spending_profiles_v2.csv", index=False)
    joblib.dump(kmeans, models_dir / "spending_profile_kmeans_v2.pkl")
    joblib.dump(scaler, models_dir / "spending_profile_scaler_v2.pkl")
    joblib.dump(feature_cols, models_dir / "spending_profile_features_v2.pkl")
    return {"clusters": 7, "users": int(len(user_features))}


def train_shared_settlement(features_dir: Path, models_dir: Path) -> Dict[str, float]:
    frame, feature_cols = _load_features(features_dir, "shared_features")
    if frame.empty or frame["target_late_settlement"].nunique() < 2:
        return {"skipped": True}
    frame["date"] = pd.to_datetime(frame["date"])
    cutoff = frame["date"].quantile(0.72)
    train = frame[frame["date"] <= cutoff]
    test = frame[frame["date"] > cutoff]
    model = HistGradientBoostingClassifier(max_iter=220, learning_rate=0.045, max_leaf_nodes=31, l2_regularization=0.05, random_state=42)
    model.fit(train[feature_cols], train["target_late_settlement"])
    probabilities = model.predict_proba(test[feature_cols])[:, 1]
    threshold = _best_threshold(test["target_late_settlement"], probabilities)
    joblib.dump(model, models_dir / "shared_settlement_risk_v2.pkl")
    joblib.dump(feature_cols, models_dir / "shared_settlement_features_v2.pkl")
    return _classification_metrics(test["target_late_settlement"], probabilities, threshold)


def main() -> None:
    parser = argparse.ArgumentParser(description="Train Nepal finance V2 assistant models")
    parser.add_argument("--input-dir", type=str, default="output_v2")
    parser.add_argument("--features-dir", type=str, default="features_v2_nepal")
    parser.add_argument("--models-dir", type=str, default="models_v2_nepal")
    args = parser.parse_args()

    input_dir = Path(args.input_dir)
    features_dir = Path(args.features_dir)
    models_dir = Path(args.models_dir)
    models_dir.mkdir(parents=True, exist_ok=True)

    monthly_metrics = train_monthly_forecast(features_dir, models_dir)
    budget_metrics = train_budget_risk(features_dir, models_dir)
    anomaly_metrics = train_anomaly_detector(features_dir, models_dir)
    profile_metrics = train_spending_profiles(input_dir, models_dir)
    shared_metrics = train_shared_settlement(features_dir, models_dir)

    thresholds = {
        "budget_risk": budget_metrics.get("threshold", 0.5),
        "anomaly_detection": anomaly_metrics.get("threshold", 0.5),
        "shared_settlement": shared_metrics.get("threshold", 0.5),
    }
    with open(models_dir / "classification_thresholds_v2.json", "w", encoding="utf-8") as file:
        json.dump(thresholds, file, indent=2)

    summary = {
        "monthly_forecast": monthly_metrics,
        "budget_risk": budget_metrics,
        "anomaly_detection": anomaly_metrics,
        "spending_profiles": profile_metrics,
        "shared_settlement": shared_metrics,
        "classification_thresholds": thresholds,
        "notes": [
            "V2 trains on NPR-normalized amounts while preserving original currency fields.",
            "Features use prior-period rolling values where prediction needs future safety.",
            "The assistant response should avoid storing raw names, email, phone, or notes.",
        ],
    }
    with open(models_dir / "training_summary_v2_nepal.json", "w", encoding="utf-8") as file:
        json.dump(summary, file, indent=2)
    print("Nepal finance V2 models trained")
    print(json.dumps(summary, indent=2))


if __name__ == "__main__":
    main()
