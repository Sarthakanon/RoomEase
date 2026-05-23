import 'package:flutter/material.dart';
import 'package:flutter_stripe/flutter_stripe.dart';
import 'dart:async';
import 'api_service.dart';

/// Stripe Payment Service
/// Simple and reliable payment processing
class StripePaymentService {
  static final StripePaymentService _instance = StripePaymentService._internal();
  factory StripePaymentService() => _instance;
  StripePaymentService._internal();

  final ApiService _apiService = ApiService();

  /// Process payment using Stripe
  Future<StripePaymentResult> processPayment({
    required BuildContext context,
    required double amount,
    required String productId,
    required String productName,
  }) async {
    try {
      debugPrint('🔵 Stripe: Initiating payment...');
      debugPrint('💰 Amount: ₹$amount');
      debugPrint('📦 Product: $productName');
      debugPrint('🆔 Product ID: $productId');

      // Step 1: Create payment intent on backend
      final paymentIntent = await _createPaymentIntent(
        amount: amount,
        productId: productId,
        productName: productName,
      );

      if (paymentIntent == null) {
        return StripePaymentResult(
          success: false,
          message: 'Failed to create payment intent',
        );
      }

      debugPrint('✅ Payment intent created: ${paymentIntent['id']}');

      // Step 2: Initialize payment sheet
      await Stripe.instance.initPaymentSheet(
        paymentSheetParameters: SetupPaymentSheetParameters(
          paymentIntentClientSecret: paymentIntent['client_secret'],
          merchantDisplayName: 'RoomEase',
          style: ThemeMode.light,
          appearance: const PaymentSheetAppearance(
            colors: PaymentSheetAppearanceColors(
              primary: Color(0xFF635BFF), // Stripe purple
            ),
          ),
        ),
      );

      debugPrint('✅ Payment sheet initialized');

      // Step 3: Present payment sheet
      await Stripe.instance.presentPaymentSheet();

      debugPrint('✅ Payment successful!');

      return StripePaymentResult(
        success: true,
        transactionId: productId,
        paymentIntentId: paymentIntent['id'],
        amount: amount,
        message: 'Payment completed successfully',
      );
    } on StripeException catch (e) {
      debugPrint('❌ Stripe Error: ${e.error.message}');
      
      if (e.error.code == FailureCode.Canceled) {
        return StripePaymentResult(
          success: false,
          message: 'Payment cancelled by user',
        );
      }
      
      return StripePaymentResult(
        success: false,
        message: e.error.message ?? 'Payment failed',
      );
    } catch (e) {
      debugPrint('❌ Payment Error: $e');
      
      return StripePaymentResult(
        success: false,
        message: 'Payment error: ${e.toString()}',
      );
    }
  }

  /// Create payment intent on backend using authenticated API service
  Future<Map<String, dynamic>?> _createPaymentIntent({
    required double amount,
    required String productId,
    required String productName,
  }) async {
    try {
      // Convert amount to cents/paisa (Stripe uses smallest currency unit)
      final amountInCents = (amount * 100).toInt();

      debugPrint('🔵 Calling backend to create payment intent...');
      debugPrint('📍 Endpoint: /api/payment/stripe/create-intent');
      debugPrint('💰 Amount in cents: $amountInCents');

      final response = await _apiService.post(
        '/api/payment/stripe/create-intent',
        data: {
          'amount': amountInCents,
          'currency': 'inr', // Indian Rupees
          'product_id': productId,
          'product_name': productName,
        },
      );

      debugPrint('✅ Payment intent created successfully');
      debugPrint('📥 Payment Intent ID: ${response['id']}');
      debugPrint('🔑 Client Secret: ${response['client_secret']?.substring(0, 20)}...');

      return response;
    } catch (e) {
      debugPrint('❌ Create intent error: $e');
      debugPrint('❌ Error type: ${e.runtimeType}');
      return null;
    }
  }
}

/// Stripe Payment Result
class StripePaymentResult {
  final bool success;
  final String? transactionId;
  final String? paymentIntentId;
  final double? amount;
  final String? message;

  StripePaymentResult({
    required this.success,
    this.transactionId,
    this.paymentIntentId,
    this.amount,
    this.message,
  });

  Map<String, dynamic> toJson() {
    return {
      'success': success,
      'transactionId': transactionId,
      'paymentIntentId': paymentIntentId,
      'amount': amount,
      'message': message,
    };
  }
}
