# Wholesale checkout and editor polish

Seller POS:
- Wholesale badge on products with configured ranges.
- Cart shows whether wholesale pricing is applied or available.
- Tap the cart quantity to enter a bulk order directly; existing stock clamping and repricing apply.
- Product/service editors show essentials first; photos and online publishing/booking are grouped in an optional expandable section.

Online checkout:
- Web variant quote, web cart, buyer API variant quote, shared cart price helper and cart-add calculation now recognize stock wholesale ranges on ordinary products, independent of the legacy wholesale_product classification.
- Both web and API cart additions price the combined quantity, not just the newly added units.
- Wholesale unit prices are final tier prices; normal product discounts do not stack on them. Outside configured ranges normal retail/discount rules apply.
- Web quantity update evaluates the accepted cart quantity, not an invalid requested quantity.
- Buyer product-card API flags recognize configured ranges.
- Buyer premium product detail source shows ranges and refreshes the API quote when quantity changes, discarding out-of-order responses. These buyer UI changes require a separate buyer-app release; this task installs the Seller Terminal only.

Validation:
- 9 targeted seller Flutter tests passed; changed seller files analyze with no issues.
- 19 targeted backend tests / 73 assertions passed, including ordinary-product wholesale and non-stacking discounts through shared web/mobile pricing helpers.
- Buyer detail file analysis has no compilation errors; existing unused-element/context/deprecation diagnostics remain (11 findings).
- No customer payment or live product mutation performed for validation.

Final checkout dialog also lists the configured quantity ranges and per-item prices. Final checkout analysis: no issues. Final release build succeeded (149.2 MB).

Device verification: ADB installation returned Success. MainActivity launched; process 23587 observed. OPPO package update time 2026-09-10 17:40:13 (device clock). Existing app data preserved.
