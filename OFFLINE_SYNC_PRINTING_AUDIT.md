# Offline Sync & Printing Audit Report

**Date:** 2026-03-13  
**App:** Soko Seller Terminal (Flutter)  
**Path:** `/var/www/soko/app/soko_seller_terminal/`  
**Schema Version:** 31  

---

## 1. Offline Mode

### Current State: ✅ WORKING — Robust offline-first architecture

The app is built on an **offline-first** design using Drift (SQLite) as the local database and a `SyncOps` outbox queue for all mutations.

#### How Offline Sales Work

1. **Sales are created locally first** — `CartController.checkout()` (`lib/src/features/checkout/cart_controller.dart`, lines 354–470) writes a `LedgerEntry` + `LedgerLines` + `Payments` directly to the local DB without any network call.
2. **Stock is updated immediately** — `recordInventoryMovement()` decrements local stock right after the sale (line 440–447).
3. **Sync op is enqueued** — A `ledger_push` operation is added to the `SyncOps` outbox table via `syncService.enqueue()` (line 449).
4. **Async sync fires** — `syncService.syncNow()` is called with `unawaited()` (line 468), meaning the UI does not block on network.

#### Queue Mechanism — SyncOps Table

- **Table:** `SyncOps` (`lib/src/core/db/app_database.dart`, lines 202–211)
- **Fields:** `id` (autoIncrement), `opType`, `payload` (JSON), `status` (pending/synced/blocked), `retryCount`, `lastError`, `createdAt`, `lastTriedAt`
- **Enqueue:** `db.enqueueSync(type, jsonPayload)` (line 1510)
- **Query pending:** `db.pendingSyncOps()` returns all `status == 'pending'` ops ordered by `createdAt ASC` (line 1516)

#### Connectivity Detection

- **Provider:** `connectivityProvider` in `lib/src/core/app_providers.dart` (line 63) — `StreamProvider` wrapping `Connectivity().onConnectivityChanged`
- **UI Banner:** `ConnectivityBanner` widget (`lib/src/widgets/connectivity_banner.dart`) shows "You are offline. Changes will sync when connected." when `ConnectivityResult.none` detected
- **Sync Status Bar:** `SyncStatusBar` (`lib/src/widgets/sync_status_bar.dart`) shows pending count, syncing animation, or offline state

#### Key Files
| File | Purpose |
|---|---|
| `lib/src/core/db/app_database.dart` | All 39 tables, CRUD, queue methods |
| `lib/src/core/sync/sync_service.dart` | Push/pull engine, connectivity listener, retry logic |
| `lib/src/core/sync/sync_status_provider.dart` | UI state for sync progress |
| `lib/src/features/checkout/cart_controller.dart` | Offline sale creation |
| `lib/src/widgets/connectivity_banner.dart` | Offline UI indicator |

#### Gaps / Issues
- **No offline PIN login** — `AuthController.loginWithQuickPin()` (`lib/src/features/auth/auth_controller.dart`, line 162) only verifies PINs against the backend. If device is offline and token has expired, user cannot log in. Comment at line 185 acknowledges this: _"if we want to support offline PIN login later, we'd check _storage here"_.
- **`isOffline` flag on `Transactions` table is defined but not actively used** — The legacy `Transactions` table has `isOffline` (line 162) but the primary flow uses the newer `LedgerEntries` table which has `synced` instead.

---

## 2. Auto-Sync

### Current State: ✅ WORKING — Full auto-sync with connectivity listener + periodic timer

#### Connectivity Listener
`SyncService.start()` (`lib/src/core/sync/sync_service.dart`, line 50):
```dart
_connectivitySub ??= Connectivity().onConnectivityChanged.listen(
  (_) => _pump(),
);
```
**Every connectivity change** triggers the `_pump()` method which:
1. Checks if actually online via `Connectivity().checkConnectivity()`
2. Fetches all pending `SyncOps` from DB
3. Dispatches each op to the correct API endpoint
4. After pushing, pulls server deltas via `pullPosDelta()`
5. Also pulls marketplace orders and service bookings (best-effort)

