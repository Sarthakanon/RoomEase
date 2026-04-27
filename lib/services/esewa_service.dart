import 'dart:convert';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:esewa_flutter/esewa_flutter.dart';
import 'package:crypto/crypto.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'api_service.dart';

/// eSewa Payment Service for handling subscription payments and balance settlements
/// 
/// Testing Flow:
/// 1. User clicks "Pay with eSewa" button
/// 2. App redirects to: https://rc-epay.esewa.com.np/auth
/// 3. User enters test credentials:
///    - eSewa ID: 9806800001, 9806800002, 9806800003, 9806800004, or 9806800005
///    - Password: Nepal@123
///    - MPIN: 1122
/// 4. Payment is processed and user is redirected back to success/failure URL
/// 5. App verifies payment with backend using signature verification
class EsewaService {
  static final EsewaService _instance = EsewaService._internal();
  factory EsewaService() => _instance;
  EsewaService._internal();

  final ApiService _apiService = ApiService();

  // eSewa SDK Test Configuration (from Android documentation)
  static const String _clientId = 'JB0BBQ4aD0UqIThFJwAKBgAXEUkEGQUBBAwdOgABHD4DChwUAB0R';
  static const String _clientSecret = 'BhwIWQQADhIYSxILExMcAgFXFhcOBwAKBgAXEQ==';
  static const String _merchantCode = 'EPAYTEST'; // Test merchant code
  static const String _secretKey = '8gBm/:&EnhH.1/q'; // Test secret key for v2
  static const String _environment = 'test'; // 'test' for development, 'live' for production
  
  // eSewa v2 Test URLs - these will redirect back to our app after payment
  static const String _successUrl = 'https://esewa.com.np/success';
  static const String _failureUrl = 'https://google.com';

