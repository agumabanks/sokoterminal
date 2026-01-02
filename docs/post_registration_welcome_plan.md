# Post-Registration Welcome Experience Plan (Full Spec)

## Goal
Deliver a post-registration welcome moment that feels Apple-like: minimal, calm, and confident. The user should immediately understand they are ready to start and be guided to their next step with one clear choice.

## Desired Flow
1. Registration success triggers a welcome experience.
2. Welcome message confirms the account is ready.
3. User chooses one of the following:
   - Add products -> route to `\`/home/more/items\``
   - Add services -> route to `\`/home/more/services\``
   - Guided setup (optional help) -> route to `\`/home/more/business-setup\``
4. A subtle option remains to continue to checkout -> route to `\`/home/checkout\``

## UI Direction (Steve Jobs-like)
- Minimal copy, strong hierarchy, generous spacing.
- Light glass card, neutral palette, soft shadow.
- One primary action, one secondary action, optional guided setup link.
- Remove busy visual elements; keep it clean and intentional.
- Use a single focal icon (checkmark) with light accent.
- Keep fonts crisp; avoid heavy gradients or noisy textures.

## UX Copy (Final)
- Title: `\`Soko 24 Terminal\``
- Subtitle: `\`Your account is ready. Choose where to begin.\``
- Primary CTA: `\`Add products\``
- Secondary CTA: `\`Add services\``
- Help prompt: `\`Need help getting started?\``
- Help CTA: `\`Show the guided setup\``
- Soft exit: `\`Continue to Checkout →\``

## Layout/Component Notes
- Use a dialog or full-screen sheet immediately after registration success.
- Keep the "welcome" wording short and direct.
- Avoid long descriptions; use a single line to explain the next step.
- Buttons should have a consistent height, soft corner radius, and clear separation.
- Ensure the dialog can be dismissed only by choosing an option (no background dismiss).

## Visual System
- Background: white to near-white gradient `\`#FFFFFF -> #F5F6FA\``
- Border: `\`#E2E3E7\``
- Primary text: `\`#1C1C1E\``
- Secondary text: `\`#636366\``
- Accent: `\`#5CC7B5\``
- Shadow: soft, low contrast, y-offset ~14px, blur ~24px

## Acceptance Criteria
- Welcome appears after a successful registration.
- User can choose Products, Services, or Guided Setup.
- Each choice navigates correctly.
- Checkout option is available but visually subdued.
- Welcome dialog cannot be dismissed by tapping outside.
- Dialog supports small screens without overflow.

## Routing and Logic
- `\`_showPostRegistrationWelcome\`` must handle four outcomes:
  - `\`products\`` -> `\`/home/more/items\``
  - `\`services\`` -> `\`/home/more/services\``
  - `\`guidedSetup\`` -> `\`/home/more/business-setup\``
  - `\`checkout\`` -> `\`/home/checkout\``

## State Handling
- Handle case where registration response completes, then navigation occurs.
- Ensure `\`mounted\`` checks before navigation.
- Avoid showing the dialog twice on retries.

## Analytics (Optional but Recommended)
- Emit a single event: `\`post_registration_choice\``
- Properties:
  - `\`choice\``: products | services | guided_setup | checkout
  - `\`device\``: optional (from device info)
  - `\`timestamp\``

## Accessibility
- All action buttons must have minimum 44px height.
- Use `\`Semantics\`` labels for the help action.
- Ensure contrast ratio for primary/secondary text is acceptable on white.

## Error Handling
- If navigation fails, show a small banner: `\`Unable to continue. Try again.\``
- If guided setup route is unavailable, fallback to `\`/home/checkout\`` with an alert.

## Implementation Touchpoints
- `lib/src/features/auth/seller_registration_screen.dart`
  - `\`_showPostRegistrationWelcome\`` routes based on user choice.
  - `\`_PostRegistrationDialog\`` implements the UI and copy.
- `\`/home/more/business-setup\`` is the guided setup entry point.

## Implementation Tasks
1. Confirm dialog styling matches the visual system above.
2. Confirm the four choice routes are wired.
3. Add optional analytics event if telemetry exists.
4. Validate on small screens and with dynamic text sizing.

## Testing Checklist
- Registration success shows dialog consistently.
- Products -> navigates to items list.
- Services -> navigates to services list.
- Guided setup -> navigates to business setup wizard.
- Checkout -> navigates to checkout.
- No dismiss on background tap.
- No overflow on small devices.

## Future Enhancements (Optional)
- Add a brief, dismissible tour overlay after guided setup.
- Capture deeper analytics for first-week seller behavior.
