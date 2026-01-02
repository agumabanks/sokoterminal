# Printing QA & Certification (GA)

This doc defines the printer QA process for **Soko Seller Terminal** and the minimum evidence needed before enabling printing by default for all paying sellers.

## What the app provides (repo deliverables)

- **Print queue** with retries + last error visibility: `More → Settings → Print queue`
- **Print diagnostics** (permissions, paired printers, test print, shareable log): `More → Settings → Print diagnostics`
- **Compatibility mode** toggle to reduce printer-specific failures (disables QR + paper cut).
- **Telemetry** for print reliability:
  - `print_test`
  - `print_success`
  - `print_fail` (with `error_type`)
  - `print_retry_count`

## Certified printers (initial targets)

These models are common in UG retail. “Certified” means we have run the full QA checklist below on a real device and have clean output.

| Printer model family | Paper | Connection | Status | Notes |
|---|---:|---|---|---|
| XPrinter (XP-P323B / XP-58) | 58mm | Bluetooth | Pending | Usually works with compatibility mode OFF |
| ZJ-58 / ZJ-5890 | 58mm | Bluetooth | Pending | Often needs compatibility mode ON |
| MTP-II / MTP-2 | 58mm | Bluetooth | Pending | Verify character set + line spacing |
| SPRT | 58/80mm | Bluetooth | Pending | Verify QR + paper cut support |
| Gprinter | 58/80mm | Bluetooth | Pending | Verify partial cut behavior |

Update this table after each device pass and keep screenshots (or photos) of the printed outputs in the release QA folder.

## Manual QA checklist (required before “Certified”)

Perform all steps on:
- Android 10–14 (at least 2 OS versions)
- at least 2 device brands (e.g., Samsung + Tecno/Infinix)
- each printer model you intend to certify

### A) Pairing + permissions

1. Pair printer in Android Bluetooth settings.
2. In app: `Settings → Choose printer` and select the paired printer.
3. In app: `Settings → Print diagnostics`:
   - permissions show as granted (or diagnostics shows a clear actionable error)
   - paired printer shows as detected

### B) Test print

1. From `Print diagnostics`, tap **Test print**.
2. Expected:
   - prints “Soko Seller Terminal / Test print OK / timestamp”
   - no missing characters / garbled symbols

If it fails:
- enable **Compatibility mode**
- retry test print
- share diagnostics log to engineering/support

### C) Real receipt print (POS flow)

1. Create a sale with:
   - at least 2 line items (include a variant item if possible)
   - a discount (optional)
   - a non-cash payment method (if configured)
2. Complete the sale, then print the receipt.
3. Expected:
   - totals match the app
   - alignment is correct (no wrapping in totals area)
   - barcode/QR (if enabled) scans successfully

### D) Stress + reliability

1. Print the same receipt 5 times (reprint flow).
2. Force-stop the app, re-open, print again.
3. Turn off Bluetooth mid-print, then turn it back on:
   - print queue should retry and eventually succeed
4. Expected:
   - no app crash
   - print queue shows failures with helpful last error
   - retry succeeds without duplicating ledger entries (printing is separate from money/ledger)

### E) Compatibility mode validation

1. Repeat B + C with compatibility mode ON.
2. Expected:
   - print succeeds even on weaker models
   - QR + paper cut are disabled (by design)

## Troubleshooting guide (operator-friendly)

- **No paired printers found**
  - Pair the printer in Android Bluetooth settings first, then return to the app.
- **Permission denied**
  - Open app settings from Print diagnostics and allow Bluetooth permissions.
- **Connect failed / printer not found**
  - Ensure the printer is ON and within range; unpair + pair again; re-select printer.
- **Garbled text**
  - Enable Compatibility mode; confirm printer is in ESC/POS mode (vendor setting).
- **Paper cut issues**
  - Enable Compatibility mode (paper cut disabled); use manual tear.

## What blocks GA

- Any “Certified” model with >1% failure rate during the stress test, without a clear mitigation (compatibility mode / operator steps).
- Any crash in print flows (Crashlytics must stay clean on release builds).
- Any printer model that prints wrong totals (must be fixed before onboarding paying sellers).

