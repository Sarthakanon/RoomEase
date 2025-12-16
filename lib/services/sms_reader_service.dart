import 'dart:developer';
import 'package:flutter/services.dart';
import 'package:permission_handler/permission_handler.dart';
import '../models/payment_notification.dart';
import 'payment_parser_service.dart';
import 'payment_notification_service.dart';

class SmsReaderService {
  static const MethodChannel _channel = MethodChannel('sms_reader_channel');
  static PaymentNotificationService? _paymentService;

  /// Initialize the SMS reader service
  static Future<void> initialize(PaymentNotificationService paymentService) async {
    _paymentService = paymentService;
  }

  /// Request SMS read permission
  static Future<bool> requestSmsPermission() async {
    try {
      final status = await Permission.sms.request();
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
    try {
      final hasPermission = await requestSmsPermission();
      if (!hasPermission) {
        log('SMS permission not granted');
        return;
      }

      // Set up method channel handler for SMS messages
      _channel.setMethodCallHandler(_handleMethodCall);

      log('SMS listener started successfully');
      log('Note: For full SMS detection, native Android implementation would be needed');
      log('Currently using manual testing feature in settings');
    } catch (e) {
      log('Error starting SMS listener: $e');
    }
  }

  /// Manual method to test SMS parsing with eSewa format
  static void testEsewaPayment(String smsText) {
    log('Testing eSewa SMS: $smsText');
    
    final smsData = {
      'sender': 'ESEWA',
      'body': smsText,
    };
    
    _processSmsMessage(smsData);
  }



  /// Process SMS message for payment information
  static void _processSmsMessage(Map<String, dynamic> smsData) {
    try {
      final sender = smsData['sender'] as String?;
      final body = smsData['body'] as String?;
      
      log('Received SMS from $sender: $body');

      if (sender == null || body == null) return;

      // Check if SMS is from a banking institution
      final bankName = _identifyBankFromSender(sender);
      if (bankName == null) {
        return; // Not from a supported bank
      }

      // Parse the SMS content
      final paymentNotification = PaymentParserService.parseNotification(
        appName: bankName,
        notificationText: body,
        source: 'sms',
      );

      if (paymentNotification != null) {
        _paymentService?.processPaymentNotification(paymentNotification);
      }
    } catch (e) {
      log('Error processing SMS: $e');
    }
  }

  /// Identify bank from SMS sender
  static String? _identifyBankFromSender(String sender) {
    // Common SMS sender IDs for Nepali banks
    const senderToBankMap = {
      // NMB Bank
      'NMB': 'NMB Bank',
      'NMBBANK': 'NMB Bank',
      'NMB-BANK': 'NMB Bank',
      
      // Sanima Bank
      'SANIMA': 'Sanima Bank',
      'SANIMABANK': 'Sanima Bank',
      'SANIMA-BANK': 'Sanima Bank',
      
      // Everest Bank
      'EVEREST': 'Everest Bank',
      'EVERESTBANK': 'Everest Bank',
      'EBL': 'Everest Bank',
      
      // Nepal Bank
      'NEPALBANK': 'Nepal Bank',
      'NBL': 'Nepal Bank',
      
      // Rastriya Banijya Bank
      'RBB': 'Rastriya Banijya Bank',
      'RBBANK': 'Rastriya Banijya Bank',
      
      // Nabil Bank
      'NABIL': 'Nabil Bank',
      'NABILBANK': 'Nabil Bank',
      
      // Standard Chartered
      'SCB': 'Standard Chartered',
      'SCBANK': 'Standard Chartered',
      'STANDARD': 'Standard Chartered',
      
      // Himalayan Bank
      'HBL': 'Himalayan Bank',
      'HIMALAYAN': 'Himalayan Bank',
      
      // Nepal Investment Bank
      'NIB': 'Nepal Investment Bank',
      'NIBBANK': 'Nepal Investment Bank',
      
      // Machhapuchchhre Bank
      'MBL': 'Machhapuchchhre Bank',
      'MACHHA': 'Machhapuchchhre Bank',
      
      // Payment services
      'ESEWA': 'eSewa',
      'KHALTI': 'Khalti',
      'IMEPAY': 'IME Pay',
      'CONNECTIPS': 'ConnectIPS',
      'FONEPAY': 'FonePay',
    };

    final upperSender = sender.toUpperCase();

    // Direct match
    if (senderToBankMap.containsKey(upperSender)) {
      return senderToBankMap[upperSender];
    }

    // Partial match
    for (final entry in senderToBankMap.entries) {
      if (upperSender.contains(entry.key) || entry.key.contains(upperSender)) {
        return entry.value;
      }
    }

    // Check for common banking keywords
    if (upperSender.contains('BANK') || 
        upperSender.contains('ATM') ||
        upperSender.contains('CARD') ||
        upperSender.contains('DEBIT') ||
        upperSender.contains('CREDIT')) {
      return 'Unknown Bank';
    }

    return null;
  }

  /// Read recent SMS messages for initial processing
  static Future<void> processRecentSms({int hours = 24}) async {
    try {
      final hasPermission = await hasSmsPermission();
      if (!hasPermission) {
        log('SMS permission not available for reading recent messages');
        return;
      }

      // For now, we'll skip reading recent SMS to avoid complexity
      // In a production app, this would use native Android code to read SMS
      log('Recent SMS processing would be implemented with native Android code');
      log('Use the manual SMS testing feature in settings to test payment detection');
    } catch (e) {
      log('Error processing recent SMS: $e');
    }
  }

  /// Handle method calls from native code
  static Future<dynamic> _handleMethodCall(MethodCall call) async {
    switch (call.method) {
      case 'onSmsReceived':
        final args = call.arguments as Map<String, dynamic>;
        _processSmsMessage(args);
        break;
      default:
        log('Unknown method call: ${call.method}');
    }
  }

  /// Stop SMS listening
  static Future<void> stopListening() async {
    try {
      // The listener will be automatically stopped when app is closed
      log('SMS listener stopped');
    } catch (e) {
      log('Error stopping SMS listener: $e');
    }
  }
}