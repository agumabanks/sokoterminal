# Staff Roles & Catalog Audit — Soko Seller Terminal

**Date**: 2026-03-13  
**App**: `/var/www/soko/app/soko_seller_terminal/`

---

## 1. Staff / Cashier Accounts & Role Management

### 1.1 Two-Tier Login Architecture

The app has **two distinct login paths**:

| Login Type | Screen | Endpoint | Token Storage |
|---|---|---|---|
| **Owner/Seller login** | `lib/src/features/auth/login_screen.dart` | `POST /v2/auth/login` | `secureStorage.writeAccessToken()` |
| **Staff login** | `lib/src/features/auth/staff_login_screen.dart` | `POST /v2/seller/pos/staff/login` | Same `writeAccessToken()` + stores `login_type=staff`, `staff_id`, `staff_name`, `staff_phone`, `staff_shop_id` in secure storage |

**Owner login flow** (L:1–452 of `login_screen.dart`):
- Phone-first → backend check (`/v2/seller/pos/auth/check`) → returns `has_pin`, `has_password`, `name`
- Authenticates via password (`/v2/auth/login`) or 6-digit PIN (`/v2/seller/pos/pin/verify`)
- Mandatory PIN setup after first password login if no PIN exists
- Navigates to `/home/checkout` on success

**Staff login flow** (L:1–268 of `staff_login_screen.dart`):
- Simple phone + 6-digit PIN form
- Calls `POST /v2/seller/pos/staff/login` → receives `token`, `staff` (with `id`, `name`, `shop_id`)
- On shop switch (different `shop_id`), clears all local DB tables
- Stores `login_type=staff` in secure storage
- Navigates to `/home/checkout` on success

### 1.2 POS Session Layer (In-App Staff Switch)

**File**: `lib/src/core/auth/pos_session_controller.dart`

A second auth layer runs *inside* the app for POS shift-based staff switching:

- **State**: `PosSessionState` with `token`, `staffId`, `staffName`, `staffRole` (cashier | manager), `expiresAt`
- **Key properties**: `isActive` (has token), `isManager` (role == 'manager')
- **Login**: `startWithPin(pin, {requiredRole?})` → `POST /v2/seller/pos/sessions/start`
  - Optional `requiredRole` parameter for gating actions to manager-only
- **Logout**: `end()` → `POST /v2/seller/pos/sessions/end`
- **Status check**: `load()` → `GET /v2/seller/pos/sessions/me`
- **POS Login Screen**: `lib/src/features/auth/pos_login_screen.dart` — PIN entry screen with "Continue offline (limited)" fallback

### 1.3 RBAC System

**File**: `lib/src/core/auth/rbac_provider.dart`

**Roles** (`UserRole` enum): `cashier`, `manager`

**Permissions** (`Permission` enum):
| Permission | Description |
|---|---|
| `refund` | Process refunds |
| `voidSale` | Void a sale |
| `priceOverride` | Override item price |
| `viewReports` | View reports |
| `manageStaff` | Manage staff members |
| `manageSettings` | Change settings |
| `adjustInventory` | Stock adjustments |

**Authorization logic** (`RbacState.can(permission)`):
- **Manager**: Can do everything (returns `true` for all permissions)
- **Cashier**: Only granted permissions from their `roles` record (`canRefund`, `canVoid`, `canPriceOverride`)

**Manager PIN Gate Widget** (`lib/src/widgets/manager_pin_gate.dart`):
- `ManagerPinGate` widget wraps an action and prompts for manager PIN if current session lacks the required `Permission`
- `checkPermissionWithPin()` helper function for imperative use
- Calls `rbacController.requestManagerOverride(pin)` which validates PIN against local DB staff table

**Note**: `ManagerPinGate` is **not currently used** in any feature screen. A grep for `ManagerPinGate` and `checkPermissionWithPin` in the features directory returned **zero matches**. The RBAC system is fully implemented but **not wired into the UI yet**.

### 1.4 Staff Management Screen

**File**: `lib/src/features/settings/staff_management_screen.dart`

