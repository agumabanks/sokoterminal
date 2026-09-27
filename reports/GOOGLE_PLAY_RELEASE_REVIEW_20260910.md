# Soko Seller Terminal: release review — 10 September 2026

Scope: fix the Seller SMS action layout and audit non-signing Google Play release risks. This is a source/artifact/device review, not a Play Console approval or complete security audit. Signing is excluded. Existing unrelated work was preserved.

## Fixed in this update

- Seller SMS: Queue campaign and Save template now stack as full-width rounded rectangular actions. Explicit spacing/padding prevents the narrow oval buttons and vertical label wrapping seen on the OPPO screenshot. Busy states disable the corresponding action.
- Splash: removed blanket contacts, location, notification and Bluetooth prompts before login. Contacts/location already request permission within their features; FCM handles notification permission. Settings requests Bluetooth connection access when enabling or choosing a printer. The permission plugin handles pre-Android-12 compatibility.
- Contacts and Settings: opt-in explains upload of names, phone numbers and emails to the shop's Soko24 customer list across terminals. Users can decline or stop future syncing. Turning sync off does not promise deletion of previously uploaded contacts.
- Settings: added “Request account deletion”, opening the existing public request form. Replaced a placeholder support phone number with the live support page.
- Android manifest: explicitly removes inherited advertising ID / AdServices ID and attribution permissions. Analytics is already deactivated in the manifest. Bluetooth and location hardware are optional, so these features do not unnecessarily exclude devices.

## Remaining release risks

### High: additional native-library alignment findings

A deeper check of the rebuilt APK found nonzero `(GNU_RELRO VirtAddr + MemSiz) % 16384` in 24 of 34 checked 64-bit libraries, including FFmpeg, Flutter and other bundled dependencies. LOAD segment alignment and APK ZIP alignment pass, but the RELRO check in the current Android guidance flags these artifacts. See `native_alignment_20260910.json`. Investigate/update or rebuild affected libraries with the appropriate linker configuration and run a real 16 KB runtime test before claiming compatibility. The 4 KB OPPO cannot resolve this finding. No native binaries were patched.

### High: paid digital subscriptions use the external wallet

`lib/src/features/wallet/seller_wallet_screen.dart` buys `seller_subscription` products through a wallet funded by hosted external payment. `lib/src/features/ads/studio_entitlements.dart` uses paid subscription state to control Studio watermark/features. No Play Billing integration was found. This is a likely policy gap for digital app functionality, unless a documented exception or enrolled regional program applies. Resolve with Play Billing or a policy-compliant Play distribution design before submission. Do not assume external wallet funding makes a digital purchase exempt.

