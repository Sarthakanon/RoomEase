import 'dart:async';
import 'package:flutter/material.dart';
import 'real_time_data_service.dart';

/// Service for showing in-app notifications for real-time updates
class InAppNotificationService {
  static final InAppNotificationService _instance = InAppNotificationService._internal();
  factory InAppNotificationService() => _instance;
  InAppNotificationService._internal();

  StreamSubscription<NotificationEvent>? _notificationSubscription;
  BuildContext? _context;

  /// Initialize the service with app context
  void initialize(BuildContext context) {
    _context = context;
    _setupNotificationListener();
  }

  void _setupNotificationListener() {
    _notificationSubscription?.cancel();
    _notificationSubscription = RealTimeDataService().notifications.listen((event) {
      _showNotification(event);
    });
  }

  void _showNotification(NotificationEvent event) {
    if (_context == null || !_context!.mounted) return;

    final messenger = ScaffoldMessenger.of(_context!);
    
    // Determine notification style based on type
    Color backgroundColor;
    IconData icon;
    
    switch (event.type) {
      case NotificationType.expenseUpdated:
        backgroundColor = Colors.blue.shade600;
        icon = Icons.edit_rounded;
        break;
      case NotificationType.paymentReceived:
        backgroundColor = Colors.green.shade600;
        icon = Icons.payment_rounded;
        break;
      case NotificationType.balanceChanged:
        backgroundColor = Colors.orange.shade600;
        icon = Icons.account_balance_wallet_rounded;
        break;
      case NotificationType.notificationsUpdated:
      case NotificationType.profileUpdated:
        return;
    }

    messenger.showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(icon, color: Colors.white, size: 20),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                event.message,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ],
        ),
        backgroundColor: backgroundColor,
        duration: const Duration(seconds: 4),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
        ),
        margin: const EdgeInsets.all(16),
        action: SnackBarAction(
          label: 'View',
          textColor: Colors.white,
          onPressed: () {
            // Handle notification tap - could navigate to relevant screen
            _handleNotificationTap(event);
          },
        ),
      ),
    );
  }

  void _handleNotificationTap(NotificationEvent event) {
    // Handle different notification types
    switch (event.type) {
      case NotificationType.expenseUpdated:
        // Could navigate to expense details or refresh current screen
        debugPrint('📱 Notification tapped: Expense updated');
        break;
      case NotificationType.paymentReceived:
        // Could navigate to payment confirmation screen
        debugPrint('📱 Notification tapped: Payment received');
        break;
      case NotificationType.balanceChanged:
        // Could navigate to balance screen
        debugPrint('📱 Notification tapped: Balance changed');
        break;
      case NotificationType.notificationsUpdated:
      case NotificationType.profileUpdated:
        break;
    }
  }

  void dispose() {
    _notificationSubscription?.cancel();
    _context = null;
  }
}
