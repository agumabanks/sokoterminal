# Soko Seller Terminal

**Version 1.2.0** · Flutter (Dart ^3.9) · Offline-First POS & Marketplace Companion

The Soko Seller Terminal is the dedicated mobile app for Soko 24 merchants. It combines a full Point-of-Sale system with inventory management, order fulfilment, customer engagement, and financial reporting — all built to work reliably without an internet connection and sync automatically when connectivity is restored.

---

## Table of Contents

- [Features](#features)
- [Architecture](#architecture)
- [Prerequisites](#prerequisites)
- [Getting Started](#getting-started)
- [Project Structure](#project-structure)
- [Key Dependencies](#key-dependencies)
- [Feature Flags](#feature-flags)
- [Building & Releasing](#building--releasing)
- [Testing](#testing)
- [Non-Negotiables](#non-negotiables)
- [Contributing](#contributing)

---

## Features

| Module | Description |
|---|---|
| **POS / Checkout** | Barcode scanning, cart management, thermal receipt printing, offline transactions |
| **Products (Items)** | CRUD for simple, variant, wholesale, and digital products; image gallery |
| **Orders** | List, detail, status updates, void flow (PIN-gated), refund requests |
| **Customers** | Customer profiles, lifetime value, purchase history, WhatsApp link |
| **Inventory / Procurement** | Stock adjustments, transfers, batch additions |
| **Payments & Wallet** | Sanaa Cards wallet balance, withdraw requests, payment history |
| **Reports & Analytics** | Sales summaries, commission logs, shift reports, expense tracking |
| **Coupons & Marketing** | Coupon CRUD, flash deals, Ads → Studio workflow |
| **Auctions** | Active auctions, bid management, create/end auction flows |
| **Chat / Inbox** | Unified inbox aggregating customer chats, product queries, notifications |
| **Services** | Service offerings and bookings management |
| **Quotations & Invoices** | Quote generation, invoice dispatch |
| **Expenses** | Expense logging linked to cashout reports |
| **Delivery** | Radius settings, delivery zone management |
| **Settings & Profile** | Shop profile, verification, subscription packages, staff management |
| **Notifications** | Firebase push notifications with deep-linking |

---

## Architecture

```
Offline-first:  Drift (SQLite)  ──▶  Background sync queue  ──▶  Laravel API v2
                 (local truth)                                    (soko24.co/api/v2)
```

| Concern | Choice |
|---|---|
| State management | **Riverpod 2.6** (`AsyncNotifierProvider`, `StateNotifierProvider`) |
| Navigation | **GoRouter 14** with `StatefulShellRoute.indexedStack` |
| Local database | **Drift 2.17** (SQLite via `sqlite3_flutter_libs`) |
| Networking | **Dio 5.7** with `pretty_dio_logger` |
| Auth storage | `flutter_secure_storage` |
| Feature flags | Firebase Remote Config |
| Crash reporting | Firebase Crashlytics |
| Analytics | Firebase Analytics |
| Push notifications | Firebase Cloud Messaging |
| Printing | `blue_thermal_printer` + `printing` (PDF) |
| Maps | `google_maps_flutter` + `flutter_map` |

**DI:** `ProviderScope` overrides in `main.dart`.  
**After any Drift schema change:** re-run `dart run build_runner build --delete-conflicting-outputs`.

---

## Prerequisites

| Tool | Version |
|---|---|
| Flutter | ≥ 3.24 (SDK constraint `^3.9.0`) |
| Dart | ^3.9.0 |
| Android Studio / Xcode | Latest stable |
| Java | 17 (for Android builds) |
| Firebase project | Configured (see `google-services.json` / `GoogleService-Info.plist`) |

---

## Getting Started

```bash
# 1. Clone the monorepo and navigate to the app
cd /path/to/soko/app/soko_seller_terminal

# 2. Install dependencies
flutter pub get

# 3. Regenerate Drift / build_runner code (required after any model change)
dart run build_runner build --delete-conflicting-outputs

# 4. Copy environment config
cp assets/config/.env.example assets/config/.env
# Edit .env with your API base URL and keys

# 5. Run on a connected device
flutter run
```

> **Tip:** The app connects to `https://soko24.co/api/v2` by default. Override `API_BASE_URL` in `assets/config/.env` to point at a local backend.

---

## Project Structure

```
lib/
├── main.dart                   # Entry point, ProviderScope, Firebase init
├── firebase_options.dart       # Auto-generated Firebase config
├── src/
│   ├── app.dart                # GoRouter + MaterialApp setup
│   ├── core/
│   │   ├── config/             # App config, environment loader
│   │   ├── data/               # Base repositories, API client
│   │   ├── db/                 # Drift database definition & DAOs
│   │   ├── network/            # Dio setup, interceptors, connectivity
│   │   ├── services/           # Shared services (sync, telemetry…)
│   │   ├── sync/               # Offline sync queue
│   │   ├── theme/              # Design tokens, AppTheme (Apple × Nike V4)
│   │   └── util/               # Extensions, helpers
│   ├── features/
│   │   ├── auth/               # Login, token refresh, PIN lock
│   │   ├── dashboard/          # Home dashboard & summary cards
│   │   ├── items/              # Product CRUD (simple, variant, digital)
│   │   ├── wholesale/          # Wholesale product flows
│   │   ├── auctions/           # Auction management
│   │   ├── orders/             # Order list, detail, void, refund
│   │   ├── checkout/           # POS cart & payment collection
│   │   ├── customers/          # Customer profiles & history
│   │   ├── payments/           # Wallet, withdrawals, payment history
│   │   ├── expenses/           # Expense logging & cashout
│   │   ├── reports/            # Sales, shifts, analytics
│   │   ├── coupons/            # Coupon & discount management
│   │   ├── marketing/          # Flash deals, ads, promotions
│   │   ├── chat/               # Customer conversations & inbox
│   │   ├── notifications/      # Push notification handling
│   │   ├── services/           # Service offerings & bookings
│   │   ├── delivery/           # Delivery zones & radius settings
│   │   ├── invoices/           # Invoice generation & dispatch
│   │   ├── quotations/         # Quotation flows
│   │   ├── receipts/           # Receipt history & reprint
│   │   ├── refunds/            # Refund request management
│   │   ├── wallet/             # Sanaa Cards wallet UI
│   │   ├── transactions/       # Transaction history
│   │   ├── settings/           # Shop settings, staff, packages
│   │   ├── profile/            # Seller profile & verification
│   │   ├── analytics/          # Advanced analytics & charts
│   │   └── onboarding/         # First-run setup wizard
│   └── widgets/                # Shared UI components
assets/
├── config/                     # .env file (gitignored in production)
└── images/                     # App images & icons
```

---

## Key Dependencies

```yaml
# State & Navigation
flutter_riverpod: ^2.6.1
go_router: ^14.6.1

# Offline Storage
drift: ^2.17.0
sqlite3_flutter_libs: ^0.5.24

# Networking
dio: ^5.7.0
connectivity_plus: ^6.1.0

# Firebase
firebase_core: ^3.15.2
firebase_messaging: ^15.1.4
firebase_crashlytics: ^4.3.3
firebase_remote_config: ^5.3.3

# POS Hardware
blue_thermal_printer: ^1.1.9
mobile_scanner: ^7.1.3          # Barcode / QR scanning

# Maps & Location
google_maps_flutter: ^2.9.0
geolocator: ^13.0.2

# UI & Media
google_fonts: ^6.2.1
fl_chart: ^0.71.0
video_player: ^2.9.2
image_picker: ^1.0.7
```

---

## Feature Flags

Feature flags are served via **Firebase Remote Config**. All flags default to `false` unless noted.

| Flag | Default | Description |
|---|---|---|
| `ff_pos_voids` | `true` | PIN-gated void flow + void reports |
| `ff_product_variants_editor` | `true` | Variant create/edit UI |
| `ff_print_diagnostics` | `true` | Printer diagnostics screen |
| `ff_delivery_radius_settings_v2` | `true` | Dynamic radius slider (0.5 km steps) |
| `ff_unified_inbox` | `true` | Aggregated orders/bookings/notifications inbox |
| `ff_customer_profile` | `false` | Full customer profile (LTV, tags, WhatsApp) |
| `ff_contacts_enrichment` | `true` | Contact normalisation & merge flow |
| `ff_soko_studio` | `false` | Ads → Studio template workflow |
| `ff_business_setup_wizard` | `false` | First-run setup completion gating |
| `ff_expenses_v1` | `false` | Expenses module + cashout linking |

---

## Building & Releasing

```bash
# Android — release APK
flutter build apk --release --target-platform android-arm64

# Android — App Bundle (for Play Store)
flutter build appbundle --release

# iOS — Archive (requires macOS + Xcode)
flutter build ios --release
```

Signed APK releases are stored in `releases/`. Current release artifacts:
- `soko-seller-terminal-v1.0.7-universal.apk`
- `soko-seller-terminal-v1.0.6-arm64.apk`

See [PLAY_STORE_DEPLOYMENT.md](PLAY_STORE_DEPLOYMENT.md) and [RELEASE_OPS.md](RELEASE_OPS.md) for full Play Store and release pipeline instructions.

---

## Testing

```bash
# Unit & widget tests
flutter test

# Static analysis
flutter analyze

# Integration tests (requires connected device/emulator)
flutter test integration_test/

# Code generation (always run after Drift schema changes)
dart run build_runner build --delete-conflicting-outputs
```

Test coverage reports are output to `coverage/`. See `test/` and `integration_test/` for test files.

---

## Non-Negotiables

1. **Offline-first is sacred.** Never bypass the local Drift DB. All writes go to Drift first; the sync queue pushes to the API.
2. **Never break barcode scanning or thermal printing** — these are core POS workflows.
3. **After any Drift model/schema change**, always re-run `build_runner build` before committing.
4. **Feature flags must gate new features.** Use `firebase_remote_config` to roll out incrementally.
5. **No secrets in source.** All keys live in `assets/config/.env` (gitignored) or Firebase Remote Config.
6. **`DEMO_MODE=On`** blocks all mutations on the backend — respect it in UI (disable action buttons, show demo badge).

---

## Contributing

This app is part of the **Soko 24 monorepo** at `/var/www/soko`. Please read the root [CLAUDE.md](../../CLAUDE.md) and [AGENTS.md](../../AGENTS.md) before making changes.

Branch convention: `feature/<description>` off `main`.  
Commit style: conventional commits (`feat:`, `fix:`, `chore:`, etc.).

---

*Built by the Antigravity team · [soko24.co](https://soko24.co)*
