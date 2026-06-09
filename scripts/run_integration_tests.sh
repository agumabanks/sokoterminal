#!/usr/bin/env bash
# Runs headless integration/smoke tests (no emulator required on Linux CI).
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

echo "[integration] flutter pub get"
flutter pub get

echo "[integration] codegen"
flutter pub run build_runner build --delete-conflicting-outputs

if ! pkg-config --exists gstreamer-1.0 2>/dev/null; then
  echo "[integration] SKIP: libgstreamer1.0-dev not installed (required for Linux integration smoke)"
  echo "[integration] Install: sudo apt-get install -y libgstreamer1.0-dev libgtk-3-dev"
  echo "[integration] Device flows: flutter test integration_test/checkout_flow_test.dart -d <device>"
  exit 0
fi

echo "[integration] running app smoke on Linux desktop target"
# checkout_flow + product_flow require POS hardware — run manually on device.
flutter test integration_test/app_smoke_test.dart -d linux

echo "[integration] OK"