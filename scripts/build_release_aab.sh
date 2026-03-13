#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

echo "[build] Running preflight checks…"
bash scripts/release_preflight.sh

read_kv() {
  local file="$1"
  local key="$2"
  if [[ ! -f "$file" ]]; then
    return 0
  fi
  grep -E "^${key}=" "$file" | head -n 1 | cut -d= -f2- | tr -d '\r' || true
}

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
appVersion="$(grep -E '^version:' pubspec.yaml | head -n 1 | awk '{print $2}' | tr -d '\r' || true)"

if [[ -z "${storeFile:-}" || -z "${storePassword:-}" || -z "${keyAlias:-}" || -z "${keyPassword:-}" ]]; then
  echo "[build] ERROR: release signing is not configured." >&2
  echo "[build] Create $KEY_PROPS (see android/key.properties.example) or set env vars:" >&2
  echo "[build]   STORE_FILE / STORE_PASSWORD / KEY_ALIAS / KEY_PASSWORD" >&2
  exit 1
fi

if [[ ! -f "android/$storeFile" && ! -f "$storeFile" ]]; then
  echo "[build] ERROR: keystore file not found: $storeFile" >&2
  echo "[build] Tip: paths in key.properties can be relative to android/." >&2
  exit 1
fi

if [[ -z "${googleMapsApiKey:-}" ]]; then
  echo "[build] ERROR: Google Maps key is not configured." >&2
  echo "[build] Add googleMapsApiKey to $KEY_PROPS or set GOOGLE_MAPS_API_KEY." >&2
  exit 1
fi

apiBaseUrl="${API_BASE_URL:-}"
if [[ -z "${apiBaseUrl}" && -f "assets/config/.env" ]]; then
  apiBaseUrl="$(grep -E '^API_BASE_URL=' "assets/config/.env" | head -n 1 | cut -d= -f2- | tr -d '\r' || true)"
fi

buildArgs=()
if [[ -n "${apiBaseUrl}" ]]; then
  echo "[build] Using API_BASE_URL via dart-define: ${apiBaseUrl}"
  buildArgs+=(--dart-define=API_BASE_URL="${apiBaseUrl}")
else
  echo "[build] WARNING: API_BASE_URL not provided; build will use assets/config/.env (or fallback .env.example)" >&2
fi

echo "[build] Using GOOGLE_MAPS_API_KEY via dart-define"
buildArgs+=(--dart-define=GOOGLE_MAPS_API_KEY="${googleMapsApiKey}")

if [[ -n "${appVersion}" ]]; then
  echo "[build] Using APP_VERSION via dart-define: ${appVersion}"
  buildArgs+=(--dart-define=APP_VERSION="${appVersion}")
fi

echo "[build] Building Android App Bundle (AAB)…"
flutter build appbundle --release "${buildArgs[@]}"

echo "[build] Output:"
echo "[build]   build/app/outputs/bundle/release/app-release.aab"
