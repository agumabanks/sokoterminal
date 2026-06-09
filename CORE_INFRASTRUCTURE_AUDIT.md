# Core Infrastructure Audit — Soko Seller Terminal

**Auditor:** Factory Droid  
**Date:** 2026-03-13  
**Scope:** `/var/www/soko/app/soko_seller_terminal/lib/src/core/`  
**Schema Version at time of audit:** 31

---

## Executive Summary

The core infrastructure is **well-architected for offline-first POS operation** with comprehensive sync, idempotency, and audit logging. However, the audit identified **several security gaps, missing resilience patterns, and potential reliability issues** that should be addressed before a wider production rollout.

**Critical findings:** 3  
**High severity findings:** 6  
**Medium severity findings:** 8  
**Low severity findings:** 5  

---

## 1. Network Layer — `api_client.dart`

### 1.1 ❌ CRITICAL — No Token Refresh Interceptor (401 Handling)

**File:** `lib/src/core/network/api_client.dart`, lines 27–46  
**Severity:** CRITICAL

The `onError` interceptor simply logs and forwards the error. There is **no automatic 401 handling** — no token refresh, no redirect to login, no session invalidation.

```dart
onError: (error, handler) {
  _logError(error);           // ← just logs
  return handler.next(error); // ← propagates raw error upstream
},
```

**Impact:** If the access token expires mid-session, every subsequent API call fails silently with 401. The user sees cryptic sync errors instead of being prompted to re-authenticate.

**Suggested Fix:**
```dart
onError: (error, handler) async {
  if (error.response?.statusCode == 401) {
    // Clear stale token
    await _secureStorage.deleteAccessToken();
    // Signal global auth state (e.g., via a stream or callback)
    _onAuthExpired?.call();
    // Optionally retry with fresh token if refresh endpoint exists
  }
  _logError(error);
  return handler.next(error);
},
```

### 1.2 ⚠️ HIGH — No Retry Interceptor for Transient Failures

**File:** `lib/src/core/network/api_client.dart`  
**Severity:** HIGH

There is no retry logic for transient network errors (timeouts, 502, 503, 504). The `dio_smart_retry` or equivalent pattern is absent. All retries are delegated to the sync queue, meaning **direct API calls from screens (e.g., login, registration) fail immediately** with no retry.

**Suggested Fix:** Add a retry interceptor (e.g., `dio_smart_retry`) for idempotent GET requests and operations with `Idempotency-Key` headers.

### 1.3 ✅ GOOD — Sensitive Data Redaction in Logs

**File:** `lib/src/core/network/api_client.dart`, lines 120–139  
**Severity:** Informational

The `_redact()` method correctly strips `password`, `pin`, `token`, `authorization`, `otp` from logged request/response bodies. Good practice.

### 1.4 ⚠️ MEDIUM — PrettyDioLogger May Leak Data in Release Builds

**File:** `lib/src/core/network/api_client.dart`, lines 50–56  
**Severity:** MEDIUM

PrettyDioLogger is gated on `config.logLevel != 'none'`, but `responseBody` is enabled when `logLevel == 'debug'`. If a production build is shipped with debug log level (misconfiguration), full response bodies including PII are printed to console/logcat.

**Suggested Fix:** Guard with `kDebugMode` as an additional check:
```dart
if (!kReleaseMode && config.logLevel != 'none') { ... }
```

---

## 2. Network Layer — `seller_api.dart`

### 2.1 ✅ GOOD — Comprehensive Idempotency Keys

**File:** `lib/src/core/network/seller_api.dart`  
Most mutating POST/PUT/PATCH endpoints accept `idempotencyKey` headers. This is correctly implemented for POS transactions, ledger entries, cash movements, expenses, shifts, customers, etc.

### 2.2 ⚠️ MEDIUM — Inconsistent HTTP Methods for Destructive Operations

**File:** `lib/src/core/network/seller_api.dart`  
**Severity:** MEDIUM

Several delete operations use `GET` instead of `DELETE`:

