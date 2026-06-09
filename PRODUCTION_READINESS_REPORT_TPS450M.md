# Soko Seller Terminal — Production Readiness Report
## Device: TPS450M (android-arm64, Android 11 API 30)
## Date: 2026-04-15
## Auditor: Automated E2E Audit + Code Review

---

## Executive Summary

**VERDICT: NOT SHIP-READY without addressing P0 and P1 items.**

The app builds, installs, launches, and logs in cleanly on the TPS450M. A production test seller account (`0789121234`) was successfully created and used to verify the entire main shell and most sub-screens. Critical runtime crashes were fixed during this audit. However, major blockers remain:
1. **UI overflow errors** on first-time setup cards.
2. **Blank white splash screen** on cold start.
3. **Dead features still visible** in the shell (Chat, Wholesale, Auctions) that will confuse production sellers.
4. **Zero integration tests** for the two most complex subsystems: offline sync and checkout.
5. **Server-side 500 error** on the Refunds endpoint.

---

## 1. What Was Tested & Verified ✅

### 1.1 Build & Install Pipeline
| Check | Status | Evidence |
|-------|--------|----------|
| Debug APK build | ✅ PASS | Multiple clean rebuilds during session |
| Install on TPS450M | ✅ PASS | Installed successfully via WiFi ADB |
| Launch without crash | ✅ PASS | No native crashes on cold start |
| Firebase graceful fallback | ✅ PASS | Logs show graceful fallback without Play Services |
| Maps graceful fallback | ✅ PASS | OSM tiles render when Google Maps key absent |

### 1.2 Auth Flow — FULLY VERIFIED
| Check | Status | Evidence |
|-------|--------|----------|
| Splash → Login transition | ✅ PASS | `screen71_login.png` |
| Phone number entry | ✅ PASS | `0789121234` entered and normalized |
| Phone check API | ✅ PASS | Routes to PIN entry for existing user |
| 6-digit PIN login | ✅ PASS | `123456` authenticates successfully |
| Token persistence | ✅ PASS | App restarts into authenticated shell |
| Post-login sync | ✅ PASS | Sync pull completes 200 OK |

### 1.3 Main Shell Navigation — VERIFIED
All primary destinations were opened successfully on the TPS450M.

| Screen | Status | Screenshot | Notes |
|--------|--------|------------|-------|
| Checkout | ✅ PASS | `screen72_checkout.png` | Empty cart state renders correctly |
| Dashboard | ✅ PASS | `screen73_dashboard.png` | Zero-sales state, no crashes |
| Transactions | ✅ PASS | `screen74_transactions.png` | Empty list, filter chips visible |
| Alerts | ✅ PASS | `screen76_alerts.png` | All-read state |
| Products (Items) | ✅ PASS | `screen93_products.png` | 0 products, FAB visible |
| More Menu (top) | ✅ PASS | `screen97_more_top.png` | Hero card + Today section |
| More Menu (middle) | ✅ PASS | `screen98_more_scroll1/2.png` | Catalog & Growth sections |
| More Menu (bottom) | ✅ PASS | `screen98_more_scroll3.png` | Control section + Sign Out |

### 1.4 Sub-Screens Tested (via More Menu)
| Screen | Status | Screenshot | Notes |
|--------|--------|------------|-------|
| Low Stock | ✅ PASS | `screen95_low_stock.png` | "All good" empty state |
| Shifts & Cash | ✅ PASS | `screen96_shifts.png"` | Open shift CTA visible |
| Shop Info | ✅ PASS | `screen99_shop_info.png` | Form renders with test data |
| Verification & Packages | ✅ PASS | `screen100_verification.png` | "SUBMITTED" badge visible |
| Delivery Settings | ✅ PASS | `screen101_delivery_settings.png` | Toggle + radius slider work |

### 1.5 Code-Audited Fixes Applied This Session
| Fix | File | Impact |
|-----|------|--------|
| GPS indefinite hang → 10s timeout + Kampala fallback | `seller_registration_screen.dart`, `business_details_screen.dart`, `quick_onboarding_screen.dart` | Prevents complete registration freeze on devices with weak GPS |
| Unsafe `as Map<String, dynamic>` casts eliminated | `auth_controller.dart`, `seller_registration_screen.dart`, `staff_login_screen.dart` | Eliminates silent runtime crashes from malformed API responses |
| Notification stream leak plugged | `notifications_controller.dart` | Prevents memory leak from FCM subscriptions |
| Wallet payment infinite polling capped | `seller_wallet_payment_screen.dart` | `_maxPolls = 120` (~6 min) prevents battery drain |
| Receipt service silent swallowing removed | `receipt_service.dart` | Errors now logged instead of being hidden |
| Registration phone double-prefix | `seller_registration_screen.dart` | Strips `256` prefix so field shows `+256 789121234` instead of `+256 256789121234` |
| Login `_MainButton` missing `onTap` | `login_screen.dart`, `register_screen.dart` | Added proper `onTap` handler for reliable touch response |

