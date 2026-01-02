# Release Ops (Android / Play Store)

This doc captures the repo + Play Console steps required to ship **Soko Seller Terminal** to paying sellers on Google Play.

## 1) Android release signing (required)

Release builds are configured to **fail** if signing is not provided.

### Preflight (recommended before any release build)

- `bash scripts/release_preflight.sh`

### Option A — `android/key.properties` (recommended for local builds)

1. Generate a keystore (example):
   - `keytool -genkey -v -keystore release.jks -keyalg RSA -keysize 2048 -validity 10000 -alias soko`
2. Create `app/soko_seller_terminal/android/key.properties` (do not commit it):
   - see `app/soko_seller_terminal/android/key.properties.example`
3. Build:
   - `flutter build appbundle --release`
   - or `bash scripts/build_release_aab.sh`

### Option B — Environment variables (recommended for CI)

Set:
- `STORE_FILE`
- `STORE_PASSWORD`
- `KEY_ALIAS`
- `KEY_PASSWORD`

Then build with `flutter build appbundle --release`.

## 1B) Production API base URL (release-safe)

The app loads `assets/config/.env` by default (fallback: `.env.example`).

For CI or multi-environment builds, you can override without editing files:
- `flutter build appbundle --release --dart-define=API_BASE_URL=https://YOUR_DOMAIN/api/`

## 2) Crash reporting (Crashlytics)

- Flutter runtime Crashlytics is initialized in `app/soko_seller_terminal/lib/main.dart`.
- Android Gradle plugin `com.google.firebase.crashlytics` is applied so **R8 mapping files upload** works for release builds.

## 3) Privacy policy + Data Safety (Play Console)

- In-app link: `More → Settings → Privacy policy` (opens `${API_BASE_URL without /api}/privacy-policy`).
- Android permissions:
  - `READ_CONTACTS` is declared for optional contacts import.
  - `WRITE_CONTACTS` is removed (not used).

Before submitting to Play Store, complete:
- Privacy policy URL (use your production domain)
- Data Safety form (declare contacts usage if you keep `READ_CONTACTS`)
- Content rating
- App access instructions (if any auth is required for reviewers)

## 4) Release checklist (minimum)

- `flutter analyze`
- `flutter test`
- Run printing QA on at least 3 common thermal models (see `app/soko_seller_terminal/PRINTING_QA.md`)
- Verify crash-free rate + key funnels in Firebase dashboards after staged rollout

## 5) CI release build (optional, recommended)

GitHub Actions workflow: `.github/workflows/seller_terminal_release.yml`

Required GitHub Secrets:
- `ANDROID_KEYSTORE_BASE64` (base64 of your `release.jks`)
- `STORE_PASSWORD`
- `KEY_ALIAS`
- `KEY_PASSWORD`
