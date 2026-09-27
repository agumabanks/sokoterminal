# Staff shop login and POS sheet

Staff sign-in now explicitly uses the shop owner's login phone number plus the staff member's unique 4–8 digit PIN. A separate staff link is shown on owner login; staff setup explains the credentials. Backend resolves the seller by normalized phone and the active staff by seller-scoped PIN HMAC, checks the PIN hash and shop availability, then issues a staff:pos token and a 12-hour POS session. Session token/metadata are stored before opening POS. Named staff tokens are bound to their staff identity during session use and PIN session switching; disabled staff are rejected. Existing legacy phone login requests without login_mode retain compatibility.

Cross-shop entry checks pending sync work before clearing cached shop data. Owner passwords are not shared with staff. Cashier/manager permissions remain enforced by existing middleware.

POS product sheet has an opaque white Material surface, clipped rounded corners, variant option cards displaying price and available stock, unavailable options disabled, and an available initial option. Quantity shortcuts, typed quantity, wholesale ranges and automatic price calculation remain.

Validation: changed app analysis clean; 5 targeted Flutter tests passed; 4 backend tests / 24 assertions passed including wrong PIN, disabled staff, correct shop and staff-only token/session issuance. PHP middleware syntax checked. Release/device results appended below.

Release build succeeded (149.2 MB), ADB install -r returned Success, MainActivity launched. OPPO currently displays Staff Login / Enter staff PIN. No PIN entered; live sheet verification is blocked by the login screen. Sheet behavior is covered by the passing widget test and opaque Material/modal surfaces are explicit in code.
