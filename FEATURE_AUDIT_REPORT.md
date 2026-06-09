# Soko Seller Terminal — Feature Module Audit Report

**Date:** 2026-03-13  
**Scope:** All feature modules in `lib/src/features/`  
**Auditor:** Automated deep-code review  

---

## Executive Summary

A comprehensive audit of **80+ Dart files** across **22+ feature directories** in the Soko Seller Terminal Flutter application. The codebase demonstrates generally solid architecture with Riverpod state management, Drift for local DB, and an offline-first sync-queue pattern. However, several recurring patterns present risks around **silent error swallowing**, **stream subscription leaks**, **unsafe type casts**, and **missing input validation**.

**Deprecated domain (`soko.sanaa.ug`):** ✅ **No references found** — the codebase is clean of deprecated domain usage.

### Issue Summary by Severity

| Severity | Count | Categories |
|----------|-------|------------|
| 🔴 Critical | 3 | Stream subscription leaks, silent error swallowing on financial operations |
| 🟠 High | 8 | Unsafe type casts, missing error feedback, unprotected financial logic |
| 🟡 Medium | 12 | Silent catch blocks, hardcoded values, missing input validation |
| 🔵 Low | 8 | Code style, debug prints in production, minor UX gaps |

---

## 🔴 CRITICAL ISSUES

### C-1: Stream Subscription Leaks in NotificationsController

**File:** `notifications/notifications_controller.dart`  
**Lines:** 107, 116, 120

```dart
FirebaseMessaging.instance.onTokenRefresh.listen((newToken) async { ... });
FirebaseMessaging.onMessage.listen((message) { ... });
FirebaseMessaging.onMessageOpenedApp.listen((message) { ... });
```

**Problem:** Three Firebase stream subscriptions are created in `bootstrap()` without storing `StreamSubscription` references. The `NotificationsController` is a `StateNotifier` with no `dispose()` override to cancel them. If the provider is ever disposed and recreated, subscriptions accumulate, leading to duplicate event handling and memory leaks.

**Impact:** Duplicate notification handling, memory leak in long-running sessions.

**Fix:** Store subscriptions in a list and cancel them in `dispose()`:
```dart
final List<StreamSubscription> _subs = [];

@override
void dispose() {
  for (final sub in _subs) { sub.cancel(); }
  super.dispose();
}
```

---

### C-2: Silent Error Swallowing on Financial Operations

**Files & Lines:**
- `receipts/receipt_service.dart:496` — `sharePdf()`: `} catch (_) {}`
- `notifications/notifications_controller.dart:185` — `markRead()`: `} catch (_) {}`
- `notifications/notifications_controller.dart:204` — `markAllRead()`: `} catch (_) {}`
- `notifications/notifications_controller.dart:229` — `refreshUnread()`: `} catch (_) {}`
- `delivery/delivery_settings_screen.dart:919` — `_pasteFromClipboard()`: `} catch (_) {}`

**Problem:** Completely empty `catch` blocks silently swallow all exceptions including network errors, serialization failures, and permission issues. For receipt sharing (`receipt_service.dart:496`), a user may think a receipt was shared when the operation failed entirely with no feedback.

**Impact:** Users receive zero feedback when critical operations fail. Data integrity issues could go undetected.

**Fix:** At minimum, log the error and consider showing user feedback for user-facing operations:
```dart
} catch (e) {
  debugPrint('sharePdf failed: $e');
  // Optionally show a snackbar to user
}
```

---

### C-3: Unsafe Type Cast Chain in Wallet Payment Status Polling

**File:** `wallet/seller_wallet_payment_screen.dart`  
**Lines:** 73–82

```dart
final body = response.data is Map<String, dynamic>
    ? Map<String, dynamic>.from(response.data as Map<String, dynamic>)
    : const <String, dynamic>{};
final data = body['data'] is Map<String, dynamic>
    ? Map<String, dynamic>.from(body['data'] as Map<String, dynamic>)
    : const <String, dynamic>{};
final topup = data['topup'] is Map<String, dynamic>
    ? Map<String, dynamic>.from(data['topup'] as Map<String, dynamic>)
    : const <String, dynamic>{};
```

**Problem:** While individual `is` checks are present, this pattern is repeated across many files (wallet, marketing, checkout) with deep nesting. If the API response shape changes even slightly, the code silently falls through to empty maps, and the payment status polling will never detect completion — the timer continues indefinitely, and the user gets stuck on the payment page.

**Impact:** Users could be stuck on the payment page with no way to know their payment succeeded or failed if the API response format changes.

**Fix:** Add explicit handling for unexpected response shapes:
```dart
if (topup.isEmpty && body.isNotEmpty) {
  debugPrint('Unexpected wallet status response: $body');
}
```

---

## 🟠 HIGH ISSUES

