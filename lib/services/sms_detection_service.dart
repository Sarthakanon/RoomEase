import 'dart:developer';
import 'package:flutter/services.dart';
import 'package:permission_handler/permission_handler.dart';
import '../models/payment_notification.dart';
import 'payment_notification_service.dart';
import 'payment_parser_service.dart';

class SmsDetectionService {
  static const MethodChannel _channel = MethodChannel('sms_detection_channel');
  static PaymentNotificationService? _paymentService;
  static bool _isListening = false;

  // Supported bank SMS senders in Nepal
  static const List<String> supportedSenders = [
    'NABIL',
    'NIC ASIA',
    'NMB',
    'GLOBAL',
    'EVEREST',
    'NEPAL BANK',
    'RBB',
    'SANIMA',
    'SCB',
    'HIMALAYAN',
    'NIB',
    'MACHHAPUCHCHHRE',
    'ESEWA',
    'KHALTI',
    'IMEPAY',
    'CONNECTIPS',
    'FONEPAY',
    'IPAY',
    // Add more generic patterns for bank SMS
    'BANK',
    'BANKING',
    'ATM',
    'CARD',
    // Common short codes and numbers that banks use
    '9801',
    '9802',
    '9803',
    '9804',
    '9805',
    '1234',
    '5678',
    // Generic patterns
    'ALERT',
    'NOTIFICATION',
  ];

  // Payment keywords to detect transaction SMS
  static const List<String> paymentKeywords = [
    'credited',
    'debited',
    'paid',
    'payment',
    'transaction',
    'successful',
    'amount',
    'NPR',
    'Rs.',
    'transfer',
    'sent',
    'received',
    'balance',
    // Nepali terms in English script
    'paisā',
    'rākam',
    'bhuktan',
  ];

  /// Initialize SMS detection service
  static Future<void> initialize(PaymentNotificationService paymentService) async {
    log('🔧 INITIALIZING SMS DETECTION SERVICE...');
    _paymentService = paymentService;
    _channel.setMethodCallHandler(_handleMethodCall);
    log('📞 SMS Method call handler set for channel: sms_detection_channel');
    log('✅ SMS Detection Service initialized');
  }

  /// Handle method calls from native code
  static Future<dynamic> _handleMethodCall(MethodCall call) async {
    log('🔥 SMS METHOD CALL RECEIVED: ${call.method}');
    log('📦 SMS Arguments: ${call.arguments}');
    
    switch (call.method) {
      case 'onSmsReceived':
        log('📱 Processing SMS method call');
        final args = call.arguments as Map<String, dynamic>;
        _handleNativeSms(args);
        break;
      default:
        log('❓ Unknown SMS method call: ${call.method}');
    }
  }

  /// Handle SMS from native Android code
  static void _handleNativeSms(Map<String, dynamic> args) {
    try {
      log('🔥 SMS RECEIVED IN FLUTTER!');
      log('📦 SMS Args: $args');
      
      final sender = args['sender'] as String?;
      final body = args['body'] as String?;

      if (sender == null || body == null) {
        log('❌ Invalid SMS data received - sender: $sender, body: $body');
        return;
      }

      log('📱 Received SMS from $sender: $body');
      _processSmsMessage(sender, body);
    } catch (e, stackTrace) {
      log('❌ CRITICAL ERROR handling native SMS: $e');
      log('Stack trace: $stackTrace');
      log('Args received: $args');
      // Don't rethrow - prevent app crash
    }
  }

  /// Request SMS permissions
  static Future<bool> requestSmsPermission() async {
    try {
      final status = await Permission.sms.request();
      log('SMS permission status: $status');
      return status == PermissionStatus.granted;
    } catch (e) {
      log('Error requesting SMS permission: $e');
      return false;
    }
  }

  /// Check if SMS permission is granted
  static Future<bool> hasSmsPermission() async {
    try {
      final status = await Permission.sms.status;
      return status == PermissionStatus.granted;
    } catch (e) {
      log('Error checking SMS permission: $e');
      return false;
    }
  }

  /// Start listening to incoming SMS messages
  static Future<void> startListening() async {
    if (_isListening) {
      log('📱 SMS listener already active');
      return;
    }

    try {
      final hasPermission = await hasSmsPermission();
      if (!hasPermission) {
        log('❌ SMS permission not granted');
        return;
      }

      // Start SMS listener via method channel
      log('🚀 Starting SMS listener via method channel...');
      await _channel.invokeMethod('startSmsListener');
      _isListening = true;
      log('✅ SMS listener started successfully');
    } catch (e) {
      log('❌ Error starting SMS listener: $e');
    }
  }

  /// Stop SMS listening
  static Future<void> stopListening() async {
    try {
      await _channel.invokeMethod('stopSmsListener');
      _isListening = false;
      log('SMS listener stopped');
    } catch (e) {
      log('Error stopping SMS listener: $e');
    }
  }

