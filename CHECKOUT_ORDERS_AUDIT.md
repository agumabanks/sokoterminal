# Checkout, Orders & Transactions — Deep Audit Report

**Audited:** 2026-03-13  
**Scope:** `/lib/src/features/checkout/`, `/lib/src/features/orders/`, `/lib/src/features/transactions/`, `/lib/src/features/refunds/`, `/lib/src/features/receipts/`, `/lib/src/core/network/seller_api.dart`, `/lib/src/core/db/app_database.dart`, `/lib/src/core/sync/sync_service.dart`

---

## Executive Summary

The checkout/POS flow is well-architected with offline-first design, idempotent sync, and comprehensive stock management. However, there are several issues ranging from **critical** (floating-point currency math, race conditions) to **low** (cosmetic/UX). Total: **4 critical**, **6 high**, **8 medium**, **5 low** findings.

---

## CRITICAL Severity

### C1. Floating-Point Currency Arithmetic — Potential Penny Rounding Errors
**Files:** `cart_controller.dart:40`, `cart_controller.dart:68`, `checkout_screen.dart:~line 680`  
**Description:** All monetary values use `double` (`CartLine.price`, `CartLine.total`, `CartState.subtotal`, `CheckoutPayment.amount`). In Dart, `double` is IEEE 754 which cannot represent all decimal values exactly. For UGX (integer currency with no subunits), this is partially mitigated by `decimalDigits: 0` in the formatter, but intermediate calculations like `price * quantity` and `lines.fold(0, (sum, line) => sum + line.total)` can accumulate rounding errors.

**Impact:** For typical small POS transactions this is unlikely to cause visible issues, but for large orders or split payments with many items, the `(paid - total).abs() > 0.01` check in `checkout()` (line ~300 of `cart_controller.dart`) could theoretically fail or allow a 1 UGX discrepancy.

**Suggested Fix:**
- Since UGX has no decimal subunits, consider using `int` for all monetary fields (price in UGX integer). This eliminates all rounding issues.
- Alternatively, use a `Decimal` package (e.g., `decimal` from pub.dev) for all monetary calculations.
- At minimum, round all intermediate results: `(price * quantity).roundToDouble()`.

### C2. Race Condition: Cart State Not Protected During Concurrent `addItem` / `addItemVariant` Calls
**File:** `cart_controller.dart:89-175`  
**Description:** `addItem()` and `addItemVariant()` read `state.lines`, find an index, copy the list, modify it, and set state. On the checkout screen, rapid tapping of product tiles (or barcode scanner auto-add) can issue multiple `addItem` calls before the first completes its `setState`. Since `CartController` extends `StateNotifier`, state mutations are synchronous and sequential within the same isolate, so this is mitigated for synchronous `addItem()`. However, `_addProduct()` in `checkout_screen.dart` is `async` (fetches stocks from DB) and calls `addItem` in its callback — multiple concurrent `_addProduct` calls **can** interleave:

```
Tap 1: _addProduct → await db.getItemStocksForItem → addItem (reads stale state)
Tap 2: _addProduct → await db.getItemStocksForItem → addItem (reads same stale state)
```

**Impact:** Two rapid taps on the same product could add qty=2 instead of qty=1 or bypass the stock limit check.

**Suggested Fix:**
- Add a per-item debounce/lock in `_addProduct()`, or use a serial queue for add operations.
- The existing `_scanLocked` pattern for barcodes is a good model — extend it to product taps.

### C3. Parked Sales Lost on App Restart
**File:** `parked_sales_controller.dart:32-36`  
**Description:** `ParkedSalesController` is a `StateNotifier` with `super(const [])` — its state is purely in-memory. Parked sales are **not persisted** to the local database. If the app is killed, crashes, or is restarted, all parked sales are permanently lost.

**Impact:** Seller loses in-progress sales when the app restarts. This is a data loss bug for any seller who parks sales and then has the app killed by the OS.

**Suggested Fix:**
- Persist parked sales to a new `parked_sales` table in `app_database.dart`, or serialize to `SharedPreferences`.
- Load persisted parked sales in the controller constructor.

### C4. No Duplicate Checkout Protection (Double-Tap)
**File:** `checkout_screen.dart:_handleCheckout()` (~line 616)  
**Description:** `_handleCheckout` is an `async` method called from the "Charge" button's `onPressed`. There is no guard preventing the user from tapping "Charge" multiple times before the first checkout completes. The method does `if (cart.lines.isEmpty) return;` but this check passes on the second tap if the first hasn't called `clear()` yet.

