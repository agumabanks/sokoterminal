# Terminal stability investigation — 24 September 2026

## Scope and evidence

Investigated the reported digital catalog failure and startup/release paths in the
current working tree. Source declares 2.0.7 (2032); the connected Android phone has
2.0.5 (2030). The rejected Play version and its stack trace were not supplied.
The phone's crash buffer provided no matching evidence. Existing repository device
logs also yielded no matching fatal Flutter/Android exception in the searches run.
These findings therefore identify risks, not Google's confirmed crash cause.

The repository already had extensive uncommitted changes, including a catalog
screen implementation that exports PDFs. Those changes were preserved. No app was
installed, uploaded, or submitted during this investigation.

## Catalog changes made

- `catalog_service.dart`: photo decoding, orientation correction, resizing and JPEG
  encoding previously ran synchronously on the UI isolate, with up to 60 photo loads
  launched together. Processing now runs one photo at a time in a worker isolate.
- `catalog_pdf_image.dart`: check encoded size (16 MiB) and decoded dimensions
  (16,777,216 pixels) before allocating decoded pixels; decode only the first frame;
  reduce the longest edge to 1,000 pixels. Invalid or excessive photos use the
  existing product/service placeholder. This intentionally trades very large image
  inclusion for bounded work; it does not guarantee a fixed process-memory ceiling.
- Font loading now has a three-second wait limit. Missing photo downloads share an
  eight-second wait budget; subsequent entries still use local cached photos. A
  timeout stops awaiting a download, not the cache's underlying network request.
- `catalog_export_review_screen.dart`: set preview resolution to 100 DPI. Installed
  printing plugin 5.14.2 allocates an Android bitmap plus a byte buffer per rasterized
  page, so device-dependent preview resolution increases native memory pressure.
  Exported PDF bytes retain their own image quality independently of preview DPI.
- Sharing failures now produce a retry message instead of escaping the async button
  handler. Native process crashes cannot be recovered by that Dart catch block.

## Startup improvements applied

- `main.dart` now paints a lightweight recoverable `StartupGate` before opening
  preferences and Drift. Migration/open failures show Retry and explicitly retain
  local data rather than leaving a blank screen.
- Firebase Core is initialized before Riverpod providers are created because the
  auth controller may initialize FCM during provider bootstrap. Remote Config,
  Analytics, Crashlytics, telemetry and notification work are deferred until the
  first frame and are best-effort.
- Splash bootstrap has a top-level error boundary with Retry, and the fixed POS
  session delay was removed. The local POS controller can restore cached state while
  its online validation runs in the background.

## Remaining gaps to investigate before release

1. **Startup network waits:** The splash screen still awaits a staff API request
   when connectivity reports a network, which does not guarantee internet access.
   This is now caught and recoverable, but a short request timeout or cached-only
   policy would make first launch faster. It was not reproduced as an ANR here.
2. **Offline PDF fonts:** Nunito is fetched at runtime. Existing Helvetica fallback
   keeps generation working but lacks Unicode coverage. Bundled licensed fonts would
   make non-Latin business names and offline typography more predictable.
3. **Release evidence mismatch:** source tests cannot certify the rejected artifact.
   Obtain its version code, crash stack/device information and exact reproduction
   steps. Exercise that artifact and the candidate fix on a low-memory Android phone,
   including full photo selection, repeated generation, offline launch, staff login,
   and returning/back-navigation while generation is pending.

## Validation

The pre-change catalog tests passed. A six-product PDF with long business details
also generated successfully; no layout crash was reproduced. New regression tests
cover corrupt input, excessive encoded size, oversized image dimensions and photo
resizing, alongside PDF image embedding and catalog-save tests.

- `flutter test --no-pub --reporter expanded`: **230 tests passed**.
- Focused catalog generation/image/save run: **14 tests passed**.
- `flutter analyze --no-pub`: **No issues found**.
- Diff whitespace check for modified tracked catalog files: passed.

Host Flutter tests do not execute Android's native PDF renderer or establish Play
acceptance.
