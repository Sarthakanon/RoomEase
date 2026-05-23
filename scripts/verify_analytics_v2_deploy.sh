#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

echo "[1/5] Checking Python bridge file syntax..."
python3 -m py_compile dataset-sarthak-ai/ml_bridge_v2_server.py

echo "[2/5] Checking backend production build..."
cd backend
go build -o /tmp/roomease-backend-check main.go
cd "$ROOT_DIR"

echo "[3/5] Checking bridge model artifacts..."
test -f dataset-sarthak-ai/models_v2_nepal/monthly_forecast_v2.pkl
test -f dataset-sarthak-ai/models_v2_nepal/budget_risk_v2.pkl
test -f dataset-sarthak-ai/models_v2_nepal/anomaly_detector_v2.pkl
test -f dataset-sarthak-ai/models_v2_nepal/shared_settlement_risk_v2.pkl

echo "[4/5] Checking env compatibility..."
grep -q "ML_API_URL" backend/.env.example

echo "[5/5] Static verification complete."
echo "PASS: code/build/artifact checks are ready for deploy."
