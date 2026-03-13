# Play Data Safety Notes

This document must match what is submitted in Google Play Data Safety.

## Android Permissions Declared

- `android.permission.READ_CONTACTS`

## Why `READ_CONTACTS` Is Used

- Purpose: optional contact import/enrichment for seller CRM workflows.
- Access model: explicit in-app opt-in and runtime permission prompt.
- App behavior if denied: feature remains disabled; POS core flows still work.

## Data Handling Summary

- Contact access is user-initiated from contacts features.
- Contact data is used for matching/linking customers and CRM sync.
- Core POS operations (sales/expenses/shifts) do not require contacts permission.

## Submission Reminder

Before uploading to production:

1. Ensure Play Data Safety answers explicitly cover contacts collection/use.
2. Ensure privacy policy reflects optional contacts usage.
3. Ensure reviewer instructions include login and fallback auth path.
