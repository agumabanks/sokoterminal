#!/usr/bin/env bash
# Reports open vs done items in FULL_PRODUCTION_PROGRESS_CHECKER.md
# and runs automated code/release gates where possible.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
CHECKER="$ROOT/FULL_PRODUCTION_PROGRESS_CHECKER.md"
cd "$ROOT"

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

pass() { echo -e "${GREEN}✓${NC} $1"; }
fail() { echo -e "${RED}✗${NC} $1"; }
warn() { echo -e "${YELLOW}~${NC} $1"; }

echo "=== Soko Seller Terminal — Production Progress ==="
echo "Checker: $CHECKER"
echo

if [[ ! -f "$CHECKER" ]]; then
  fail "Missing FULL_PRODUCTION_PROGRESS_CHECKER.md"
  exit 1
fi

count_status() {
  local pattern="$1"
  grep -c "$pattern" "$CHECKER" 2>/dev/null || echo 0
}

DONE=$(count_status '\[x\]')
OPEN=$(count_status '\[ \]')
PARTIAL=$(count_status '\[~\]')
DEFERRED=$(count_status '\[—\]')

echo "--- Checklist counts ---"
echo "Done:      $DONE"
echo "Open:      $OPEN"
echo "Partial:   $PARTIAL"
echo "Deferred:  $DEFERRED"
TOTAL=$((DONE + OPEN + PARTIAL))
if [[ $TOTAL -gt 0 ]]; then
  PCT=$((DONE * 100 / TOTAL))
  echo "Progress:  ${PCT}% (${DONE}/${TOTAL} actionable items)"
fi
echo

echo "--- Automated gates ---"
GATES_OK=0
GATES_FAIL=0

gate() {
  local name="$1"
  shift
  if "$@"; then
    pass "$name"
    GATES_OK=$((GATES_OK + 1))
  else
    fail "$name"
    GATES_FAIL=$((GATES_FAIL + 1))
  fi
}

gate "Flutter tests" flutter test --reporter compact >/dev/null

if [[ -f build/app/outputs/bundle/release/app-release.aab ]]; then
  pass "Release AAB exists"
  GATES_OK=$((GATES_OK + 1))
else
  warn "Release AAB not found (run scripts/build_release_aab.sh)"
fi

if grep -q 'YYYY-MM-DD\|XXXXXXXX\|CHANGE_ME\|\*\*\*\*\*\*\*\*' PLAY_REVIEWER_ACCESS.md 2>/dev/null; then
  fail "Play reviewer access still has placeholders"
  GATES_FAIL=$((GATES_FAIL + 1))
else
  pass "Play reviewer access has no obvious placeholders"
  GATES_OK=$((GATES_OK + 1))
fi

BACKEND_DIR="$ROOT/../../apps/backend-laravel"
if [[ -d "$BACKEND_DIR" ]]; then
  if (cd "$BACKEND_DIR" && php artisan test --filter=ServiceProvider --compact >/dev/null 2>&1); then
    pass "Backend ServiceProvider tests"
    GATES_OK=$((GATES_OK + 1))
  else
    fail "Backend ServiceProvider tests"
    GATES_FAIL=$((GATES_FAIL + 1))
  fi
else
  warn "Backend dir not found — skipping ServiceProvider tests"
fi

if grep -q 'Pending' PRINTING_QA.md 2>/dev/null; then
  PENDING_PRINTERS=$(grep -c 'Pending' PRINTING_QA.md || true)
  warn "Printer QA: ${PENDING_PRINTERS} Pending entries in PRINTING_QA.md"
fi

echo
echo "--- P0 open items (sample) ---"
grep -E '^\| P0-' "$CHECKER" | grep '\[ \]' | head -15 || true

echo
if [[ $GATES_FAIL -eq 0 ]]; then
  pass "All automated gates passed ($GATES_OK)"
  exit 0
else
  fail "$GATES_FAIL automated gate(s) failed ($GATES_OK passed)"
  exit 1
fi