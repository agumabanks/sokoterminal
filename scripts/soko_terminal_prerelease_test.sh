#!/usr/bin/env bash
set -u -o pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
APP_DIR="$ROOT_DIR"
ARTIFACT_DIR="${ARTIFACT_DIR:-/tmp/soko_terminal_prerelease}"
mkdir -p "$ARTIFACT_DIR"

API_BASE="${API_BASE:-$(grep -E '^API_BASE_URL=' "$APP_DIR/assets/config/.env" 2>/dev/null | head -n 1 | cut -d= -f2-)}"
API_BASE="${API_BASE%/}"

DEMO_PHONE_RAW="${DEMO_PHONE_RAW:-256773533428}"
DEMO_PHONE_INTL="${DEMO_PHONE_INTL:-+256773533428}"
DEMO_PHONE_LOCAL="${DEMO_PHONE_LOCAL:-0773533428}"
DEMO_PASSWORD="${DEMO_PASSWORD:-654321}"
DEMO_PIN="${DEMO_PIN:-654321}"

APP_PACKAGE="${APP_PACKAGE:-com.soko24.soko_seller_terminal}"
APP_MAIN_ACTIVITY="${APP_MAIN_ACTIVITY:-.MainActivity}"
APK_PATH="${APK_PATH:-$APP_DIR/build/app/outputs/flutter-apk/app-debug.apk}"

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
BOLD='\033[1m'
RESET='\033[0m'

PASS_COUNT=0
FAIL_COUNT=0
WARN_COUNT=0
declare -a FAILED_TESTS=()

log() { echo -e "${CYAN}[•]${RESET} $*"; }
ok() { echo -e "${GREEN}[✓]${RESET} $*"; PASS_COUNT=$((PASS_COUNT + 1)); }
warn() { echo -e "${YELLOW}[!]${RESET} $*"; WARN_COUNT=$((WARN_COUNT + 1)); }
fail() { echo -e "${RED}[✗]${RESET} $*"; FAIL_COUNT=$((FAIL_COUNT + 1)); FAILED_TESTS+=("$*"); }
section() {
  echo
  echo -e "${BOLD}${CYAN}══════════════════════════════════════${RESET}"
  echo -e "${BOLD}  $*${RESET}"
  echo -e "${BOLD}${CYAN}══════════════════════════════════════${RESET}"
}

require_tool() {
  if command -v "$1" >/dev/null 2>&1; then
    ok "Tool available: $1"
  else
    fail "Required tool not found: $1"
  fi
}

run_cmd() {
  local logfile="$1"
  shift
  (
    set +e
    "$@" >"$logfile" 2>&1
    echo $? >"${logfile}.exit"
  )
  cat "$logfile"
  return "$(cat "${logfile}.exit")"
}

api_post() {
  local endpoint="$1"
  local body="$2"
  curl -sS -o "$ARTIFACT_DIR/api_response.json" -w "%{http_code}" \
    -X POST "${API_BASE}${endpoint}" \
    -H "Accept: application/json" \
    -H "Content-Type: application/json" \
    -d "$body"
}

api_get() {
  local endpoint="$1"
  local token="$2"
  curl -sS -o "$ARTIFACT_DIR/api_response.json" -w "%{http_code}" \
    -X GET "${API_BASE}${endpoint}" \
    -H "Accept: application/json" \
    -H "Authorization: Bearer ${token}"
}