| Method | Line | Endpoint | Issue |
|--------|------|----------|-------|
| `deleteProduct()` | ~line 100 | `GET /v2/seller/product/delete/$productId` | GET for delete |
| `deleteCoupon()` | ~line 380 | `GET /v2/seller/coupon/delete/$couponId` | GET for delete |
| `deleteAuctionBid()` | ~line 395 | `GET /v2/seller/auction-product-bids/destroy/$bidId` | GET for delete |

**Impact:** GET requests can be retried by proxies/CDNs and are cached. Destructive operations via GET are a security risk (CSRF, accidental replays). This is likely a backend legacy issue, but the client should document it as tech debt.

### 2.3 ⚠️ MEDIUM — Registration Creates Raw Dio Instance Without Interceptors

**File:** `lib/src/core/network/seller_api.dart`, `registerSeller()` and `fetchSellerRegistrationPlans()`  
**Severity:** MEDIUM

The `registerSeller()` method creates a **new Dio instance** bypassing the main `ApiClient`. While intentional (no auth token needed for registration), this bypasses:
- Timeouts configured in `AppConfig`
- Any future global interceptors (e.g., retry, certificate pinning)

**Suggested Fix:** Create a shared `publicDio` factory method in `ApiClient` that reuses timeout config without auth interceptors.

### 2.4 ⚠️ LOW — Retry Heuristic for Schema Migration

**File:** `lib/src/core/network/seller_api.dart`, `registerSeller()`, line ~530  
**Severity:** LOW

The registration method catches `Unknown column 'latitude'` SQL errors from the server and retries without coordinates. This is a fragile coupling to backend error messages. If the backend changes the error format, this retry silently stops working.

---

## 3. Database — `app_database.dart`

### 3.1 ❌ CRITICAL — No `onUpgrade` Error Handling / Migration Rollback

**File:** `lib/src/core/db/app_database.dart`, lines ~450–620 (migration block)  
**Severity:** CRITICAL

The `onUpgrade` migration strategy runs a long chain of `if (from < N)` blocks. If **any single migration step fails** (e.g., `addColumn` throws because of a corrupt DB or disk full), the entire migration is abandoned in an **inconsistent state**. There is no:
- Try-catch around individual migration steps
- Rollback mechanism
- Schema version pinning on partial success

**Impact:** If a user's DB is in an inconsistent state between schema 15 and 16, the app will crash on every startup with no recovery path.

**Suggested Fix:**
1. Wrap each migration step in try-catch with logging to telemetry
2. Consider a "nuclear option" that drops and recreates the DB if migration fails (with data backup to sync queue)
3. At minimum, catch migration errors and surface them to the user with a "Reset local data" button

### 3.2 ⚠️ HIGH — No Database Encryption at Rest

**File:** `lib/src/core/db/app_database.dart`, `make()` method  
**Severity:** HIGH

```dart
static Future<AppDatabase> make() async {
  final dir = await getApplicationDocumentsDirectory();
  final file = File(p.join(dir.path, 'seller_terminal.db'));
  return AppDatabase._internal(NativeDatabase.createInBackground(file));
}
```

The SQLite database is stored as a **plain unencrypted file** on the device filesystem. This database contains:
- All transaction history (financial data)
- Customer PII (names, phones, emails)
- Staff PINs (stored in `Staff` table `pin` column)
- Business financial data (expenses, revenue)

**Impact:** Any app with root access, or a stolen/lost device, can read all business data.

**Suggested Fix:** Use `sqlcipher` via `drift`'s `encrypted_moor` / `sqlcipher_flutter_libs` to encrypt the database at rest. The encryption key can be stored in `SecureStorage`.

### 3.3 ⚠️ HIGH — Staff PINs Stored in Plaintext in DB

**File:** `lib/src/core/db/app_database.dart`, `Staff` table  
**Severity:** HIGH

```dart
class Staff extends Table {
  TextColumn get pin => text().nullable()();
  ...
}
```

