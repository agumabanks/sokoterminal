# Soko Seller Terminal — Production Readiness Assessment & Implementation Plan

Last updated: 2025-12-27

## GA Readiness Implementation Plan (phased, PR-sized)

This section turns the remaining GA scope into PR-sized increments with explicit acceptance criteria and feature flags.

### Feature flags (Firebase Remote Config)

- `ff_pos_voids` (default: `false`) — enable Void flow + reports/receipts handling
- `ff_product_variants_editor` (default: `false`) — enable variant create/edit UI + sync push
- `ff_print_diagnostics` (default: `false`) — enable Print Diagnostics screen + certified-printers mode
- `ff_delivery_radius_settings_v2` (default: `true`) — enable dynamic radius limits + 0.5km steps
- `ff_unified_inbox` (default: `false`) — enable Inbox module aggregating orders/bookings/notifications
- `ff_customer_profile` (default: `false`) — enable Customer Profile (LTV, history, tags, WhatsApp)
- `ff_contacts_enrichment` (default: `false`) — enable contacts normalization + merge/link flow
- `ff_soko_studio` (default: `false`) — enable Ads → Studio workflow (templates + export/share)

### Phase 0 — Discovery + contracts (done / keep current)

Acceptance criteria:
- Flutter: identify modules, Drift tables, and sync entry points; confirm current behavior of GA targets (voids/variants/customers/inbox/ads/contacts/printing).
- Backend: confirm v2 POS endpoints + idempotency middleware + RBAC enforcement points and gaps.

### Phase 1 — GA blockers (do first)

#### PR1 — Checkout reactivity + responsive cart totals
Acceptance criteria:
- Portrait cart sheet reflects quantity changes instantly (totals + line items).
- No regression on wide layout checkout.
- Telemetry: `checkout_cart_qty_changed`.

#### PR2 — Online publish validation + marketplace listing parity
Acceptance criteria:
- Enabling “Publish online” requires required marketplace fields before save/publish.
- Image uploads + gallery remain offline-first and retry-safe; no stuck sync ops on missing local images.
- Publishing from the Products list is blocked unless required details exist (redirect to editor).

#### PR3 — Delivery radius settings hardening
Acceptance criteria:
- Slider supports backend-provided max radius + 0.5km steps (min 0.5).
- UI uses API-provided `radius_km_max` when present; backend uses a setting-driven max.
- Save/load round-trips without silent clamping surprises.

#### PR4 — VOIDS (distinct from refunds)
Acceptance criteria:
- Manager-only (PIN-gated) void flow with required reason code (configurable list).
- Append-only reversal entry referencing original sale; inventory restored; reports treat voids correctly.
- Idempotent retries safe; AuditLogs entry created on every void.
- Receipt share/print clearly marked “VOIDED”.

#### PR5 — Variant creation/edit UI + sync push
Acceptance criteria:
- Seller can add/edit variants offline-first: variant label, SKU/barcode, price, stock, optional image.
- SKU uniqueness enforced locally + server-side guard; no collisions across seller catalog.
- Sync reliably creates/updates product_stocks (variants) and reconciles totals; retries safe.

#### PR6 — Print Diagnostics + certified printers mode
Acceptance criteria:
- New diagnostics screen: permissions state, paired printer detection, test print, queue status + last error.
- Certified printers list (static initial) + “compatibility mode” toggle.
- Telemetry: `print_success`, `print_fail`, `print_retry_count`, `print_test`.

#### PR7 — Design token enforcement baseline
Acceptance criteria:
- Checkout, Items, Orders, More, Settings use `DesignTokens` consistently (spacing, text, colors).
- Add lightweight helpers/lints only if low-risk (no over-engineering).

### Phase 2 — Merchant growth tooling

#### PR8 — Customer profile enrichment (MVP)
Acceptance criteria:
- Customer profile loads from local DB (offline): last purchase, total orders, LTV, tags, WhatsApp actions.
- Tags editable offline and synced later.
- Telemetry: `customer_profile_open`, `tag_added`, `whatsapp_action_used`.

#### PR9 — Contacts enrichment + matching
Acceptance criteria:
- Normalize phones (E.164), dedupe/merge rules, and link/create customer flow.
- Permission-safe UX + opt-out; minimal contact fields stored.
- Telemetry: `contacts_sync_success/fail`, `contact_linked_to_customer`.

