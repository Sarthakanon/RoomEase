# Flutter Black-Box Integration Tests

RoomEase uses Flutter's official `integration_test` package for app-level black-box testing. These tests launch the real Flutter app and interact with visible UI controls such as login, roomspace selection, expenses, balances, payment confirmation, notifications, and profile navigation.

## Prerequisites

- Keep the local backend running before authenticated tests.
- Keep Docker/Postgres running for backend-backed app flows.
- Use Firebase test accounts for login flows.
- Ensure `lib/core/constants.dart` points to the local backend URL you want to test.

## Commands

```bash
flutter pub get
flutter test -d <deviceId> integration_test
```

Run only the main black-box suite:

```bash
flutter test -d <deviceId> integration_test/app_blackbox_test.dart
```

Run authenticated flows with test credentials:

```bash
flutter test -d <deviceId> integration_test/app_blackbox_test.dart \
  --dart-define=ROOM_EASE_TEST_EMAIL="$ROOM_EASE_TEST_EMAIL" \
  --dart-define=ROOM_EASE_TEST_PASSWORD="$ROOM_EASE_TEST_PASSWORD"
```

These tests are intentionally mobile/emulator focused. Desktop and web targets are skipped because Firebase/Stripe platform channels and the mobile UI flow are not equivalent to the Android/iOS app behavior used for final-report evidence.

Optional roommate credentials are reserved for future roommate/payment-specific scenarios:

```bash
--dart-define=ROOM_EASE_TEST_ROOMMATE_EMAIL="$ROOM_EASE_TEST_ROOMMATE_EMAIL"
--dart-define=ROOM_EASE_TEST_ROOMMATE_PASSWORD="$ROOM_EASE_TEST_ROOMMATE_PASSWORD"
```

## Current Coverage

- App startup and splash-to-login transition.
- Empty login validation.
- Invalid login failure feedback.
- Valid login into authenticated app state when credentials are provided.
- Roomspace create/join validation when the fixture user has no active roomspace.
- Bottom navigation across expenses, analytics, and profile.
- Expense balance overview and payment confirmation smoke flows.
- Notification screen rendering.
- Regression guard for dialog stability, including the deactivated-widget-ancestor crash class.
