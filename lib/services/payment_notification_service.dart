import 'dart:convert';
import 'dart:developer';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/payment_notification.dart';
import '../services/api_service.dart';
import 'notification_listener_service.dart';
import 'sms_detection_service.dart';
import 'transaction_validation_service.dart';

class PaymentNotificationService {
  static PaymentNotificationService? _instance;
  static PaymentNotificationService get instance {
    _instance ??= PaymentNotificationService._();
    return _instance!;
  }

  PaymentNotificationService._();

  final FlutterLocalNotificationsPlugin _localNotifications = FlutterLocalNotificationsPlugin();
  PaymentNotificationSettings _settings = PaymentNotificationSettings();
  final List<PaymentNotification> _pendingNotifications = [];

  // Callback for when user wants to add expense
  Function(PaymentNotification)? onExpenseRequested;

  /// Initialize the payment notification service
  Future<void> initialize() async {
    try {
      // Initialize local notifications
      await _initializeLocalNotifications();
      
      // Load settings
      await _loadSettings();
      
      // Initialize sub-services
      await NotificationListenerService.initialize(this);
      await SmsDetectionService.initialize(this);
      
      // Start monitoring if enabled
      if (_settings.isEnabled) {
        await startMonitoring();
      }
      
      log('Payment notification service initialized');
    } catch (e) {
      log('Error initializing payment notification service: $e');
    }
  }

  /// Initialize local notifications for showing expense suggestions
  Future<void> _initializeLocalNotifications() async {
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

    await _localNotifications.initialize(
      initSettings,
      onDidReceiveNotificationResponse: _onNotificationTapped,
    );

    // Request notification permissions for Android 13+
    await _requestNotificationPermissions();
  }

  /// Request notification permissions
  Future<void> _requestNotificationPermissions() async {
    try {
      final androidPlugin = _localNotifications.resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>();
      
      if (androidPlugin != null) {
        final granted = await androidPlugin.requestNotificationsPermission();
        log('Notification permission granted: $granted');
      }
    } catch (e) {
      log('Error requesting notification permissions: $e');
    }
  }

  /// Handle notification tap
  void _onNotificationTapped(NotificationResponse response) {
    try {
      log('Notification tapped with payload: ${response.payload}');
      
      final payload = response.payload;
      if (payload != null) {
        final data = jsonDecode(payload);
        final notificationId = data['notificationId'] as String;
        
        log('Looking for notification with ID: $notificationId');
        log('Pending notifications count: ${_pendingNotifications.length}');
        
        // Find the pending notification
        PaymentNotification? notification;
        try {
          notification = _pendingNotifications.firstWhere(
            (n) => n.id == notificationId,
          );
        } catch (e) {
          log('Notification not found in pending list, creating from stored data');
          // If not found, we can still trigger the expense dialog
          // This is a fallback for when the notification was processed but user tapped later
        }
        
        if (data['action'] == 'add_expense') {
          if (notification != null) {
            _handleAddExpenseRequest(notification);
          } else {
            // Fallback: trigger expense dialog anyway
            log('Triggering expense dialog as fallback');
            onExpenseRequested?.call(PaymentNotification(
              id: notificationId,
              source: 'notification_tap',
              appName: 'Unknown',
              rawText: 'Notification tapped',
              timestamp: DateTime.now(),
              type: PaymentType.debit,
            ));
          }
        } else if (data['action'] == 'dismiss') {
          if (notification != null) {
            _dismissNotification(notification);
          }
        }
      } else {
        log('No payload in notification response');
        // Fallback: just trigger expense dialog
        onExpenseRequested?.call(PaymentNotification(
          id: DateTime.now().millisecondsSinceEpoch.toString(),
          source: 'notification_tap_no_payload',
          appName: 'Unknown',
          rawText: 'Notification tapped without payload',
          timestamp: DateTime.now(),
          type: PaymentType.debit,
        ));
      }
    } catch (e) {
      log('Error handling notification tap: $e');
      // Even if there's an error, try to open expense dialog
      onExpenseRequested?.call(PaymentNotification(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        source: 'notification_tap_error',
        appName: 'Unknown',
        rawText: 'Notification tapped with error',
        timestamp: DateTime.now(),
        type: PaymentType.debit,
      ));
    }
  }

