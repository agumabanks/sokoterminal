# Play Console Checklist (GA rollout)

This is the shortest safe path to shipping **Soko Seller Terminal** to paying sellers.

## A) Before upload (repo)

- [ ] `flutter analyze`
- [ ] `flutter test`
- [ ] Release signing configured (`android/key.properties` or CI env vars)
- [ ] Build AAB: `flutter build appbundle --release`
- [ ] Confirm API URL for this build:
  - [ ] `assets/config/.env` OR `--dart-define=API_BASE_URL=...`

## B) Play Console setup (one-time)

- [ ] App details: name, short description, full description
- [ ] Graphics: screenshots (phone + tablet if you claim support), feature graphic, app icon
- [ ] Privacy policy URL (must be public)
- [ ] Data Safety form completed (declare contacts usage if `READ_CONTACTS` is enabled)
- [ ] Content rating completed
- [ ] App access instructions for reviewers (seller test account + steps)

## C) Internal testing (fast sanity)

- [ ] Upload AAB to Internal testing
- [ ] Install from Play
- [ ] Verify core flows:
  - [ ] Login
  - [ ] Sync pull works (products show)
  - [ ] POS sale → receipt number → print/share
  - [ ] Refund (manager PIN) → correct ledger/report
  - [ ] Void (manager PIN + reason code) → correct ledger/report
  - [ ] Expenses (if enabled) → reports reflect; cashouts link

## D) Closed testing (pilot paying sellers)

- [ ] Create pilot cohort (10–50)
- [ ] Enable only required feature flags (Remote Config)
- [ ] Support channel ready (WhatsApp + escalation)
- [ ] Daily monitoring checklist (Crashlytics + key telemetry)

## E) Production staged rollout (recommended)

- [ ] 5% rollout for 24h (watch crash-free, ANR, print_fail, sync_op_blocked)
- [ ] 20% rollout for 24h
- [ ] 50% rollout for 24–48h
- [ ] 100% rollout when stable

