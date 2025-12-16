import 'dart:developer';
import 'package:flutter/services.dart';
import 'payment_parser_service.dart';
import 'payment_notification_service.dart';

class NotificationListenerService {
  static const MethodChannel _channel = MethodChannel('payment_notification_channel');
  static PaymentNotificationService? _paymentService;

  /// Initialize the notification listener service
  static Future<void> initialize(PaymentNotificationService paymentService) async {
    _paymentService = paymentService;
    _channel.setMethodCallHandler(_handleMethodCall);
  }

  /// Request notification access permission
  static Future<bool> requestNotificationPermission() async {
    try {
      // For now, we'll use a simplified approach
      // In a real implementation, this would open Android settings
      log('Notification permission requested - user should enable manually in settings');
      return true;
    } catch (e) {
      log('Error requesting notification permission: $e');
      return false;
    }
  }

  /// Start listening to notifications
  static Future<void> startListening() async {
    try {
      final hasPermission = await requestNotificationPermission();
      if (!hasPermission) {
        log('Notification permission not granted');
        return;
      }

      log('Notification listener started successfully');
      // Note: In a production app, this would integrate with native Android code
      // to actually listen for notifications. For now, we'll rely on the test functionality.
    } catch (e) {
      log('Error starting notification listener: $e');
    }
  }

  /// Stop listening to notifications
  static Future<void> stopListening() async {
    try {
      log('Notification listener stopped');
    } catch (e) {
      log('Error stopping notification listener: $e');
    }
  }

  /// Handle method calls from native code
  static Future<dynamic> _handleMethodCall(MethodCall call) async {
    switch (call.method) {
      case 'onNotificationReceived':
        final args = call.arguments as Map<String, dynamic>;
        _handleNativeNotification(args);
        break;
      default:
        log('Unknown method call: ${call.method}');
    }
  }

  /// Handle notifications from native Android code
  static void _handleNativeNotification(Map<String, dynamic> args) {
    try {
      final packageName = args['packageName'] as String?;
      final title = args['title'] as String?;
      final content = args['content'] as String?;

      if (packageName == null) return;

      final appName = _getAppNameFromPackage(packageName);
      if (appName == null) return;

      final notificationText = '${title ?? ''} ${content ?? ''}'.trim();
      if (notificationText.isEmpty) return;

      final paymentNotification = PaymentParserService.parseNotification(
        appName: appName,
        notificationText: notificationText,
        source: 'notification',
      );

      if (paymentNotification != null) {
        _paymentService?.processPaymentNotification(paymentNotification);
      }
    } catch (e) {
      log('Error handling native notification: $e');
    }
  }

  /// Get app name from package name
  static String? _getAppNameFromPackage(String packageName) {
    // Map of package names to app names for supported apps
    const packageToAppMap = {
      // Banking apps
      'com.f1soft.nmbbank': 'NMB Bank',
      'com.sanimabank.mobile': 'Sanima Bank',
      'com.everestbankltd.mobile': 'Everest Bank',
      'com.nepalbank.mobile': 'Nepal Bank',
      'com.rbb.mobile': 'Rastriya Banijya Bank',
      'com.nabilbank.mobile': 'Nabil Bank',
      'com.scb.mobile': 'Standard Chartered',
      'com.himalayanbank.mobile': 'Himalayan Bank',
      'com.nib.mobile': 'Nepal Investment Bank',
      'com.machhapuchchhrebank.mobile': 'Machhapuchchhre Bank',
      
      // Payment apps
      'com.f1soft.esewa': 'eSewa',
      'com.khalti': 'Khalti',
      'com.imepay.wallet': 'IME Pay',
      'com.connectips.mobile': 'ConnectIPS',
      'com.fonepay.mobile': 'FonePay',
      'com.ipay.mobile': 'iPay',
    };

    // Direct match
    if (packageToAppMap.containsKey(packageName)) {
      return packageToAppMap[packageName];
    }

    // Partial match for apps that might have different package names
    for (final entry in packageToAppMap.entries) {
      if (packageName.contains(entry.key.split('.').last) ||
          entry.key.contains(packageName.split('.').last)) {
        return entry.value;
      }
    }

    // Check if package name contains known banking/payment keywords
    final lowerPackage = packageName.toLowerCase();
    if (lowerPackage.contains('bank') || 
        lowerPackage.contains('esewa') ||
        lowerPackage.contains('khalti') ||
        lowerPackage.contains('ime') ||
        lowerPackage.contains('fonepay')) {
      // Extract app name from package name
      final parts = packageName.split('.');
      return parts.isNotEmpty ? parts.last : null;
    }

    return null;
  }

  /// Check if notification listener is enabled
  static Future<bool> isNotificationListenerEnabled() async {
    try {
      // For now, return true as a placeholder
      // In production, this would check actual notification access permission
      return true;
    } catch (e) {
      log('Error checking notification listener status: $e');
      return false;
    }
  }
}