### Phase 3 — Unified Inbox (“Merchant brain”)

#### PR10 — Inbox module
Acceptance criteria:
- Aggregates cached Orders + Service Bookings + Notifications into one queue with filters.
- Offline actions show “Pending sync” and reconcile after pull.
- Telemetry: `inbox_open`, `item_action_taken`, `time_to_first_action`.

### Phase 4 — Ads / Soko Studio mobile

#### PR11 — Soko Studio workflow
Acceptance criteria:
- Select product → choose template → customize → export/share (offline capable).
- Templates cached locally; export errors actionable.
- Telemetry: `studio_open`, `template_selected`, `export_success/fail`.

## 2025-12-25 Progress (implemented)

- [x] Fixed splash auth token key mismatch (now uses `readAccessToken()`)
- [x] Fixed API base URL/path joining bug (centralized in `ApiClient`)
- [x] Telemetry now chains global error handlers (no Crashlytics override)
- [x] Removed duplicate FCM init (single notification subscription)
- [x] Improved “online” detection for sync (treat any non-`none` connectivity as online)
- [x] POS stock accuracy: checkout decrements stock locally; refunds restore stock
- [x] POS refunds: manager PIN gated, receipt lookup by receipt number, creates ledger refund entry + payment row
- [x] Cash movements: cash-in/out can be tagged (expense/supplier/owner/other) and displayed cleanly
- [x] Invoice generation:
  - POS invoice PDF (A4) for sales/refunds (credit note)
  - Online order invoice PDF (A4) from order details
- [x] Marketplace orders (“More → Orders”):
  - Order list + details parsing fixed end-to-end
  - Delivery + payment status updates wired to backend
- [x] Engineering baseline: `flutter analyze` clean + `flutter test` passing
- [x] Product module sync (POS + Online-ready foundation):
  - Backend: `POST /v2/seller/pos/catalog/products` idempotent create/update returns `product_id` (maps local UUID → remote ID)
  - Backend: POS delta pull now includes richer product fields + `image_url` (thumbnail) for local catalog hydration
  - Flutter: product create/update/stock-adjust now uses POS catalog upsert and persists `items.remoteId`
  - Flutter: ledger sync remaps local `itemId/serviceId` → remote IDs before push (offline-created products can now sync sales)
  - Flutter: POS pull merges products by `remoteId` to reduce duplicates and keep local UUIDs stable
- [x] Full catalog upload parity (images + variants foundation):
  - Offline-first image uploads (local file paths → server upload IDs/URLs)
  - Product gallery upload parity (multi-image) via `photo_upload_ids`
  - Variant stocks pulled into local `ItemStocks` and selectable at checkout
- [x] Omni-channel inventory atomicity:
  - POS ledger applies stock deltas atomically against `product_stocks` (shared with online orders)
  - Server enforces `variation` for variant products; POS sends `variation` on sale/refund
- [x] Backend migration required for variants in POS ledger:
  - `database/migrations/2025_12_25_000001_add_variation_to_pos_ledger_lines_table.php`
- [x] Sync reconciliation + recovery tooling:
  - “Blocked” sync ops (non-retryable 4xx) surfaced in Sync Health
  - Retry blocked ops + Full Resync + safe discard (manager approval)
- [x] Checkout responsiveness polish:
  - Debounced search, variant-aware scanning, local images render correctly

## 2025-12-26 Progress (implemented)

- [x] POS staff sessions (server-side RBAC) wired end-to-end:
  - Splash gates to Staff Login when staff is initialized
  - “More → Staff & Roles” now opens backend staff management with session status + switch/sign out
  - Sync service starts on app cold start (not only after login)
- [x] RBAC hardening + attribution:
  - Staff initialization is cached for offline gating
  - Manager approvals use server-side staff roles when online (offline fallback via device PIN)
  - POS sales and cash movements are attributed to the active staff + outlet in the local ledger
  - Privileged actions emit POS audit logs (refunds, cash float/withdrawals, price overrides)
- [x] Customer sync parity:
  - Checkout “quick add customer” now syncs (immediate push, else outbox `customer_push`)
  - Sync marks customers as synced and stores `remoteId` after push
  - Customer pull merges by `remoteId` to reduce duplicates