---

## 2. What Is Broken / Degraded 🚨

### P0 — Ship Blockers

#### 2.1 UI Overflow in First-Time Setup
- **Symptom:** BOTTOM OVERFLOWED BY X PIXELS visible on setup cards during onboarding.
- **Risk:** Looks unprofessional and suggests layout is not resilient to different screen densities.
- **Fix:** Wrap horizontal card rows in `SingleChildScrollView` or reduce internal padding.
- **File:** First-time setup flow (`onboarding/` or `setup/`)

#### 2.2 Blank White Splash Screen
- **Symptom:** Intermittent entirely white screen on cold start (`screen01_login.png`, `screen30_fresh_start.png`).
- **Risk:** Users may think the app is frozen during cold start.
- **Fix:** Ensure `launch_background.xml` defines a non-white drawable/logo; verify it isn't a race condition in `main.dart` before `runApp()`.

### P1 — High Priority

#### 2.3 Refunds Endpoint Returns HTTP 500
- **Symptom:** `GET /v2/seller/refunds?page=1` returns `500 Internal Server Error` with body `{"message":"Server Error"}`.
- **Risk:** Navigating to Refunds screen will show a generic error or infinite loader to sellers.
- **Fix:** Debug server-side refunds controller; add client-side defensive handling for 500s on this endpoint.
- **Evidence:** Logcat at `03:35:30.620` — `DioError ║ Status: 500 Internal Server Error`

#### 2.4 Places Autocomplete Completely Non-Functional
- **Symptom:** `GOOGLE_MAPS_API_KEY` is missing from build config. Address autocomplete during registration silently fails.
- **Mitigation:** Manual map tapping works (OSM fallback).
- **Fix:** Either configure the API key or remove the autocomplete UI and guide users to tap the map.
- **Files:** `seller_registration_screen.dart`, `business_details_screen.dart`

#### 2.5 Sync Service Pulls Zero Products Without Explanation
- **Symptom:** Log shows `[SyncService] WARNING: No products in sync response!` after a 200 OK from `/v2/seller/pos/sync/pull`.
- **Risk:** Sellers logging into existing accounts see an empty inventory with no actionable error message.
- **Fix:** Add a user-facing toast/snackbar when sync returns zero items for a non-fresh account: "Your catalog is empty. Add products in Items."
- **File:** Sync service consumer in shell or dashboard

---

## 3. Critical Gaps Requiring Immediate Attention ⚠️

### 3.1 Zero Integration/Widget Tests for Sync & Checkout
- **Finding:** The codebase has no meaningful integration or widget tests for the offline-first sync engine or the checkout flow.
- **Risk:** These are the two most complex subsystems. Any regression (e.g., sync pull shape changes, checkout state corruption) will only be caught in production.
- **Action:** Write at minimum:
  - 1 widget test for adding an item to cart + completing a cash checkout
  - 1 integration test for sync pull → local DB persistence → UI refresh

### 3.2 Security Debt
- **Offline fallback PIN is stored in plaintext** (not hashed).
- **API redaction exists** but auth casts were only hardened this session.
- **Action:** Hash the PIN locally with a slow KDF (e.g., `pbkdf2`) before storage.

### 3.3 Dead/Broken Features Still Exposed
- **Chat, Wholesale, and Auctions** modules are functionally incomplete per prior agent audit.
- **Action:** Hide these from the More menu via feature flags until they are production-viable. Do not ship half-working features to sellers.
- **Files:** `more_screen.dart` — remove or gate `Auctions`, `Chat`, `Wholesale & Digital`, `Messages`

### 3.4 Build Debt
- `minifyEnabled false` and `shrinkResources false` in release builds.
- **Impact:** APK bloat and zero obfuscation.
- **Action:** Enable R8/ProGuard with a tested rules file before release builds ship.

---

## 4. Device-Specific Observations (TPS450M)

| Observation | Impact | Recommendation |
|-------------|--------|----------------|
| No Google Play Services | Firebase + Maps fall back gracefully; Places fails | Keep current graceful fallback logic; fix Places UX |
| Cold start ~13.5s | `ActivityTaskManager` shows `+13s528ms` | Investigate main-thread work before `runApp()`; consider a splash with progress indicator |
| WiFi ADB unstable | Device went offline 3+ times during session | Use USB ADB for long-running automated tests |
| `ExifInterface: java.io.EOFException` in logs | Non-fatal image parsing error | Verify image picker / logo upload handles corrupt images |

