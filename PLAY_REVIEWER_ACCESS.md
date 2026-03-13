# Play Reviewer App Access (Required For Review)

Fill this file before every Play submission.

## Build Under Review

- App: `Soko Seller Terminal`
- Build date (UTC): `YYYY-MM-DD`
- Version name/code: `x.y.z+N`
- Environment/API: `https://.../api/`

## Reviewer Test Account

- Login phone (international format): `+256XXXXXXXXX`
- Password: `********`
- PIN (if enabled): `******`
- Last verified with `bash scripts/verify_play_reviewer_login.sh`: `YYYY-MM-DD`

## Reviewer Steps

1. Open the app and tap `Sign in`.
2. Enter the test phone above and tap `Continue`.
3. If PIN screen appears:
   - Enter the PIN above, or
   - Tap `Use password instead` and enter the password above.
4. Expected destination after successful auth: `Checkout` (`/home/checkout`).

## What To Verify Quickly

1. Catalog loads on Checkout.
2. Create one expense (`Expenses`), then run `Sync now`.
3. Create one cash out (`Shifts` -> `Cash out`), then run `Sync now`.

## Notes For Reviewer

- First login requires internet.
- After first sync, core POS data is available offline.
- If login fails, use password fallback from the PIN screen (`Use password instead`).
- Use the phone above (not email) on the first login step.
