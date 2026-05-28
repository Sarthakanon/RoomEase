import 'dart:developer';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_stripe/flutter_stripe.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:room_ease/firebase_options.dart';
import 'package:room_ease/main.dart' as app;
import 'package:room_ease/services/api_service.dart';
import 'package:room_ease/services/auth_state_service.dart';
import 'package:room_ease/services/performance_service.dart';

const testEmail = String.fromEnvironment('ROOM_EASE_TEST_EMAIL');
const testPassword = String.fromEnvironment('ROOM_EASE_TEST_PASSWORD');
const roommateEmail = String.fromEnvironment('ROOM_EASE_TEST_ROOMMATE_EMAIL');
const roommatePassword = String.fromEnvironment(
  'ROOM_EASE_TEST_ROOMMATE_PASSWORD',
);

const hasPrimaryCredentials = testEmail != '' && testPassword != '';
const hasRoommateCredentials = roommateEmail != '' && roommatePassword != '';

bool _isInitialized = false;

Future<void> initializeRoomEaseForIntegrationTest() async {
  if (_isInitialized) return;

  TestWidgetsFlutterBinding.ensureInitialized();

  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
  } on FirebaseException catch (error) {
    if (error.code != 'duplicate-app') rethrow;
  }

  try {
    Stripe.publishableKey =
        'pk_test_51TU9vSHqZqdKUPbJu11tfIfeUWuwYxZvCfCQUMzAGWBXip0YbLbykzxIBUOqgVvu5KXBP6S8qo9EZe66ykmoqMpm00eZ5U1MGu';
    await Stripe.instance.applySettings();
  } catch (error) {
    log('Stripe initialization skipped in integration test: $error');
  }

  try {
    await ApiService().initializePersistentCookies();
  } catch (error) {
    log('Cookie initialization skipped in integration test: $error');
  }

  try {
    await PerformanceService().initialize();
  } catch (error) {
    log('Performance initialization skipped in integration test: $error');
  }

  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.white,
      statusBarIconBrightness: Brightness.dark,
      statusBarBrightness: Brightness.light,
      systemNavigationBarColor: Colors.white,
      systemNavigationBarIconBrightness: Brightness.dark,
    ),
  );

  _isInitialized = true;
}

Future<void> resetAuthForBlackBoxTest() async {
  await initializeRoomEaseForIntegrationTest();

  try {
    await FirebaseAuth.instance.signOut();
  } catch (error) {
    log('Firebase sign-out skipped in integration test reset: $error');
  }

  try {
    await AuthStateService.clearLoginState();
  } catch (error) {
    log('Auth state reset skipped in integration test reset: $error');
  }
}

Future<void> pumpRoomEaseApp(WidgetTester tester) async {
  await initializeRoomEaseForIntegrationTest();
  await tester.pumpWidget(const app.RoomEaseApp());
  await settleFor(tester, const Duration(milliseconds: 300));
}

Future<void> pumpLoggedOutRoomEaseApp(WidgetTester tester) async {
  await resetAuthForBlackBoxTest();
  await pumpRoomEaseApp(tester);
  await waitForAny(tester, [
    find.text('Welcome Back'),
    find.text('RoomEase'),
  ], timeout: const Duration(seconds: 12));
  await waitForFinder(
    tester,
    find.text('Welcome Back'),
    timeout: const Duration(seconds: 12),
  );
}

Future<void> settleFor(WidgetTester tester, Duration duration) async {
  final end = DateTime.now().add(duration);
  do {
    await tester.pump(const Duration(milliseconds: 100));
  } while (DateTime.now().isBefore(end));
}

Future<void> settleLong(WidgetTester tester) async {
  await settleFor(tester, const Duration(seconds: 2));
}

Future<void> waitForFinder(
  WidgetTester tester,
  Finder finder, {
  Duration timeout = const Duration(seconds: 15),
}) async {
  final end = DateTime.now().add(timeout);
  while (DateTime.now().isBefore(end)) {
    await tester.pump(const Duration(milliseconds: 250));
    if (finder.evaluate().isNotEmpty) return;
  }

  fail('Timed out waiting for $finder');
}