- [x] Services (online + offline) foundation:
  - Backend: `/v2/service-provider/*` routes wired (offerings + bookings actions)
  - Backend: POS delta pull now returns service offerings for the seller’s provider
  - Flutter: service create/update now maps payload correctly, is idempotent on create, and persists `services.remoteId`
  - Flutter: Bookings inbox + cached fallback added (confirm/complete/cancel)
- [x] Payment settings → POS + receipts:
  - Backend: shop info now returns and stores mobile money codes + `receipt_payment_methods`
  - Flutter: checkout payment options respect configured methods (cash/mobile money/bank transfer/card)
  - Flutter: receipts/invoices include payment instructions (MoMo/bank) when relevant
- [x] POS quotations sync + offline-first list:
  - Fixed quotation sync payload parity with backend (`quotation_number`, `validity_days`, line fields)
  - Quotations screen now reads local DB and can refresh from server into local cache

## 2025-12-27 Progress (implemented)

- [x] Phase 7 (Procurement & inventory control) MVP:
  - Suppliers CRUD (backend tables + API + Flutter screen)
  - Purchase orders create/list + offline-first push (Flutter outbox)
  - Receive stock (GRN) + stocktake flows (Flutter offline-first outbox + backend endpoints)
  - Low-stock reorder suggestions screen

## Current readiness score (2025-12-26)

**92 / 100 (Strong beta; core POS + RBAC + sync recovery are usable end-to-end, final QA still required)**

Main blockers to “GA for all paying sellers”:
- Remaining RBAC hardening (voids + discount overrides UX and enforcement)
- Full catalog parity vs web product builder (taxes/attributes/variant creation & per-variant images)
- Print QA across devices + template management hardening
- Deeper conflict remediation (guided fixes for blocked ops; inventory reconciliation reports)

## GA launch checklist (Paying Sellers)

- [x] Seller login + stable session persistence
- [x] Products: create/update/stock adjust + image uploads + variant selling (pulled variants)
- [x] POS checkout: fast scan/search + multi-method payments + receipt numbers + invoices/receipts
- [x] Offline-first sync: idempotent push + delta pull + blocked ops visibility + recovery tools
- [x] RBAC: staff sessions + manager approval for refunds/cash float/withdrawals + audit logs
- [x] Marketplace orders: list/details + status updates + invoice PDF
- [~] Printing QA: validate common thermal printers + default template rollout
- [~] Release ops: store listing, signing, privacy policy, Data Safety, crash-free target

This file is the single checklist + progress tracker for making the Seller Terminal production‑ready.

It prioritizes:
- Offline‑first catalog + POS workflows (Uganda‑level connectivity)
- Append‑only sales ledger + idempotent sync (no duplicates)
- Simple, premium UI (Steve Jobs standard) using proven Amazon patterns
- Seller business management tools that actually matter (SME focus)

---

## How to use this doc (progress checker)

1. Treat every checkbox as a “release gate” item.
2. Update status using this legend:
   - `[x]` Done (works end‑to‑end, tested, production‑ready)
   - `[~]` Partially done (scaffolded / local only / needs backend contract)
   - `[ ]` Not started
3. A feature is “production ready” only when:
   - It works offline
   - It syncs without duplicates (idempotency)
   - It has clear UX + error states
   - It’s permission‑safe (RBAC where needed)

---

## Snapshot (where we are now)

### What exists in the Flutter app today (high level)
- Local DB using Drift (items/services/customers/transactions/sync queue exist)
- Sync queue (`SyncOps`) that retries when online
- Seller marketplace orders: list/details/status updates + invoice PDF (cached)
- POS checkout flow with local persistence (now writing a local ledger entry)
- New feature screens scaffolded (auctions/chat/coupons/refunds/verification/wholesale) — not fully wired

### Major blockers to production readiness
- Backend now has a v2 **POS ledger API** with **idempotency acknowledgements**, **atomic inventory**, and **delta pull**; remaining: deeper validation, reporting completeness, and full RBAC enforcement.
- Sync engine now has blocked-op handling + Sync Health recovery tools; remaining: guided remediation flows and stronger reconciliation strategy across all op types.
- Product management now supports images + online fields + variant selling; remaining: taxes/attributes + full variant creation/editing parity vs web.
- RBAC + approvals are not end‑to‑end (tables exist, enforcement is not complete on backend or frontend).
- Design system not enforced (no strict tokens; too many UI styles and patterns).