### H-1: Unsafe Direct Cast `as Map` Without Type Check

**File:** `orders/order_details_screen.dart`  
**Lines:** 139, 142, 147

```dart
if ((_order!['soko_delivery_request'] as Map?) != null)
    ((_order!['soko_delivery_request'] as Map)['status'] ?? 'pending')
```

**Problem:** Direct cast to `Map?` without checking if the value actually is a Map. If `soko_delivery_request` is a non-Map value (string, int), this will throw a `TypeError` at runtime.

**Fix:** Use `is Map` pattern: `if (_order!['soko_delivery_request'] is Map)`

---

### H-2: Unprotected `as List` Casts Across Multiple Files

**Files & Lines:**
- `invoices/invoice_service.dart:353` — `order['order_items'] as List`
- `splash/splash_screen.dart:99` — `data['data'] as List`
- `auth/seller_registration_screen.dart:225` — `body['data'] as List`
- `settings/staff_management_screen.dart:92` — `data['data'] as List`

**Problem:** These casts assume the API always returns a List. If the API returns null, a Map, or a malformed response, a `TypeError` will crash the screen with no graceful error handling.

**Fix:** Defensively handle: `final list = data['data'] is List ? data['data'] as List : [];`

---

### H-3: Receipt Template Editor Unsafe Cast

**File:** `receipts/receipt_template_editor.dart`  
**Line:** 203

```dart
'${(i['qty'] as int) * (i['price'] as int)}'
```

**Problem:** Direct `as int` casts on map values that may not be integers (could be double, String, or null from JSON deserialization). This will throw a `TypeError` at runtime.

**Fix:** Use `(i['qty'] as num?)?.toInt() ?? 0`

---

### H-4: StaffMember.fromJson Unsafe Cast

**File:** `settings/staff_management_screen.dart`  
**Lines:** 36, 290-292

```dart
id: (json['id'] as num).toInt(),
// ...
name: result['name'] as String,
role: result['role'] as String,
pin: result['pin'] as String,
```

**Problem:** Direct `as num` and `as String` casts without null safety. If the API ever returns null for `id`, `name`, `role`, or `pin`, this crashes.

**Fix:** Add null-safe fallbacks: `id: (json['id'] as num?)?.toInt() ?? 0`

---

### H-5: Dashboard Metrics Provider Loads All Entries

**File:** `dashboard/dashboard_screen.dart`  
**Lines:** 9-16

```dart
final dashboardMetricsProvider = FutureProvider<DashboardMetrics>((ref) async {
  final db = ref.read(appDatabaseProvider);
  final entries = await db.watchLedgerEntries().first;
  final sales = entries.where((e) => e.type == 'sale').toList();
```

**Problem:** `watchLedgerEntries().first` loads ALL ledger entries into memory to compute dashboard stats. For a busy seller with thousands of transactions, this will cause significant memory pressure and slow rendering.

**Fix:** Use a dedicated SQL aggregation query or limit the date range.

---

### H-6: Analytics Controller Memory-Intensive Data Processing

**File:** `analytics/analytics_controller.dart`  
**Lines:** 57-117

**Problem:** The `refresh()` method loads all ledger entries for 7 days, all ledger lines for those entries, and all products into memory to compute analytics. For stores with high transaction volumes, this performs O(n) iterations multiple times.

**Fix:** Use SQL-level aggregation (GROUP BY date, SUM(total)) instead of loading all rows into Dart.

---

### H-7: Reports Screen Loads All Entries via Streams

**File:** `reports/reports_screen.dart`  
**Lines:** 12-24

```dart
final ledgerEntriesStreamProvider = StreamProvider<List<LedgerEntry>>((ref) {
  return ref.watch(appDatabaseProvider).watchLedgerEntries();
});
```

**Problem:** Watches ALL ledger entries as a stream (up to 2000 expenses, 500 cash movements, all ledger entries). For a mature business this could be thousands of records loaded into memory simultaneously. The date filter in the UI is applied in Dart, not at the SQL level.

**Fix:** Pass date range parameters to the database query.

---

### H-8: Checkout Customer Creation Silently Falls to Sync Queue

**File:** `checkout/checkout_screen.dart`  
**Lines:** 1131-1133

```dart
} catch (_) {
  await sync.enqueue('customer_push', {
    'idempotency_key': id,
```

**Problem:** When creating a customer during checkout, if the API call fails, the error is silently caught and the operation is queued for sync. The user gets no indication that the customer wasn't actually created on the server, which could lead to duplicate customers when the sync eventually runs.

---

## 🟡 MEDIUM ISSUES

### M-1: Repeated Deep Response Parsing Pattern

**Files:** `wallet/seller_wallet_screen.dart`, `marketing/bulk_sms_screen.dart`, `checkout/checkout_screen.dart`, `wallet/seller_wallet_payment_screen.dart`

