# Seller Terminal UX expansion

Implemented:
- POS: wholesale/variant products open a bottom sheet with option selection, typed quantity, 1/10/50/100 shortcuts, stock validation, wholesale ranges and line total before adding to cart. Ordinary single-option products retain one-tap add.
- Today: summary revenue and receivables use compact UGX amounts; full amounts remain in sale rows and accessibility labels.
- Alerts: notification and stock-alert taps open a summary sheet with an explicit related-page action.
- Startup: removed initial 350 ms artificial pause, shortened intro animation, capped initial sync wait at 3 seconds while retaining auth/staff checks. Background sync continues after the wait; no measured cold-start speed claim.
- Seller SMS: credit balance and Buy SMS remain visible during module loading/error; existing wallet top-up flow and backend SMS credits retained. Bulk SMS / One person labels clarify modes.
- Customers: searchable name/phone list, detail sheet and call action. Contacts: clearer search hint, removal of a nonfunctional header icon and more visible details affordance.
- Shop Info: logo picker, compressed image upload and local preview, save through existing logo/backend profile sync.
- Staff: optional profile photo for create/edit, photo in list, clearer role explanations. Existing cashier/manager roles and separate menu-access management retained. Backend validates upload ownership and stores photo_upload_id.

Backend migration applied only for the new nullable staff photo column:
`2026_09_10_180000_add_photo_to_pos_staff_members.php`.

Validation:
- Changed app files: no analyzer issues.
- 10 targeted Flutter tests pass, including bulk sheet quantity 100 and stock rejection, wholesale pricing, migration, payments and shifts.
- 6 backend tests / 35 assertions pass: staff photo ownership/persistence, SMS API, file upload security and wholesale.
- No live customer message, payment, staff creation or product edit used during verification.

Photo selection/upload requires connectivity. This adds photos to supported staff roles; it does not introduce arbitrary new permission roles.

Deployment:
- Release build succeeded (149.2 MB); ADB install -r returned Success on OPPO CPH1933, 192.168.1.65:37947.
- MainActivity cold launch returned Status ok; Android reported TotalTime 2388 ms (activity launch metric, not a full end-to-end startup benchmark).
- Live UI verified POS, then tapped an existing wholesale product. Bottom sheet displayed Standard option, quantity 1, 3 available, 1/10/50/100 shortcuts, two wholesale ranges, unit/total amount and Add 1 to sale. Left the sheet open without submitting.
