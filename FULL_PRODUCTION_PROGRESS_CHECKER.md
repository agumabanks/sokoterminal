# Soko Seller Terminal — Full Production Progress Checker

**Last updated:** 2026-06-09  
**Scope:** Seller Terminal + Laravel POS/ServiceProvider backend  
**Goal:** 100% production-ready (Play GA + backend deploy + POS + catalog + services + QA)

---

## How to use

1. Every item has an **ID** (`P0-R1.1`, `P1-B2.6`, etc.) — cite these in PRs and commits.
2. Status legend:
   - `[ ]` Not started
   - `[~]` In progress / partial
   - `[x]` Done (verified end-to-end)
   - `[—]` Deferred (post-GA / feature-flagged)
3. Run the auto-checker:

```bash
cd app/soko_seller_terminal
bash scripts/check_production_progress.sh
```

4. Update this file when an item is verified — the script reports open vs done counts.

---

## Overall progress (update after each sprint)

| Metric | Target | Current |
|--------|--------|---------|
| P0 blockers closed | 18 | 0 |
| P1 blockers closed | 32 | 14 |
| P2 blockers closed | 17 | 2 |
| Flutter tests | PASS | PASS (106) |
| Backend ServiceProvider tests | PASS | PASS (4) |
| Signed release AAB | exists | YES |
| Play submission gate | PASS | FAIL (reviewer creds) |
| Printer certification | ≥3 models | 0 |

**Production verdict:** NOT READY for 100% Play rollout. READY for controlled pilot after P0 ops + backend deploy.

---

## 10/10 Master Plan

Each phase has a clear exit gate. Complete phases in order; do not skip P0.

### Phase 1 — Truth & tracking (Day 0–1)
**Exit gate:** This doc + `check_production_progress.sh` green on code gates.

- [x] P1-TR1.1 Enumerate all blockers in this file
- [x] P1-TR1.2 Add automated progress script
- [ ] P1-TR1.3 Assign owner per P0 item (ops / backend / mobile)

### Phase 2 — Backend deploy & contracts (Day 1–3)
**Exit gate:** Production migrations run, `pos:v2-doctor` clean, ServiceProvider tests green, smoke script pass.

- [ ] P0-B2.1 Production DB backup + rollback plan
- [ ] P0-B2.2 Deploy POS v2 + service catalog changes to production
- [ ] P0-B2.3 Run all `2025_12_*` POS migrations on production
- [ ] P0-B2.4 Run `php artisan pos:v2-doctor`
- [ ] P0-B2.5 Smoke: sync pull, ledger sale/refund/void, expenses idempotency
- [x] P1-B2.6 Fix `is_published` boolean JSON in ServiceOffering API
- [ ] P1-B2.7 Triage full backend test suite failures (112 failing)
- [ ] P1-B2.8 Seller-scoped customers pagination/search API

### Phase 3 — Release ops & Play Console (Day 2–5)
**Exit gate:** `play_submission_gate.sh` passes; Internal testing build uploaded.

- [ ] P0-R3.1 Fill `PLAY_REVIEWER_ACCESS.md` with real credentials
- [ ] P0-R3.2 Pass `verify_play_reviewer_login.sh`
- [ ] P0-R3.3 Complete Play listing, screenshots, Data Safety, content rating
- [ ] P0-R3.4 Upload AAB to Internal testing
- [ ] P0-R3.5 Closed testing with 10–50 pilot sellers
- [ ] P1-R3.6 Firebase Remote Config rollout policy documented
- [ ] P1-R3.7 7-day rollout monitoring per `ROLLOUT_MONITORING.md`

### Phase 4 — Printer & device QA (Day 3–7)
**Exit gate:** ≥3 certified printer models with evidence; TPS450M signed off.

- [ ] P0-Q4.1 Run printer QA matrix (`PRINTING_QA.md`)
- [ ] P0-Q4.2 Certify ≥3 thermal models; fill `PRINTING_QA_RESULTS_TEMPLATE.md`
- [ ] P1-Q4.3 Device matrix: Android 10–14, 2+ brands, core flows
- [ ] P1-Q4.4 TPS450M full regression (`PRODUCTION_READINESS_REPORT_TPS450M.md`)

### Phase 5 — Core POS hardening (Week 1–2)
**Exit gate:** Offline sale → sync → no duplicates signed off; no P1 POS security gaps.

- [x] P1-P5.1 SyncService dispose wired in provider (no leak)
- [x] P1-P5.2 Named parked sales persist to Drift (survive restart)
- [x] P1-P5.3 Active cart clear no longer wipes named parked sales
- [x] P1-P5.4 Checkout rapid-tap guard on `_addProduct`
- [ ] P0-Q5.5 Manual offline-sale → online sync script signed off
- [x] P1-P5.6 DB migration steps wrapped with error telemetry
- [ ] P1-P5.7 TLS certificate pinning for `soko24.co`
- [ ] P1-P5.8 Offline PIN login when token expired
- [ ] P1-P5.9 Cart stock check + ledger write atomic transaction
- [ ] P1-P5.10 Staff PIN hashing (bcrypt/argon2)
- [ ] P1-P5.11 SQLite encryption (sqlcipher) evaluation + decision
- [ ] P1-P5.12 PIN brute-force rate limiting