  /// Start monitoring notifications and SMS
  Future<void> startMonitoring() async {
    try {
      if (_settings.notificationMonitoringEnabled) {
        await NotificationListenerService.startListening();
      }
      
      if (_settings.smsMonitoringEnabled) {
        await SmsDetectionService.startListening();
        // Process recent SMS messages
        await SmsDetectionService.processRecentSms();
      }
      
      log('Payment monitoring started');
    } catch (e) {
      log('Error starting payment monitoring: $e');
    }
  }

  /// Stop monitoring
  Future<void> stopMonitoring() async {
    try {
      await NotificationListenerService.stopListening();
      await SmsDetectionService.stopListening();
      log('Payment monitoring stopped');
    } catch (e) {
      log('Error stopping payment monitoring: $e');
    }
  }

  /// Process a detected payment notification
  Future<void> processPaymentNotification(PaymentNotification notification) async {
    try {
      log('Processing payment notification: ${notification.amount} from ${notification.appName}');
      
      // Validate transaction (includes duplicate checking)
      final isValid = await TransactionValidationService.validateTransaction(notification);
      if (!isValid) {
        log('Transaction validation failed, skipping');
        return;
      }
      
      // Check if notification meets user criteria
      if (!_shouldProcessNotification(notification)) {
        log('Notification does not meet user criteria, skipping');
        return;
      }
      
      // Add to pending notifications
      _pendingNotifications.add(notification);
      log('Added notification to pending list. Total pending: ${_pendingNotifications.length}');
      
      // Show expense suggestion notification
      await _showExpenseSuggestionNotification(notification);
      
      // Save notification for history
      await _saveNotificationHistory(notification);
      
    } catch (e) {
      log('Error processing payment notification: $e');
    }
  }

  /// Check if notification should be processed based on settings
  bool _shouldProcessNotification(PaymentNotification notification) {
    // Check if feature is enabled
    if (!_settings.isEnabled) return false;
    
    // Check minimum amount
    if (notification.amount != null && notification.amount! < _settings.minimumAmount) {
      return false;
    }
    
    // Check if app is enabled
    if (_settings.enabledApps.isNotEmpty && 
        !_settings.enabledApps.contains(notification.appName)) {
      return false;
    }
    
    // Check if merchant is enabled (if merchant filtering is active)
    if (_settings.enabledMerchants.isNotEmpty && 
        notification.merchant != null &&
        !_settings.enabledMerchants.contains(notification.merchant)) {
      return false;
    }
    
    return true;
  }

