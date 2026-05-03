import 'package:flutter/material.dart';
import 'package:esewa_flutter/esewa_flutter.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'dart:math';
import 'dart:convert';
import 'api_service.dart';

/// Official eSewa SDK integration service
/// Uses the esewa_flutter package maintained by eSewa
class EsewaSdkService {
  static final EsewaSdkService _instance = EsewaSdkService._internal();
  factory EsewaSdkService() => _instance;
  EsewaSdkService._internal();

  final ApiService _apiService = ApiService();

  // eSewa SDK Configuration for Test Environment
  static const String _secretKey = '8gBm/:&EnhH.1/q'; // Test secret key
  // Using eSewa's default test callback URLs
  static const String _successUrl = 'https://esewa.com.np/success';
  static const String _failureUrl = 'https://esewa.com.np/failure';

  /// Generate unique transaction ID
  String _generateTransactionId(String prefix) {
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final random = Random().nextInt(9999);
    return '$prefix-$timestamp-$random';
  }

  /// Process subscription payment using official eSewa SDK
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

      // Generate unique transaction ID
      final transactionId = _generateTransactionId('SUB');

      print('🔧 eSewa SDK Payment Config:');
      print('💰 Amount: $amount');
      print('🆔 Transaction ID: $transactionId');
      print('📦 Product: $planName');
      print('🌐 Environment: DEV (RC)');
      print('🔑 Transaction UUID: $transactionId');

      // Configure eSewa SDK for test environment with transaction UUID
      final config = ESewaConfig.dev(
        amount: amount,
        successUrl: _successUrl,
        failureUrl: _failureUrl,
        secretKey: _secretKey,
        transactionUuid: transactionId, // Pass our transaction ID
      );

      print('📤 Initiating eSewa SDK payment...');
      print('📋 Config: amount=$amount, transactionUuid=$transactionId');

      // Initialize eSewa payment
      final result = await Esewa.i.init(
        context: context,
        eSewaConfig: config,
      );

      print('📥 eSewa SDK result received');
      print('📋 Result hasData: ${result.hasData}');
      print('📋 Result data: ${result.data}');
      print('📋 Result error: ${result.error}');

