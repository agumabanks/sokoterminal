#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
LOG_DIR="${LOG_DIR:-$ROOT_DIR/logs}"
ADB_SOCKET="${ADB_SERVER_SOCKET:-tcp:127.0.0.1:15037}"
DEVICE_ID="${1:-${DEVICE_ID:-}}"
TIMESTAMP="$(date +%Y%m%d_%H%M%S)"
LOG_FILE="$LOG_DIR/flutter_run_$TIMESTAMP.log"
LOGCAT_FILE="$LOG_DIR/adb_logcat_$TIMESTAMP.log"
INFO_FILE="$LOG_DIR/device_info_$TIMESTAMP.txt"

adb_cmd() {
  ADB_SERVER_SOCKET="$ADB_SOCKET" adb "$@"
}

detect_device() {
  local devices=()
  mapfile -t devices < <(adb_cmd devices | awk 'NR>1 && $2=="device" {print $1}')
  if [[ ${#devices[@]} -eq 0 ]]; then
    echo "No online devices found. Run 'adb devices' to check connectivity." >&2
    exit 1
  fi
  if [[ ${#devices[@]} -gt 1 ]]; then
    echo "Multiple devices found; using ${devices[0]}."
    echo "Set DEVICE_ID or pass an argument to select another one."
  fi
  DEVICE_ID="${devices[0]}"
}

mkdir -p "$LOG_DIR"

if [[ -z "$DEVICE_ID" ]]; then
  detect_device
fi

echo "Using device: $DEVICE_ID"
echo "Logging flutter run to: $LOG_FILE"
echo "Logging adb logcat to: $LOGCAT_FILE"
echo "Saving device info to: $INFO_FILE"

{
  echo "timestamp: $(date -Is)"
  echo "device: $DEVICE_ID"
  adb_cmd -s "$DEVICE_ID" shell getprop ro.product.model 2>/dev/null | sed 's/^/model: /'
  adb_cmd -s "$DEVICE_ID" shell getprop ro.build.version.release 2>/dev/null | sed 's/^/android: /'
  adb_cmd -s "$DEVICE_ID" shell getprop ro.build.display.id 2>/dev/null | sed 's/^/build: /'
} > "$INFO_FILE" || true

adb_cmd -s "$DEVICE_ID" logcat -c || true
adb_cmd -s "$DEVICE_ID" logcat -v time > "$LOGCAT_FILE" &
LOGCAT_PID=$!
trap 'kill "$LOGCAT_PID" >/dev/null 2>&1 || true' EXIT INT TERM

ADB_SERVER_SOCKET="$ADB_SOCKET" flutter run -d "$DEVICE_ID" ${FLUTTER_ARGS:-} 2>&1 | tee "$LOG_FILE"
