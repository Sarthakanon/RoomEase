import 'dart:developer';
import 'package:flutter/services.dart';
import 'payment_parser_service.dart';
import 'payment_notification_service.dart';
import '../models/payment_notification.dart';

class NotificationListenerService {
  static const MethodChannel _channel = MethodChannel('payment_notification_channel');
  static PaymentNotificationService? _paymentService;
  static bool _isListening = false;

  /// Initialize the notification listener service
  static Future<void> initialize(PaymentNotificationService paymentService) async {
    print('🔧 NOTIFICATION LISTENER: Initializing...');
    log('🔧 Initializing NotificationListenerService...');
    _paymentService = paymentService;
    print('📱 NOTIFICATION LISTENER: Payment service set');
    log('📱 Payment service set');
    
    _channel.setMethodCallHandler(_handleMethodCall);
    print('📞 NOTIFICATION LISTENER: Method call handler set for channel: payment_notification_channel');
    log('📞 Method call handler set for channel: payment_notification_channel');
    print('✅ NOTIFICATION LISTENER: Initialization complete');
    log('✅ NotificationListenerService initialization complete');
  }

  /// Request notification access permission
  static Future<bool> requestNotificationPermission() async {
    try {
      // Use method channel to open notification settings
      await _channel.invokeMethod('openNotificationSettings');
      log('Opened notification permission settings');
      
      // Check permission after user potentially grants it
      await Future.delayed(const Duration(seconds: 2));
      return await isNotificationListenerEnabled();
    } catch (e) {
      log('Error requesting notification permission: $e');
      return false;
    }
  }

  /// Start listening to notifications
  static Future<void> startListening() async {
    if (_isListening) {
      log('Notification listener already active');
      return;
    }

    try {
      final hasPermission = await isNotificationListenerEnabled();
      if (!hasPermission) {
        log('Notification listener permission not granted');
        return;
      }

      // Start listening via method channel
      await _channel.invokeMethod('startNotificationListener');
      _isListening = true;
      log('Notification listener started successfully');
    } catch (e) {
      log('Error starting notification listener: $e');
    }
  }

  /// Stop listening to notifications
  static Future<void> stopListening() async {
    try {
      await _channel.invokeMethod('stopNotificationListener');
      _isListening = false;
      log('Notification listener stopped');
    } catch (e) {
      log('Error stopping notification listener: $e');
    }
  }

  /// Handle method calls from native code
  static Future<dynamic> _handleMethodCall(MethodCall call) async {
    print('🔥 METHOD CALL RECEIVED: ${call.method}');
    log('🔥 METHOD CALL RECEIVED: ${call.method}');
    
    try {
      switch (call.method) {
        case 'onNotificationReceived':
          print('🔔 PROCESSING NOTIFICATION');
          print('📦 Arguments type: ${call.arguments.runtimeType}');
          print('📦 Arguments: ${call.arguments}');
          
          // Safe casting from Map<Object?, Object?> to Map<String, dynamic>
          final rawArgs = call.arguments as Map<Object?, Object?>;
          final args = Map<String, dynamic>.from(rawArgs);
          print('✅ Arguments cast successful');
          
          _handleNativeNotification(args);
          print('✅ _handleNativeNotification called');
          break;
        default:
          print('❓ UNKNOWN METHOD: ${call.method}');
          log('Unknown method call: ${call.method}');
      }
    } catch (e) {
      print('💥 ERROR in method call handler: $e');
      log('💥 ERROR in method call handler: $e');
    }
  }



  /// Handle notifications from native Android code
  static void _handleNativeNotification(Map<String, dynamic> args) {
    try {
      print('🔥 STARTING _handleNativeNotification');
      
      final packageName = args['packageName'] as String?;
      final title = args['title'] as String?;
      final content = args['content'] as String?;
      final appName = args['appName'] as String?; // New field from Android
      final source = args['source'] as String? ?? 'notification';

      print('🔔 FLUTTER: Received notification from native');
      print('📱 Package: $packageName');
      print('📝 Title: $title');
      print('📄 Content: $content');
      print('🏷️ App Name: $appName');
      print('📡 Source: $source');
      
      log('🔔 FLUTTER: Received notification from native');
      log('📱 Package: $packageName');
      log('📝 Title: $title');
      log('📄 Content: $content');
      log('🏷️ App Name: $appName');
      log('📡 Source: $source');

      if (packageName == null) {
        print('❌ Package name is null, skipping');
        log('❌ Package name is null, skipping');
        return;
      }

      // Use provided app name or map from package
      final finalAppName = appName ?? _getAppNameFromPackage(packageName);
      print('🏷️ Final app name: $finalAppName');
      log('🏷️ Final app name: $finalAppName');
      
      if (finalAppName == null) {
        print('❌ App name not available, skipping');
        log('❌ App name not available, skipping');
        return;
      }

      final notificationText = '${title ?? ''} ${content ?? ''}'.trim();
      if (notificationText.isEmpty) {
        print('❌ Notification text is empty, skipping');
        log('❌ Notification text is empty, skipping');
        return;
      }

      print('🔍 Parsing notification text: $notificationText');
      log('🔍 Parsing notification text: $notificationText');

      final paymentNotification = PaymentParserService.parseNotification(
        appName: finalAppName,
        notificationText: notificationText,
        source: source,
      );

      if (paymentNotification != null) {
        print('✅ Payment parsed successfully: ${paymentNotification.amount} from ${paymentNotification.appName}');
        print('🚀 Sending to payment service...');
        log('✅ Payment parsed successfully: ${paymentNotification.amount} from ${paymentNotification.appName}');
        log('🚀 Sending to payment service...');
        _paymentService?.processPaymentNotification(paymentNotification);
        print('📤 Sent to payment service');
      } else {
        print('❌ Failed to parse payment from notification');
        log('❌ Failed to parse payment from notification');
      }
    } catch (e) {
      print('💥 Error handling native notification: $e');
      log('💥 Error handling native notification: $e');
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
      
      // SMS/Messaging apps (will be overridden by content detection)
      'com.google.android.apps.messaging': 'SMS',
      'com.android.mms': 'SMS',
      'com.samsung.android.messaging': 'SMS',
      'com.textra': 'SMS',
      'com.microsoft.android.sms': 'SMS',
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
      final hasPermission = await _channel.invokeMethod('hasNotificationPermission');
      log('Notification listener permission status: $hasPermission');
      return hasPermission ?? false;
    } catch (e) {
      log('Error checking notification listener status: $e');
      return false;
    }
  }

  /// Check if notification is payment-related
  static bool _isPaymentNotification(String title, String text) {
    final combinedText = '$title $text'.toLowerCase();
    
    // Payment success indicators
    final paymentIndicators = [
      'payment successful',
      'transaction successful',
      'paid npr',
      'paid rs',
      'payment complete',
      'transaction complete',
      'successfully transferred',
      'successfully paid',
      'payment of',
      'transaction of',
      'debited',
      'credited',
      'balance',
      'amount',
    ];

    return paymentIndicators.any((indicator) =>
        combinedText.contains(indicator.toLowerCase())
    );
  }

  /// Get notification listening status
  static bool get isListening => _isListening;
}