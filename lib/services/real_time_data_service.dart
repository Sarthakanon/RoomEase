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
  final StreamController<MemberUpdateEvent> _memberUpdates = StreamController<MemberUpdateEvent>.broadcast();
  final StreamController<JoinRequestUpdateEvent> _joinRequestUpdates = StreamController<JoinRequestUpdateEvent>.broadcast();

  // Getters for streams
  Stream<ExpenseUpdateEvent> get expenseUpdates => _expenseUpdates.stream;
  Stream<BalanceUpdateEvent> get balanceUpdates => _balanceUpdates.stream;
  Stream<NotificationEvent> get notifications => _notifications.stream;
  Stream<MemberUpdateEvent> get memberUpdates => _memberUpdates.stream;
  Stream<JoinRequestUpdateEvent> get joinRequestUpdates => _joinRequestUpdates.stream;

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

  /// Notify that a member was added to a roomspace
  void notifyMemberAdded(String roomspaceId, String userId) {
    debugPrint('🔄 RealTime: Member added to roomspace $roomspaceId');
    _memberUpdates.add(MemberUpdateEvent(
      type: MemberUpdateType.added,
      roomspaceId: roomspaceId,
      userId: userId,
    ));
  }

  /// Notify that a member was removed from a roomspace
  void notifyMemberRemoved(String roomspaceId, String userId) {
    debugPrint('🔄 RealTime: Member removed from roomspace $roomspaceId');
    _memberUpdates.add(MemberUpdateEvent(
      type: MemberUpdateType.removed,
      roomspaceId: roomspaceId,
      userId: userId,
    ));
  }

  /// Notify that a join request was processed
  void notifyJoinRequestProcessed(String requestId, bool accepted) {
    debugPrint('🔄 RealTime: Join request $requestId ${accepted ? "accepted" : "rejected"}');
    _joinRequestUpdates.add(JoinRequestUpdateEvent(
      type: accepted ? JoinRequestUpdateType.accepted : JoinRequestUpdateType.rejected,
      requestId: requestId,
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

  /// Notify listeners that notification read-status changed
  void notifyNotificationsUpdated() {
    _notifications.add(NotificationEvent(
      type: NotificationType.notificationsUpdated,
      userId: '',
      message: 'Notifications updated',
    ));
  }

  /// Notify listeners that user profile data changed (e.g., QR updated)
  void notifyProfileUpdated() {
    _notifications.add(NotificationEvent(
      type: NotificationType.profileUpdated,
      userId: '',
      message: 'Profile updated',
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
    _memberUpdates.close();
    _joinRequestUpdates.close();
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
  notificationsUpdated,
  profileUpdated,
}

/// Event types for member updates
enum MemberUpdateType {
  added,
  removed,
}

/// Event types for join request updates
enum JoinRequestUpdateType {
  accepted,
  rejected,
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

/// Member update event
class MemberUpdateEvent {
  final MemberUpdateType type;
  final String roomspaceId;
  final String userId;

  MemberUpdateEvent({
    required this.type,
    required this.roomspaceId,
    required this.userId,
  });
}

/// Join request update event
class JoinRequestUpdateEvent {
  final JoinRequestUpdateType type;
  final String requestId;

  JoinRequestUpdateEvent({
    required this.type,
    required this.requestId,
  });
}