Staff PINs are stored as plaintext in the local database. Combined with finding 3.2 (no DB encryption), any device compromise exposes all staff PINs.

**Suggested Fix:** Hash PINs with a proper one-way hash (bcrypt/argon2) before storage. Verification should compare hashes.

### 3.4 ⚠️ MEDIUM — Thread Safety: `createInBackground` Is Good

**File:** `lib/src/core/db/app_database.dart`, `make()`  
**Severity:** Informational (positive finding)

`NativeDatabase.createInBackground(file)` correctly uses Drift's background isolate pattern, which provides thread safety for concurrent reads/writes. No issues here.

### 3.5 ⚠️ LOW — Schema Version 27 Is a No-Op

**File:** `lib/src/core/db/app_database.dart`, migration block  
**Severity:** LOW

```dart
if (from < 27) {
  // Schema version 27 intentionally has no table mutation.
}
```

This is documented but wastes a version number. Not a bug, but indicates the migration strategy may benefit from a more disciplined versioning approach.

### 3.6 ⚠️ MEDIUM — `clearAllData()` Deletion Order May Fail

**File:** `lib/src/core/db/app_database.dart`, `clearAllData()`  
**Severity:** MEDIUM

The `clearAllData()` method deletes tables in a specific order to avoid FK violations, but `ExpenseCategories` table is not included in the deletion list. This means expense categories persist across logout/account-switch, potentially leaking data between sellers on the same device.

---

## 4. Secure Storage — `secure_storage.dart`

### 4.1 ⚠️ HIGH — Permanent Fallback to No-Op on First Error

**File:** `lib/src/core/storage/secure_storage.dart`, lines 8–14  
**Severity:** HIGH

```dart
bool _storageAvailable = true;

void _markUnavailable(Object error) {
  if (_storageAvailable) {
    _storageAvailable = false;
    debugPrint('[SecureStorage] disabled after backend error: $error');
  }
}
```

If `FlutterSecureStorage` throws **any** error (even a transient one like a brief Keystore lock), the entire secure storage is **permanently disabled** for the app session. All subsequent reads return `null` and writes become no-ops. This means:
- Access token reads return null → all API calls fail (no auth header)
- Token writes silently drop → login appears to succeed but token is lost
- No recovery without app restart

**Impact:** A single transient Keystore error disables authentication for the entire session.

**Suggested Fix:**
1. Implement per-operation retry (2-3 attempts with backoff)
2. Only disable after N consecutive failures
3. Add a `resetAvailability()` method and periodically re-check
4. Log to telemetry when storage becomes unavailable

### 4.2 ✅ GOOD — Proper Key Separation

Storage keys are well-organized with clear naming (`access_token`, `pos_session_token`, `seller_quick_pin`, etc.). POS session metadata is stored separately with proper cleanup via `deletePosSessionMeta()`.

---

## 5. Sync Service — `sync_service.dart`

### 5.1 ✅ GOOD — Robust Sync Queue with Backoff and Blocking

**File:** `lib/src/core/sync/sync_service.dart`  
The sync service implements:
- Exponential backoff (5s base, 5min max, capped at 16 retries)
- Blocked state for permanent failures (4xx except 408)
- Conflict detection for 409 responses
- Pump deduplication (`_isPumping` + `_pumpQueued`)

### 5.2 ⚠️ HIGH — StreamController Never Closed (Memory Leak)

**File:** `lib/src/core/sync/sync_service.dart`, line 44  
**Severity:** HIGH

```dart
final _syncStatusController = StreamController<String>.broadcast();
```

The `dispose()` method cancels the connectivity subscription and retry timer, but **never closes `_syncStatusController`**. Since this is a broadcast stream, listeners are not automatically cleaned up.

```dart
Future<void> dispose() async {
  await _connectivitySub?.cancel();
  _retryTimer?.cancel();
  // Missing: await _syncStatusController.close();
}
```

**Impact:** Memory leak in long-running sessions. The StreamController and its listener list grow indefinitely.

**Suggested Fix:** Add `await _syncStatusController.close();` to `dispose()`.