The `checkout()` method in `CartController` generates a new `transactionId` each time, so a double-tap would create **two separate sales** for the same cart contents.

**Impact:** Double charges, duplicate inventory deductions, duplicate sync operations.

**Suggested Fix:**
- Add a `_checkingOut` boolean guard in `_CheckoutScreenState`, set `true` at entry, `false` in `finally`.
- Or disable the checkout button while processing (show loading indicator).

---

## HIGH Severity

### H1. `CartState.copyWith` Does Not Support Clearing `customer` to Null
**File:** `cart_controller.dart:36-42`  
**Description:** The `copyWith` method uses `customer: customer ?? this.customer`. This means calling `copyWith(customer: null)` does NOT clear the customer — it keeps the existing one. However, `setCustomer(null)` does work because it passes `null` which falls through. This is actually fine for `setCustomer` but the `copyWith` pattern is misleading and error-prone for future callers who want to reset customer.

**Impact:** If any code tries `state = state.copyWith(customer: null)` to clear the customer, it silently fails.

**Suggested Fix:** Use a sentinel pattern or make customer an `Optional<Customer?>`:
```dart
CartState copyWith({
  List<CartLine>? lines,
  String? notes,
  Customer? Function()? customer,
}) {
  return CartState(
    lines: lines ?? this.lines,
    notes: notes ?? this.notes,
    customer: customer != null ? customer() : this.customer,
  );
}
```

### H2. `checkout()` Stock Check Has TOCTOU Race
**File:** `cart_controller.dart:305-330`  
**Description:** The `checkout()` method re-validates stock before committing, but reads stock from the DB and then writes the ledger entry in a separate step. Another device (or sync) could modify stock between the check and the write. The `saveLedgerEntry` call and `recordInventoryMovement` are separate DB transactions.

**Impact:** In multi-terminal setups, it's theoretically possible for two terminals to both pass the stock check and oversell.

**Suggested Fix:**
- Wrap the stock check + ledger save + inventory deduction in a single `db.transaction()` block.
- Add an optimistic lock (check-and-decrement atomically).

### H3. Orders Controller: Untyped `Map<String, dynamic>` Everywhere
**File:** `orders_controller.dart`, `order_details_screen.dart`  
**Description:** The entire orders feature uses raw `Map<String, dynamic>` for order data with no model class. Every access is `order['customer_name']?.toString()` with fallbacks. This is fragile — any API field name change causes silent failures, and there's no compile-time safety.

**Impact:** Silent data display errors if API response shape changes. Hard to maintain.

**Suggested Fix:** Create `Order`, `OrderItem` model classes with `fromJson` factory constructors.

### H4. Split Payment: No Validation That All Split Amounts Are Positive Before Submission
**File:** `checkout_screen.dart:_splitPaymentFlow()` (~line 1900)  
**Description:** The `ok` check includes `drafts.every((d) => (_parseAmount(d.amountCtrl.text) ?? 0) > 0)`, which is correct. However, the amount parsing uses `_parseAmount` which calls `double.tryParse(normalized)` — if the user enters a non-numeric string, this returns `null`, treated as `0`, which should fail the `> 0` check. This is correct but there's no user feedback about **which** split has an invalid amount.

Additionally, the `remaining` display can show negative values if the user over-allocates (e.g., two splits each for the full amount). The button is disabled but the UI doesn't explain why.

**Impact:** Poor UX — user confusion about why "Complete sale" is disabled.

**Suggested Fix:** Add inline validation messages per split draft showing "Invalid amount" or "Over budget".

### H5. Refund Always Creates `cash` Payment Regardless of Original Payment Method
**File:** `pos_refund_screen.dart:_processRefund()` (~line 194)  
**Description:** The refund always creates `PaymentsCompanion.insert(method: 'cash', amount: _refundTotal)`. If the original sale was paid via mobile money or card, the refund is still recorded as cash.

**Impact:** Inaccurate payment reconciliation. Cash drawer discrepancies.

**Suggested Fix:** Carry forward the original payment method(s), or let the cashier choose the refund payment method.

### H6. Missing Error Handling on `_fetchDetails` in `OrderDetailsScreen`
**File:** `order_details_screen.dart:_fetchDetails()` (line ~40)  
**Description:** `_fetchDetails` calls `loadOrderDetails` which can throw. The result is checked for `null` but exceptions bubble up unhandled (no `try/catch`). If the API call throws, `_loading` remains `true` forever. Actually, looking more carefully, `loadOrderDetails` catches errors internally and returns `null` on failure — so the state will be `_loading = false` and `_order = null`, which shows "Failed to load". But if the `setState` in the `if (mounted)` block itself throws or the widget is disposed during the await, there's no outer catch. This is minor but technically incomplete.

