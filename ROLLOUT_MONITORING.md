# GA Rollout Monitoring (Soko Seller Terminal)

Use this during staged rollout to avoid breaking paying sellers.

## Minimum SLOs to advance rollout

- Crash-free users: **≥ 99.5%**
- ANR rate: **near-zero**
- Print failure rate (for certified printers): **< 1%**
- Sync health: no spike in `sync_op_blocked` or repeated retries

## What to watch daily (first 7 days)

### Firebase Crashlytics

- [ ] New crash types
- [ ] Crash-free users trend
- [ ] Top devices/OS versions affected

### Firebase Analytics / Telemetry events

Printing:
- `print_test`
- `print_success`
- `print_fail` (inspect `error_type`)
- `print_retry_count`

Sync:
- `sync_op_failed`
- `sync_op_blocked`

Expenses:
- `expense_create_open`
- `expense_create_submit`
- `expense_create_success`
- `expense_create_failed`

Checkout:
- `checkout_cart_qty_changed`

## Rollout rules (feature flags)

Recommended initial state for paying-seller GA:
- Keep OFF: `ff_unified_inbox`, `ff_customer_profile`, `ff_contacts_enrichment`, `ff_soko_studio`
- Pilot-only: `ff_expenses_v1` (enable for a small cohort first, then widen)

If a critical incident happens:
1) Disable the risky feature flag(s) first (Remote Config)
2) Post an operator message to sellers (if you have an in-app channel)
3) Ship a hotfix release if needed