### Phase 6 — Catalog parity (Week 2–3)
**Exit gate:** Product preview → add-to-cart → checkout works; services publish/moderation E2E verified.

- [x] P1-C6.1 Product preview "Add to cart" wired to CartController + checkout
- [ ] P1-C6.2 Taxes, attributes, colors in product editor
- [ ] P1-C6.3 Per-variant image upload
- [ ] P1-C6.4 Product draft/autosave offline
- [x] P1-C6.5 Service `is_published` API boolean contract
- [x] P1-C6.6 Service publish → moderation pending UX verified on device
- [x] P1-C6.7 Integration test: service edit → sync → moderation state

### Phase 7 — Orders, bookings & notifications (Week 3–4)
**Exit gate:** Unified inbox covers orders + bookings; push opens correct screen.

- [x] P1-N7.1 FCM token registered with seller notifications API
- [x] P1-N7.2 FCM foreground notification UI
- [x] P1-N7.3 FCM deep-link routing (orders, bookings, alerts)
- [x] P1-N7.4 Typed order models (replace raw `Map` casts)
- [x] P1-N7.5 Refund requests tab in unified inbox
- [x] P1-N7.6 Order details full Drift cache + delta pull

### Phase 8 — UX & design system (Week 4–5)
**Exit gate:** Design tokens on top 5 screens; perf budgets measured on profile build.

- [x] P1-U8.1 Design tokens enforced: Checkout, Items, Orders, More, Settings
- [x] P1-U8.2 8pt grid + 3 font sizes + 3 grays enforced
- [ ] P2-U8.3 "Remove 20%" simplification pass
- [ ] P2-U8.4 Performance budgets (startup, list FPS) on profile build
- [x] P2-U8.5 Orders "next action first" UX

### Phase 9 — Testing & CI gates (Week 2–ongoing)
**Exit gate:** CI runs unit + integration tests; release gate blocks on failure.

- [x] P1-T9.1 ServiceProvider PHPUnit regression fixed
- [x] P1-T9.2 Wire `integration_test/` into `seller_terminal_ci.yml`
- [x] P1-T9.3 Integration: offline sale sync no duplicates
- [x] P1-T9.4 Integration: manager PIN required for refund/void
- [x] P2-T9.5 Replace placeholder `widget_test.dart`
- [ ] P2-T9.6 Backend POS contract tests green in CI

### Phase 10 — Post-GA merchant platform (Week 6+)
**Exit gate:** Feature flags enabled per pilot cohort without regressions.

- [ ] [—] P2-G10.1 Collections (`ff_collections_v1`)
- [ ] [—] P2-G10.2 Channel pricing (`ff_channel_pricing_v1`)
- [ ] [—] P2-G10.3 Promotions engine (`ff_promotions_v1`)
- [ ] [—] P2-G10.4 Inventory reservations (`ff_inventory_reservations_v1`)
- [ ] [—] P2-G10.5 Soko Studio mobile workflow (`ff_soko_studio`)
- [ ] [—] P2-G10.6 Returns/exchanges (`ff_returns_exchanges_v1`)
- [ ] [—] P2-G10.7 Device fleet management (`ff_device_fleet_mgmt_v1`)
- [ ] [—] P2-G10.8 Messaging templates (`ff_messaging_templates_v1`)

---

## Full blocker registry

### A. Release / Ops

| ID | Sev | Status | Item |
|----|-----|--------|------|
| P0-R1.1 | P0 | [ ] | Play reviewer access docs — real credentials |
| P0-R1.2 | P0 | [ ] | Play Console listing + Data Safety + content rating |
| P0-R1.3 | P0 | [ ] | `play_submission_gate.sh` passes |
| P0-R1.4 | P0 | [ ] | Printer QA matrix — 0/5 families certified |
| P0-R1.5 | P0 | [ ] | Staged Play rollout not started |
| P1-R1.6 | P1 | [ ] | 7-day Crashlytics monitoring |
| P1-R1.7 | P1 | [ ] | Remote Config rollout policy |
| P2-R1.8 | P2 | [x] | Production keystore + signed AAB |

### B. Backend deploy / contracts

| ID | Sev | Status | Item |
|----|-----|--------|------|
| P0-B2.1 | P0 | [ ] | Production backup + rollback plan |
| P0-B2.2 | P0 | [ ] | Deploy POS v2 + service changes |
| P0-B2.3 | P0 | [ ] | Run production migrations |
| P0-B2.4 | P0 | [ ] | `pos:v2-doctor` on production |
| P0-B2.5 | P0 | [ ] | HTTP smoke tests on production |
| P1-B2.6 | P1 | [x] | `is_published` boolean JSON cast |
| P1-B2.7 | P1 | [ ] | Full backend test suite triage |
| P1-B2.8 | P1 | [ ] | Seller-scoped customers API |
| P2-B2.9 | P2 | [ ] | DELETE-via-GET endpoints in seller_api |
| P2-B2.10 | P2 | [ ] | Structured logging + request IDs |

