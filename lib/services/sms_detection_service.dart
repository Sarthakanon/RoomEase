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
    _paymentService = paymentService;
    _channel.setMethodCallHandler(_handleMethodCall);
    log('SMS Detection Service initialized');
  }

  /// Handle method calls from native code
  static Future<dynamic> _handleMethodCall(MethodCall call) async {
    switch (call.method) {
      case 'onSmsReceived':
        final args = call.arguments as Map<String, dynamic>;
        _handleNativeSms(args);
        break;
      default:
        log('Unknown method call: ${call.method}');
    }
  }

  /// Handle SMS from native Android code
  static void _handleNativeSms(Map<String, dynamic> args) {
    try {
      final sender = args['sender'] as String?;
      final body = args['body'] as String?;

      if (sender == null || body == null) return;

      log('Received SMS from $sender: $body');
      _processSmsMessage(sender, body);
    } catch (e) {
      log('Error handling native SMS: $e');
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
      log('SMS listener already active');
      return;
    }

    try {
      final hasPermission = await hasSmsPermission();
      if (!hasPermission) {
        log('SMS permission not granted');
        return;
      }

      // Start SMS listener via method channel
      await _channel.invokeMethod('startSmsListener');
      _isListening = true;
      log('SMS listener started successfully');
    } catch (e) {
      log('Error starting SMS listener: $e');
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
      log('Processing SMS from $sender: $body');

      // Check if sender is from supported bank/payment service
      if (!_isSupportedSender(sender)) {
        log('Sender not supported: $sender');
        return;
      }

      // Check if SMS contains payment keywords
      if (!_containsPaymentKeywords(body)) {
        log('No payment keywords found in SMS');
        return;
      }

      // Determine app name from sender
      final appName = _getAppNameFromSender(sender);
      
      // Parse the SMS for payment information
      final paymentNotification = PaymentParserService.parseNotification(
        appName: appName,
        notificationText: body,
        source: 'sms',
      );

      if (paymentNotification != null) {
        log('Payment detected from SMS: ${paymentNotification.amount} from ${paymentNotification.appName}');
        
        // Send to payment notification service
        _paymentService?.processPaymentNotification(paymentNotification);
      } else {
        log('Could not parse payment information from SMS');
      }
    } catch (e) {
      log('Error processing SMS message: $e');
    }
  }

  /// Check if sender is from supported bank/payment service
  static bool _isSupportedSender(String sender) {
    final upperSender = sender.toUpperCase();
    
    return supportedSenders.any((supportedSender) =>
        upperSender.contains(supportedSender.toUpperCase()) ||
        supportedSender.toUpperCase().contains(upperSender)
    );
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
}