Future<Finder> waitForAny(
  WidgetTester tester,
  List<Finder> finders, {
  Duration timeout = const Duration(seconds: 15),
}) async {
  final end = DateTime.now().add(timeout);
  while (DateTime.now().isBefore(end)) {
    await tester.pump(const Duration(milliseconds: 250));
    for (final finder in finders) {
      if (finder.evaluate().isNotEmpty) return finder;
    }
  }

  fail('Timed out waiting for one of: ${finders.join(', ')}');
}

Future<void> enterTextByHint(
  WidgetTester tester,
  String hint,
  String value,
) async {
  final field = find.byWidgetPredicate(
    (widget) => widget is TextField && widget.decoration?.hintText == hint,
    description: 'TextField with hint "$hint"',
  );
  await waitForFinder(tester, field);
  await tester.enterText(field, value);
  await tester.pump();
}

Future<void> tapText(
  WidgetTester tester,
  String text, {
  bool last = false,
  Duration settle = const Duration(milliseconds: 500),
}) async {
  final finder = find.text(text);
  await waitForFinder(tester, finder);
  await tester.ensureVisible(last ? finder.last : finder.first);
  await tester.tap(last ? finder.last : finder.first, warnIfMissed: false);
  await settleFor(tester, settle);
}

Future<bool> tapTextIfVisible(
  WidgetTester tester,
  String text, {
  bool last = false,
  Duration settle = const Duration(milliseconds: 500),
}) async {
  final finder = find.text(text);
  if (finder.evaluate().isEmpty) return false;
  await tester.ensureVisible(last ? finder.last : finder.first);
  await tester.tap(last ? finder.last : finder.first, warnIfMissed: false);
  await settleFor(tester, settle);
  return true;
}

Future<bool> tapIconIfVisible(
  WidgetTester tester,
  IconData icon, {
  Duration settle = const Duration(milliseconds: 500),
}) async {
  final finder = find.byIcon(icon);
  if (finder.evaluate().isEmpty) return false;
  await tester.tap(finder.last, warnIfMissed: false);
  await settleFor(tester, settle);
  return true;
}

Future<void> dismissFirstTimePermissionsIfVisible(WidgetTester tester) async {
  await settleFor(tester, const Duration(milliseconds: 500));
  if (find.text('Enable Smart Features').evaluate().isNotEmpty) {
    await tapText(tester, 'Not Now');
  }
}

Future<void> loginWithPrimaryCredentials(WidgetTester tester) async {
  if (!hasPrimaryCredentials) {
    fail(
      'ROOM_EASE_TEST_EMAIL and ROOM_EASE_TEST_PASSWORD are required for this test.',
    );
  }

  await pumpLoggedOutRoomEaseApp(tester);
  await enterTextByHint(tester, 'Enter your Email', testEmail);
  await enterTextByHint(tester, 'Enter your Password', testPassword);
  await tapText(tester, 'Sign In', settle: const Duration(seconds: 1));
  await dismissFirstTimePermissionsIfVisible(tester);
  await waitForAuthenticatedArea(tester);
}

Future<void> waitForAuthenticatedArea(WidgetTester tester) async {
  await waitForAny(tester, [
    find.text('Manage Your Space'),
    find.text('Expenses'),
    find.text('Profile'),
    find.text('No Roomspaces Yet'),
    find.text('Create Room'),
  ], timeout: const Duration(seconds: 30));
}

Future<void> openExpensesTab(WidgetTester tester) async {
  if (find.text('Expenses').evaluate().isEmpty ||
      find.text('Management').evaluate().isEmpty) {
    await tapIconIfVisible(
      tester,
      Icons.receipt_long_rounded,
      settle: const Duration(seconds: 1),
    );
  }

  await waitForAny(tester, [
    find.text('Expenses'),
    find.text('Personal Expenses'),
    find.text('Shared Expenses'),
    find.text('No Roomspaces Yet'),
  ], timeout: const Duration(seconds: 20));
}

Future<void> openProfileTab(WidgetTester tester) async {
  await tapIconIfVisible(
    tester,
    Icons.person_rounded,
    settle: const Duration(seconds: 1),
  );
  await waitForFinder(
    tester,
    find.text('Profile'),
    timeout: const Duration(seconds: 20),
  );
}
