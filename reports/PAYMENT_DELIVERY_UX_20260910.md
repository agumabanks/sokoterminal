# Payment, catalog, cash and delivery refinement — 10 September 2026

Implemented in the Seller Terminal and Laravel backend:

- Payment breakdowns say **Mobile money charges**, including the hosted web page.
- Payment links share a PNG QR card plus the HTTPS payment URL. The QR encodes `/pay/{code}`; it does not require the Terminal app. Sharing opens the system share sheet.
- Me → Create payment link uses a full-screen searchable product/service picker with category filters, visible list and keyboard-safe layout.
- Product and service editors put essential fields first and collapse optional settings. New services default to catalog-only until the operator chooses online publishing. Explicit empty service galleries and summaries sync to the backend.
- Shifts & Cash has a responsive cash summary, live transaction updates, and validated start/movement/close forms with save guards and closing differences.
- Delivery Area & Fees is reachable from Me. Owners choose radius, free/fixed/distance pricing, shop location and optional ETA. Switching to free clears old fee limits. Existing verification and platform policy remain enforced.
- Backend radius validation and calculation use one policy limit. Outside the seller radius, existing checkout carrier recommendations apply. This does not implement automatic rider dispatch or a new rider marketplace.
- Delivery sync stores the server's accepted profile, including decimal values returned as strings, and preserves pending local edits during refresh.

Validation:
- Targeted Flutter analysis: no issues.
- 8 Flutter widget/unit tests passed (picker with keyboard on a narrow phone, QR PNG and secure URL, quantity/fee submission, reactive shift totals, required opening cash).
- 17 backend tests / 59 assertions passed (payment quantities and checkout links, free/fixed/distance delivery, radius handoff and carrier recommendation).
- OpenCV decoded the generated QR as `https://soko24.co/pay/QRTEST123`.
- No real payment was initiated and no customer message was sent.

Release APK build and device installation status are reported separately. Existing unrelated workspace changes are preserved.

Release result: `flutter build apk --release --no-tree-shake-icons` succeeded (149.1 MB), artifact `build/app/outputs/flutter-apk/app-release.apk`.
Installation blocked: forwarded ADB at `127.0.0.1:5038` timed out, then returned connection refused. This refined APK has not been installed on OPPO `7aef1a4c`.