### 5.3 ⚠️ MEDIUM — Sync Conflict Resolution Is "Server Wins"

**File:** `lib/src/core/sync/sync_service.dart`, `_pullPosDeltaInternal()`  
**Severity:** MEDIUM

The pull sync uses `insertOnConflictUpdate` for all entities (products, customers, ledger entries, etc.). This means **server data always overwrites local data**, even if local changes are more recent. There is no:
- Conflict detection for concurrent edits
- Merge strategy for overlapping changes
- User notification when local changes are overwritten

For a POS system where offline edits are common, this can lead to silent data loss (e.g., a locally-edited product name gets overwritten by a stale server version).

**Suggested Fix:** Compare `updatedAt` timestamps before overwriting. If local `updatedAt > server updatedAt` and `synced == false`, prefer local data and re-enqueue for push.

### 5.4 ⚠️ MEDIUM — `forceFullResync()` Uses Raw SQL

**File:** `lib/src/core/sync/sync_service.dart`, `forceFullResync()`  
**Severity:** MEDIUM

```dart
await db.customStatement('DELETE FROM sync_cursors');
```

This bypasses Drift's type-safe API. If the table name changes, this silently fails.

**Suggested Fix:** Use Drift's API: `await db.delete(db.syncCursors).go();`

### 5.5 ⚠️ LOW — Phone Normalization Assumes Uganda Country Code

**File:** `lib/src/core/sync/sync_service.dart`, `_normalizePhone()`  
**Severity:** LOW

```dart
String? _normalizePhone(String input) {
  final normalized = normalizeUgPhone(input);
  if (normalized.isNotEmpty) return '+$normalized';
  return null;
}
```

The phone normalization is Uganda-specific (`normalizeUgPhone`). If the app expands to other markets, all contact phone numbers from non-Uganda users will fail normalization and be dropped.

---

## 6. Security

### 6.1 ❌ CRITICAL — No Certificate Pinning

**Files:** All network files  
**Severity:** CRITICAL

There is **no certificate pinning** anywhere in the codebase. The `ApiClient` uses default Dio TLS validation, which trusts the system certificate store. This makes the app vulnerable to:
- Man-in-the-middle attacks via compromised CAs
- Corporate proxy interception
- Government-level traffic inspection (relevant for East African markets)

**Suggested Fix:** Implement certificate pinning using `dio_http2_adapter` or `SecurityContext` with pinned certificates for `soko24.co`.

### 6.2 ⚠️ HIGH — FCM Token Logged to Console in Plaintext

**File:** `lib/src/core/firebase/fcm_service.dart`, line 33  
**Severity:** HIGH

```dart
_token = await _messaging.getToken();
debugPrint('[FCM] Token: $_token');
```

The FCM device token is printed to the debug console. In release builds, `debugPrint` still outputs to logcat on Android. An attacker with ADB access can capture FCM tokens and use them to send targeted push notifications.

**Suggested Fix:** Remove or gate behind `kDebugMode`:
```dart
if (kDebugMode) debugPrint('[FCM] Token obtained');
```

### 6.3 ⚠️ MEDIUM — Seller Profile Stored in SecureStorage as Plain JSON

**File:** `lib/src/core/sync/sync_service.dart`, end of `_pullPosDeltaInternal()`  
**Severity:** MEDIUM

```dart
await secureStorage.write(
  key: 'seller_profile',
  value: jsonEncode({
    'id': pull.sellerProfile!.id,
    'name': pull.sellerProfile!.name,
    'email': pull.sellerProfile!.email,
    'phone': pull.sellerProfile!.phone,
    'business_name': pull.sellerProfile!.businessName,
  }),
);
```

PII (name, email, phone) is stored in SecureStorage. This is acceptable IF SecureStorage works (see finding 4.1), but if it degrades to no-op mode, this data is lost silently.

---

## 7. Provider Architecture — `app_providers.dart`

### 7.1 ✅ GOOD — Override Pattern for Dependency Injection