#### Periodic Retry Timer
```dart
_retryTimer ??= Timer.periodic(const Duration(minutes: 5), (_) => _pump());
```
Every **5 minutes**, the pump runs regardless of connectivity changes.

#### Exponential Backoff
`_backoff()` (line 163): Base 5s, doubles each retry, max 5 minutes. `_isDue()` checks if enough time has passed since `lastTriedAt`.

#### Blocking vs Retry Logic
- **4xx errors (except 408, 409-race):** Marked as `blocked` — won't retry automatically
- **5xx errors, timeouts, network errors:** Marked as `failed` — will retry with backoff
- **409 with "still being processed" or "sync the original sale first":** Not blocked, retried

#### What Happens on Reconnect
1. Connectivity change fires → `_pump()` called
2. All pending ops dispatched in FIFO order
3. After push, `pullPosDelta()` reconciles server state into local DB
4. Sync cursors (`SyncCursors` table) track `lastPulledAt` per entity type
5. `syncNow()` also resets blocked/failed ops to force immediate retry

#### Key Files
| File | Lines | Detail |
|---|---|---|
| `sync_service.dart` | 50–56 | `start()` with connectivity sub + timer |
| `sync_service.dart` | 113–200 | `_pump()` — the core sync engine |
| `sync_service.dart` | 85–100 | `syncNow()` — manual trigger, resets backoff |
| `sync_service.dart` | 163–170 | Exponential backoff calculation |

#### Gaps / Issues
- **No "push-only" mode** — The pump always does push AND pull. If pull fails, it's silently swallowed (`catch (_) {}`). This is correct behavior.
- **`_pumpQueued` coalescing** — If a connectivity event fires while pumping, it sets `_pumpQueued = true` and re-pumps after. This prevents stacking but could miss rapid reconnects. Acceptable tradeoff.
- **Print queue is NOT triggered by connectivity changes** — Only the sync queue is. The `PrintQueueService` has its own independent 25-second timer.

---

## 3. Printing

### Current State: ✅ WORKING — Bluetooth thermal printing with print queue and retry

#### Supported Protocols
1. **Bluetooth Thermal (ESC/POS)** via `blue_thermal_printer` package — Primary protocol for POS receipts
2. **PDF Generation** via `pdf` + `printing` packages — For sharing/email/system print dialog
3. **WhatsApp Share** — Text-based receipt via `url_launcher` + `share_plus`
4. **PDF Share** — Share PDF receipt via `Printing.sharePdf()`

#### Print Queue (`PrintQueueService`)
**File:** `lib/src/features/receipts/print_queue_service.dart`

- **Table:** `PrintJobs` (`app_database.dart`, lines 212–222) — `id`, `jobType`, `referenceId` (ledger entry ID), `status` (pending/printed/cancelled), `retryCount`, `lastError`, `printedAt`
- **Enqueue:** `enqueueReceipt(entryId)` → inserts into `PrintJobs` with `status: pending`, deduplicates (checks for existing pending job for same entry)
- **Pump timer:** `Timer.periodic(Duration(seconds: 25))` — checks pending jobs every 25 seconds
- **Retry with backoff:** Same exponential pattern as sync — base 3s, max 2 min, doubles each retry
- **On failure:** `markPrintJobFailed()` increments `retryCount`, saves error
- **On success:** `markPrintJobPrinted()` sets `printedAt` timestamp

#### Bluetooth Printing Flow
1. `_resolvePreferredDevice()` — Looks up saved Bluetooth address from `SharedPreferences`
2. Connects if not already connected
3. Prints using ESC/POS commands: `printCustom()`, `printLeftRight()`, `printQRcode()`, `paperCut()`
4. **Compatibility mode** — Skips QR code and paper cut for cheaper printers

#### Can It Print Offline-Created Receipts?
**YES** — `printBluetooth(entryId)` fetches the `LedgerEntryBundle` from local DB, not from the server. Since offline sales are saved locally first, they can be printed immediately regardless of internet connectivity.