**Impact:** Potential unhandled exception if widget disposed during fetch.

**Suggested Fix:** Wrap in try/catch with proper error state.

---

## MEDIUM Severity

### M1. `CartLine.total` Recomputed on Every Access
**File:** `cart_controller.dart:68`  
**Description:** `double get total => price * quantity;` is recomputed every time it's accessed. While cheap, this is called in `subtotal` (which folds over all lines), in the UI for every line render, and in checkout validation.

**Suggested Fix:** Cache the value or accept as-is (performance impact is negligible for typical cart sizes of <50 items).

### M2. `updateQuantity` and `updateQuantityWithFreshStock` Have Duplicate Logic
**File:** `cart_controller.dart:193-266`  
**Description:** `updateQuantity` is synchronous and uses cached `availableStock`. `updateQuantityWithFreshStock` is async and re-reads from DB. The synchronous version is only used indirectly (the screen always calls the async version). The sync version could become stale.

**Suggested Fix:** Consider removing `updateQuantity` or making it private, as only `updateQuantityWithFreshStock` is used from the UI.

### M3. Search Debounce Timer Leak on Hot Reload
**File:** `checkout_screen.dart:70-76`  
**Description:** `_searchDebounce` timer is cancelled in `dispose()` but not on hot reload when `initState` might not re-run. This is a minor dev-mode issue only.

### M4. `_cashReceivedFlow` Allows Exact Payment But Not Under-Payment
**File:** `checkout_screen.dart:_cashReceivedFlow()` (~line 1718)  
**Description:** The `ok` check is `received >= total - 0.01`. This means the seller can't proceed if they receive slightly less (e.g., customer pays 9,999 on a 10,000 bill). This is intentional but the 0.01 tolerance is odd for UGX (integer currency).

**Suggested Fix:** Use `received >= total` (exact integer comparison) or allow configurable tolerance.

### M5. Telemetry Events Use `unawaited()` But No Error Handling
**Files:** `cart_controller.dart:244`, `cart_controller.dart:383`  
**Description:** Telemetry calls are fire-and-forget with `unawaited()`. If telemetry throws, the error is unhandled and could crash in debug mode.

**Suggested Fix:** Add `.catchError((_) {})` or wrap in try/catch within the telemetry service.

### M6. `OrdersController.load()` Doesn't Clear Error on Retry
**File:** `orders_controller.dart:43`  
**Description:** `load()` sets `state = OrdersState(loading: true, orders: state.orders)` which implicitly clears `error` to `null`. On success it also clears error. This is actually correct. However, on failure with cached data, it sets `error` but keeps stale orders — the error message persists even after a successful retry because the screen doesn't clear it. Actually, on success `state = OrdersState(orders: list)` which has `error: null` by default. So this is fine.

### M7. Transactions Screen: Custom Date Range Filter is Inclusive-Exclusive
**File:** `transactions_screen.dart:~line 290`  
**Description:** The POS custom filter uses `e.createdAt.isAfter(customStart!) && e.createdAt.isBefore(customEnd!.add(const Duration(days: 1)))`. The online orders filter uses the same logic. However, `isAfter` is exclusive of the start boundary — entries at exactly midnight of `customStart` would be excluded.

**Suggested Fix:** Use `!e.createdAt.isBefore(customStart!)` (i.e., `>=`) for the start boundary.

### M8. Receipt Number Collision Risk on Multi-Device
**File:** `app_database.dart:getNextReceiptNumber()` (~line 1010)  
**Description:** Receipt numbers are sequential per-device (`MAX(receipt_number) + 1`). Two terminals operating offline will generate overlapping receipt numbers. When synced, the server receives duplicate receipt numbers from different terminals.

**Impact:** Confusing for accounting and receipt lookups.

**Suggested Fix:** Prefix receipt numbers with a terminal/outlet ID, or use a UUID-based receipt number with a human-readable sequential suffix.

---

## LOW Severity

### L1. `DropdownButtonFormField` Uses `initialValue` Instead of `value`
**Files:** `checkout_screen.dart:_splitPaymentFlow()` (~line 1882), `order_details_screen.dart:_showStatusModal()` (~line 385)  
**Description:** `DropdownButtonFormField` is constructed with an `initialValue` parameter. In standard Flutter, the parameter is called `value` for `DropdownButtonFormField`. This might be a custom wrapper or could cause a compile error.

