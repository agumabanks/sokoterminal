#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

if ! command -v curl >/dev/null 2>&1; then
  echo "[reviewer-check] ERROR: curl is required" >&2
  exit 1
fi
if ! command -v jq >/dev/null 2>&1; then
  echo "[reviewer-check] ERROR: jq is required" >&2
  exit 1
fi

read_kv() {
  local file="$1"
  local key="$2"
  if [[ -f "$file" ]]; then
    grep -E "^${key}=" "$file" | head -n 1 | cut -d= -f2- | tr -d '\r' || true
  fi
}

normalize_ug_phone() {
  local raw="$1"
  raw="${raw#\"}"
  raw="${raw%\"}"
  raw="${raw#+}"
  local digits
  digits="$(echo "$raw" | tr -cd '0-9')"
  if [[ -z "$digits" ]]; then
    echo ""
    return
  fi
  if [[ "$digits" =~ ^256[0-9]{9}$ ]]; then
    echo "$digits"
    return
  fi
  if [[ "$digits" =~ ^0[0-9]{9}$ ]]; then
    echo "256${digits:1}"
    return
  fi
  if [[ "$digits" =~ ^[0-9]{9}$ ]]; then
    echo "256$digits"
    return
  fi
  echo "$digits"
}

extract_backticked_value() {
  local file="$1"
  local prefix="$2"
  awk -v p="$prefix" '
    index($0, p) == 1 {
      line=$0
      sub(/^[^`]*`/, "", line)
      sub(/`.*/, "", line)
      print line
      exit
    }
  ' "$file"
}

API_BASE_URL="${API_BASE_URL:-}"
if [[ -z "$API_BASE_URL" ]]; then
  API_BASE_URL="$(read_kv "assets/config/.env" "API_BASE_URL")"
fi
API_BASE_URL="${API_BASE_URL%/}"
if [[ -z "$API_BASE_URL" ]]; then
  echo "[reviewer-check] ERROR: API_BASE_URL is missing (env or assets/config/.env)" >&2
  exit 1
fi

phone_raw="${REVIEWER_PHONE:-}"
password_raw="${REVIEWER_PASSWORD:-}"

if [[ -z "$phone_raw" || -z "$password_raw" ]]; then
  if [[ ! -f "PLAY_REVIEWER_ACCESS.md" ]]; then
    echo "[reviewer-check] ERROR: PLAY_REVIEWER_ACCESS.md not found" >&2
    exit 1
  fi
  [[ -z "$phone_raw" ]] && phone_raw="$(extract_backticked_value "PLAY_REVIEWER_ACCESS.md" "- Login phone")"
  [[ -z "$password_raw" ]] && password_raw="$(extract_backticked_value "PLAY_REVIEWER_ACCESS.md" "- Password")"
fi

if [[ -z "$phone_raw" || -z "$password_raw" ]]; then
  echo "[reviewer-check] ERROR: reviewer credentials are missing" >&2
  exit 1
fi

if [[ "$phone_raw" =~ X|\* ]]; then
  echo "[reviewer-check] ERROR: reviewer phone still looks like a placeholder" >&2
  exit 1
fi
if [[ "$password_raw" =~ CHANGE_ME|\*\*\*\*\*\* ]]; then
  echo "[reviewer-check] ERROR: reviewer password still looks like a placeholder" >&2
  exit 1
fi

phone="$(normalize_ug_phone "$phone_raw")"
if [[ ! "$phone" =~ ^256[0-9]{9}$ ]]; then
  echo "[reviewer-check] ERROR: normalized reviewer phone is invalid: $phone" >&2
  exit 1
fi

post_json() {
  local url="$1"
  local body="$2"
  local auth_token="${3:-}"
  if [[ -n "$auth_token" ]]; then
    curl -sS --max-time 30 -w "\n%{http_code}" \
      -H 'Accept: application/json' \
      -H 'Content-Type: application/json' \
      -H "Authorization: Bearer $auth_token" \
      -X POST "$url" \
      -d "$body"
  else
    curl -sS --max-time 30 -w "\n%{http_code}" \
      -H 'Accept: application/json' \
      -H 'Content-Type: application/json' \
      -X POST "$url" \
      -d "$body"
  fi
}

get_json() {
  local url="$1"
  local auth_token="$2"
  curl -sS --max-time 30 -w "\n%{http_code}" \
    -H 'Accept: application/json' \
    -H "Authorization: Bearer $auth_token" \
    "$url"
}

split_http() {
  local response="$1"
  local __body_var="$2"
  local __code_var="$3"
  local code
  code="$(echo "$response" | tail -n 1 | tr -d '\r')"
  local body
  body="$(echo "$response" | sed '$d')"
  printf -v "$__body_var" '%s' "$body"
  printf -v "$__code_var" '%s' "$code"
}

echo "[reviewer-check] Checking account existence for reviewer phone"
check_payload="$(jq -cn --arg phone "$phone" '{phone:$phone}')"
check_response="$(post_json "$API_BASE_URL/v2/seller/pos/auth/check" "$check_payload")"
split_http "$check_response" check_body check_code
if [[ "$check_code" -lt 200 || "$check_code" -ge 300 ]]; then
  echo "[reviewer-check] ERROR: auth check failed (HTTP $check_code)" >&2
  echo "$check_body" | jq -r '.message // .error // "unknown error"' >&2 || true
  exit 1
fi

exists="$(echo "$check_body" | jq -r '.exists // false')"
if [[ "$exists" != "true" ]]; then
  echo "[reviewer-check] ERROR: reviewer account does not exist according to /v2/seller/pos/auth/check" >&2
  exit 1
fi

echo "[reviewer-check] Verifying /v2/auth/login with reviewer credentials"
login_payload="$(jq -cn --arg phone "$phone" --arg password "$password_raw" '{login_by:"phone",email:$phone,password:$password,user_type:"seller"}')"
login_response="$(post_json "$API_BASE_URL/v2/auth/login" "$login_payload")"
split_http "$login_response" login_body login_code
if [[ "$login_code" -lt 200 || "$login_code" -ge 300 ]]; then
  echo "[reviewer-check] ERROR: login failed (HTTP $login_code)" >&2
  echo "$login_body" | jq -r '.message // .error // "unknown error"' >&2 || true
  exit 1
fi

token="$(echo "$login_body" | jq -r '.access_token // .token // empty')"
if [[ -z "$token" ]]; then
  echo "[reviewer-check] ERROR: login response missing token" >&2
  exit 1
fi

echo "[reviewer-check] Verifying seller sync pull authorization"
sync_url="$API_BASE_URL/v2/seller/pos/sync/pull?since=1970-01-01T00:00:00Z"
sync_response="$(get_json "$sync_url" "$token")"
split_http "$sync_response" sync_body sync_code
if [[ "$sync_code" -lt 200 || "$sync_code" -ge 300 ]]; then
  echo "[reviewer-check] ERROR: sync pull failed after login (HTTP $sync_code)" >&2
  echo "$sync_body" | jq -r '.message // .error // "unknown error"' >&2 || true
  exit 1
fi

echo "[reviewer-check] OK: reviewer account can authenticate and access seller sync endpoints"