  /// Process SMS message for payment detection
  static void _processSmsMessage(String sender, String body) {
    try {
      log('🔍 Processing SMS from $sender: $body');

      // Check if sender is from supported bank/payment service
      if (!_isSupportedSender(sender)) {
        log('❌ Sender not supported: $sender');
        return;
      }

      // Check if SMS contains payment keywords
      if (!_containsPaymentKeywords(body)) {
        log('❌ No payment keywords found in SMS: $body');
        return;
      }

      log('✅ SMS passed initial checks - proceeding with parsing');

      // Determine app name from sender
      final appName = _getAppNameFromSender(sender);
      log('📱 App name determined: $appName');
      
      // Parse the SMS for payment information
      final paymentNotification = PaymentParserService.parseNotification(
        appName: appName,
        notificationText: body,
        source: 'sms',
      );

      if (paymentNotification != null) {
        log('🎉 Payment detected from SMS: ${paymentNotification.amount} from ${paymentNotification.appName}');
        
        // Send to payment notification service with additional error handling
        try {
          log('📤 Sending to payment service...');
          _paymentService?.processPaymentNotification(paymentNotification);
          log('✅ Successfully sent to payment service');
        } catch (e, stackTrace) {
          log('❌ Error in payment service processing: $e');
          log('Stack trace: $stackTrace');
          // Don't rethrow - continue execution
        }
      } else {
        log('❌ Could not parse payment information from SMS');
        log('   Sender: $sender');
        log('   Body: $body');
        log('   App name: $appName');
      }
    } catch (e, stackTrace) {
      log('❌ CRITICAL ERROR processing SMS message: $e');
      log('Stack trace: $stackTrace');
      log('   Sender: $sender');
      log('   Body: $body');
      // Don't rethrow - prevent app crash
    }
  }

  /// Check if sender is from supported bank/payment service
  static bool _isSupportedSender(String sender) {
    final upperSender = sender.toUpperCase();
    
    // First check exact matches
    bool isSupported = supportedSenders.any((supportedSender) =>
        upperSender.contains(supportedSender.toUpperCase()) ||
        supportedSender.toUpperCase().contains(upperSender)
    );
    
    // If not found in list, check if it's a numeric sender (common for banks)
    if (!isSupported) {
      // Check if sender is numeric (banks often use short codes)
      final isNumeric = RegExp(r'^\d+$').hasMatch(sender);
      if (isNumeric) {
        log('Numeric sender detected: $sender - treating as potential bank SMS');
        return true;
      }
      
      // Check if sender contains common bank-related terms
      final bankTerms = ['BANK', 'ATM', 'CARD', 'ALERT', 'NOTIFICATION'];
      isSupported = bankTerms.any((term) => upperSender.contains(term));
    }
    
    log('Sender check for "$sender": $isSupported');
    return isSupported;
  }

  /// Check if SMS body contains payment-related keywords
  static bool _containsPaymentKeywords(String body) {
    final lowerBody = body.toLowerCase();
    
    return paymentKeywords.any((keyword) =>
        lowerBody.contains(keyword.toLowerCase())
    );
  }

  /// Get app name from SMS sender
  static String _getAppNameFromSender(String sender) {
    final upperSender = sender.toUpperCase();
    
    // Map common sender patterns to app names
    if (upperSender.contains('ESEWA')) return 'eSewa';
    if (upperSender.contains('KHALTI')) return 'Khalti';
    if (upperSender.contains('IMEPAY')) return 'IME Pay';
    if (upperSender.contains('FONEPAY')) return 'FonePay';
    if (upperSender.contains('IPAY')) return 'iPay';
    if (upperSender.contains('CONNECTIPS')) return 'ConnectIPS';
    
    // Bank mappings
    if (upperSender.contains('NABIL')) return 'Nabil Bank';
    if (upperSender.contains('NIC') && upperSender.contains('ASIA')) return 'NIC Asia Bank';
    if (upperSender.contains('NMB')) return 'NMB Bank';
    if (upperSender.contains('GLOBAL')) return 'Global IME Bank';
    if (upperSender.contains('EVEREST')) return 'Everest Bank';
    if (upperSender.contains('NEPAL') && upperSender.contains('BANK')) return 'Nepal Bank';
    if (upperSender.contains('RBB')) return 'Rastriya Banijya Bank';
    if (upperSender.contains('SANIMA')) return 'Sanima Bank';
    if (upperSender.contains('SCB')) return 'Standard Chartered Bank';
    if (upperSender.contains('HIMALAYAN')) return 'Himalayan Bank';
    if (upperSender.contains('NIB')) return 'Nepal Investment Bank';
    if (upperSender.contains('MACHHAPUCHCHHRE')) return 'Machhapuchchhre Bank';
    
    // Default to sender if no specific mapping found
    return sender;
  }

  /// Process recent SMS messages (for initial setup)
  static Future<void> processRecentSms() async {
    try {
      final hasPermission = await hasSmsPermission();
      if (!hasPermission) {
        log('SMS permission not granted for processing recent messages');
        return;
      }

      // Request recent SMS via method channel
      await _channel.invokeMethod('processRecentSms');
      log('Requested processing of recent SMS messages');
    } catch (e) {
      log('Error processing recent SMS messages: $e');
    }
  }

  /// Get SMS listening status
  static bool get isListening => _isListening;
  
  /// Manual test method for debugging SMS detection
  static void testSmsDetection(String sender, String body) {
    log('🧪 MANUAL TEST: Testing SMS detection');
    log('   Sender: $sender');
    log('   Body: $body');
    
    _processSmsMessage(sender, body);
  }
  
  /// Test with your specific message format
  static void testYourMessage() {
    const testSender = "9801234567";
    const testMessage = "Your #282###32100 has been Debited by NPR 500.00 on 01/04/2026 19:24:56";
    
    log('🧪 Testing your specific message format...');
    testSmsDetection(testSender, testMessage);
  }
}