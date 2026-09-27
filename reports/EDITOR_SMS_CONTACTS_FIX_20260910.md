# Editor, SMS and contacts layout fixes

- Wholesale editor: padded opaque card, outlined filled fields, spacing before unit price, stable range keys on the list children. Deleting a range preserves the next range's values.
- Product stock quantity and cost are separate full-width fields instead of cramped half-width inputs.
- Photo section: smaller preview, white padded expandable panel, scrollable safe-area photo options sheet.
- SMS and customer lists: additional bottom clearance for navigation controls and drag-to-dismiss keyboard.
- Contacts: recent contacts collapsed by default and hidden while searching/typing, preserving space for the main list.
- Customers list heading clarified.

Five targeted widget/pricing tests pass, including deleting the first wholesale range and retaining values in the remaining row. Analysis initially reported only an unnecessary const, subsequently removed.

Device inspection: screenshot confirmed Soko POS after launch. Amara repeatedly foregrounded itself, preventing reliable traversal of editor/SMS/contacts; requested user pause its automation. No live catalog changes or SMS sends performed.

Release build succeeded (149.2 MB). ADB install -r returned Success. Soko MainActivity launch returned Status ok, TotalTime 3065 ms. Subsequent screenshot again showed Amara foregrounded, so editor/SMS/contacts live visual acceptance remains unverified until its automation is paused. No unrelated app was stopped or modified.
