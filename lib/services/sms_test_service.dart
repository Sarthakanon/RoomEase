import 'dart:developer';
import 'payment_parser_service.dart';
import 'sms_detection_service.dart';

class SmsTestService {
  /// Test SMS detection with your specific message format
  static void testSmsDetection() {
    log('🧪 Testing SMS detection...');
    
    // Your specific message
    const testMessage = "Your #282###32100 has been Debited by NPR 500.00 on 01/04/2026 19:24:56";
    const testSender = "9801234567"; // Example numeric sender
    
    log('📱 Testing message: $testMessage');
    log('📱 Testing sender: $testSender');
    
    // Test sender validation
    // final isSupportedSender = SmsDetectionService._isSupportedSender(testSender);
    // log('✅ Sender supported: $isSupportedSender');
    
    // Test keyword detection
    // final hasKeywords = SmsDetectionService._containsPaymentKeywords(testMessage);
    // log('✅ Has payment keywords: $hasKeywords');
    
    // Test amount extraction
    // final amount = PaymentParserService._extractAmount(testMessage);
    // log('✅ Extracted amount: $amount');
    
    // Test transaction type
    // final type = PaymentParserService._determineTransactionType(testMessage);
    // log('✅ Transaction type: $type');
    
    log('⚠️ SMS test methods are currently disabled for compilation');
    
    // Test full parsing
    final notification = PaymentParserService.parseNotification(
      appName: 'Bank SMS',
      notificationText: testMessage,
      source: 'sms',
    );
    
    if (notification != null) {
      log('🎉 SUCCESS! Parsed notification:');
      log('   Amount: ${notification.amount}');
      log('   Type: ${notification.type}');
      log('   App: ${notification.appName}');
      log('   Merchant: ${notification.merchant}');
    } else {
      log('❌ FAILED to parse notification');
    }
  }
  
  /// Test with various message formats
  static void testVariousFormats() {
    final testCases = [
      {
        'sender': '9801234567',
        'message': 'Your #282###32100 has been Debited by NPR 500.00 on 01/04/2026 19:24:56',
        'expected_amount': 500.0,
      },
      {
        'sender': 'NABIL',
        'message': 'Your account has been debited by Rs. 1,200.50 for transaction at ATM',
        'expected_amount': 1200.5,
      },
      {
        'sender': '1234',
        'message': 'Amount NPR 750 has been debited from your account',
        'expected_amount': 750.0,
      },
      {
        'sender': 'ESEWA',
        'message': 'You have successfully transferred Rs. 300.00 to John Doe',
        'expected_amount': 300.0,
      },
    ];
    
    log('🧪 Testing various SMS formats...');
    
    for (int i = 0; i < testCases.length; i++) {
      final testCase = testCases[i];
      final sender = testCase['sender'] as String;
      final message = testCase['message'] as String;
      final expectedAmount = testCase['expected_amount'] as double;
      
      log('📱 Test ${i + 1}: $sender -> $message');
      
      final notification = PaymentParserService.parseNotification(
        appName: sender,
        notificationText: message,
        source: 'sms',
      );
      
      if (notification != null && notification.amount == expectedAmount) {
        log('✅ Test ${i + 1} PASSED - Amount: ${notification.amount}');
      } else {
        log('❌ Test ${i + 1} FAILED - Expected: $expectedAmount, Got: ${notification?.amount}');
      }
    }
  }
}