# Soko Seller Terminal Progress Checker

Date: 2026-03-08
Scope: `app/soko_seller_terminal`

## Current verdict

The app is the correct seller/POS terminal codebase and is materially closer to release than the buyer app previously reviewed. Core auth, POS, orders, stock, receipts, staff, and release docs already exist.

The app now has a freshly built production-signed Android App Bundle for the current codebase. Remaining gaps are mostly Play-submission hygiene items, not bundle-generation blockers.

## Checks run

- `flutter test`
  - Status: PASS
  - Result: all tests passed
- `flutter analyze`
  - Status: FAIL
  - Result: initially 214 issues, now down to 182 after the hardening pass
  - Notes: current remaining output is overwhelmingly info-level deprecations and style items; warning-level faults have been nearly eliminated
- `flutter build appbundle --release --no-pub`
  - Status: PASS
  - Result: fresh signed bundle generated at `build/app/outputs/bundle/release/app-release.aab`
- `bash scripts/build_release_aab.sh`
  - Status: PASS
  - Result: preflight, codegen, analyze, tests, and release AAB build completed successfully

## Fixes applied in this pass

- Splash navigation flow hardened
  - Removed route selection from a `finally` block
  - Prevents startup navigation from being hidden behind control flow that can mask failures
  - File: `lib/src/features/splash/splash_screen.dart`
- Connectivity guard hardened
  - Avoids deprecated provider stream usage
  - Avoids using `BuildContext` after the async gap when showing offline warnings
  - File: `lib/src/core/network/connectivity_guard.dart`
- Login async navigation safety tightened
  - Added mounted checks after PIN setup flow
  - Switched dialog navigation guards to `dialogContext.mounted`
  - File: `lib/src/features/auth/login_screen.dart`
- Release preflight strengthened
  - Fails early when signing secrets or `GOOGLE_MAPS_API_KEY` are missing
  - Catches placeholder `CHANGE_ME` values before Gradle work starts
  - File: `scripts/release_preflight.sh`
- Google Maps client key leak removed
  - `PlacesService` no longer embeds a hardcoded Maps key in Dart source
  - Release builds now inject `GOOGLE_MAPS_API_KEY` into Dart via `scripts/build_release_aab.sh`
  - Files: `lib/src/core/services/places_service.dart`, `lib/src/core/config/build_metadata.dart`, `scripts/build_release_aab.sh`
- Seller registration background tasks hardened
  - Delivery-profile upsert and first full resync now run as explicit fire-and-forget tasks with error logging
  - Removes analyzer warnings that were hiding bad async error handling
  - File: `lib/src/features/auth/seller_registration_screen.dart`
- Submission gate tightened
  - Rejects placeholder reviewer credentials more reliably
  - Rejects hardcoded non-Firebase Google API keys in Dart source
  - File: `scripts/play_submission_gate.sh`

## Release checklist status

- [x] Seller terminal shell exists and routes to POS-focused features
- [x] Auth flows exist for seller, staff, and POS PIN sessions
- [x] Automated tests currently pass
- [x] Release preflight now checks signing + Maps secrets before build
- [x] `android/key.properties` or release env vars populated with real values
- [x] Real Google Maps Android API key provided for release builds
- [x] Release secrets present so the stronger preflight/build gates can run end-to-end
- [x] Final release AAB generated and signed with the production keystore
- [ ] Play reviewer access docs filled with real reviewer credentials and current dates

## Remaining blockers to clear before proceeding

1. Play submission inputs
   - Reviewer access details and any final store metadata still need real values, not placeholders
2. Analyzer cleanup debt
   - Remaining output is mainly info-level deprecations and style lints, not warning-level release failures

## Recommended next move

1. Upload the new bundle to Play:
   - `app/soko_seller_terminal/build/app/outputs/bundle/release/app-release.aab`
2. If you want the full Play submission gate clean as well, fill `PLAY_REVIEWER_ACCESS.md` with the real reviewer account for this build.
3. Optionally, continue the info-level analyzer cleanup pass after the release is out.