**Note:** If this compiles, it may be that a custom `DropdownButtonFormField` is being used, or `initialValue` was added in a newer Flutter version. Verify at compile time.

### L2. Category Grid Widget Is Unused
**File:** `checkout/widgets/category_grid.dart`  
**Description:** The `CategoryGrid` widget and `selectedCategoryProvider` are defined but never used in the checkout screen. The checkout screen has its own product/service grid without category filtering.

**Suggested Fix:** Remove dead code or integrate category filtering.

### L3. Demo Seed Data Uses Hardcoded Prices
**File:** `checkout_screen.dart:_seedDemoDataIfEmpty()` (~line 2020)  
**Description:** Seed items like "Coffee" at UGX 6,000 are hardcoded. Not a bug, but could confuse sellers if they appear in production.

### L4. Inconsistent Null Handling in Order Details
**File:** `order_details_screen.dart:_buildItemsList()` (~line 260)  
**Description:** Item price fallback: `item['unit_price'] is num ? ... : double.tryParse(...)`. If `unit_price` is a string "0", `double.tryParse` returns 0.0 but `is num` returns false. The `lineTotal` calculation has `(item['total'] is num) ? ... : (unitPrice * qty)` — if `total` is missing AND `unit_price` is 0, the line shows 0. This is correct fallback behavior but could mask data issues.

### L5. WhatsApp Receipt Share: Phone Sanitization Assumes Uganda (+256)
**File:** `receipt_service.dart:_sanitizePhone()` (~line 480)  
**Description:** If phone starts with `0`, it's converted to `256...`. This hardcodes Uganda country code. If the platform expands to other countries, this will send to wrong numbers.

---

## Positive Observations

1. **Offline-first architecture** is solid: local DB writes first, sync queue with exponential backoff, idempotent server operations.
2. **Stock validation** at checkout with real-time DB reads (`updateQuantityWithFreshStock`) is a good pattern.
3. **Idempotency keys** on all server-bound operations prevent duplicate transactions.
4. **Audit logging** for sensitive operations (price override, refunds, voids) with staff attribution.
5. **Manager PIN gate** for price overrides and refunds is properly implemented.
6. **Sync queue** with blocked/failed/pending states and automatic retry with backoff.
7. **Receipt generation** supports PDF, Bluetooth thermal printing, WhatsApp, and SMS — comprehensive.
8. **Split payment** and **credit sales** are well-implemented with proper validation.
9. **Barcode scanning** with variant disambiguation is thorough.
10. **Service variant picker** with auto-selection for single variants is good UX.

---

## Summary Table

| ID | Severity | Category | File | Line(s) |
|----|----------|----------|------|---------|
| C1 | Critical | Currency | `cart_controller.dart` | 40, 68 |
| C2 | Critical | Race Condition | `checkout_screen.dart` | 130-180 |
| C3 | Critical | Data Loss | `parked_sales_controller.dart` | 32-36 |
| C4 | Critical | Double-Charge | `checkout_screen.dart` | ~616 |
| H1 | High | API Design | `cart_controller.dart` | 36-42 |
| H2 | High | Race Condition | `cart_controller.dart` | 305-330 |
| H3 | High | Maintainability | `orders_controller.dart` | all |
| H4 | High | UX | `checkout_screen.dart` | ~1900 |
| H5 | High | Data Accuracy | `pos_refund_screen.dart` | ~194 |
| H6 | High | Error Handling | `order_details_screen.dart` | ~40 |
| M1 | Medium | Performance | `cart_controller.dart` | 68 |
| M2 | Medium | Code Quality | `cart_controller.dart` | 193-266 |
| M3 | Medium | Memory Leak | `checkout_screen.dart` | 70-76 |
| M4 | Medium | UX | `checkout_screen.dart` | ~1718 |
| M5 | Medium | Stability | `cart_controller.dart` | 244, 383 |
| M6 | Medium | UX | `orders_controller.dart` | 43 |
| M7 | Medium | Data Accuracy | `transactions_screen.dart` | ~290 |
| M8 | Medium | Multi-Device | `app_database.dart` | ~1010 |
| L1 | Low | API Usage | multiple | various |
| L2 | Low | Dead Code | `category_grid.dart` | all |
| L3 | Low | Data | `checkout_screen.dart` | ~2020 |
| L4 | Low | Data | `order_details_screen.dart` | ~260 |
| L5 | Low | Localization | `receipt_service.dart` | ~480 |