Features:
- **Bootstrap flow**: First-time setup creates a manager account (`POST /v2/seller/pos/staff/bootstrap`)
- **CRUD operations**: Add/edit/delete staff via API endpoints
- **Staff form fields**: Name, Role (dropdown: `cashier` or `manager`), PIN (4-8 digits), Active toggle
- **POS Session card**: Shows current logged-in staff with Sign in / Switch staff / Sign out
- **API endpoints used**:
  - `GET /v2/seller/pos/staff` — list all staff
  - `POST /v2/seller/pos/staff` — create staff
  - `PUT /v2/seller/pos/staff/{id}` — update staff
  - `DELETE /v2/seller/pos/staff/{id}` — delete staff
  - `POST /v2/seller/pos/staff/bootstrap` — initialize first manager
  - `POST /v2/seller/pos/staff/login` — phone+PIN login
  - `GET /v2/seller/pos/staff/me` — current staff info

### 1.5 Legacy Staff PIN Screen

**File**: `lib/src/features/settings/staff_screen.dart`  
**Controller**: `lib/src/features/settings/staff_pin_controller.dart`

A simpler, older staff PIN system:
- Toggle "Require PIN for staff login" on/off
- Stores a single PIN in secure storage (not per-staff)
- Locks the entire app with an overlay in `HomeShell` when `staffState.enabled && staffState.locked`
- "Permissions" list tile exists but is **non-functional** (just a label with subtitle "Limit access to reports, items, or refunds")

### 1.6 Database Schema

**File**: `lib/src/core/db/app_database.dart`

**`Roles` table** (L:261–268):
```dart
class Roles extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get name => text()();
  BoolColumn get canRefund => boolean().withDefault(const Constant(false))();
  BoolColumn get canVoid => boolean().withDefault(const Constant(false))();
  BoolColumn get canPriceOverride => boolean().withDefault(const Constant(false))();
}
```

**`Staff` table** (L:270–281):
```dart
class Staff extends Table {
  TextColumn get id => text().clientDefault(() => _uuid.v4())();
  TextColumn get name => text()();
  TextColumn get pin => text().nullable()();
  IntColumn get roleId => integer().nullable().references(Roles, #id)();
  BoolColumn get active => boolean().withDefault(const Constant(true))();
  DateTimeColumn get updatedAt => dateTime().clientDefault(() => DateTime.now().toUtc())();
}
```

**Staff references in other tables**: `staffId` FK in `LedgerEntries` (L:357), `Shifts` (L:401), `CashMovements` (L:414), `Expenses` (L:433).

---

## 2. Menu Structure & Navigation

### 2.1 Bottom Navigation Bar

**File**: `lib/src/features/home/home_shell.dart`

4-tab `BottomNavigationBar`:
| Index | Label | Icon | Screen |
|---|---|---|---|
| 0 | Checkout | `point_of_sale` | `CheckoutScreen` |
| 1 | Transactions | `receipt_long` | `TransactionsScreen` |
| 2 | Alerts | `notifications_none` (with badge) | `NotificationsEntryScreen` |
| 3 | More | `grid_view` | `MoreScreen` |

### 2.2 "More" Menu (Full Feature Hub)

**File**: `lib/src/features/more/more_screen.dart`

**No role-based conditional rendering** on menu items. All items shown to all users regardless of role.

| Section | Items |
|---|---|
| **Business** | Dashboard, Reports, Insights & Analytics, Expenses* (feature flag `ffExpensesV1`), Sanaa Wallet, Customers |
| **Catalog** | Products, Suppliers, Purchase Orders, Receive Stock, Stock Count, Low Stock, Services, Quotations, Wholesale & Digital |
| **Sales** | Shifts & Cash, Orders, Auctions, Refunds |
| **Marketing** | Ads & Creatives, Bulk SMS, Coupons, Messages |
| **Settings** | Business Setup* (feature flag `ffBusinessSetupWizard`), Profile, Shop Settings, Verification, Payment Settings, Delivery Options, **Staff & Roles**, App Settings, Receipt Templates |
| — | Sign Out |

*Items marked with * are conditionally shown via Firebase Remote Config feature flags, NOT role-based.*

### 2.3 Router Configuration

**File**: `lib/src/app.dart`

- **Redirect guards**: Only checks `AuthStatus.authenticated` (logged in or not). No role-based route guards exist.
- **Business setup redirect**: If `setupRequired && !setupCompleted`, forces to `/home/more/business-setup`
- Routes: `/login`, `/staff-login`, `/pos-login`, `/register`, plus the `StatefulShellRoute` for `/home/*`

### 2.4 Staff PIN Lock Overlay

In `HomeShell` (L:108–118): When `staffPinProvider` is enabled and locked, a full-screen overlay blocks the app until PIN is entered. This is a blunt on/off lock, not per-feature gating.

---

## 3. Digital Catalog / Sharing Features

### 3.1 No Product Catalog Generation

