# Wholesale pricing in Seller Terminal

The product editor has a Wholesale pricing toggle and rows for minimum quantity, maximum quantity and price per item (UGX), matching the web seller editor. Boundaries are inclusive. Ranges cannot overlap, maximum must exceed minimum, and unit prices must be positive. Disabling wholesale removes saved tiers. Quantities outside the ranges use the normal selling price.

The local Drift database advances from schema 40 to 41 with a nullable item wholesale range JSON column. Product save, queued sync, backend POS catalog upsert and POS catalog pull carry the same min_qty/max_qty/price fields as web stock wholesale prices. Older clients which omit the toggle preserve the backend ranges. The feature uses the web's ordinary product pricing tiers, without changing the separate wholesale_product catalog classification.

Checkout cart lines retain retail price and ranges, calculate unit prices at quantity changes, and persist this pricing context when restoring the active cart. Stock limits remain enforced.

Validation and installation results are appended after completion.

Validation:
- Changed app code analysis: no issues.
- 9 targeted Flutter tests passed, including narrow-phone editor, inclusive range boundaries, checkout repricing back to retail, overlap validation and a real v40 → v41 SQLite upgrade preserving product data.
- 18 targeted Laravel tests passed / 63 assertions (wholesale persistence, payment and delivery regressions).
- Broader PosCatalogProductsTest: 3 failures from the existing test SQLite products schema missing `added_by` (and catalog create returning 500); not counted as passing.
- Product details list wholesale quantity ranges and unit prices.

Release / device result:
- Release APK build succeeded (149.2 MB).
- `adb -s 192.168.1.65:37947 install -r .../app-release.apk`: Success.
- OPPO CPH1933: MainActivity launched successfully, process PID 13904 observed.
- Package lastUpdateTime: 2026-09-10 17:21:27 (device clock), version 2.0.3 / 2028.
- Existing app data preserved. No live product or payment created during device verification.