---

## Production readiness gates (non‑negotiable)

### Reliability & Offline
- [x] Offline-first catalog: items + services usable offline, including search
- [x] Offline-first POS: create sales while offline
- [~] Offline-first refunds/voids: recorded locally and synced later
- [~] Offline-first customer management (including walk-ins)
- [~] Sync never creates duplicates (server idempotency; ledger entries)
- [~] Sync handles retries safely (at-least-once delivery; ledger + SyncOps backoff)
- [x] Sync handles partial failures (blocked ops, per-op visibility, recovery tools)

### Security & Permissions
- [~] Seller auth (token) stable with refresh + device token management
- [x] Staff PIN lock exists (device-level lock)
- [~] RBAC policies enforced server-side (cashier vs manager; void pending)
- [~] Audit log for privileged actions (refund, cash movements, price override; void pending)
- [~] Rate limiting + abuse prevention for seller endpoints

### UX & Product Quality
- [ ] One consistent design system (8pt grid, 3 font sizes, 3 grays)
- [x] Replace dialogs with smooth bottom sheets for core flows
- [ ] Brutal simplification pass (remove 20% of elements)
- [ ] Performance: smooth scrolling, fast startup, image caching
- [~] Instrumentation: crash reporting + analytics + key funnel events (local telemetry log + export; remote pending)

---

## Implementation roadmap (front + back)

### Phase 0 — “Truth” contract (backend + client agreement)
Goal: establish the minimal server contracts that make offline-first possible.

Backend (Laravel)
- [~] Create POS Ledger API (append-only):
  - `POST /v2/seller/pos/ledger-entries` (sale/refund/adjustment)
  - `POST /v2/seller/pos/cash-movements` (float/withdraw/open/close)
  - `POST /v2/seller/pos/audit-logs` (privileged actions)
- [x] Idempotency:
  - Accept `Idempotency-Key` header
  - Store request + response hash and return same ack for duplicates
  - Return `{server_entry_id, idempotency_key, received_at}` on success
- [~] Delta pull endpoints:
  - `GET /v2/seller/pos/sync/pull?since=...`
  - Returns changed items/services/customers/config since timestamp
- [~] Auth + RBAC:
  - Seller-only guard added for new POS v2 endpoints; staff roles endpoints + enforcement still pending
- [~] Reports endpoints (from ledger, numeric values only):
  - Daily sales + top items added; profit + cashier performance pending

Flutter (Seller Terminal)
- [~] Local DB schema foundations for ledger/staff/roles/outlets/audit (added)
- [~] Tight sync protocol:
  - Ledger sync marks “synced” only after server ack payload
  - Persist last successful pull timestamps per dataset
  - Concurrency guard: only one sync pump at a time
  - Backoff + retryCount updates in `SyncOps`
- [~] Typed API models (stop using raw `Map<String,dynamic>` for core flows)

---

### Phase 1 — Catalog (Products + Services) offline-first and “seller-grade”

#### 1A. Products (online + offline)
Backend
- [ ] Product list endpoint supports pagination, search, updated-since
- [~] Full product create/update supports:
  - [x] Images upload (multi) via upload IDs (`thumbnail_upload_id`, `photo_upload_ids`)
  - [~] Variants / SKU combinations (sell + per-variant stock adjust; full variant creation/editing pending)
  - [ ] Taxes, attributes, colors
  - [x] Publish/unpublish + stock updates (incl per-variant)
- [ ] Seller categories/collections (see below)

Flutter
- [x] Pull seller products to local DB (`SyncService.pullSellerProducts`)
- [x] Catalog screens use only local DB as truth (remote is just sync)
- [~] Full product editor:
  - [ ] Draft mode (offline), autosave
  - [x] Upload queue for images
  - [ ] Variant builder UI
  - [~] Validation that matches backend rules (core pricing/discount/online fields)
- [~] Stock management:
  - [x] Fast stock adjust UI (supports variants)
  - [~] Inventory logs + low stock alerts (alerts pending)
- [ ] Product “Preview as customer” page using Amazon patterns (see UX section)

#### 1B. Services (online + offline)
Backend
- [x] Service offerings endpoints match seller routes (create/update/publish)
- [x] Bookings endpoints + provider-side actions (confirm/cancel/complete)

