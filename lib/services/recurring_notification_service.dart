import 'dart:convert';
import 'dart:developer';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/recurring_expense_models.dart';
import 'recurring_expense_service.dart';

class RecurringNotificationService {
  static final RecurringNotificationService _instance = RecurringNotificationService._internal();
  factory RecurringNotificationService() => _instance;
  RecurringNotificationService._internal();

  final FlutterLocalNotificationsPlugin _localNotifications = FlutterLocalNotificationsPlugin();
  final RecurringExpenseService _recurringService = RecurringExpenseService();

  bool _initialized = false;
  static const String _shownIdsKey = 'shown_recurring_notification_ids';

  Future<void> initialize() async {
    if (_initialized) return;
    try {
      const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
      const iosSettings = DarwinInitializationSettings(
        requestAlertPermission: true,
        requestBadgePermission: true,
        requestSoundPermission: true,
      );
      const initSettings = InitializationSettings(
        android: androidSettings,
        iOS: iosSettings,
      );

      await _localNotifications.initialize(initSettings);

      final androidPlugin = _localNotifications.resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>();
      if (androidPlugin != null) {
        await androidPlugin.requestNotificationsPermission();
      }
      _initialized = true;
      log('RecurringNotificationService initialized');
    } catch (e) {
      log('Failed to initialize recurring notifications: $e');
    }
  }

  Future<void> syncAndNotifyPending() async {
    if (!_initialized) {
      await initialize();
    }
    if (!_initialized) return;

    try {
      final notifications = await _recurringService.getRecurringExpenseNotifications();
      if (notifications.isEmpty) return;

      final shownIds = await _getShownIds();
      final now = DateTime.now();

      for (final item in notifications) {
        if (item.id == null) continue;
        final id = item.id!.toString();
        if (shownIds.contains(id)) continue;
        if (item.notificationDate.isAfter(now)) continue;

        await _showRecurringReminder(item);
        shownIds.add(id);
      }

      await _setShownIds(shownIds);
    } catch (e) {
      log('Failed to sync recurring notifications: $e');
    }
  }

  Future<void> _showRecurringReminder(RecurringExpenseNotification item) async {
    const androidDetails = AndroidNotificationDetails(
      'recurring_expense_reminders',
      'Recurring Expense Reminders',
      channelDescription: 'Upcoming recurring expense reminders',
      importance: Importance.high,
      priority: Priority.high,
      showWhen: true,
      enableVibration: true,
      playSound: true,
    );
    const iosDetails = DarwinNotificationDetails();
    const details = NotificationDetails(android: androidDetails, iOS: iosDetails);

    final payload = jsonEncode({
      'type': 'recurring_expense',
      'notificationId': item.id,
      'templateId': item.templateId,
    });

    await _localNotifications.show(
      item.id!,
      'Recurring payment reminder',
      '${item.title} • Rs. ${item.amount.toStringAsFixed(0)} is due on ${_formatDate(item.scheduledDate)}',
      details,
      payload: payload,
    );
  }

  Future<Set<String>> _getShownIds() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getStringList(_shownIdsKey) ?? [];
    return raw.toSet();
  }

  Future<void> _setShownIds(Set<String> ids) async {
    final prefs = await SharedPreferences.getInstance();
    final list = ids.toList();
    if (list.length > 500) {
      list.removeRange(0, list.length - 500);
    }
    await prefs.setStringList(_shownIdsKey, list);
  }

  String _formatDate(DateTime date) {
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
    ];
    return '${months[date.month - 1]} ${date.day}';
  }
}