**Problem:** The same deeply-nested response parsing pattern is copy-pasted across 10+ locations:
```dart
final body = response.data is Map<String, dynamic>
    ? Map<String, dynamic>.from(response.data as Map<String, dynamic>)
    : const <String, dynamic>{};
final data = body['data'] is Map<String, dynamic>
    ? Map<String, dynamic>.from(body['data'] as Map<String, dynamic>)
    : body;
```

**Fix:** Extract into a shared helper: `Map<String, dynamic> extractApiData(Response response)`

---

### M-2: Hardcoded Currency "UGX" Throughout

**Files:** `wallet/seller_wallet_screen.dart:121`, `delivery/delivery_settings_screen.dart` (multiple), `reports/reports_screen.dart`, `checkout/checkout_screen.dart`

**Problem:** Currency is hardcoded as "UGX" in multiple screens. If the product expands to other markets, this requires a global search-and-replace.

**Fix:** Centralize currency symbol in a configuration constant or derive from the seller's profile.

---

### M-3: Hardcoded Location Default to Kampala

**File:** `onboarding/business_details_screen.dart`  
**Line:** 514

```dart
initialLocation = const LatLng(0.3476, 32.5825); // Kampala
```

**Problem:** When GPS fails, defaults to Kampala coordinates. If the app is used outside Uganda, this would place the marker at an incorrect location.

**Fix:** Use a configurable default or show a "location unavailable" state.

---

### M-4: SMS Segment Calculation Not Accounting for Unicode

**File:** `marketing/bulk_sms_screen.dart`

**Problem:** SMS segment calculation assumes 160 chars = 1 segment (GSM 03.38 encoding). If messages contain Unicode characters (emojis, non-Latin scripts), segments are 70 characters. The credit estimate could be off by 2x.

**Fix:** Detect Unicode characters and use 70-char segments when present.

---

### M-5: Missing Input Validation in Delivery Fee Fields

**File:** `delivery/delivery_settings_screen.dart`

**Problem:** While the radius is clamped, the base fee, per-km fee, min fee, and max fee text fields lack validation for:
- Negative values
- Non-numeric input (partially handled by `tryParse`)
- Min fee > Max fee (logical validation)
- Unreasonably large values

---

### M-6: Coupon Date Range Not Validated

**File:** `coupons/coupons_screen.dart`

**Problem:** The coupon creation form accepts a date range but doesn't validate that:
- End date is after start date
- Start date is not in the past
- Date range is reasonable (not spanning years)

---

### M-7: POS Refund Screen No Maximum Quantity Check

**File:** `refunds/pos_refund_screen.dart`

**Problem:** The refund quantity selector allows selecting quantities, but there's no clear validation that the refund quantity doesn't exceed the original sale quantity minus any previous refunds for the same line item.

---

### M-8: Chat loadMessages Has No Error Handling

**File:** `chat/chat_screen.dart`  
**Lines:** 116-126

```dart
Future<List<MessageDto>> loadMessages(int conversationId) async {
    final res = await api.fetchConversationMessages(conversationId);
    // ... no try/catch
```

**Problem:** The `loadMessages` method has no try-catch. Any API error will propagate uncaught and likely crash the chat bottom sheet.

---

### M-9: Service Bookings Controller Queues Actions Without Dedup

**File:** `services/service_bookings_controller.dart`  
**Lines:** 86-89, 101-104, 116-120

**Problem:** When API calls fail, actions are queued for sync, but there's no deduplication. If a user taps "confirm" multiple times quickly during a network issue, multiple confirm actions get queued for the same booking.

---

### M-10: WhatsApp URL Construction Without Phone Validation

**Files:**
- `receipts/receipt_service.dart:520`
- `contacts/contacts_screen.dart:599`
- `inbox/inbox_screen.dart:589`

```dart
'https://wa.me/${sanitizedPhone ?? ''}?text=...'
```

**Problem:** If `sanitizedPhone` is null, the URL becomes `https://wa.me/?text=...` which opens WhatsApp without a recipient. The user experience is confusing.

**Fix:** Check for empty/null phone before constructing the URL and show a prompt instead.

---

### M-11: Quotation Validity Days Hardcoded Default

**File:** `quotations/quotations_screen.dart`  
**Line:** 75

```dart
final validityDays = (q['validity_days'] as num?)?.toInt() ?? 30;
```

**Problem:** Default validity of 30 days is hardcoded. Should be configurable per seller.

---

### M-12: Backup Item `createdAt` Parse Without Try-Catch

**File:** `backup/backup_screen.dart`  
**Line:** 62

```dart
createdAt: DateTime.parse(json['created_at'] as String),
```