Flutter
- [x] Pull seller services to local DB (`SyncService.pullSellerServices`)
- [~] Service editor with availability + pricing options
- [~] Bookings inbox (offline cache + sync)

---

### Phase 2 — POS Core (Ledger, Payments, Customers, Shifts)

#### 2A. Sales ledger (append-only)
Backend
- [~] Ledger entry stored immutably; refunds reference original (void pending)
- [x] Server validates totals, item existence, permissions
- [x] Server returns deterministic ack for idempotent retries

Flutter
- [x] Local ledger tables exist and checkout writes a ledger entry
- [x] Add “Ledger sync status” UI (pending, failed, synced)
- [~] Implement refund/void as new ledger entries (refund done; void pending)
- [x] Payment methods:
  - Cash, mobile money, card
  - Split payments (optional)
  - Credit / pay-later sales (common in hardware/wholesale)
- [x] Receipt rendering + thermal print pipeline
- [x] Invoice PDF (A4) generation (POS + online orders)

#### 2B. Customers (walk-ins included)
Backend
- [ ] Seller-scoped customers endpoint (do not return all platform customers)
- [ ] Customer create/update/search (fast)

Flutter
- [~] Customers table exists
- [~] Pull customers exists, but needs seller-scoping and pagination
- [x] Walk-in customer:
  - Always available
  - One-tap switch between walk-in and saved customer
- [x] “Quick add customer” bottom sheet in checkout

#### 2C. Shifts + cash movements (SME reality)
Backend
- [~] Shift open/close endpoints + cash movements
- [ ] Cash drawer reconciliation report

Flutter
- [x] Tables exist (shifts/cash movements)
- [x] Shift UX:
  - Open shift (float)
  - Close shift (counted cash + variance)
  - Cash in/out quick actions

---

### Phase 3 — Orders (Marketplace + Service bookings) “full manage”
Backend
- [ ] Order details endpoint includes line items, shipping, buyer info
- [ ] Status updates are permission-checked and audited
- [ ] Refund request workflow is seller-friendly

Flutter
- [~] Orders list + update exists; details items are partially wired/cached
- [ ] Unified “Orders inbox”:
  - Marketplace orders tab
  - Service bookings tab
  - Refund requests tab
- [~] Offline cache:
  - Persist order details to local DB (Drift, not SharedPreferences)
  - Delta pull since last sync

---

### Phase 4 — Business management for SMEs

Backend
- [ ] Business profile endpoints (business name, outlets, staff, tax)
- [ ] Expense tracking + suppliers (if included)
- [ ] Reports endpoints from ledger (see Phase 0)

Flutter
- [ ] Business setup wizard:
  - Business name + outlet
  - Receipt header
  - Staff + PIN
- [ ] Business tools:
  - Expenses (simple)
  - Inventory alerts
  - Profit basics dashboard (not accounting-grade)
  - Quotes / proforma invoices (optional but powerful for hardware/SMEs)
  - Customer credit tracker (AR) + reminders (if enabled)

---

### Phase 5 — Ads & Marketing from products/services

Goal: seller can generate high quality creatives quickly.

Backend (preferred approach)
- [ ] “Creative templates” endpoint returns template metadata
- [ ] Optional server-side render (if using headless rendering) OR return assets + layout hints
- [ ] Track campaign actions + export links

Flutter
- [~] Ads screen exists but is not a full workflow
- [ ] Flow:
  - Pick product/service
  - Choose template (square/story/banner)
  - Auto-fill: name, price, discount, urgency, QR link
  - Generate export (image/video)
  - Share to WhatsApp/Instagram/Facebook
  - Save drafts offline

---

### Phase 6 — Seller categories / collections

Important: platform product categories are global; sellers need “store organization”.

Backend
- [ ] Implement “Collections” (seller-owned categories):
  - CRUD, sort order
  - Assign products/services to collections
  - Optional public visibility flag

Flutter
- [ ] Collections manager (simple CRUD)
- [ ] Product list filters by collection
- [ ] Collections shown on seller preview page

---

### Phase 7 — Procurement & inventory control (supermarkets + hardware stores)

If you don’t manage purchasing/receiving and stock counts, inventory accuracy collapses and online stock will oversell.

