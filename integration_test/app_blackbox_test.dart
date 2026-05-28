import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import 'blackbox_test_helpers.dart';

final skipNonMobileIntegrationTarget =
    kIsWeb ||
    {
      TargetPlatform.linux,
      TargetPlatform.macOS,
      TargetPlatform.windows,
    }.contains(defaultTargetPlatform);

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  group('RoomEase Flutter black-box smoke tests', () {
    testWidgets(
      'app launches and reaches login after splash',
      (tester) async {
        await pumpLoggedOutRoomEaseApp(tester);

        expect(find.text('Welcome Back'), findsOneWidget);
        expect(find.text('Sign In'), findsOneWidget);
      },
      skip: skipNonMobileIntegrationTarget,
    );

    testWidgets(
      'empty login form shows validation errors',
      (tester) async {
        await pumpLoggedOutRoomEaseApp(tester);

        await tapText(tester, 'Sign In');

        expect(find.text('Email required'), findsOneWidget);
        expect(find.text('Password required'), findsOneWidget);
      },
      skip: skipNonMobileIntegrationTarget,
    );

    testWidgets('invalid login shows failure feedback', (tester) async {
      await pumpLoggedOutRoomEaseApp(tester);

      await enterTextByHint(
        tester,
        'Enter your Email',
        'invalid.blackbox@example.com',
      );
      await enterTextByHint(tester, 'Enter your Password', 'wrong-password');
      await tapText(tester, 'Sign In', settle: const Duration(seconds: 1));

      await waitForAny(tester, [
        find.byType(SnackBar),
        find.textContaining('invalid', findRichText: true),
        find.textContaining('user', findRichText: true),
        find.textContaining('Failed', findRichText: true),
      ], timeout: const Duration(seconds: 25));
    }, skip: skipNonMobileIntegrationTarget);

    testWidgets(
      'valid login reaches authenticated roomspace or dashboard area',
      (tester) async {
        await loginWithPrimaryCredentials(tester);

        expect(
          find.byWidgetPredicate((widget) {
            if (widget is! Text) return false;
            final text = widget.data ?? widget.textSpan?.toPlainText() ?? '';
            return text == 'Manage Your Space' ||
                text == 'Expenses' ||
                text == 'Profile' ||
                text == 'No Roomspaces Yet' ||
                text == 'Create Room';
          }),
          findsWidgets,
        );
      },
      skip: skipNonMobileIntegrationTarget || !hasPrimaryCredentials,
    );

    testWidgets(
      'roomspace create and join forms validate required inputs',
      (tester) async {
        await loginWithPrimaryCredentials(tester);

        if (find.text('Manage Your Space').evaluate().isEmpty) {
          await tapIconIfVisible(
            tester,
            Icons.meeting_room_rounded,
            settle: const Duration(seconds: 1),
          );
        }

        if (find.text('Manage Your Space').evaluate().isEmpty) {
          // Existing roomspace users land in the dashboard; this fixture has no selection screen to validate.
          return;
        }

        await tapText(tester, 'Create Room');
        await waitForFinder(tester, find.text('New Roomspace'));
        await tapText(tester, 'Create Room', last: true);
        expect(find.text('Name required'), findsOneWidget);
        expect(find.text('Address required'), findsOneWidget);

        await tester.pageBack();
        await settleLong(tester);

        await tapText(tester, 'Join Room');
        await waitForFinder(tester, find.text('Join Room'));
        await tapText(tester, 'Join Room', last: true);
        expect(find.text('Invalid code'), findsOneWidget);
      },
      skip: skipNonMobileIntegrationTarget || !hasPrimaryCredentials,
    );

    testWidgets(
      'bottom navigation opens expenses, analytics, and profile sections',
      (tester) async {
        await loginWithPrimaryCredentials(tester);

        await openExpensesTab(tester);
        expect(find.text('Expenses'), findsWidgets);

        await tapIconIfVisible(
          tester,
          Icons.analytics_rounded,
          settle: const Duration(seconds: 1),
        );
        await waitForAny(tester, [
          find.text('Analytics'),
          find.textContaining('Spending', findRichText: true),
          find.byType(CircularProgressIndicator),
        ], timeout: const Duration(seconds: 20));

        await openProfileTab(tester);
        expect(find.text('Profile'), findsWidgets);
      },
      skip: skipNonMobileIntegrationTarget || !hasPrimaryCredentials,
    );

    testWidgets(
      'expense management screens open without dialog ancestor crashes',
      (tester) async {
        await loginWithPrimaryCredentials(tester);
        await openExpensesTab(tester);

        if (find.text('Balance Overview').evaluate().isNotEmpty) {
          await tapText(tester, 'Balance Overview');
          await waitForAny(tester, [
            find.text('Who Owes Who'),
            find.text('No balance data available'),
            find.byType(CircularProgressIndicator),
          ], timeout: const Duration(seconds: 20));
          await tester.pageBack();
          await settleLong(tester);
        }

        if (find.text('Confirm Payments').evaluate().isNotEmpty) {
          await tapText(tester, 'Confirm Payments');
          await waitForFinder(
            tester,
            find.text('Confirmations'),
            timeout: const Duration(seconds: 20),
          );

          if (find.text('Record Payment').evaluate().isNotEmpty) {
            await tapText(
              tester,
              'Record Payment',
              settle: const Duration(seconds: 1),
            );
            await waitForAny(tester, [
              find.text('Record Payment'),
              find.text('Please select a roommate'),
              find.text('Nothing here yet'),
              find.byType(AlertDialog),
            ], timeout: const Duration(seconds: 20));
          }
        }

        expect(tester.takeException(), isNull);
      },
      skip: skipNonMobileIntegrationTarget || !hasPrimaryCredentials,
    );

    testWidgets(
      'notifications screen renders loading, empty, or list state',
      (tester) async {
        await loginWithPrimaryCredentials(tester);

        var openedFromBell = await tapIconIfVisible(
          tester,
          Icons.notifications_none_rounded,
          settle: const Duration(seconds: 1),
        );
        openedFromBell =
            openedFromBell ||
            await tapIconIfVisible(
              tester,
              Icons.notifications_outlined,
              settle: const Duration(seconds: 1),
            );
        openedFromBell =
            openedFromBell ||
            await tapIconIfVisible(
              tester,
              Icons.notifications_rounded,
              settle: const Duration(seconds: 1),
            );

        if (!openedFromBell) {
          // Some authenticated fixtures do not expose the notification bell on their current landing page.
          return;
        }

        await waitForFinder(
          tester,
          find.text('Notifications'),
          timeout: const Duration(seconds: 20),
        );
        await waitForAny(tester, [
          find.text('All caught up'),
          find.text('Mark all read'),
          find.byType(ListView),
          find.byType(CircularProgressIndicator),
        ], timeout: const Duration(seconds: 20));
      },
      skip: skipNonMobileIntegrationTarget || !hasPrimaryCredentials,
    );
  });
}