  /// Process subscription payment via eSewa v2 SDK
  Future<EsewaPaymentResult> processSubscriptionPayment({
    required BuildContext context,
    required String planId,
    required double amount,
    required String planName,
  }) async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        throw Exception('User not authenticated');
      }

      // Generate unique transaction UUID
      final transactionUuid = _generateTransactionUuid('SUB');
      
      // Create eSewa SDK config for subscription (using test environment)
      final eSewaConfig = ESewaConfig.dev(
        amt: amount,
        su: _successUrl,
        fu: _failureUrl,
        pid: 'SUB-$transactionUuid',
      );

      print('🔧 eSewa Config: Environment=test, Amount=$amount, PID=SUB-$transactionUuid');
      print('🔧 Success URL: $_successUrl');
      print('🔧 Failure URL: $_failureUrl');

      // Process payment through eSewa SDK
      final result = await Esewa.i.init(
        context: context,
        eSewaConfig: eSewaConfig,
      );

      print('📱 eSewa SDK Result: ${result.hasData ? 'Success' : 'Failed'}');
      if (result.error != null) {
        print('❌ eSewa Error: ${result.error}');
      }

      if (result.hasData && result.data != null) {
        print('✅ Payment data received: ${result.data}');
        
        // Verify payment with backend
        final verificationResult = await _verifySubscriptionPayment(
          transactionData: result.data!.toString(),
          planId: planId,
          amount: amount,
          transactionUuid: transactionUuid,
        );

        return EsewaPaymentResult(
          success: verificationResult,
          transactionId: transactionUuid,
          amount: amount,
          message: verificationResult 
              ? 'Subscription payment successful' 
              : 'Payment verification failed',
        );
      } else {
        return EsewaPaymentResult(
          success: false,
          transactionId: transactionUuid,
          amount: amount,
          message: result.error ?? 'Payment failed or cancelled',
        );
      }
    } catch (e) {
      print('❌ Payment processing error: $e');
      return EsewaPaymentResult(
        success: false,
        transactionId: '',
        amount: amount,
        message: 'Payment error: ${e.toString()}',
      );
    }
  }

  /// Process balance settlement payment via eSewa v2 SDK
  Future<EsewaPaymentResult> processBalanceSettlement({
    required BuildContext context,
    required String roomspaceId,
    required String recipientUserId,
    required double amount,
    required String description,
  }) async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        throw Exception('User not authenticated');
      }

      // Generate unique transaction UUID
      final transactionUuid = _generateTransactionUuid('BAL');
      
      // Create eSewa SDK config for balance settlement (using test environment)
      final eSewaConfig = ESewaConfig.dev(
        amt: amount,
        su: _successUrl,
        fu: _failureUrl,
        pid: 'BAL-$transactionUuid',
      );

      print('🔧 eSewa Config: Environment=test, Amount=$amount, PID=BAL-$transactionUuid');
      print('🔧 Success URL: $_successUrl');
      print('🔧 Failure URL: $_failureUrl');

      // Process payment through eSewa SDK
      final result = await Esewa.i.init(
        context: context,
        eSewaConfig: eSewaConfig,
      );

      print('📱 eSewa SDK Result: ${result.hasData ? 'Success' : 'Failed'}');
      if (result.error != null) {
        print('❌ eSewa Error: ${result.error}');
      }

      if (result.hasData && result.data != null) {
        print('✅ Payment data received: ${result.data}');
        
        // Verify payment and create settlement record
        final verificationResult = await _verifyBalanceSettlement(
          transactionData: result.data!.toString(),
          roomspaceId: roomspaceId,
          recipientUserId: recipientUserId,
          amount: amount,
          description: description,
          transactionUuid: transactionUuid,
        );

        return EsewaPaymentResult(
          success: verificationResult,
          transactionId: transactionUuid,
          amount: amount,
          message: verificationResult 
              ? 'Balance settlement successful' 
              : 'Settlement verification failed',
        );
      } else {
        return EsewaPaymentResult(
          success: false,
          transactionId: transactionUuid,
          amount: amount,
          message: result.error ?? 'Payment failed or cancelled',
        );
      }
    } catch (e) {
      print('❌ Settlement processing error: $e');
      return EsewaPaymentResult(
        success: false,
        transactionId: '',
        amount: amount,
        message: 'Settlement error: ${e.toString()}',
      );
    }
  }

  /// Verify subscription payment with backend
  Future<bool> _verifySubscriptionPayment({
    required String transactionData,
    required String planId,
    required double amount,
    required String transactionUuid,
  }) async {
    try {
      // Decode base64 transaction data
      final decodedData = utf8.decode(base64.decode(transactionData));
      final transactionInfo = jsonDecode(decodedData) as Map<String, dynamic>;

      // Verify signature
      if (!_verifySignature(transactionInfo)) {
        print('❌ Signature verification failed');
        return false;
      }

      // Check transaction status
      if (transactionInfo['status'] != 'COMPLETE') {
        print('❌ Transaction not complete: ${transactionInfo['status']}');
        return false;
      }

      // Verify amount
      final paidAmount = double.tryParse(transactionInfo['total_amount'].toString()) ?? 0;
      if (paidAmount != amount) {
        print('❌ Amount mismatch: expected $amount, got $paidAmount');
        return false;
      }

      // Send verification to backend
      final response = await _apiService.post('/api/payments/subscription/verify', data: {
        'plan_id': planId,
        'transaction_uuid': transactionUuid,
        'transaction_code': transactionInfo['transaction_code'],
        'amount': amount,
        'esewa_response': transactionInfo,
      });

      return response['success'] == true;
    } catch (e) {
      print('❌ Subscription verification error: $e');
      return false;
    }
  }

  /// Verify balance settlement with backend
  Future<bool> _verifyBalanceSettlement({
    required String transactionData,
    required String roomspaceId,
    required String recipientUserId,
    required double amount,
    required String description,
    required String transactionUuid,
  }) async {
    try {
      // Decode base64 transaction data
      final decodedData = utf8.decode(base64.decode(transactionData));
      final transactionInfo = jsonDecode(decodedData) as Map<String, dynamic>;

      // Verify signature
      if (!_verifySignature(transactionInfo)) {
        print('❌ Signature verification failed');
        return false;
      }

      // Check transaction status
      if (transactionInfo['status'] != 'COMPLETE') {
        print('❌ Transaction not complete: ${transactionInfo['status']}');
        return false;
      }

      // Verify amount
      final paidAmount = double.tryParse(transactionInfo['total_amount'].toString()) ?? 0;
      if (paidAmount != amount) {
        print('❌ Amount mismatch: expected $amount, got $paidAmount');
        return false;
      }

      // Send settlement to backend
      final response = await _apiService.post('/api/payments/settlement/verify', data: {
        'roomspace_id': roomspaceId,
        'recipient_user_id': recipientUserId,
        'amount': amount,
        'description': description,
        'transaction_uuid': transactionUuid,
        'transaction_code': transactionInfo['transaction_code'],
        'esewa_response': transactionInfo,
      });

      return response['success'] == true;
    } catch (e) {
      print('❌ Settlement verification error: $e');
      return false;
    }
  }

  /// Verify eSewa signature
  bool _verifySignature(Map<String, dynamic> transactionInfo) {
    try {
      final signedFieldNames = transactionInfo['signed_field_names'] as String;
      final signature = transactionInfo['signature'] as String;
      
      // Build message from signed fields
      final fields = signedFieldNames.split(',');
      final messageBuilder = StringBuffer();
      
      for (int i = 0; i < fields.length; i++) {
        final fieldName = fields[i].trim();
        final fieldValue = transactionInfo[fieldName]?.toString() ?? '';
        messageBuilder.write('$fieldName=$fieldValue');
        if (i < fields.length - 1) {
          messageBuilder.write(',');
        }
      }
      
      final message = messageBuilder.toString();
      
      // Generate HMAC-SHA256 signature
      final key = utf8.encode(_secretKey);
      final bytes = utf8.encode(message);
      final hmacSha256 = Hmac(sha256, key);
      final digest = hmacSha256.convert(bytes);
      final computedSignature = base64.encode(digest.bytes);
      
      return computedSignature == signature;
    } catch (e) {
      print('❌ Signature verification error: $e');
      return false;
    }
  }

  /// Generate unique transaction UUID
  String _generateTransactionUuid(String prefix) {
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final random = Random().nextInt(9999);
    return '$prefix-$timestamp-$random';
  }

  /// Get eSewa test configuration info for debugging
  Map<String, String> getTestConfigInfo() {
    return {
      'client_id': _clientId,
      'client_secret': _clientSecret,
      'merchant_code': _merchantCode,
      'environment': _environment,
      'test_esewa_ids': '9806800001, 9806800002, 9806800003, 9806800004, 9806800005',
      'test_password': 'Nepal@123',
      'test_mpin': '1122',
      'success_url': _successUrl,
      'failure_url': _failureUrl,
      'note': 'Using ESewaConfig.dev() - should redirect to test environment automatically',
    };
  }

  /// Test eSewa configuration by creating a minimal config
  void testEsewaConfig() {
    print('🧪 Testing eSewa Configuration:');
    print('📋 Client ID: $_clientId');
    print('🔐 Client Secret: ${_clientSecret.substring(0, 10)}...');
    print('🏪 Merchant Code: $_merchantCode');
    print('🌍 Environment: $_environment');
    print('✅ Success URL: $_successUrl');
    print('❌ Failure URL: $_failureUrl');
    
    // Test config creation
    try {
      ESewaConfig.dev(
        amt: 100.0,
        su: _successUrl,
        fu: _failureUrl,
        pid: 'TEST-${DateTime.now().millisecondsSinceEpoch}',
      );
      print('✅ ESewaConfig.dev() created successfully');
    } catch (e) {
      print('❌ ESewaConfig.dev() failed: $e');
    }
  }

  /// Show eSewa v2 payment button widget
  Widget buildEsewaPaymentButton({
    required double amount,
    required String description,
    required VoidCallback onSuccess,
    required Function(String) onFailure,
    String buttonText = 'Pay with eSewa',
    Color? buttonColor,
  }) {
    return EsewaPayButton(
      paymentConfig: ESewaConfig.dev(
        amt: amount,
        su: _successUrl,
        fu: _failureUrl,
        pid: 'PAY-${DateTime.now().millisecondsSinceEpoch}',
      ),
      onSuccess: (resp) {
        print('✅ eSewa payment success: ${resp}');
        onSuccess();
      },
      onFailure: (message) {
        print('❌ eSewa payment failed: $message');
        onFailure(message);
      },
    );
  }

  /// Check eSewa v2 transaction status
  Future<EsewaTransactionStatus> checkTransactionStatus({
    required String transactionUuid,
    required double totalAmount,
    String productCode = 'EPAYTEST',
  }) async {
    try {
      // eSewa v2 testing environment transaction status URL
      const baseUrl = 'https://rc-epay.esewa.com.np/api/epay/transaction/status/';
      final url = '$baseUrl?product_code=$productCode&total_amount=$totalAmount&transaction_uuid=$transactionUuid';
      
      final response = await _apiService.get(url);
      
      if (response['status'] != null) {
        return EsewaTransactionStatus(
          status: response['status'],
          transactionUuid: response['transaction_uuid'],
          totalAmount: double.tryParse(response['total_amount'].toString()) ?? 0,
          refId: response['ref_id'],
        );
      } else {
        throw Exception('Invalid response format');
      }
    } catch (e) {
      print('❌ Transaction status check error: $e');
      return EsewaTransactionStatus(
        status: 'ERROR',
        transactionUuid: transactionUuid,
        totalAmount: totalAmount,
        refId: null,
      );
    }
  }
}

/// eSewa payment result model
class EsewaPaymentResult {
  final bool success;
  final String transactionId;
  final double amount;
  final String message;

  EsewaPaymentResult({
    required this.success,
    required this.transactionId,
    required this.amount,
    required this.message,
  });
}

/// eSewa transaction status model
class EsewaTransactionStatus {
  final String status;
  final String transactionUuid;
  final double totalAmount;
  final String? refId;

  EsewaTransactionStatus({
    required this.status,
    required this.transactionUuid,
    required this.totalAmount,
    this.refId,
  });

  bool get isComplete => status == 'COMPLETE';
  bool get isPending => status == 'PENDING';
  bool get isCanceled => status == 'CANCELED';
  bool get isRefunded => status == 'FULL_REFUND' || status == 'PARTIAL_REFUND';
}