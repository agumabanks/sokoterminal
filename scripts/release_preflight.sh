#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

cd "$ROOT_DIR"

read_kv() {
  local file="$1"
  local key="$2"
  if [[ ! -f "$file" ]]; then
    return 0
  fi
  grep -E "^${key}=" "$file" | head -n 1 | cut -d= -f2- | tr -d '\r' || true
}

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

echo "[preflight] checking for hardcoded non-Firebase Google API keys in Dart sources"
if rg -n 'AIza[0-9A-Za-z_-]{20,}' lib --glob '!firebase_options.dart'; then
  echo "[preflight] ERROR: hardcoded Google API key detected in Dart source. Use dart-define or runtime config instead." >&2
  exit 1
fi

echo "[preflight] checking release secrets"
KEY_PROPS="android/key.properties"
storeFile="$(read_kv "$KEY_PROPS" "storeFile")"
storePassword="$(read_kv "$KEY_PROPS" "storePassword")"
keyAlias="$(read_kv "$KEY_PROPS" "keyAlias")"
keyPassword="$(read_kv "$KEY_PROPS" "keyPassword")"
googleMapsApiKey="$(read_kv "$KEY_PROPS" "googleMapsApiKey")"

storeFile="${storeFile:-${STORE_FILE:-}}"
storePassword="${storePassword:-${STORE_PASSWORD:-}}"
keyAlias="${keyAlias:-${KEY_ALIAS:-}}"
keyPassword="${keyPassword:-${KEY_PASSWORD:-}}"
googleMapsApiKey="${googleMapsApiKey:-${GOOGLE_MAPS_API_KEY:-}}"

missing_release_secret=false
for required in "$storeFile" "$storePassword" "$keyAlias" "$keyPassword" "$googleMapsApiKey"; do
  if [[ -z "$required" ]]; then
    missing_release_secret=true
    break
  fi
done

if [[ "$missing_release_secret" == true ]]; then
  echo "[preflight] ERROR: release signing and Google Maps secrets are required." >&2
  echo "[preflight] Provide android/key.properties (see android/key.properties.example) or env vars:" >&2
  echo "[preflight]   STORE_FILE / STORE_PASSWORD / KEY_ALIAS / KEY_PASSWORD / GOOGLE_MAPS_API_KEY" >&2
  exit 1
fi

if [[ "$storePassword" == "CHANGE_ME" || "$keyPassword" == "CHANGE_ME" || "$googleMapsApiKey" == "CHANGE_ME" ]]; then
  echo "[preflight] ERROR: release secrets still contain CHANGE_ME placeholders." >&2
  exit 1
fi

if [[ ! -f "android/$storeFile" && ! -f "$storeFile" ]]; then
  echo "[preflight] ERROR: keystore file not found: $storeFile" >&2
  exit 1
fi

echo "[preflight] flutter pub get"
flutter pub get

echo "[preflight] codegen (drift/build_runner)"
flutter pub run build_runner build --delete-conflicting-outputs

echo "[preflight] flutter analyze"
flutter analyze --no-fatal-infos

echo "[preflight] flutter test"
flutter test

echo "[preflight] OK"