extract_bounds() {
  local xml_file="$1"
  local pattern="$2"
  python3 - "$xml_file" "$pattern" <<'PY'
import re
import sys

xml = open(sys.argv[1], 'r', encoding='utf-8').read()
pattern = sys.argv[2]
match = re.search(pattern + r'.*?bounds="\[(\d+),(\d+)\]\[(\d+),(\d+)\]"', xml)
if not match:
    sys.exit(1)
x1, y1, x2, y2 = map(int, match.groups())
print((x1 + x2) // 2, (y1 + y2) // 2)
PY
}

adb_tap_pattern() {
  local xml_file="$1"
  local pattern="$2"
  local coords
  if coords="$(extract_bounds "$xml_file" "$pattern" 2>/dev/null)"; then
    adb -s "$DEVICE_ID" shell input tap ${coords}
    return 0
  fi
  return 1
}

dump_ui() {
  local target="$1"
  rm -f "$target"
  adb -s "$DEVICE_ID" shell uiautomator dump /sdcard/uidump.xml >/dev/null 2>&1 || return 1
  adb -s "$DEVICE_ID" pull /sdcard/uidump.xml "$target" >/dev/null 2>&1 || return 1
  [[ -s "$target" ]]
}

wait_for_ui() {
  local target="$1"
  local pattern="$2"
  local attempts="${3:-5}"
  local sleep_seconds="${4:-2}"
  local current=1

  while [[ "$current" -le "$attempts" ]]; do
    if dump_ui "$target" && rg -q "$pattern" "$target"; then
      return 0
    fi
    sleep "$sleep_seconds"
    current=$((current + 1))
  done

  return 1
}

section "1. Preflight"
require_tool flutter
require_tool adb
require_tool curl
require_tool jq
require_tool python3

if [[ ! -d "$APP_DIR" ]]; then
  fail "Flutter project not found at $APP_DIR"
  echo "Blocking suite: missing app directory"
  exit 1
else
  ok "Flutter project found at $APP_DIR"
fi

DEVICE_COUNT="$(adb devices | awk '/device$/{count++} END{print count+0}')"
if [[ "$DEVICE_COUNT" -lt 1 ]]; then
  fail "No Android device connected via ADB"
  echo "Blocking suite: no device connected"
  exit 1
fi
DEVICE_ID="$(adb devices | awk '/device$/{print $1; exit}')"
ok "Android device connected: $DEVICE_ID"

if [[ -n "$API_BASE" ]]; then
  HTTP="$(curl -s -o /dev/null -w "%{http_code}" "$API_BASE" || true)"
  if [[ "$HTTP" =~ ^[23] ]]; then
    ok "API reachable: $API_BASE (HTTP $HTTP)"
  else
    warn "API returned HTTP $HTTP at $API_BASE"
  fi
else
  fail "API_BASE_URL not configured"
fi

section "2. Static analysis"
cd "$APP_DIR" || exit 1

if run_cmd "$ARTIFACT_DIR/flutter_analyze.log" flutter analyze; then
  ok "flutter analyze is clean"
else
  fail "flutter analyze failed"
fi

redirect_block="$(awk '
  /redirect: \(context, state\) \{/ {capture=1}
  capture {print}
  /routes: \[/ && capture {exit}
' lib/src/app.dart)"
if echo "$redirect_block" | rg -q 'ref\.watch'; then
  fail "ref.watch still appears inside GoRouter redirect callback"
else
  ok "GoRouter redirect callback no longer uses ref.watch"
fi

if rg -q 'final persistedToken = await _persistAccessToken\(token\);' lib/src/features/auth/auth_controller.dart &&
   rg -q 'await _storage.writeAccessToken\(normalized\);' lib/src/features/auth/auth_controller.dart &&
   rg -q 'final persisted = await _storage.readAccessToken\(\);' lib/src/features/auth/auth_controller.dart; then
  ok "SecureStorage write-read verification exists before authenticated state"
else
  fail "SecureStorage write-read verification missing in auth_controller.dart"
fi

section "3. Unit tests"
if run_cmd "$ARTIFACT_DIR/flutter_test.log" flutter test; then
  ok "Full Flutter test suite passed"
else
  fail "Full Flutter test suite failed"
fi

if run_cmd \
  "$ARTIFACT_DIR/flutter_targeted_test.log" \
  flutter test test/prerelease_auth_regression_test.dart; then
  ok "Targeted auth regression test passed"
else
  fail "Targeted auth regression test failed"
fi

section "4. Backend API"
RAW_CHECK_HTTP="$(api_post '/v2/seller/pos/auth/check' "{\"phone\":\"${DEMO_PHONE_RAW}\"}")"
RAW_CHECK_BODY="$(cat "$ARTIFACT_DIR/api_response.json")"
if [[ "$RAW_CHECK_HTTP" == "200" ]]; then
  ok "POST /v2/seller/pos/auth/check with raw 256 phone succeeds"
else
  fail "POST /v2/seller/pos/auth/check failed (HTTP $RAW_CHECK_HTTP)"
fi

RAW_LOGIN_HTTP="$(api_post '/v2/auth/login' "{\"login_by\":\"phone\",\"email\":\"${DEMO_PHONE_RAW}\",\"password\":\"${DEMO_PASSWORD}\",\"user_type\":\"seller\"}")"
RAW_LOGIN_BODY="$(cat "$ARTIFACT_DIR/api_response.json")"
if echo "$RAW_LOGIN_BODY" | jq -r '.message // empty' | grep -q 'User not found'; then
  fail "POST /v2/auth/login with raw 256 phone still returns 'User not found'"
elif [[ "$RAW_LOGIN_HTTP" == "200" ]]; then
  ok "POST /v2/auth/login with raw 256 phone succeeds"
else
  fail "POST /v2/auth/login with raw 256 phone failed (HTTP $RAW_LOGIN_HTTP)"
fi

INTL_LOGIN_HTTP="$(api_post '/v2/auth/login' "{\"login_by\":\"phone\",\"email\":\"${DEMO_PHONE_INTL}\",\"password\":\"${DEMO_PASSWORD}\",\"user_type\":\"seller\"}")"
INTL_LOGIN_BODY="$(cat "$ARTIFACT_DIR/api_response.json")"
INTL_TOKEN="$(echo "$INTL_LOGIN_BODY" | jq -r '.access_token // .token // empty')"
if [[ "$INTL_LOGIN_HTTP" == "200" && -n "$INTL_TOKEN" ]]; then
  ok "POST /v2/auth/login with +256 phone returns a token"
else
  fail "POST /v2/auth/login with +256 phone failed to return a token"
fi

if [[ -n "$INTL_TOKEN" ]]; then
  PROFILE_HTTP="$(api_get '/v2/seller/profile' "$INTL_TOKEN")"
  if [[ "$PROFILE_HTTP" == "200" ]]; then
    ok "Auth token works on /v2/seller/profile without 401"
  else
    fail "Auth token failed on /v2/seller/profile (HTTP $PROFILE_HTTP)"
  fi
else
  fail "Authenticated route check skipped because login token was missing"
fi

section "5. On-device login loop regression"
if run_cmd "$ARTIFACT_DIR/flutter_build_debug.log" flutter build apk --debug; then
  ok "Debug APK built"
else
  fail "flutter build apk --debug failed"
fi

if [[ -f "$APK_PATH" ]]; then
  ok "Debug APK present at $APK_PATH"
else
  fail "Debug APK missing at $APK_PATH"
fi

if adb -s "$DEVICE_ID" install -r "$APK_PATH" >"$ARTIFACT_DIR/adb_install.log" 2>&1; then
  ok "Debug APK installed on device"
else
  cat "$ARTIFACT_DIR/adb_install.log"
  fail "APK install failed"
fi

if adb -s "$DEVICE_ID" shell pm clear "$APP_PACKAGE" >"$ARTIFACT_DIR/adb_pm_clear.log" 2>&1; then
  ok "App data cleared"
else
  cat "$ARTIFACT_DIR/adb_pm_clear.log"
  fail "Failed to clear app data"
fi

if adb -s "$DEVICE_ID" shell am start -n "${APP_PACKAGE}/${APP_MAIN_ACTIVITY}" >"$ARTIFACT_DIR/adb_launch.log" 2>&1; then
  ok "App launched"
else
  cat "$ARTIFACT_DIR/adb_launch.log"
  fail "Failed to launch app"
fi

sleep 5
if dump_ui "$ARTIFACT_DIR/ui_before_login.xml"; then
  ok "Captured pre-login UI dump"
else
  fail "Could not capture pre-login UI dump"
fi
adb -s "$DEVICE_ID" exec-out screencap -p >"$ARTIFACT_DIR/screen_before_login.png"
ok "Captured pre-login screenshot"

if ! adb_tap_pattern "$ARTIFACT_DIR/ui_before_login.xml" 'class="android.widget.EditText"'; then
  adb -s "$DEVICE_ID" shell input tap 450 680
fi
sleep 1
adb -s "$DEVICE_ID" shell input text "$DEMO_PHONE_LOCAL"
sleep 1
if ! adb_tap_pattern "$ARTIFACT_DIR/ui_before_login.xml" 'content-desc="Continue"'; then
  adb -s "$DEVICE_ID" shell input tap 400 790
fi
sleep 3

if ! wait_for_ui \
  "$ARTIFACT_DIR/ui_after_phone.xml" \
  'Enter your 6-digit access PIN|Use password instead|Enter your password to login|Hello,' \
  4 \
  2; then
  if dump_ui "$ARTIFACT_DIR/ui_after_phone.xml" &&
     rg -q 'Enter your phone number to continue' "$ARTIFACT_DIR/ui_after_phone.xml"; then
    if ! adb_tap_pattern "$ARTIFACT_DIR/ui_after_phone.xml" 'content-desc="Continue"'; then
      adb -s "$DEVICE_ID" shell input tap 400 790
    fi
    sleep 3
    wait_for_ui \
      "$ARTIFACT_DIR/ui_after_phone.xml" \
      'Enter your 6-digit access PIN|Use password instead|Enter your password to login|Hello,' \
      4 \
      2 || true
  fi
fi

if grep -q 'Enter your 6-digit access PIN' "$ARTIFACT_DIR/ui_after_phone.xml"; then
  if ! adb_tap_pattern "$ARTIFACT_DIR/ui_after_phone.xml" 'class="android.widget.EditText"'; then
    adb -s "$DEVICE_ID" shell input tap 400 700
  fi
  sleep 1
  adb -s "$DEVICE_ID" shell input text "$DEMO_PIN"
  sleep 1
  if ! adb_tap_pattern "$ARTIFACT_DIR/ui_after_phone.xml" 'content-desc="Unlock"'; then
    adb -s "$DEVICE_ID" shell input tap 400 815
  fi
  ok "Submitted seller PIN"
elif grep -q 'Use password instead' "$ARTIFACT_DIR/ui_after_phone.xml"; then
  if ! adb_tap_pattern "$ARTIFACT_DIR/ui_after_phone.xml" 'Use password instead'; then
    adb -s "$DEVICE_ID" shell input tap 200 695
  fi
  sleep 2
  dump_ui "$ARTIFACT_DIR/ui_password_step.xml" || true
  if ! adb_tap_pattern "${ARTIFACT_DIR}/ui_password_step.xml" 'class="android.widget.EditText"'; then
    adb -s "$DEVICE_ID" shell input tap 400 700
  fi
  adb -s "$DEVICE_ID" shell input text "$DEMO_PASSWORD"
  sleep 1
  if ! adb_tap_pattern "${ARTIFACT_DIR}/ui_password_step.xml" 'content-desc="Login"'; then
    adb -s "$DEVICE_ID" shell input tap 400 815
  fi
  ok "Submitted seller password"
else
  fail "Could not reach seller PIN/password step after phone submission"
fi

sleep 8
dump_ui "$ARTIFACT_DIR/ui_post_login_raw.xml" || true

if grep -q 'com.android.permissioncontroller' "$ARTIFACT_DIR/ui_post_login_raw.xml"; then
  if adb_tap_pattern "$ARTIFACT_DIR/ui_post_login_raw.xml" 'permission_allow_foreground_only_button'; then
    ok "Accepted location permission prompt"
  else
    adb -s "$DEVICE_ID" shell input tap 400 635
    ok "Accepted location permission prompt via fallback tap"
  fi
  sleep 4
fi

dump_ui "$ARTIFACT_DIR/ui_after_login.xml" || true
adb -s "$DEVICE_ID" exec-out screencap -p >"$ARTIFACT_DIR/screen_after_login.png"

if grep -q 'Welcome&#10;Enter your phone number to continue' "$ARTIFACT_DIR/ui_after_login.xml" ||
   grep -q 'Enter your 6-digit access PIN' "$ARTIFACT_DIR/ui_after_login.xml"; then
  fail "App is still showing a login screen after credentials were submitted"
else
  ok "App navigated away from the login screen after credential submission"
fi

if adb -s "$DEVICE_ID" shell run-as "$APP_PACKAGE" sh -c \
  "grep -R 'access_token' /data/user/0/${APP_PACKAGE}/shared_prefs 2>/dev/null || true" \
  >"$ARTIFACT_DIR/device_flutter_secure_storage.xml" 2>"$ARTIFACT_DIR/device_flutter_secure_storage.err"; then
  if [[ -s "$ARTIFACT_DIR/device_flutter_secure_storage.xml" ]]; then
    ok "Device secure storage contains a persisted access token after login"
  else
    fail "Device secure storage does not contain access_token after login"
  fi
else
  warn "Could not inspect FlutterSecureStorage.xml via run-as"
fi

section "6. Play Store readiness"
if [[ -f "$APP_DIR/PLAY_REVIEWER_ACCESS.md" ]]; then
  if rg -q '\+256[0-9]{9}' "$APP_DIR/PLAY_REVIEWER_ACCESS.md" &&
     ! rg -q '\+256X+|YYYY-MM-DD|[*]{6,}|x\.y\.z\+N|https://\.\.\./api/' "$APP_DIR/PLAY_REVIEWER_ACCESS.md" &&
     rg -q 'Password:' "$APP_DIR/PLAY_REVIEWER_ACCESS.md"; then
    ok "Reviewer credentials file exists with concrete +256 phone and password"
  else
    fail "PLAY_REVIEWER_ACCESS.md still has placeholders or missing concrete demo credentials"
  fi
else
  fail "PLAY_REVIEWER_ACCESS.md is missing"
fi

CURRENT_VERSION="$(grep '^version:' pubspec.yaml | awk '{print $2}')"
BUILD_CODE="${CURRENT_VERSION##*+}"
if [[ "$BUILD_CODE" =~ ^[0-9]+$ && "$BUILD_CODE" -ge 5 ]]; then
  ok "pubspec.yaml build number looks bumped for release ($CURRENT_VERSION)"
else
  fail "pubspec.yaml build number does not look release-ready ($CURRENT_VERSION)"
fi

if run_cmd "$ARTIFACT_DIR/flutter_analyze_release.log" flutter analyze; then
  ok "Final flutter analyze is clean"
else
  fail "Final flutter analyze failed"
fi

section "Final report"
TOTAL_COUNT=$((PASS_COUNT + FAIL_COUNT))
echo "Passed:   $PASS_COUNT / $TOTAL_COUNT"
echo "Failed:   $FAIL_COUNT / $TOTAL_COUNT"
echo "Warnings: $WARN_COUNT"

if [[ ${#FAILED_TESTS[@]} -gt 0 ]]; then
  echo
  echo "Failed checks:"
  for failed in "${FAILED_TESTS[@]}"; do
    echo " - $failed"
  done
fi

if [[ "$FAIL_COUNT" -eq 0 ]]; then
  echo
  echo "PASS — Safe to submit."
  exit 0
fi

echo
echo "FAIL — Block submission until the failed checks above are resolved."
exit 1
