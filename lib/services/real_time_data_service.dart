import 'dart:async';
import 'package:flutter/foundation.dart';

/// Service for managing real-time data updates across the app
class RealTimeDataService {
  static final RealTimeDataService _instance = RealTimeDataService._internal();
  factory RealTimeDataService() => _instance;
  RealTimeDataService._internal();

  // Stream controllers for different data types
  final StreamController<ExpenseUpdateEvent> _expenseUpdates = StreamController<ExpenseUpdateEvent>.broadcast();
  final StreamController<BalanceUpdateEvent> _balanceUpdates = StreamController<BalanceUpdateEvent>.broadcast();
  final StreamController<NotificationEvent> _notifications = StreamController<NotificationEvent>.broadcast();

  // Getters for streams
  Stream<ExpenseUpdateEvent> get expenseUpdates => _expenseUpdates.stream;
  Stream<BalanceUpdateEvent> get balanceUpdates => _balanceUpdates.stream;
  Stream<NotificationEvent> get notifications => _notifications.stream;

  /// Notify that an expense was created
  void notifyExpenseCreated(String roomspaceId, Map<String, dynamic> expenseData) {
    debugPrint('🔄 RealTime: Expense created in roomspace $roomspaceId');
    _expenseUpdates.add(ExpenseUpdateEvent(
      type: ExpenseUpdateType.created,
      roomspaceId: roomspaceId,
      expenseData: expenseData,
    ));
    
    // Also trigger balance update
    _balanceUpdates.add(BalanceUpdateEvent(
      roomspaceId: roomspaceId,
      type: BalanceUpdateType.expenseChanged,
    ));
  }

  /// Notify that an expense was updated
  void notifyExpenseUpdated(String roomspaceId, Map<String, dynamic> expenseData, List<String> affectedUsers) {
    debugPrint('🔄 RealTime: Expense updated in roomspace $roomspaceId');
    _expenseUpdates.add(ExpenseUpdateEvent(
      type: ExpenseUpdateType.updated,
      roomspaceId: roomspaceId,
      expenseData: expenseData,
      affectedUsers: affectedUsers,
    ));
    
    // Trigger balance update
    _balanceUpdates.add(BalanceUpdateEvent(
      roomspaceId: roomspaceId,
      type: BalanceUpdateType.expenseChanged,
    ));

    // Send notifications to affected users
    for (final userId in affectedUsers) {
      sendNotification(
        type: NotificationType.expenseUpdated,
        userId: userId,
        roomspaceId: roomspaceId,
        message: 'An expense "${expenseData['title']}" was updated',
        data: expenseData,
      );
    }
  }

  /// Notify that an expense was deleted
  void notifyExpenseDeleted(String roomspaceId, String expenseId, List<String> affectedUsers) {
    debugPrint('🔄 RealTime: Expense deleted in roomspace $roomspaceId');
    _expenseUpdates.add(ExpenseUpdateEvent(
      type: ExpenseUpdateType.deleted,
      roomspaceId: roomspaceId,
      expenseId: expenseId,
      affectedUsers: affectedUsers,
    ));
    
    // Trigger balance update
    _balanceUpdates.add(BalanceUpdateEvent(
      roomspaceId: roomspaceId,
      type: BalanceUpdateType.expenseChanged,
    ));
  }

  /// Notify that a personal expense was created
  void notifyPersonalExpenseCreated(Map<String, dynamic> expenseData) {
    debugPrint('🔄 RealTime: Personal expense created');
    _expenseUpdates.add(ExpenseUpdateEvent(
      type: ExpenseUpdateType.personalCreated,
      expenseData: expenseData,
    ));
  }

  /// Notify that balances should be refreshed
  void notifyBalanceUpdate(String roomspaceId) {
    debugPrint('🔄 RealTime: Balance update for roomspace $roomspaceId');
    _balanceUpdates.add(BalanceUpdateEvent(
      roomspaceId: roomspaceId,
      type: BalanceUpdateType.manual,
    ));
  }

  /// Send a notification to a specific user
  void sendNotification({
    required NotificationType type,
    required String userId,
    String? roomspaceId,
    required String message,
    Map<String, dynamic>? data,
  }) {
    debugPrint('📱 RealTime: Sending notification to user $userId');
    _notifications.add(NotificationEvent(
      type: type,
      userId: userId,
      roomspaceId: roomspaceId,
      message: message,
      data: data,
    ));
  }

  /// Clear all cached data (useful for logout)
  void clearAllData() {
    debugPrint('🔄 RealTime: Clearing all cached data');
    _expenseUpdates.add(ExpenseUpdateEvent(type: ExpenseUpdateType.clearCache));
    _balanceUpdates.add(BalanceUpdateEvent(type: BalanceUpdateType.clearCache));
  }

  void dispose() {
    _expenseUpdates.close();
    _balanceUpdates.close();
    _notifications.close();
  }
}

/// Event types for expense updates
enum ExpenseUpdateType {
  created,
  updated,
  deleted,
  personalCreated,
  clearCache,
}

/// Event types for balance updates
enum BalanceUpdateType {
  expenseChanged,
  paymentConfirmed,
  manual,
  clearCache,
}

/// Event types for notifications
enum NotificationType {
  expenseUpdated,
  paymentReceived,
  balanceChanged,
}

/// Expense update event
class ExpenseUpdateEvent {
  final ExpenseUpdateType type;
  final String? roomspaceId;
  final String? expenseId;
  final Map<String, dynamic>? expenseData;
  final List<String>? affectedUsers;

  ExpenseUpdateEvent({
    required this.type,
    this.roomspaceId,
    this.expenseId,
    this.expenseData,
    this.affectedUsers,
  });
}

/// Balance update event
class BalanceUpdateEvent {
  final String? roomspaceId;
  final BalanceUpdateType type;

  BalanceUpdateEvent({
    this.roomspaceId,
    required this.type,
  });
}

/// Notification event
class NotificationEvent {
  final NotificationType type;
  final String userId;
  final String? roomspaceId;
  final String message;
  final Map<String, dynamic>? data;

  NotificationEvent({
    required this.type,
    required this.userId,
    this.roomspaceId,
    required this.message,
    this.data,
  });
}