#### Certified Printers (from `print_diagnostics_screen.dart`)
- XPRINTER (XP-P323B / XP-58)
- ZJ-58 / ZJ-5890
- MTP-II / MTP-2
- SPRT
- Gprinter

#### Key Files
| File | Purpose |
|---|---|
| `lib/src/features/receipts/print_queue_service.dart` | Print queue pump, Bluetooth connection, retry |
| `lib/src/features/receipts/receipt_service.dart` | PDF generation, Bluetooth print commands, WhatsApp/share |
| `lib/src/features/receipts/receipt_providers.dart` | Riverpod providers for receipt + print services |
| `lib/src/features/settings/print_diagnostics_screen.dart` | Bluetooth diagnostics, permission checks, test print |
| `lib/src/features/settings/print_queue_screen.dart` | UI for viewing/managing print jobs |
| `lib/src/core/db/app_database.dart` (PrintJobs table) | Print job persistence |

#### Gaps / Issues
- **No max retry limit** — Print jobs never stop retrying. `retryCount` increases indefinitely. Should cap at ~10 retries and auto-cancel.
- **Print queue not triggered by Bluetooth state changes** — Only runs on a 25-second timer. If user pairs a printer, they must wait up to 25 seconds for queued jobs to start printing, or manually tap a job.
- **No Wi-Fi/Network printer support** — Only Bluetooth thermal. No support for USB, Wi-Fi, or network printers (e.g., Star Micronics TSP100).
- **No receipt preview before printing** — User cannot preview the thermal layout before sending to printer.

---

## 4. Expense Recording

### Current State: ✅ WORKING — Full offline-first expense tracking with sync

#### Storage
- **Table:** `Expenses` (`app_database.dart`, lines 315–330) — `id` (UUID), `remoteId`, `outletId`, `staffId`, `method`, `category`, `supplierId`, `amount`, `note`, `occurredAt`, `synced`, `updatedAt`
- **Table:** `ExpenseCategories` (`app_database.dart`, lines 432–438) — `id` (auto-increment, doubles as remote ID), `name`, `type`, `isActive`

#### Recording Flow (`ExpensesScreen._showAddExpense`)
**File:** `lib/src/features/expenses/expenses_screen.dart`, lines 108–167

1. Requires **manager PIN approval** via `requireManagerPin()` 
2. Shows bottom sheet form with: payment method (cash/mobile_money/bank/card/other), category, amount, supplier (if category=supplier), note
3. Calls `db.recordExpense()` which:
   - Inserts into `Expenses` table with `synced: false`
   - Enqueues `expense_push` sync op with idempotency key
   - Records audit log
4. If method is `cash`, also records a `CashMovement` (withdrawal) linked to the expense
5. Triggers `syncNow()`

#### Sync
- **Push:** `expense_push` handler in `sync_service.dart` (lines 612–648) sends to `sellerApi.pushExpense()`, marks synced with remote ID on success
- **Pull:** `pullPosDelta()` pulls expenses from server (line ~2470), upserts into local DB with `synced: true`
- **Category sync:** Categories are fetched separately via `sellerApi.fetchExpenseCategories()` during pull

#### Category Management
- Users can **create new categories** from the expense form via `_showAddCategoryDialog()` (line 345+)
- New categories get a **temporary negative ID** to avoid collision with server IDs
- Enqueued as `expense_category_create` sync op
- On pull, server categories overwrite local temporary ones via `deleteLocalTemporaryCategory(name)` + upsert

#### Key Files
| File | Purpose |
|---|---|
| `lib/src/features/expenses/expenses_screen.dart` | Full expense UI + form |
| `lib/src/core/db/app_database.dart` (Expenses, ExpenseCategories) | Storage |
| `lib/src/core/sync/sync_service.dart` (expense_push, expense_category_create) | Sync dispatch |