Physical goods, in-person services, delivery and POS customer payment links are distinct: Google Play Billing must not be used for the physical-goods/services categories. SMS telecommunications credits need classification separately from Studio subscriptions. [Google Payments policy](https://support.google.com/googleplay/android-developer/answer/9858738?hl=en), [Payments policy explanation](https://support.google.com/googleplay/android-developer/answer/10281818?hl=en).

### High: deletion request processing still needs certification

The app now exposes the request pathway, and `https://soko24.co/account/delete-request` returned HTTP 200 without login. Backend routes and `ContactController::submitDeleteRequest` already record a Contact entry and queue an admin email. This is a request workflow, not verified end-to-end erasure.

Before release, verify with a dedicated test account that the request is recorded, the administrator receives it, identity is verified, account access is revoked, and applicable associated data is deleted/anonymised. Document retention periods and reasons for transaction/tax/fraud records. The form currently requires email and a reason, though seller login is phone-based; simplify this friction and state expected response time. No live deletion or outbound email was triggered during this audit. [Account-deletion requirements](https://support.google.com/googleplay/android-developer/answer/13327111?hl=en-EN).

### High: privacy policy and Data safety must describe the seller app

The public privacy page returned HTTP 200. It describes Soko24 and its seller operating system, selected media, location, payments and Firebase. Its contacts explanation focuses on discovering existing Soko24 users, whereas this terminal uploads contacts for shop CRM and marketing. Update that description and ensure staff profiles/roles, sales/customer records, uploads, SMS campaigns, diagnostics and third-party processors are represented accurately. Match the exact app/developer name used in the listing. Avoid claiming data stays on-device when sync uploads it.

Complete Data safety from actual server and SDK behavior, including collection versus sharing, encryption, deletion and optional versus required data. Android permission removal alone does not answer Data safety. Review Firebase runtime configuration too: analytics is manifest-deactivated, while Firebase messaging/diagnostics have separate runtime paths. [User data policy](https://support.google.com/googleplay/android-developer/answer/10144311?hl=en).

### Required Console work, not verified here

- Provide a reusable review shop login and staff PIN, clear owner/staff instructions, and access to paid/restricted screens. Do not rely on reviewer access to the OPPO or an OTP. [Review access requirements](https://support.google.com/googleplay/android-developer/answer/15748846?hl=en).
- Complete accurate Financial features declarations: the app has seller-wallet/payment functionality and a BNPL settings route. Determine which functionality is actually offered in each release market; do not classify it automatically as a personal-loan app. [Financial declaration](https://support.google.com/googleplay/android-developer/answer/13849271?hl=en).
- Check App content, content rating, target audience, ads declaration, store assets, support details, testing-track and developer-account requirements in the actual Console. Generating seller ads does not by itself mean the app displays third-party advertising.
- Compare versionCode 2028 against every previously uploaded artifact. A new upload needs an unused/increasing code. This review did not change it without knowing Console history.
- Run Play pre-launch testing and Android 15/16 edge-to-edge, keyboard, permission-denial and back-navigation tests. The connected OPPO is a 4 KB page-size device, so it cannot certify 16 KB runtime behavior.

## Technical evidence and limits

- Baseline release package: `com.soko24.soko_seller_terminal`, version `2.0.3+2028`, minimum API 24, target API 36; arm64-v8a, armeabi-v7a and x86_64. Target API 36 meets the current phone/tablet target requirement. [Target API policy](https://support.google.com/googleplay/android-developer/answer/11926878?hl=en).
- AGP 8.9.1. Native-library LOAD alignment passed for all 34 checked 64-bit libraries in the baseline APK. Final artifact results are recorded below. ELF/ZIP alignment is necessary evidence, not a substitute for a 16 KB runtime test. [Android 16 KB guidance](https://developer.android.com/guide/practices/page-sizes).
- No broad READ_MEDIA_IMAGES/VIDEO or external-storage access, SMS-reading/sending permissions, or QUERY_ALL_PACKAGES in the audited merged APK permissions. SMS campaigns use the backend rather than device SMS permissions.
- HTTPS required (`usesCleartextTraffic=false`), backups disabled, release manifest not debuggable. Bundled `.env` keys are API URL, timeout and logging configuration; no secret values were printed or copied into this report.
- A geolocator location service is inherited in the merged manifest. No foreground location-stream usage was found in app Dart source; test any future background location feature separately, including foreground-service permissions and declarations.
- Standard icon tree shaking remains incompatible with existing dynamic IconData. Build with `--no-tree-shake-icons`; this increases size but is not itself a Play policy blocker.
- Tests: all six SMS/wholesale/POS-sheet regression tests passed, including 320 px width with 1.5× text, action callbacks/busy states, range removal, tier boundaries/validation and entering 100 units.
- Targeted Flutter analysis: no issues in SMS, Settings, splash and Contacts files.

## Final build and device verification

Intermediate release APKs built successfully (149.2 MB). The final Inbox-inclusive build and phone verification are recorded below. An AAB was not generated in this audit; generate and inspect the Play bundle after resolving the open release findings.

## Follow-up: Orders, visible Alerts tab and SMS

The OPPO showed that `ffUnifiedInbox` selects `InboxScreen` for the bottom Alerts tab. Its order, booking and stock tap handlers were empty. These now open an opaque, scrollable summary sheet with status and a link to the corresponding order, bookings or stock screen. The tab title now reads Alerts, and list bottom padding clears the navigation bar. Notification details no longer dump raw backend payload keys into the user interface.

The alternative notifications screen now opens details immediately without waiting for mark-read API completion. Stock sheets are opaque and scrollable too. Removed a misleading Undo button that only reloaded after deleting a notification.

Orders filter chips wrap on narrow phones; a test reproduced the former 35 px horizontal overflow at 320 px. Summary now says Order value and excludes cancelled orders, instead of presenting all order totals as Revenue. Large summary values use compact notation. Cached orders show a refresh warning when fetching fails; populated lists remain pull-to-refreshable.

Automated coverage: 13 tests passed together across Alerts/Orders, full SMS dashboard, SMS action layout, marketplace-order models, wholesale editing/pricing and POS quantities. After adding the actual unified Inbox regression, its 3-test file passed (14 distinct focused tests overall). Mock APIs were used; tests sent no SMS and changed no live order status. The full SMS test checks backend-shaped balance data, scrolls to Queue campaign, verifies empty-message validation, switches to Activity, and verifies no campaign API call.

Targeted static analysis passed for the earlier changed screens; Inbox had one style-only missing-braces lint, corrected before the final build.

### Final installed artifact

Final build completed successfully with `flutter build apk --release --no-tree-shake-icons` (149.2 MB). `adb -s 7aef1a4c install -r` returned Success; app launched into the existing shop's POS. Final package still targets API 36, contains arm64/arm32/x86_64 and passes `zipalign -c -P 16 4`. Only faketouch/portrait remain required hardware features in badging; Bluetooth/location are optional. Final native report retains 24 RELRO findings out of 34 64-bit libraries.

Verified visually on the OPPO after installation:

- Active combined Alerts tab: tapping an order opens an opaque white summary sheet showing status, View order and Close. Closed the sheet successfully.
- Seller SMS: backend balance and recipient count loaded; Queue campaign and Save template display clearly as full-width rectangular buttons above the navigation bar.
- Orders: live orders loaded, compact UGX 1.19M summary displayed, both filter controls visible.

Screenshots: `screenshots/oppo-alert-sheet-20260910.png`, `screenshots/oppo-sms-actions-20260910.png`, `screenshots/oppo-orders-20260910.png`. The “Needs…” floating overlay belongs to the separate Amara app. It was not modified. Order detail/customer data are real test-shop data; avoid using these screenshots as public store assets without review.

Result: tested UI update installed successfully. Google Play submission is still gated by the unresolved findings above; this is not a claim of full release readiness.