Backend
- [x] Suppliers (CRUD) + supplier contacts
- [x] Purchase orders (create/cancel; printable PO pending)
- [x] Goods received note (GRN): receive stock into an outlet with cost price
- [ ] Supplier credit (optional): track payables and partial payments
- [ ] Stock transfers between outlets (request/approve/receive) (blocked: backend is single-outlet today)
- [x] Stock count (stocktake): post variance as adjustments (append-only)
- [ ] Batch/expiry support (optional but important for supermarkets)
- [ ] Serial number tracking (optional; electronics/hardware)
- [~] Units of measure + decimal quantities (units exist; fractional qty pending)

Flutter
- [x] Suppliers module (simple)
- [x] Receive stock flow (scan/search item, enter qty + cost)
- [ ] Stock transfer flow (outlet → outlet)
- [~] Stock count flow (offline-first; “count all items” UX + performance pending)
- [x] Low-stock reorder suggestions (simple thresholds)
- [ ] Update local schema to support decimal quantities where required (hardware/weighted items)

---

### Phase 8 — Pricing, promotions, loyalty (omni-channel)

Backend
- [ ] Separate price types (in-store vs online) or explicit “same price” flag
- [ ] Price lists per outlet (optional)
- [ ] Promotions engine:
  - Item discount, cart discount, buy X get Y, bundles
  - Time windows + usage limits
- [ ] Loyalty basics (optional):
  - Points accrual + redemption
  - Customer tiers
- [ ] Gift cards/vouchers (optional)

Flutter
- [ ] Simple “price + availability” editor with clear publish states
- [ ] Promotions UI that doesn’t overwhelm (wizard + presets)
- [ ] Loyalty: lightweight customer wallet/points view (if enabled)

---

### Phase 9 — Returns, exchanges, warranties (retail reality)

Backend
- [ ] POS returns/exchanges are ledger adjustments (append-only)
- [ ] Restock rules per item (restock vs damaged)
- [ ] Warranty/repair intake (optional for hardware/electronics)

Flutter
- [ ] Return flow from receipt lookup (scan QR/receipt number)
- [ ] Exchange flow (return + new sale in one guided UX)
- [ ] Manager approval required (PIN) for returns beyond limits

---

### Phase 10 — Omni-channel unification (marketplace + in-person)

This is the “single brain” that keeps online and POS consistent.

Backend
- [ ] Single inventory source of truth:
  - Online order reserves/consumes stock
  - POS consumes stock
  - Transfers/stocktakes adjust stock
- [ ] Oversell protection (atomic stock decrement + reservation)
- [ ] Webhooks/events (optional): push order updates to devices
- [ ] Unified reporting from ledger + marketplace orders (same KPIs)

Flutter
- [ ] One catalog, two channels:
  - Per item: “Sell in store” + “Sell online” toggles
  - Clear “Available online” qty if you support channel allocation
- [ ] One “Orders inbox” that merges marketplace + bookings + returns

---

### Phase 11 — Messaging (SMS/WhatsApp) + lightweight CRM

SMEs live in WhatsApp. Receipts and order updates must reach the customer.

Backend
- [ ] Message templates (receipt, order status, pickup ready)
- [ ] SMS/WhatsApp provider integration + delivery receipts
- [ ] Consent/opt-out tracking (compliance)

Flutter
- [x] One-tap send receipt via WhatsApp from completed sale
- [~] Customer contact card with last interactions + notes

---

### Phase 12 — Hardware + device fleet management (terminal-ready)

Backend
- [ ] Device registration + device roles (POS device vs admin device)
- [ ] Remote config (printer settings, tax, receipt header, feature flags)
- [ ] Remote lock/logout + session policies

Flutter
- [x] Barcode scanning (fast flow, offline search)
- [x] Thermal printing pipeline + retry queue
- [ ] Cash drawer trigger (if supported)
- [ ] Optional scale integration for weighted items

---

### Phase 13 — Data export, backups, and operations

Backend
- [ ] CSV export endpoints (products, customers, ledger, inventory)
- [ ] Backup/restore story for sellers (at least export + support tooling)
- [ ] Observability dashboards for seller POS sync health

Flutter
- [x] Export flows (share CSV/PDF)
- [x] “Sync health” diagnostics page (queue size, last sync, failures)

## UX / Design system — Steve Jobs standard (Amazon patterns)