#### Gaps / Issues
- **ExpenseCategories ID collision risk** — The `id` column is `autoIncrement` but also used as the remote server ID (comment says "remote id"). When a local category is created with a negative temporary ID and the server returns a different positive ID, the `deleteLocalTemporaryCategory(name)` + upsert handles dedup by name. This works but is fragile — if two categories have the same name on different devices, they could collide.
- **No expense editing** — Once recorded, expenses cannot be edited or deleted from the UI. Only creation is supported.
- **No expense receipts/attachments** — Cannot attach photos of receipts/invoices to expense records.

---

## 5. Sales Tracker / Transactions

### Current State: ✅ WORKING — Daily totals, date filtering, shift summaries all operational

#### Transaction Views

**TransactionsScreen** (`lib/src/features/transactions/transactions_screen.dart`):
- **Two tabs:** POS Sales (local `LedgerEntries`) and Online Orders (cached from server API)
- **Date filtering:** Today, This Week, This Month, All Time, Custom date range
- **Grouping:** POS transactions grouped by date with per-group total and count
- **Sync indicator:** Each transaction shows cloud_done (synced) or cloud_upload (pending) icon
- **Refund/void handling:** Reversals shown with negative amounts and error coloring

**DashboardScreen** (`lib/src/features/dashboard/dashboard_screen.dart`):
- `dashboardMetricsProvider` computes: gross sales, net sales (minus refunds), transaction count, average sale, today's transaction count
- All computed from local `LedgerEntries` — works fully offline

**AnalyticsController** (`lib/src/features/analytics/analytics_controller.dart`):
- 7-day daily sales chart from local `ledgerEntries`
- Top 5 products by revenue
- Total inventory value
- All computed locally — offline-safe

#### Shift Summaries

**ShiftsScreen** (`lib/src/features/shifts/shifts_screen.dart`):
- Shows open shift with: opening float, cash sales since open, net cash movements
- **Expected cash** = opening + cash sales + net movements
- Cash sales computed via `db.computeCashSalesSince()` — joins `Payments` with `LedgerEntries` where `method == 'cash'`
- Cash movements computed via `db.computeCashMovementsNetSince()`
- All from local DB — **fully offline**

#### Do They Account for Offline Sales?
**YES** — All analytics, daily totals, and shift summaries query the local `LedgerEntries` table directly. Since offline sales are written to this table immediately during checkout, they appear in all reports and summaries in real-time, regardless of sync status.

#### Key Files
| File | Purpose |
|---|---|
| `lib/src/features/transactions/transactions_screen.dart` | Transaction list with filters |
| `lib/src/features/dashboard/dashboard_screen.dart` | Dashboard metrics |
| `lib/src/features/analytics/analytics_controller.dart` | 7-day sales, top products |
| `lib/src/features/shifts/shifts_screen.dart` | Shift status, cash tracking |

#### Gaps / Issues
- **No export to CSV/PDF from transactions screen** — There's an `ExportScreen` (`lib/src/features/settings/export_screen.dart`) but it's separate from the transactions view.
- **DashboardMetrics uses ALL entries, not just today** — `dashboardMetricsProvider` computes gross/net from all-time ledger entries, not filtered by date. The `todayTransactions` count is filtered though.
- **No profit calculation** — Items have a `cost` field in the DB but no margin/profit analytics are computed.

---

## 6. Logout Flow

### Current State: ✅ WORKING — Full data wipe on logout, but no lock-screen option

#### What Happens on Logout
**File:** `lib/src/features/auth/auth_controller.dart`, `logout()` method (lines 217–230):

```dart
Future<void> logout() async {
  _refreshTimer?.cancel();
  final db = ref.read(appDatabaseProvider);
  await db.clearAllData();           // ← Wipes ALL 39 tables
  await _storage.clearAll();         // ← Clears secure storage (tokens, keys)
  final prefs = ref.read(sharedPreferencesProvider);
  await prefs.clear();               // ← Clears shared preferences
  state = AuthState.unauthenticated;
}
```