**Problem:** If `created_at` is null, malformed, or not a String, this will throw. Should use `DateTime.tryParse` with a fallback.

---

## 🔵 LOW ISSUES

### L-1: Debug Prints in Production Code

**Files:**
- `splash/splash_screen.dart:127` — `debugPrint('Splash sync failed: $e')`
- `auth/seller_registration_screen.dart` — 15+ `debugPrint()` statements
- `contacts/contacts_controller.dart:318,326` — debug prints

**Problem:** `debugPrint` is suppressed in release builds, so this is low severity. However, the registration screen has extensive debug prints that may log PII (user name, phone number) in debug mode.

**Recommendation:** Audit debug prints for PII and consider a structured logging approach.

---

### L-2: Focus Listener Pattern Without Cleanup

**Files:**
- `auth/register_screen.dart:52-55`
- `auth/login_screen.dart:78-79`

```dart
_nameFocus.addListener(() => mounted ? setState(() {}) : null);
```

**Problem:** While `mounted` check prevents errors, the listener is not explicitly removed. When `dispose()` is called, the FocusNode is disposed which removes listeners, so this is safe — but the pattern is inconsistent and potentially confusing.

---

### L-3: Inconsistent Error Message Display

**Problem:** Some screens use `e.toString()` directly in error messages shown to users (e.g., `SnackBar(content: Text('Failed: $e'))`), which can expose internal error details like stack traces or API error payloads.

**Files:** Multiple — `pos_refund_screen.dart:88`, `staff_login_screen.dart:93`, `wallet/seller_wallet_screen.dart:296`

**Fix:** Use a helper to extract user-friendly error messages.

---

### L-4: Missing Loading States in Some Screens

**Files:**
- `profile/profile_screen.dart` — No loading state, just navigation links
- `customers/customers_screen.dart` — Quick-add form has no loading indicator during save

---

### L-5: TODO Comment in Production Code

**File:** `contacts/keypad_screen.dart`  
**Line:** 56

```dart
// TODO: Open Add Contact modal
```

**Problem:** Indicates incomplete feature implementation.

---

### L-6: Hardcoded Tile Server URL

**File:** `auth/seller_registration_screen.dart`  
**Line:** 1784

```dart
urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
```

**Problem:** OpenStreetMap tile server URL is hardcoded. OSM has usage policies and rate limits. For production, consider using a dedicated tile server or commercial provider.

---

### L-7: Hardcoded Product URL Pattern

**File:** `ads/ads_screen.dart`  
**Line:** 882

```dart
data: 'https://soko24.co/product/${item.id}',
```

**Problem:** The product URL domain `soko24.co` is hardcoded. Should use a configuration value.

---

### L-8: Color Parsing Without Validation

**File:** `settings/receipt_templates_screen.dart`  
**Lines:** 373-376

```dart
try {
  return Color(int.parse(hex.replaceFirst('#', '0xFF')));
} catch (_) {
  return DesignTokens.grayLight;
}
```

**Problem:** While the fallback is reasonable, the `replaceFirst` approach doesn't handle edge cases like `#abc` (3-char hex), `rgb(...)`, or other color formats. Low severity since it gracefully falls back.

---

## PATTERNS & RECOMMENDATIONS

### 1. Extract Common API Response Parser
The deep-nested `response.data is Map` → `body['data'] is Map` pattern is repeated 15+ times. Create:
```dart
extension ApiResponseExt on Response {
  Map<String, dynamic> get apiData { ... }
  List<dynamic> get apiList { ... }
}
```

### 2. Centralize Error Handling
Create a user-facing error message extractor to avoid exposing raw error objects:
```dart
String userFriendlyError(Object error) {
  if (error is DioException) return error.message ?? 'Network error';
  return 'Something went wrong. Please try again.';
}
```

### 3. SQL-Level Aggregation for Reports/Analytics/Dashboard
Move data aggregation from Dart to SQL queries to reduce memory usage for high-volume sellers.

### 4. Configuration Constants
Centralize: currency symbol, default location coordinates, product URL domain, tile server URL, default validity days, etc.

### 5. Stream Subscription Management
Audit all `.listen()` calls in StateNotifiers and State objects to ensure subscriptions are properly stored and cancelled.

---

## Conclusion

The codebase is well-structured with consistent patterns and good use of Flutter/Riverpod conventions. The offline-first architecture with sync queues is robust. The main areas of concern are:

1. **Memory**: Large dataset loading for dashboard/analytics/reports (High impact for busy sellers)
2. **Reliability**: Silent error swallowing in financial operations (Critical for trust)
3. **Safety**: Unsafe type casts that can crash screens (High impact)
4. **Maintainability**: Duplicated response parsing logic (Medium impact)

The application would benefit most from addressing the Critical and High severity items, particularly the stream subscription leaks and the database query optimization.