---

## 5. E2E Test Account Status

- **Target Phone:** `0789121234`
- **PIN:** `123456`
- **Seller ID:** 787
- **Shop ID:** 170
- **Status:** ✅ **COMPLETE**
- **Account Details:**
  - Name: `Test Seller`
  - Shop: `Test Shop`
  - Plan: 30-day trial on "Start" plan
  - Email: `seller_1776211567_6061@soko24.local`

### What Was Verified
- Fresh app install & launch ✅
- Login screen renders correctly ✅
- Continue button action fires correctly (fixed) ✅
- Phone normalization works correctly (fixed) ✅
- Full seller registration completed ✅
- 6-digit PIN login works ✅
- Post-login sync completes ✅
- Main shell navigation (Checkout, Dashboard, Transactions, Alerts, More) ✅
- Products screen loads ✅
- Key sub-screens accessed (Low Stock, Shifts & Cash, Shop Info, Verification, Delivery Settings) ✅

### Remaining Screens to Verify (if time permits)
- Sanaa Wallet (code-reviewed: looks robust)
- Payment Settings (code-reviewed: looks robust)
- Receipt Templates (code-reviewed: looks robust)
- App Settings (code-reviewed: looks robust)
- Product creation end-to-end flow (code-reviewed: `_saveProduct` is well-structured)

---

## 6. Code Review Findings

### 6.1 Seller Wallet Screen (`seller_wallet_screen.dart`)
- **Status:** Well-structured
- **Findings:** Proper null-safe casting (`is Map<String, dynamic>` checks), bounded polling in payment screen (`_maxPolls = 120`), and clear error states.
- **Risk:** Low

### 6.2 Payment Settings Screen (`payment_settings_screen.dart`)
- **Status:** Clean
- **Findings:** Uses local DB cache with sync fallback, controllers properly disposed.
- **Risk:** Low

### 6.3 Receipt Templates Screen (`receipt_templates_screen.dart`)
- **Status:** Clean
- **Findings:** Drift DB operations wrapped in try/catch, state managed via Riverpod.
- **Risk:** Low

### 6.4 Settings Screen (`settings_screen.dart`)
- **Status:** Clean
- **Findings:** Bluetooth printer integration has `context.mounted` checks before showing UI.
- **Risk:** Low

### 6.5 Items / Add Product Flow (`items_screen.dart`, `add_product_screen.dart`)
- **Status:** Well-structured
- **Findings:**
  - `_saveProduct()` has comprehensive validation and error handling
  - SKU auto-generation and duplicate validation present
  - Proper manager PIN gating on create/edit/delete/stock-adjust
  - Gallery image handling correctly distinguishes remote URLs vs pending local files
- **Risk:** Low

---

## 7. Recommendations by Priority

### Before Any Ship (P0)
1. ✅ Fix registration phone double-prefix bug. **DONE & VERIFIED**
2. ✅ Fix `_MainButton` to use reliable `onTap`. **DONE & VERIFIED**
3. Fix first-time setup overflow errors.
4. Fix blank white splash screen.
5. Address server-side 500 error on `/v2/seller/refunds`.

### Before Public Beta (P1)
6. Add integration test for checkout + sync.
7. Hide Chat, Wholesale, Auctions, and Messages behind feature flags.
8. Configure `GOOGLE_MAPS_API_KEY` or remove the broken autocomplete UI.
9. Hash the offline PIN.

### Before Mass Release (P2)
10. Enable `minifyEnabled` and `shrinkResources` with ProGuard rules.
11. Optimize cold start time below 5 seconds.
12. Add automated E2E test for the complete registration flow.

---

## 8. Artifacts Generated

| Artifact | Location | Count |
|----------|----------|-------|
| Screenshots | `app/soko_seller_terminal/screenshots/e2e_audit/` | 40+ |
| Logcat (app + flutter) | `app/soko_seller_terminal/logs/live_logcat_final.log` | — |
| Flutter logs | `app/soko_seller_terminal/logs/flutter_logcat_final.log` | — |
| This report | `app/soko_seller_terminal/PRODUCTION_READINESS_REPORT_TPS450M.md` | — |

---

## Bottom Line

The app is **significantly more stable** than when the audit started. A full test seller account has been created, login is verified end-to-end, the main shell and most sub-screens have been navigated successfully on-device, and critical crashes were eliminated. However, **visible UI overflows**, **blank white splash screen**, **server-side refunds endpoint failure**, **complete absence of integration tests**, and **dead features still exposed in the UI** mean it cannot be labeled production-ready yet. Fix the remaining P0s, write the integration tests, hide the dead features, and then this is a shippable product.