#### `clearAllData()` Wipes These Tables (in dependency order):
`packageRedemptions` → `customerPackages` → `servicePackages` → `customerMemberships` → `localBookings` → `quotationLines` → `quotations` → `serviceVariants` → `auditLogs` → `shifts` → `expenses` → `cashMovements` → `payments` → `ledgerLines` → `ledgerEntries` → `printJobs` → `stockAlerts` → `inventoryLogs` → `cachedServiceBookings` → `cachedOrders` → `syncCursors` → `appSettings` → `syncOps` → `receipts` → `transactionLines` → `transactions` → `itemStocks` → `items` → `services` → `deviceContacts` → `customers` → `staff` → `roles` → `businessProfiles` → `outlets` → `suppliers` → `expenseCategories` → `receiptTemplates` → `quotationTemplates`

#### Login Also Clears Data
Both `login()` (line 97) and `loginWithQuickPin()` (line 176) call `db.clearAllData()` BEFORE setting the new token. This ensures data isolation between sellers.

#### Lock Screen vs Full Logout
- **POS Session (Staff PIN):** `PosSessionController` (`lib/src/core/auth/pos_session_controller.dart`) provides a staff-level session with `end()` method that only clears the POS session token — does NOT clear business data. This acts as a **soft lock**.
- **Full Logout:** `AuthController.logout()` — complete data wipe, returns to login screen.
- **No explicit lock-screen UI** — There's no "Lock Terminal" button that keeps the seller logged in but requires a PIN to resume. The POS session PIN entry serves a similar purpose but is designed for staff switching, not screen locking.

#### Key Files
| File | Lines | Purpose |
|---|---|---|
| `auth_controller.dart` | 217–230 | Full logout with data wipe |
| `auth_controller.dart` | 85–100, 176 | Login clears previous data |
| `pos_session_controller.dart` | 215–225 | `end()` — soft session close |
| `app_database.dart` | `clearAllData()` | Cascade delete all 39 tables |

#### Gaps / Issues
- **No lock-screen feature** — No way to lock the terminal and require a PIN to resume without doing a full logout. This is important for POS devices left unattended.
- **Unsynced data lost on logout** — If there are pending `SyncOps` when the user logs out, `clearAllData()` destroys them. There's no warning dialog like _"You have 5 unsynced transactions. Logout anyway?"_
- **No confirmation dialog** — The logout action appears to execute immediately without asking "Are you sure?"
- **`clearAll()` on SecureStorage** removes quick-PIN data — After logout, the user loses their saved quick login PIN and must re-enter full credentials.

---

## Summary Matrix

| Area | Status | Offline-Safe? | Auto-Sync? | Key Gap |
|---|---|---|---|---|
| **Offline Sales** | ✅ Working | Yes | Yes | No offline PIN login |
| **Sync Queue** | ✅ Working | N/A | Yes (connectivity + 5min timer) | No max retry cap on blocked ops |
| **Printing** | ✅ Working | Yes (local data) | Timer-based (25s) | No max retry limit; BT only |
| **Expenses** | ✅ Working | Yes | Yes | No edit/delete; ID collision risk |
| **Sales Tracker** | ✅ Working | Yes (local queries) | N/A | No profit analytics |
| **Logout** | ✅ Working | N/A | N/A | No lock screen; unsynced data lost silently |

---

## Priority Recommendations

### Must Fix (Data Loss Risk)
1. **Warn before logout with pending sync ops** — Show count of unsynced items and require confirmation
2. **Cap print job retries** — After 10 failures, auto-cancel to prevent infinite retry loops

### Should Fix (UX)
3. **Add lock-screen mode** — Lock terminal with staff PIN, keep data intact
4. **Add offline PIN login** — Cache hashed PIN locally for offline authentication
5. **Trigger print queue on Bluetooth state change** — Don't wait 25 seconds

### Nice to Have
6. **Expense editing/deletion** — Allow corrections within same shift
7. **Profit margin analytics** — Use the existing `cost` field on Items
8. **Network printer support** — Add Wi-Fi/USB printing via `esc_pos_printer` or similar