### Hard constraints (enforce in code)
- [ ] 8pt grid everywhere (padding/margins are multiples of 8)
- [ ] Only 3 font sizes across core UI:
  - Small (12–13), Body (15–16), Title (20–22)
- [ ] Only 3 gray shades in the whole app (define tokens)
- [x] Replace dialogs with bottom sheets for actions and edits
- [ ] Every screen has one primary action; remove competing CTAs
- [ ] “Remove 20%” pass: delete UI elements that don’t help sellers run the business

### Amazon.com patterns to adopt (seller preview + fast decisions)
- [ ] Hero imagery:
  - Image carousel with clear left/right controls
  - Quick zoom + full-screen viewer
- [ ] Price / availability / urgency in one tight section:
  - Price
  - Stock now
  - “Low stock” / “Fast moving” indicator
- [ ] Streamlined add-to-cart:
  - One tap add
  - Quantity controls in-place
  - Sticky cart summary on wide layouts
- [ ] Inline reviews preview (seller needs feedback fast)
- [ ] Tabbed specifications:
  - Overview / Specs / Reviews / Logistics

### Screens to redesign (brutal simplification targets)
- [ ] Checkout: remove non-essential chrome; make scanning and cart primary
- [ ] Items: replace switches with clearer publish state + edit
- [ ] Orders: show “next action” first (ship / confirm / cancel)
- [ ] More: reduce tile count, group tools into 5–7 sections max

---

## Engineering quality checklist (release gates)

Backend (Laravel)
- [x] Contract tests for ledger idempotency (same key ⇒ same result)
- [x] DB constraints to prevent duplicates (unique idempotency_key per seller/outlet)
- [ ] Observability: structured logs, request IDs, error reporting
- [~] Rate limiting + auth hardening for seller APIs

Flutter
- [ ] Integration tests for:
  - Offline sale → online sync (no duplicates)
  - Retry after crash mid-sync
  - Manager PIN required for refund/void
- [ ] Performance budgets (startup time, list FPS)
- [~] Crash reporting + analytics event schema (local telemetry log + export; remote pending)

---

## Current status summary (quick)

- Catalog offline-first (products/services): `[~]` delta pull + image uploads + variant stocks exist; still needs full variant builder + taxes/attributes parity vs web.
- POS ledger: `[~]` local append-only ledger + refunds exist; backend v2 ledger + idempotency acks + atomic inventory exist; voids + RBAC enforcement pending.
- Orders: `[x]` marketplace orders list/details/status updates + caching + invoice PDF.
- Business management: `[~]` partial scaffolding; not end-to-end.
- Ads: `[~]` UI placeholder; needs real template workflow.
- Design system: `[ ]` not enforced; needs tokens + simplification pass.

---

## Next “production readiness” milestone (recommended)

**Milestone M1 — Offline sale without duplicates**
- [x] Backend adds idempotent ledger endpoint with ack response
- [x] Flutter sync only marks ledger synced on ack
- [~] Manual test script passes:
  1) Create sale offline
  2) Kill app
  3) Relaunch, go online
  4) Sale appears exactly once in backend

---

## Manual Test Script — Offline sale → online sync → no duplicates

### Preconditions
- Backend deployed with:
  - `POST /api/v2/seller/pos/ledger-entries` (idempotent)
  - `GET /api/v2/seller/pos/sync/pull?since=...`
- Seller has at least 1 product in catalog.
- Seller Terminal is logged in (valid token) and has Sync started.

### Steps (app)
1. Disable connectivity (airplane mode).
2. In the app: go to Checkout → add 1 item → complete sale.
3. (Optional) Repeat step 2 for a second sale.
4. Force-stop / kill the app.
5. Re-open the app (still offline) and confirm sales are still visible locally.
6. Re-enable connectivity (Wi‑Fi or mobile data).
7. Wait up to 1 minute (or open Settings → “Start Sync” to trigger the pump).

### Expected (app)
- Each local ledger entry transitions from pending → synced only after server ack.
- No duplicate synced entries appear locally after retries/app restart.

### Steps (backend idempotency sanity check)
1. Make a ledger POST with a chosen `Idempotency-Key`.
2. Repeat the same POST with the same `Idempotency-Key` and identical body.

### Expected (backend)
- The second request returns the *exact same* JSON body as the first (same `server_entry_id`, same `received_at`).
- Server stores only one ledger entry for that idempotency key.
