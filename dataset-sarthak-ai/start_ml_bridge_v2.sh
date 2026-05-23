#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

export ML_API_HOST="${ML_API_HOST:-0.0.0.0}"
export ML_API_PORT="${ML_API_PORT:-5001}"
export V2_MODELS_DIR="${V2_MODELS_DIR:-models_v2_nepal}"

python3 ml_bridge_v2_server.py
