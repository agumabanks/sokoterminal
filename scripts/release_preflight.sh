#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

cd "$ROOT_DIR"

echo "[preflight] cwd: $ROOT_DIR"
echo "[preflight] flutter: $(command -v flutter || true)"

if ! command -v flutter >/dev/null 2>&1; then
  echo "[preflight] ERROR: flutter is not installed or not on PATH" >&2
  exit 1
fi

flutter --version | head -n 20

ENV_DIR="assets/config"
ENV_FILE="$ENV_DIR/.env"
ENV_EXAMPLE="$ENV_DIR/.env.example"

if [[ ! -f "$ENV_FILE" ]]; then
  if [[ -f "$ENV_EXAMPLE" ]]; then
    echo "[preflight] Creating $ENV_FILE from $ENV_EXAMPLE"
    cp "$ENV_EXAMPLE" "$ENV_FILE"
  else
    echo "[preflight] WARNING: $ENV_FILE is missing and no $ENV_EXAMPLE found"
  fi
fi

if [[ -f "$ENV_FILE" ]]; then
  echo "[preflight] Using env file: $ENV_FILE"
  apiBaseUrl="$(grep -E '^API_BASE_URL=' "$ENV_FILE" | head -n 1 | cut -d= -f2- | tr -d '\r' || true)"
  echo "[preflight] API_BASE_URL: ${apiBaseUrl}"
  if [[ -n "${apiBaseUrl}" ]]; then
    if [[ "${apiBaseUrl}" != http://* && "${apiBaseUrl}" != https://* ]]; then
      echo "[preflight] WARNING: API_BASE_URL should start with http(s)://" >&2
    fi
    if [[ "${apiBaseUrl}" != */api/* && "${apiBaseUrl}" != */api/ ]]; then
      echo "[preflight] WARNING: API_BASE_URL usually ends with /api/ (example: https://domain.tld/api/)" >&2
    fi
    if [[ "${apiBaseUrl}" != */ ]]; then
      echo "[preflight] WARNING: API_BASE_URL should end with a trailing slash (/)" >&2
    fi
  fi
fi

echo "[preflight] flutter pub get"
flutter pub get

echo "[preflight] codegen (drift/build_runner)"
flutter pub run build_runner build --delete-conflicting-outputs

echo "[preflight] flutter analyze"
flutter analyze

echo "[preflight] flutter test"
flutter test

echo "[preflight] OK"