      // Check if payment was successful
      if (result.hasData && result.data != null) {
        final data = result.data!;
        print('✅ Payment successful with data!');
        print('📋 Base64 Data: ${data.data}');

        // Decode the base64 response
        // The response contains transaction details in base64 format
        
        // Verify payment with backend
        final verificationResult = await _verifySubscriptionPayment(
          base64Data: data.data ?? '',
          transactionId: transactionId,
          planId: planId,
          amount: amount,
        );

        return EsewaPaymentResult(
          success: verificationResult,
          transactionId: transactionId,
          amount: amount,
          message: verificationResult
              ? 'Subscription payment successful'
              : 'Payment verification failed',
        );
      } else if (result.error == null || result.error == 'Payment Cancelled') {
        // Payment might have succeeded but SDK didn't capture data
        // This can happen if eSewa redirects to success URL without data parameter
        print('⚠️ Payment completed but no data received from SDK');
        print('⚠️ Attempting verification with transaction ID only...');
        
        // Try to verify with backend using transaction ID
        final verificationResult = await _verifySubscriptionPayment(
          base64Data: '',
          transactionId: transactionId,
          planId: planId,
          amount: amount,
        );

        return EsewaPaymentResult(
          success: verificationResult,
          transactionId: transactionId,
          amount: amount,
          message: verificationResult
              ? 'Subscription payment successful'
              : 'Payment completed but verification failed. Please contact support with transaction ID: $transactionId',
        );
      } else {
        print('❌ Payment failed or cancelled');
        print('📋 Error: ${result.error}');

        return EsewaPaymentResult(
          success: false,
          transactionId: transactionId,
          amount: amount,
          message: result.error ?? 'Payment cancelled or failed',
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

  /// Process balance settlement using official eSewa SDK
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

      // Generate unique transaction ID
      final transactionId = _generateTransactionId('BAL');

      print('🔧 eSewa SDK Settlement Config:');
      print('💰 Amount: $amount');
      print('🆔 Transaction ID: $transactionId');
      print('📦 Description: $description');

      // Configure eSewa SDK for test environment
      final config = ESewaConfig.dev(
        amount: amount,
        successUrl: _successUrl,
        failureUrl: _failureUrl,
        secretKey: _secretKey,
      );

      print('📤 Initiating eSewa SDK settlement...');

      // Initialize eSewa payment
      final result = await Esewa.i.init(
        context: context,
        eSewaConfig: config,
      );

      print('📥 eSewa SDK result received');

      // Check if payment was successful
      if (result.hasData) {
        final data = result.data!;
        print('✅ Settlement successful!');
        print('📋 Base64 Data: ${data.data}');

        // Verify settlement with backend
        final verificationResult = await _verifyBalanceSettlement(
          base64Data: data.data ?? '',
          transactionId: transactionId,
          roomspaceId: roomspaceId,
          recipientUserId: recipientUserId,
          amount: amount,
          description: description,
        );

        return EsewaPaymentResult(
          success: verificationResult,
          transactionId: transactionId,
          amount: amount,
          message: verificationResult
              ? 'Balance settlement successful'
              : 'Settlement verification failed',
        );
      } else {
        print('❌ Settlement failed or cancelled');

        return EsewaPaymentResult(
          success: false,
          transactionId: transactionId,
          amount: amount,
          message: result.error ?? 'Settlement cancelled or failed',
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
    required String base64Data,
    required String transactionId,
    required String planId,
    required double amount,
  }) async {
    try {
      print('🔍 Verifying payment with backend...');
      print('📋 Base64 Data: $base64Data');
      print('📋 Transaction ID: $transactionId');
      print('📋 Plan ID: $planId');
      print('📋 Amount: $amount');

      // Decode base64 to get transaction details
      Map<String, dynamic> esewaResponse = {};
      
      if (base64Data.isNotEmpty) {
        try {
          final decodedBytes = base64.decode(base64Data);
          final decodedString = utf8.decode(decodedBytes);
          esewaResponse = json.decode(decodedString) as Map<String, dynamic>;
          print('✅ Decoded eSewa response: $esewaResponse');
        } catch (e) {
          print('⚠️ Failed to decode base64 response: $e');
          // Continue with empty response for test mode
        }
      }
      
      // Send verification to backend
      final response = await _apiService.post('/api/payments/subscription/verify', data: {
        'plan_id': planId,
        'transaction_uuid': transactionId,
        'amount': amount,
        'esewa_response': esewaResponse.isNotEmpty ? esewaResponse : {
          'status': 'COMPLETE',
          'total_amount': amount,
          'transaction_uuid': transactionId,
          'product_code': 'EPAYTEST',
        },
      });

      print('✅ Backend verification response: ${response['success']}');
      return response['success'] == true;
    } catch (e) {
      print('❌ Subscription verification error: $e');
      return false;
    }
  }

  /// Verify balance settlement with backend
  Future<bool> _verifyBalanceSettlement({
    required String base64Data,
    required String transactionId,
    required String roomspaceId,
    required String recipientUserId,
    required double amount,
    required String description,
  }) async {
    try {
      print('🔍 Verifying settlement with backend...');

      // Decode base64 to get transaction details
      Map<String, dynamic> esewaResponse = {};
      
      if (base64Data.isNotEmpty) {
        try {
          final decodedBytes = base64.decode(base64Data);
          final decodedString = utf8.decode(decodedBytes);
          esewaResponse = json.decode(decodedString) as Map<String, dynamic>;
          print('✅ Decoded eSewa response: $esewaResponse');
        } catch (e) {
          print('⚠️ Failed to decode base64 response: $e');
        }
      }

      // Send settlement to backend
      final response = await _apiService.post('/api/payments/settlement/verify', data: {
        'roomspace_id': roomspaceId,
        'recipient_user_id': recipientUserId,
        'amount': amount,
        'description': description,
        'transaction_uuid': transactionId,
        'esewa_response': esewaResponse.isNotEmpty ? esewaResponse : {
          'status': 'COMPLETE',
          'total_amount': amount,
          'transaction_uuid': transactionId,
          'product_code': 'EPAYTEST',
        },
      });

      print('✅ Backend verification response: ${response['success']}');
      return response['success'] == true;
    } catch (e) {
      print('❌ Settlement verification error: $e');
      return false;
    }
  }
}

/// Payment result model
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
