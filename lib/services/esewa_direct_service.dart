import 'dart:convert';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:crypto/crypto.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'api_service.dart';

/// Direct eSewa ePay V2 integration service (same approach as your friend's React project)
/// 
/// Testing credentials (from eSewa docs):
///   Product Code : EPAYTEST
///   Secret Key   : 8gBm/:&EnhH.1/q
///   Payment URL  : https://rc-epay.esewa.com.np/api/epay/main/v2/form
///   Status URL   : https://rc.esewa.com.np/api/epay/transaction/status/
class EsewaDirectService {
  static final EsewaDirectService _instance = EsewaDirectService._internal();
  factory EsewaDirectService() => _instance;
  EsewaDirectService._internal();

  final ApiService _apiService = ApiService();

  // eSewa ePay V2 Configuration (same as your friend's React project)
  static const String _productCode = 'EPAYTEST';
  static const String _secretKey = '8gBm/:&EnhH.1/q';
  static const String _paymentUrl = 'https://rc-epay.esewa.com.np/api/epay/main/v2/form';
  static const String _statusUrl = 'https://rc.esewa.com.np/api/epay/transaction/status/';
  
  // Success/Failure URLs (will be handled by our app)
  static const String _successUrl = 'https://esewa.com.np/success';
  static const String _failureUrl = 'https://google.com';

  /// Generate HMAC-SHA256 signature in base64 as required by eSewa
  /// Input format: "total_amount={},transaction_uuid={},product_code={}"
  String _generateSignature(double totalAmount, String transactionUuid, String productCode) {
    final message = 'total_amount=$totalAmount,transaction_uuid=$transactionUuid,product_code=$productCode';
    final key = utf8.encode(_secretKey);
    final bytes = utf8.encode(message);
    final hmacSha256 = Hmac(sha256, key);
    final digest = hmacSha256.convert(bytes);
    return base64.encode(digest.bytes);
  }

  /// Generate unique transaction UUID
  String _generateTransactionUuid(String prefix) {
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final random = Random().nextInt(9999);
    return '$prefix-$timestamp-$random';
  }

  /// Process subscription payment using direct eSewa ePay V2 API
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
      
      // Calculate amounts (same as your friend's setup)
      final taxAmount = 0.0;
      final serviceCharge = 0.0;
      final deliveryCharge = 0.0;
      final totalAmount = amount + taxAmount + serviceCharge + deliveryCharge;

      // Generate HMAC signature
      final signature = _generateSignature(totalAmount, transactionUuid, _productCode);

      // Create form data for eSewa (same structure as your friend's React project)
      final formData = {
        'amount': amount.toString(),
        'tax_amount': taxAmount.toString(),
        'total_amount': totalAmount.toString(),
        'transaction_uuid': transactionUuid,
        'product_code': _productCode,
        'product_service_charge': serviceCharge.toString(),
        'product_delivery_charge': deliveryCharge.toString(),
        'success_url': _successUrl,
        'failure_url': _failureUrl,
        'signed_field_names': 'total_amount,transaction_uuid,product_code',
        'signature': signature,
      };

      print('🔧 eSewa Direct Payment Config:');
      print('💰 Amount: $amount, Total: $totalAmount');
      print('🆔 Transaction UUID: $transactionUuid');
      print('🔐 Signature: $signature');
      print('🌐 Payment URL: $_paymentUrl');

      // Show eSewa payment WebView
      final result = await _showEsewaWebView(
        context: context,
        formData: formData,
        transactionUuid: transactionUuid,
      );