### C. Core POS

| ID | Sev | Status | Item |
|----|-----|--------|------|
| P0-Q5.5 | P0 | [ ] | Offline sale sync manual sign-off |
| P1-P5.1 | P1 | [x] | SyncService provider dispose |
| P1-P5.2 | P1 | [x] | Named parked sales Drift persistence |
| P1-P5.3 | P1 | [x] | Active cart vs parked sales isolation |
| P1-P5.4 | P1 | [x] | Checkout add-product debounce |
| P1-P5.6 | P1 | [x] Migration error telemetry |
| P1-P5.7 | P1 | [ ] | TLS certificate pinning |
| P1-P5.8 | P1 | [ ] | Offline PIN when token expired |
| P1-P5.9 | P1 | [ ] | Atomic stock + ledger transaction |
| P1-P5.10 | P1 | [ ] | Staff PIN hashing |
| P1-P5.11 | P1 | [ ] | SQLite encryption |
| P1-P5.12 | P1 | [ ] | PIN brute-force limiting |

### D. Products catalog

| ID | Sev | Status | Item |
|----|-----|--------|------|
| P1-C6.1 | P1 | [x] | Preview add-to-cart → checkout |
| P1-C6.2 | P1 | [ ] | Taxes, attributes, colors |
| P1-C6.3 | P1 | [ ] | Per-variant images |
| P1-C6.4 | P1 | [ ] | Product draft/autosave |
| P2-C6.5 | P2 | [ ] | Reviews tab (needs ratings API) |
| P2-C6.6 | P2 | [ ] | Collections CRUD |

### E. Services module

| ID | Sev | Status | Item |
|----|-----|--------|------|
| P1-C6.5 | P1 | [x] | API boolean `is_published` |
| P1-E5.1 | P1 | [ ] | Publish → moderation UX device QA |
| P1-E5.2 | P1 | [ ] | Integration test edit→sync→moderation |
| P2-E5.3 | P2 | [x] | Categories, packages, publish gates (P0 sprint) |
| P2-E5.4 | P2 | [x] | Bookings inbox + offline cache |
| P2-E5.5 | P2 | [ ] | Provider profile in-app |

### F. Orders / bookings / notifications

| ID | Sev | Status | Item |
|----|-----|--------|------|
| P1-N7.1 | P1 | [x] | FCM token backend registration |
| P1-N7.2 | P1 | [x] | FCM foreground UI |
| P1-N7.3 | P1 | [x] | FCM deep-links |
| P1-N7.4 | P1 | [x] | Typed order models |
| P2-N7.5 | P2 | [x] | Refund requests inbox tab |
| P2-N7.6 | P2 | [x] | Order details Drift cache |

### G. UX / design

| ID | Sev | Status | Item |
|----|-----|--------|------|
| P1-U8.1 | P1 | [x] | Design tokens on core 5 screens |
| P2-U8.2 | P2 | [ ] | 8pt grid / typography constraints |
| P2-U8.3 | P2 | [ ] | Remove 20% UI chrome |
| P2-U8.4 | P2 | [ ] | Performance budgets |

### H. Testing / CI

| ID | Sev | Status | Item |
|----|-----|--------|------|
| P0-Q4.1 | P0 | [ ] | Physical printer QA |
| P1-T9.1 | P1 | [x] | ServiceProvider PHPUnit fix |
| P1-T9.2 | P1 | [x] | Integration tests in CI |
| P1-T9.3 | P1 | [x] | Offline sync integration test |
| P2-T9.4 | P2 | [x] | Manager PIN gate widget test |

---

## Sprint log

| Date | Items closed | Notes |
|------|--------------|-------|
| 2026-06-09 | P1-B2.6, P1-P5.1–4, P1-C6.1, P1-N7.1, P1-T9.1 | Progress checker + code hardening sprint |
| 2026-06-09 | P1-N7.2–3, P1-P5.6, P1-T9.2 | FCM routing, migration telemetry, CI integration job |
| 2026-06-09 | P1-N7.4, P1-C6.7, P1-U8.1 | Typed `MarketplaceOrder`, service moderation test, design token pass on Checkout/Items/Orders |
| 2026-06-09 | P1-N7.5, P1-T9.3 | Inbox refunds tab + ledger sync dedupe tests |
| 2026-06-09 | P1-N7.6, P1-T9.4 | Order Drift cache delta pull + manager PIN gate tests |
| 2026-06-09 | P1-U8.2, P1-C6.6, P2-U8.5, P2-T9.5 | More screen tokens, orders needs-action sort, moderation snackbars, widget smoke |

---

## Quick commands

```bash
# Progress report
bash scripts/check_production_progress.sh

# Flutter quality
flutter test && flutter analyze

# Backend service tests
cd ../../apps/backend-laravel && php artisan test --filter=ServiceProvider

# Release build
bash scripts/build_release_aab.sh

# Play gate (needs real reviewer creds)
bash scripts/play_submission_gate.sh
```