**File:** `lib/src/core/app_providers.dart`  
All core providers (`appConfigProvider`, `secureStorageProvider`, `appDatabaseProvider`) use the `throw UnimplementedError` pattern, requiring override in `main.dart`. This is the correct Riverpod pattern for late-initialized singletons.

### 7.2 ⚠️ MEDIUM — No `keepAlive` or Lifecycle Management for Database Provider

**File:** `lib/src/core/app_providers.dart`  
**Severity:** MEDIUM

The `appDatabaseProvider` is a simple `Provider<AppDatabase>`. If the provider tree is rebuilt (e.g., after a hot restart in development), the database connection is re-created without closing the old one. In production this is unlikely but in edge cases (e.g., provider scope disposal), the old connection leaks.

### 7.3 ⚠️ LOW — Missing `dispose` for SyncService Provider

**File:** `lib/src/core/sync/sync_service.dart`  
**Severity:** LOW

```dart
final syncServiceProvider = Provider<SyncService>((ref) {
  final db = ref.watch(appDatabaseProvider);
  final api = ref.watch(sellerApiProvider);
  final secureStorage = ref.watch(secureStorageProvider);
  return SyncService(db: db, sellerApi: api, secureStorage: secureStorage);
});
```

The provider does not call `ref.onDispose(() => syncService.dispose())`. The `SyncService.dispose()` method exists but is never invoked, meaning the connectivity subscription and retry timer run indefinitely.

**Suggested Fix:**
```dart
final syncServiceProvider = Provider<SyncService>((ref) {
  final service = SyncService(db: db, sellerApi: api, secureStorage: secureStorage);
  ref.onDispose(() => service.dispose());
  return service;
});
```

---

## 8. Config — `app_config.dart`

### 8.1 ✅ GOOD — Environment-Based Configuration

**File:** `lib/src/core/config/app_config.dart`  
Config supports compile-time overrides (`String.fromEnvironment`) and runtime env map fallbacks. Default API URL is `https://soko24.co/api/` (correct production domain).

### 8.2 ⚠️ LOW — No Send Timeout Configured

**File:** `lib/src/core/config/app_config.dart`  
**Severity:** LOW

Only `connectTimeout` and `receiveTimeout` are configured. There is no `sendTimeout` for upload operations (product images, file uploads). Large file uploads could hang indefinitely.

---

## 9. Theme — `design_tokens.dart` / `app_theme.dart`

### 9.1 ✅ GOOD — Well-Structured Design System

Strict 8pt grid, 3 font sizes, 3 grays. Consistent across the app. No issues found.

---

## 10. Firebase Services

### 10.1 ⚠️ MEDIUM — FCM Service Has Unimplemented TODO Handlers

**File:** `lib/src/core/firebase/fcm_service.dart`, lines 36, 43, 49  
**Severity:** MEDIUM

```dart
// TODO: Send new token to backend
// TODO: Show local notification or update UI
// TODO: Navigate to relevant screen based on message.data
```

Three TODO comments indicate incomplete push notification handling. Token refresh doesn't update the backend, foreground messages are ignored, and notification taps don't navigate.

### 10.2 ✅ GOOD — Crashlytics Properly Disabled in Debug Mode

**File:** `lib/src/core/firebase/crashlytics_service.dart`  
`setCrashlyticsCollectionEnabled(!kDebugMode)` — correct pattern.

---

## 11. Legacy / Domain References

### 11.1 ✅ No `soko.sanaa.ug` References Found

Grep search across the entire `lib/` directory returned **zero matches** for `soko.sanaa.ug`. The codebase has been properly migrated to `soko24.co`.

### 11.2 ⚠️ LOW — Firebase Project Still Named "sanaaos"

**File:** `lib/firebase_options.dart`, lines 47, 57, 65, 76, 87  
**Severity:** LOW (cosmetic)

Firebase project ID is `sanaaos` with storage bucket `sanaaos.firebasestorage.app`. This is a legacy naming issue but functionally harmless — changing it would require Firebase project migration.

---

