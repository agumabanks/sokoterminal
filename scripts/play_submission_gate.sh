#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

read_kv() {
  local file="$1"
  local key="$2"
  if [[ -f "$file" ]]; then
    grep -E "^${key}=" "$file" | head -n 1 | cut -d= -f2- | tr -d '\r' || true
  fi
}

echo "[play-gate] Running release preflight"
bash scripts/release_preflight.sh

echo "[play-gate] Verifying required submission docs"
required_files=(
  "PLAY_CONSOLE_CHECKLIST.md"
  "PLAY_REVIEWER_ACCESS.md"
  "PLAY_DATA_SAFETY_NOTES.md"
)
for file in "${required_files[@]}"; do
  if [[ ! -f "$file" ]]; then
    echo "[play-gate] ERROR: Missing required file: $file" >&2
    exit 1
  fi
done

echo "[play-gate] Verifying Data Safety notes against AndroidManifest"
if rg -q "android.permission.READ_CONTACTS" android/app/src/main/AndroidManifest.xml; then
  if ! rg -q "READ_CONTACTS" PLAY_DATA_SAFETY_NOTES.md; then
    echo "[play-gate] ERROR: Manifest has READ_CONTACTS but PLAY_DATA_SAFETY_NOTES.md does not mention it" >&2
    exit 1
  fi
fi

echo "[play-gate] Verifying release signing + Maps key config"
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

for required in "$storeFile" "$storePassword" "$keyAlias" "$keyPassword" "$googleMapsApiKey"; do
  if [[ -z "$required" ]]; then
    echo "[play-gate] ERROR: Missing release secret(s). Provide signing + googleMapsApiKey in android/key.properties or env." >&2
    exit 1
  fi
done

if [[ "$storePassword" == "CHANGE_ME" || "$keyPassword" == "CHANGE_ME" || "$googleMapsApiKey" == "CHANGE_ME" ]]; then
  echo "[play-gate] ERROR: key.properties still has CHANGE_ME placeholders" >&2
  exit 1
fi

if [[ ! -f "android/$storeFile" && ! -f "$storeFile" ]]; then
  echo "[play-gate] ERROR: Keystore file not found: $storeFile" >&2
  exit 1
fi

echo "[play-gate] Verifying reviewer credentials are filled"
if rg -n 'YYYY-MM-DD|\+256X+|`[*]{6,}`|x\.y\.z\+N|https://\.\.\./api/' PLAY_REVIEWER_ACCESS.md; then
  echo "[play-gate] ERROR: PLAY_REVIEWER_ACCESS.md still contains placeholders" >&2
  exit 1
fi

echo "[play-gate] Verifying Google Maps API key wiring"
if rg -q 'android:value="AIza' android/app/src/main/AndroidManifest.xml; then
  echo "[play-gate] ERROR: Hardcoded Google Maps key found in AndroidManifest.xml" >&2
  exit 1
fi
if ! rg -q 'android:value="\\$\\{googleMapsApiKey\\}"' android/app/src/main/AndroidManifest.xml; then
  echo "[play-gate] ERROR: AndroidManifest.xml must use \${googleMapsApiKey} placeholder" >&2
  exit 1
fi
if rg -n 'AIza[0-9A-Za-z_-]{20,}' lib --glob '!firebase_options.dart'; then
  echo "[play-gate] ERROR: hardcoded Google API key detected in Dart source" >&2
  exit 1
fi

echo "[play-gate] Verifying reviewer login against live API"
bash scripts/verify_play_reviewer_login.sh

echo "[play-gate] OK"