- **No catalog PDF generation** exists in the items feature
- `lib/src/features/items/product_preview_screen.dart` has **no share/PDF/WhatsApp functionality**
- Items screen (`items_screen.dart`) is purely a CRUD list for product management
- **No shop link** feature or public catalog URL generation found anywhere

### 3.2 Receipt & Invoice Sharing (Existing)

**Receipt sharing** — `lib/src/features/receipts/receipt_service.dart`:
- `sharePdf(entryId)` — Generates PDF receipt and shares via system share sheet (L:490–497)
- `shareWhatsapp(entryId, {phone?})` — Builds text receipt, opens `wa.me` link or falls back to `Share.share()` (L:499–535)
- `printBluetooth(entryId)` — Prints via Bluetooth thermal printer

**Invoice PDF generation** — `lib/src/features/invoices/invoice_service.dart`:
- `sharePosInvoicePdf(entryId)` — Full A4 PDF invoice for POS sales
- `shareOrderInvoicePdf(order)` — PDF invoice for marketplace orders  
- `shareQuotationPdf(row)` — PDF for quotations

**Receipt details sheet** — `lib/src/features/receipts/receipt_details_sheet.dart`:
- Three share buttons: "Receipt PDF", "Invoice PDF", "WhatsApp" (L:196–222)

### 3.3 Marketing

**File**: `lib/src/features/marketing/bulk_sms_screen.dart`
- Bulk SMS functionality only. No catalog sharing or digital storefront features.

---

## 4. Installed Packages (Relevant)

### From `pubspec.yaml`:

| Category | Package | Version |
|---|---|---|
| **PDF Generation** | `pdf` | ^3.11.1 |
| **PDF Printing/Sharing** | `printing` | ^5.13.3 |
| **Sharing** | `share_plus` | ^10.1.3 |
| **URL Launching** | `url_launcher` | ^6.3.0 |
| **Bluetooth Printing** | `blue_thermal_printer` | ^1.1.9 |
| **QR Code Generation** | `qr_flutter` | ^4.1.0 |
| **Image Processing** | `image` | ^4.3.0 |
| **Barcode Scanning** | `mobile_scanner` | ^7.1.3 |
| **File Picking** | `file_picker` | ^8.1.2 |
| **Image Picking** | `image_picker` | ^1.0.7 |
| **Contacts Access** | `flutter_contacts` | ^1.1.9+2 |
| **Permissions** | `permission_handler` | ^11.3.1 |
| **Charts** | `fl_chart` | ^0.71.0 |
| **WebView** | `webview_flutter` | ^4.8.0 |

---

## 5. Key Findings Summary

### What EXISTS:
1. ✅ **Two login paths**: Owner (phone+password/PIN) and Staff (phone+6-digit PIN)
2. ✅ **POS session system**: In-app staff switching with PIN, manager/cashier roles
3. ✅ **Full RBAC system**: `RbacController` with 7 permissions, `ManagerPinGate` widget
4. ✅ **Staff CRUD**: Full management screen with bootstrap, add/edit/delete, role assignment
5. ✅ **Database tables**: `Staff` (id, name, pin, roleId, active) and `Roles` (id, name, canRefund, canVoid, canPriceOverride)
6. ✅ **Receipt sharing**: PDF generation + WhatsApp sharing for receipts/invoices/quotations
7. ✅ **Printing**: Bluetooth thermal + `printing` package PDF sharing
8. ✅ **All sharing packages installed**: pdf, printing, share_plus, url_launcher, qr_flutter

### What's MISSING / NOT WIRED:
1. ❌ **RBAC not enforced in UI**: `ManagerPinGate` / `checkPermissionWithPin` not used in ANY feature screen
2. ❌ **No role-based menu filtering**: All menu items visible to all users (cashier sees everything)
3. ❌ **No route guards by role**: Router only checks auth status, not staff role
4. ❌ **No product catalog generation**: No PDF catalog, no shop link, no product sharing
5. ❌ **No digital storefront / catalog URL**: No public-facing catalog feature
6. ❌ **Roles table limited**: Only has `canRefund`, `canVoid`, `canPriceOverride` — missing permissions for `viewReports`, `manageStaff`, `manageSettings`, `adjustInventory` (these exist in the `Permission` enum but have no DB column)
7. ❌ **Legacy vs. new staff system overlap**: Both `StaffScreen` (single-PIN lock) and `StaffManagementScreen` (full CRUD) exist, creating UX confusion
