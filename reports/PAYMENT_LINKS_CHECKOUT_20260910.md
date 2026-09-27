# Checkout payment links and catalog fixes — 10 September 2026

Implemented in the Seller Terminal and `/var/www/soko/apps/backend-laravel`.

- Checkout offers Payment Link beside Cash. It submits the synced product/service cart, quantities, variants, POS prices and tax. A generated link clears the active cart without recording a paid cash sale. Backend fulfillment happens after gateway confirmation.
- Me → Payment Links includes a searchable catalog picker. Product details also expose link generation. The generator accepts a unit price, quantity and editable service fee (default 5%). UGX 10,000 × 3 + 5% = UGX 31,500. The customer payment page displays the saved breakdown.
- Link amounts are fixed at generation. Existing API callers retain quantity 1 and zero fee defaults. Checkout creation requires an idempotency key and preserves existing seller/staff session restrictions.
- Checkout links expire after seven days and close after payment. Pending checkout can be resumed by the same buyer. Callback processing records all cart lines and purchased quantities; duplicate callbacks do not duplicate orders or stock deductions. Mixed carts create product orders and service bookings linked to the same payment attempt.
- Fully paid service links no longer leave a deposit balance outstanding. Service booking metadata records purchased quantity.
- Product updates use a sync-operation-specific request key, so later edits do not conflict with the original create request. Failed image uploads retain the unsynced edit. Catalog pulls preserve unsynced local edits and apply cleared gallery/cover/description fields from the backend.
- Product details render saved HTML descriptions. Service galleries support full-screen swiping and zooming.

Validation:
- `php artisan test --filter=PaymentLinkQuantityTest`: 10 passed, 35 assertions (in-memory SQLite; gateway mocked).
- Three payment-sheet widget tests passed, covering quantity/fee preview, invalid input, single submission and full-cart payload.
- Existing cart, sync, service HTML and pricing tests passed; final sync regression run: five passed.
- Scoped Flutter analysis: no issues. PHP syntax and diff whitespace checks passed.
- Checkout route verified with seller authentication, attached/required POS session and write throttling.

No database schema changes. No live payment or device installation performed. The release build requires `flutter build apk --release --no-tree-shake-icons` because existing ads editor code constructs dynamic IconData values. The signed release APK build passed. Artifact: `build/app/outputs/flutter-apk/app-release.apk`. Run release builds after tests have finished so test tooling cannot rewrite plugin registrations during compilation.