  /// Show expense suggestion notification
  Future<void> _showExpenseSuggestionNotification(PaymentNotification notification) async {
    final amount = notification.amount?.toStringAsFixed(2) ?? 'Unknown';
    final merchant = notification.merchant ?? 'Unknown merchant';
    
    try {
      
      const androidDetails = AndroidNotificationDetails(
        'payment_suggestions',
        'Payment Expense Suggestions',
        channelDescription: 'Notifications suggesting to add payments as RoomEase expenses',
        importance: Importance.high,
        priority: Priority.high,
        showWhen: true,
        enableVibration: true,
        playSound: true,
        actions: [
          AndroidNotificationAction(
            'add_expense',
            'Add as Expense',
          ),
          AndroidNotificationAction(
            'dismiss',
            'Dismiss',
            cancelNotification: true,
          ),
        ],
      );
      
      const iosDetails = DarwinNotificationDetails(
        categoryIdentifier: 'payment_suggestion',
      );
      
      const details = NotificationDetails(
        android: androidDetails,
        iOS: iosDetails,
      );
      
      final payload = jsonEncode({
        'notificationId': notification.id,
        'action': 'add_expense',
      });
      
      log('Attempting to show notification: Payment Detected - Rs. $amount');
      
      await _localNotifications.show(
        notification.id.hashCode,
        'Payment Detected - Rs. $amount',
        'Add payment to $merchant as RoomEase expense?',
        details,
        payload: payload,
      );
      
      log('Notification shown successfully');
      
    } catch (e) {
      log('Error showing expense suggestion notification: $e');
      
      // Fallback: Try a simple notification without actions
      try {
        const simpleAndroidDetails = AndroidNotificationDetails(
          'payment_suggestions',
          'Payment Expense Suggestions',
          channelDescription: 'Payment notifications',
          importance: Importance.high,
          priority: Priority.high,
        );
        
        const simpleDetails = NotificationDetails(android: simpleAndroidDetails);
        
        await _localNotifications.show(
          notification.id.hashCode,
          'Payment Detected - Rs. $amount',
          'Tap to add payment to $merchant as expense',
          simpleDetails,
        );
        
        log('Fallback notification shown');
      } catch (fallbackError) {
        log('Fallback notification also failed: $fallbackError');
      }
    }
  }

  /// Handle add expense request
  void _handleAddExpenseRequest(PaymentNotification notification) {
    try {
      // Mark as processed
      notification = PaymentNotification(
        id: notification.id,
        source: notification.source,
        appName: notification.appName,
        rawText: notification.rawText,
        amount: notification.amount,
        merchant: notification.merchant,
        timestamp: notification.timestamp,
        type: notification.type,
        isProcessed: true,
      );
      
      // Remove from pending
      _pendingNotifications.removeWhere((n) => n.id == notification.id);
      
      // Mark as processed in database if it has a numeric ID
      final numericId = int.tryParse(notification.id);
      if (numericId != null) {
        ApiService().markPaymentNotificationAsProcessed(numericId).catchError((e) {
          log('Error marking notification as processed in database: $e');
        });
      }
      
      // Trigger expense dialog callback
      onExpenseRequested?.call(notification);
      
    } catch (e) {
      log('Error handling add expense request: $e');
    }
  }

  /// Dismiss notification
  void _dismissNotification(PaymentNotification notification) {
    try {
      _pendingNotifications.removeWhere((n) => n.id == notification.id);
      _localNotifications.cancel(notification.id.hashCode);
    } catch (e) {
      log('Error dismissing notification: $e');
    }
  }

  /// Save notification to history
  Future<void> _saveNotificationHistory(PaymentNotification notification) async {
    try {
      // Save to database via API
      final notificationData = {
        'amount': notification.amount,
        'merchant': notification.merchant ?? 'Unknown',
        'app_name': notification.appName,
        'raw_text': notification.rawText,
        'type': notification.type.toString().split('.').last.toUpperCase(),
        'timestamp': notification.timestamp.toIso8601String(),
      };
      
      await ApiService().createPaymentNotification(notificationData);
      log('Payment notification saved to database');
    } catch (e) {
      log('Error saving notification to database: $e');
      
      // Fallback to SharedPreferences for offline storage
      try {
        final prefs = await SharedPreferences.getInstance();
        final historyKey = 'payment_notification_history';
        
        final existingHistory = prefs.getStringList(historyKey) ?? [];
        existingHistory.add(jsonEncode(notification.toJson()));
        
        // Keep only last 100 notifications
        if (existingHistory.length > 100) {
          existingHistory.removeRange(0, existingHistory.length - 100);
        }
        
        await prefs.setStringList(historyKey, existingHistory);
        log('Payment notification saved to local storage as fallback');
      } catch (localError) {
        log('Error saving notification to local storage: $localError');
      }
    }
  }