## 12. RBAC — `rbac_provider.dart`

### 12.1 ⚠️ MEDIUM — Local PIN Check Without Rate Limiting

**File:** `lib/src/core/auth/rbac_provider.dart`, `loginWithPin()` / `requestManagerOverride()`  
**Severity:** MEDIUM

Staff PIN verification queries the local DB with no rate limiting. An attacker with physical device access could brute-force short PINs (typically 4-6 digits) rapidly.

**Suggested Fix:** Implement exponential lockout after N failed attempts (e.g., 3 failed → 30s lockout, 5 failed → 5min lockout).

---

## Summary Table

| # | Finding | File | Severity | Category |
|---|---------|------|----------|----------|
| 1.1 | No 401 token refresh interceptor | api_client.dart | 🔴 CRITICAL | Auth |
| 3.1 | No migration error handling/rollback | app_database.dart | 🔴 CRITICAL | Database |
| 6.1 | No certificate pinning | api_client.dart | 🔴 CRITICAL | Security |
| 1.2 | No retry interceptor for transient failures | api_client.dart | 🟠 HIGH | Network |
| 3.2 | No database encryption at rest | app_database.dart | 🟠 HIGH | Security |
| 3.3 | Staff PINs stored in plaintext | app_database.dart | 🟠 HIGH | Security |
| 4.1 | SecureStorage permanently disabled on first error | secure_storage.dart | 🟠 HIGH | Storage |
| 5.2 | StreamController never closed (memory leak) | sync_service.dart | 🟠 HIGH | Memory |
| 6.2 | FCM token logged to console | fcm_service.dart | 🟠 HIGH | Security |
| 1.4 | PrettyDioLogger may leak data in release | api_client.dart | 🟡 MEDIUM | Security |
| 2.2 | GET used for delete operations | seller_api.dart | 🟡 MEDIUM | API Design |
| 2.3 | Registration bypasses ApiClient config | seller_api.dart | 🟡 MEDIUM | Network |
| 3.6 | clearAllData() misses ExpenseCategories | app_database.dart | 🟡 MEDIUM | Database |
| 5.3 | Server-wins conflict resolution | sync_service.dart | 🟡 MEDIUM | Sync |
| 5.4 | Raw SQL in forceFullResync | sync_service.dart | 🟡 MEDIUM | Code Quality |
| 7.2 | No lifecycle management for DB provider | app_providers.dart | 🟡 MEDIUM | Architecture |
| 10.1 | FCM TODO handlers not implemented | fcm_service.dart | 🟡 MEDIUM | Notifications |
| 12.1 | No rate limiting on PIN checks | rbac_provider.dart | 🟡 MEDIUM | Security |
| 2.4 | Fragile server error message parsing | seller_api.dart | 🟢 LOW | Robustness |
| 3.5 | No-op schema version 27 | app_database.dart | 🟢 LOW | Code Quality |
| 5.5 | Uganda-only phone normalization | sync_service.dart | 🟢 LOW | Localization |
| 7.3 | Missing dispose for SyncService provider | sync_service.dart | 🟢 LOW | Memory |
| 8.2 | No sendTimeout configured | app_config.dart | 🟢 LOW | Network |

---

## Recommended Priority Actions

1. **Immediate (P0):** Add 401 interceptor to `ApiClient` with session expiry handling
2. **Immediate (P0):** Wrap DB migration steps in try-catch with telemetry reporting
3. **Short-term (P1):** Implement certificate pinning for `soko24.co`
4. **Short-term (P1):** Fix SecureStorage resilience (retry + gradual degradation)
5. **Short-term (P1):** Close StreamController in SyncService.dispose()
6. **Short-term (P1):** Add `ref.onDispose` to SyncService provider
7. **Medium-term (P2):** Encrypt database at rest with sqlcipher
8. **Medium-term (P2):** Hash staff PINs in local DB
9. **Medium-term (P2):** Remove FCM token from logs in release builds
10. **Medium-term (P2):** Add PIN brute-force rate limiting