      if (result != null && result['success'] == true) {
        // Verify payment with backend
        final verificationResult = await _verifySubscriptionPayment(
          transactionData: result['data'],
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
          message: result?['message'] ?? 'Payment cancelled or failed',
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

  /// Process balance settlement using direct eSewa ePay V2 API
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
      
      // Calculate amounts
      final taxAmount = 0.0;
      final serviceCharge = 0.0;
      final deliveryCharge = 0.0;
      final totalAmount = amount + taxAmount + serviceCharge + deliveryCharge;

      // Generate HMAC signature
      final signature = _generateSignature(totalAmount, transactionUuid, _productCode);

      // Create form data for eSewa
      final formData = {
        'amount': amount.toString(),
        'tax_amount': taxAmount.toString(),
        'total_amount': totalAmount.toString(),
        'transaction_uuid': transactionUuid,
        'product_code': _productCode,
        'product_service_charge': serviceCharge.toString(),
        'product_delivery_charge': deliveryCharge.toString(),
        'success_url': _successUrl,
        'failure_url': _failureUrl,
        'signed_field_names': 'total_amount,transaction_uuid,product_code',
        'signature': signature,
      };

      print('🔧 eSewa Direct Settlement Config:');
      print('💰 Amount: $amount, Total: $totalAmount');
      print('🆔 Transaction UUID: $transactionUuid');
      print('🔐 Signature: $signature');

      // Show eSewa payment WebView
      final result = await _showEsewaWebView(
        context: context,
        formData: formData,
        transactionUuid: transactionUuid,
      );

      if (result != null && result['success'] == true) {
        // Verify payment with backend
        final verificationResult = await _verifyBalanceSettlement(
          transactionData: result['data'],
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
          message: result?['message'] ?? 'Payment cancelled or failed',
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

  /// Show eSewa payment WebView with form submission
  Future<Map<String, dynamic>?> _showEsewaWebView({
    required BuildContext context,
    required Map<String, String> formData,
    required String transactionUuid,
  }) async {
    return showDialog<Map<String, dynamic>>(
      context: context,
      barrierDismissible: false,
      builder: (context) => EsewaWebViewDialog(
        paymentUrl: _paymentUrl,
        formData: formData,
        transactionUuid: transactionUuid,
        successUrl: _successUrl,
        failureUrl: _failureUrl,
      ),
    );
  }

  /// Verify subscription payment with backend
  Future<bool> _verifySubscriptionPayment({
    required Map<String, dynamic> transactionData,
    required String planId,
    required double amount,
    required String transactionUuid,
  }) async {
    try {
      // Send verification to backend
      final response = await _apiService.post('/api/payments/subscription/verify', data: {
        'plan_id': planId,
        'transaction_uuid': transactionUuid,
        'transaction_code': transactionData['transaction_code'],
        'amount': amount,
        'esewa_response': transactionData,
      });

      return response['success'] == true;
    } catch (e) {
      print('❌ Subscription verification error: $e');
      return false;
    }
  }

  /// Verify balance settlement with backend
  Future<bool> _verifyBalanceSettlement({
    required Map<String, dynamic> transactionData,
    required String roomspaceId,
    required String recipientUserId,
    required double amount,
    required String description,
    required String transactionUuid,
  }) async {
    try {
      // Send settlement to backend
      final response = await _apiService.post('/api/payments/settlement/verify', data: {
        'roomspace_id': roomspaceId,
        'recipient_user_id': recipientUserId,
        'amount': amount,
        'description': description,
        'transaction_uuid': transactionUuid,
        'transaction_code': transactionData['transaction_code'],
        'esewa_response': transactionData,
      });

      return response['success'] == true;
    } catch (e) {
      print('❌ Settlement verification error: $e');
      return false;
    }
  }

  /// Check transaction status directly with eSewa's API
  Future<Map<String, dynamic>> checkTransactionStatus({
    required String transactionUuid,
    required double totalAmount,
    String? productCode,
  }) async {
    final url = '$_statusUrl?product_code=${Uri.encodeComponent(productCode ?? _productCode)}&total_amount=$totalAmount&transaction_uuid=${Uri.encodeComponent(transactionUuid)}';
    
    try {
      final response = await _apiService.get(url);
      return response;
    } catch (e) {
      print('❌ eSewa status check error: $e');
      return {'status': 'AMBIGUOUS', 'ref_id': null};
    }
  }
}

/// WebView dialog for eSewa payment (same approach as your friend's React form submission)
class EsewaWebViewDialog extends StatefulWidget {
  final String paymentUrl;
  final Map<String, String> formData;
  final String transactionUuid;
  final String successUrl;
  final String failureUrl;

  const EsewaWebViewDialog({
    super.key,
    required this.paymentUrl,
    required this.formData,
    required this.transactionUuid,
    required this.successUrl,
    required this.failureUrl,
  });

  @override
  State<EsewaWebViewDialog> createState() => _EsewaWebViewDialogState();
}

class _EsewaWebViewDialogState extends State<EsewaWebViewDialog> {
  late WebViewController _controller;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _initializeWebView();
  }

  void _initializeWebView() {
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageStarted: (String url) {
            print('🌐 WebView loading: $url');
            
            // Check for success/failure URLs
            if (url.contains('esewa.com.np/success') || url.contains(widget.successUrl)) {
              _handlePaymentSuccess(url);
            } else if (url.contains('google.com') || url.contains(widget.failureUrl)) {
              _handlePaymentFailure('Payment cancelled or failed');
            }
          },
          onPageFinished: (String url) {
            setState(() {
              _isLoading = false;
            });
          },
          onWebResourceError: (WebResourceError error) {
            print('❌ WebView error: ${error.description}');
            _handlePaymentFailure('Network error: ${error.description}');
          },
        ),
      );

    // Create HTML form and submit it (same as your friend's React approach)
    _submitFormToEsewa();
  }

  void _submitFormToEsewa() {
    final formFields = widget.formData.entries
        .map((entry) => '<input type="hidden" name="${entry.key}" value="${entry.value}">')
        .join('\n');

    final html = '''
    <!DOCTYPE html>
    <html>
    <head>
        <title>eSewa Payment</title>
        <meta name="viewport" content="width=device-width, initial-scale=1.0">
    </head>
    <body>
        <div style="text-align: center; padding: 20px; font-family: Arial, sans-serif;">
            <h3>Redirecting to eSewa...</h3>
            <p>Please wait while we redirect you to eSewa payment gateway.</p>
            <div style="margin: 20px 0;">
                <div style="display: inline-block; width: 40px; height: 40px; border: 4px solid #f3f3f3; border-top: 4px solid #60BB46; border-radius: 50%; animation: spin 1s linear infinite;"></div>
            </div>
        </div>
        <form id="esewaForm" action="${widget.paymentUrl}" method="POST">
            $formFields
        </form>
        <style>
            @keyframes spin {
                0% { transform: rotate(0deg); }
                100% { transform: rotate(360deg); }
            }
        </style>
        <script>
            // Auto-submit form after a short delay
            setTimeout(function() {
                document.getElementById('esewaForm').submit();
            }, 1000);
        </script>
    </body>
    </html>
    ''';

    _controller.loadHtmlString(html);
  }

  void _handlePaymentSuccess(String url) {
    print('✅ Payment success detected: $url');
    
    // Extract payment data from URL
    final uri = Uri.parse(url);
    final queryParams = uri.queryParameters;
    
    // eSewa returns data in different formats, try multiple extraction methods
    Map<String, dynamic> esewaData = {};
    String? transactionCode;
    
    // Method 1: Check for direct query parameters (common format)
    if (queryParams.containsKey('oid')) {
      transactionCode = queryParams['oid'];
      esewaData = {
        'transaction_code': transactionCode,
        'status': 'COMPLETE',
        'total_amount': queryParams['amt'] ?? '0',
        'product_code': 'EPAYTEST',
        'ref_id': queryParams['refId'],
      };
      print('✅ Extracted from direct params: $esewaData');
    }
    
    // Method 2: Check for base64 encoded data parameter
    else if (queryParams.containsKey('data')) {
      try {
        final decodedData = utf8.decode(base64.decode(queryParams['data']!));
        esewaData = jsonDecode(decodedData) as Map<String, dynamic>;
        transactionCode = esewaData['transaction_code'] ?? esewaData['oid'];
        print('✅ Decoded eSewa data: $esewaData');
      } catch (e) {
        print('❌ Failed to decode eSewa data: $e');
        // Fallback to query params
        transactionCode = queryParams['oid'] ?? widget.transactionUuid;
        esewaData = {
          'transaction_code': transactionCode,
          'status': 'COMPLETE',
          'total_amount': queryParams['amt'] ?? '0',
        };
      }
    }
    
    // Method 3: Extract from URL fragments or other formats
    else {
      // Check URL fragments or other patterns
      final urlString = url.toLowerCase();
      if (urlString.contains('oid=')) {
        final oidMatch = RegExp(r'oid=([^&]+)').firstMatch(url);
        transactionCode = oidMatch?.group(1);
      }
      
      // Fallback to transaction UUID if nothing found
      transactionCode ??= widget.transactionUuid;
      
      esewaData = {
        'transaction_code': transactionCode,
        'status': 'COMPLETE',
        'total_amount': queryParams['amt'] ?? '0',
        'product_code': 'EPAYTEST',
      };
      print('✅ Fallback extraction: $esewaData');
    }
    
    // Ensure we have a transaction code
    if (transactionCode == null || transactionCode.isEmpty) {
      transactionCode = widget.transactionUuid;
      print('⚠️ Using transaction UUID as fallback: $transactionCode');
    }
    
    Navigator.of(context).pop({
      'success': true,
      'data': {
        'transaction_uuid': widget.transactionUuid,
        'transaction_code': transactionCode,
        'status': esewaData['status'] ?? 'COMPLETE',
        'total_amount': esewaData['total_amount'] ?? '0',
        'product_code': esewaData['product_code'] ?? 'EPAYTEST',
        'signed_field_names': esewaData['signed_field_names'] ?? 'total_amount,transaction_uuid,product_code',
        'signature': esewaData['signature'] ?? '',
        'ref_id': esewaData['ref_id'],
        'url': url,
        'query_params': queryParams,
        'raw_esewa_response': esewaData,
      },
    });
  }

  void _handlePaymentFailure(String message) {
    print('❌ Payment failure: $message');
    
    Navigator.of(context).pop({
      'success': false,
      'message': message,
    });
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      insetPadding: const EdgeInsets.all(16),
      child: Container(
        width: double.infinity,
        height: MediaQuery.of(context).size.height * 0.8,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          children: [
            // Header
            Container(
              padding: const EdgeInsets.all(16),
              decoration: const BoxDecoration(
                color: Color(0xFF60BB46),
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(12),
                  topRight: Radius.circular(12),
                ),
              ),
              child: Row(
                children: [
                  const Icon(Icons.payment, color: Colors.white),
                  const SizedBox(width: 8),
                  const Expanded(
                    child: Text(
                      'eSewa Payment',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  IconButton(
                    onPressed: () => _handlePaymentFailure('Payment cancelled by user'),
                    icon: const Icon(Icons.close, color: Colors.white),
                  ),
                ],
              ),
            ),
            // WebView
            Expanded(
              child: Stack(
                children: [
                  WebViewWidget(controller: _controller),
                  if (_isLoading)
                    const Center(
                      child: CircularProgressIndicator(
                        valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF60BB46)),
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
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