  /// Get notification history
  Future<List<PaymentNotification>> getNotificationHistory() async {
    try {
      // Try to get from database first
      final response = await ApiService().getPaymentNotifications(limit: 100);
      
      if (response['success'] == true && response['data'] != null) {
        final List<dynamic> notificationData = response['data'];
        final notifications = notificationData.map((data) {
          return PaymentNotification(
            id: data['id'].toString(),
            source: 'database',
            appName: data['app_name'] ?? 'Unknown',
            rawText: data['raw_text'] ?? '',
            amount: (data['amount'] as num?)?.toDouble(),
            merchant: data['merchant'],
            timestamp: DateTime.parse(data['timestamp']),
            type: data['type'] == 'CREDIT' ? PaymentType.credit : PaymentType.debit,
            isProcessed: data['is_processed'] ?? false,
          );
        }).toList();
        
        log('Loaded ${notifications.length} payment notifications from database');
        return notifications;
      }
    } catch (e) {
      log('Error getting notifications from database: $e');
    }
    
    // Fallback to SharedPreferences
    try {
      final prefs = await SharedPreferences.getInstance();
      final historyKey = 'payment_notification_history';
      
      final historyStrings = prefs.getStringList(historyKey) ?? [];
      final notifications = historyStrings.map((str) {
        final json = jsonDecode(str) as Map<String, dynamic>;
        return PaymentNotification.fromJson(json);
      }).toList();
      
      log('Loaded ${notifications.length} payment notifications from local storage');
      return notifications;
    } catch (e) {
      log('Error getting notification history from local storage: $e');
      return [];
    }
  }

  /// Update settings
  Future<void> updateSettings(PaymentNotificationSettings newSettings) async {
    try {
      _settings = newSettings;
      await _saveSettings();
      
      // Background service settings update skipped
      
      // Restart monitoring with new settings
      if (_settings.isEnabled) {
        await startMonitoring();
      } else {
        await stopMonitoring();
      }
    } catch (e) {
      log('Error updating settings: $e');
    }
  }

  /// Get current settings
  PaymentNotificationSettings get settings => _settings;

  /// Load settings from storage
  Future<void> _loadSettings() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final settingsJson = prefs.getString('payment_notification_settings');
      
      if (settingsJson != null) {
        final json = jsonDecode(settingsJson) as Map<String, dynamic>;
        _settings = PaymentNotificationSettings.fromJson(json);
      }
    } catch (e) {
      log('Error loading settings: $e');
    }
  }

  /// Save settings to storage
  Future<void> _saveSettings() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final settingsJson = jsonEncode(_settings.toJson());
      await prefs.setString('payment_notification_settings', settingsJson);
    } catch (e) {
      log('Error saving settings: $e');
    }
  }

  /// Check permissions status
  Future<Map<String, bool>> checkPermissions() async {
    final notificationPermission = await NotificationListenerService.isNotificationListenerEnabled();
    final smsPermission = await SmsDetectionService.hasSmsPermission();
    
    return {
      'notification': notificationPermission,
      'sms': smsPermission,
    };
  }

  /// Request all necessary permissions
  Future<Map<String, bool>> requestPermissions() async {
    final notificationPermission = await NotificationListenerService.requestNotificationPermission();
    final smsPermission = await SmsDetectionService.requestSmsPermission();
    
    return {
      'notification': notificationPermission,
      'sms': smsPermission,
    };
  }

  /// Get transaction statistics
  Future<Map<String, dynamic>> getTransactionStats() async {
    return await TransactionValidationService.getTransactionStats();
  }

  /// Clear transaction history (for testing)
  Future<void> clearTransactionHistory() async {
    await TransactionValidationService.clearStoredTransactions();
  }

  /// Initialize background service
  Future<void> initializeBackgroundService() async {
    // Background service temporarily disabled to avoid native code access issues
    log('Background service initialization skipped');
  }

  /// Start background monitoring
  Future<void> startBackgroundMonitoring() async {
    // Background service temporarily disabled
    log('Background monitoring skipped');
  }

  /// Stop background monitoring
  Future<void> stopBackgroundMonitoring() async {
    // Background service temporarily disabled
    log('Background monitoring stop skipped');
  }
}