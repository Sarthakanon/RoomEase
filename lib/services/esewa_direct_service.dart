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
  
  // Success/Failure URLs - Using example.com which is a valid domain
  // We'll intercept these URLs in the WebView before they load
  static const String _successUrl = 'https://example.com/esewa/success';
  static const String _failureUrl = 'https://example.com/esewa/failure';

  /// Generate HMAC-SHA256 signature in base64 as required by eSewa
  /// Input format: "total_amount=X,transaction_uuid=Y,product_code=Z"
  /// IMPORTANT: total_amount must match exactly what's sent in the form
  String _generateSignature(String totalAmount, String transactionUuid, String productCode) {
    final message = 'total_amount=$totalAmount,transaction_uuid=$transactionUuid,product_code=$productCode';
    print('🔐 Signature message: $message');
    final key = utf8.encode(_secretKey);
    final bytes = utf8.encode(message);
    final hmacSha256 = Hmac(sha256, key);
    final digest = hmacSha256.convert(bytes);
    final signature = base64.encode(digest.bytes);
    print('🔐 Generated signature: $signature');
    return signature;
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
      
      // Format total amount as string (must match exactly in signature and form)
      final totalAmountStr = totalAmount.toStringAsFixed(2);

      // Generate HMAC signature with string values
      final signature = _generateSignature(totalAmountStr, transactionUuid, _productCode);

      print('🔧 eSewa Direct Payment Config:');
      print('💰 Amount: $amount, Total: $totalAmountStr');
      print('🆔 Transaction UUID: $transactionUuid');
      print('🔐 Signature: $signature');
      print('🌐 Payment URL: $_paymentUrl');
      print('📦 Product Code: $_productCode');
      print('🔑 Secret Key: ${_secretKey.substring(0, 5)}...');

      // Create form data for eSewa (exact format from documentation)
      final formData = {
        'amount': amount.toStringAsFixed(2),
        'tax_amount': taxAmount.toStringAsFixed(2),
        'total_amount': totalAmountStr,
        'transaction_uuid': transactionUuid,
        'product_code': _productCode,
        'product_service_charge': serviceCharge.toStringAsFixed(2),
        'product_delivery_charge': deliveryCharge.toStringAsFixed(2),
        'success_url': _successUrl,
        'failure_url': _failureUrl,
        'signed_field_names': 'total_amount,transaction_uuid,product_code',
        'signature': signature,
      };

      print('📋 Complete Form Data:');
      formData.forEach((key, value) {
        print('  $key = $value');
      });

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
      
      // Format total amount as string (must match exactly in signature and form)
      final totalAmountStr = totalAmount.toStringAsFixed(2);

      // Generate HMAC signature with string values
      final signature = _generateSignature(totalAmountStr, transactionUuid, _productCode);

      // Create form data for eSewa
      final formData = {
        'amount': amount.toStringAsFixed(2),
        'tax_amount': taxAmount.toStringAsFixed(2),
        'total_amount': totalAmountStr,
        'transaction_uuid': transactionUuid,
        'product_code': _productCode,
        'product_service_charge': serviceCharge.toStringAsFixed(2),
        'product_delivery_charge': deliveryCharge.toStringAsFixed(2),
        'success_url': _successUrl,
        'failure_url': _failureUrl,
        'signed_field_names': 'total_amount,transaction_uuid,product_code',
        'signature': signature,
      };

      print('🔧 eSewa Direct Settlement Config:');
      print('💰 Amount: $amount, Total: $totalAmountStr');
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
  bool _paymentProcessed = false;
  int _pageLoadCount = 0;

  @override
  void initState() {
    super.initState();
    _initializeWebView();
  }

  void _initializeWebView() {
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..enableZoom(false)
      ..setBackgroundColor(Colors.white)
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageStarted: (String url) {
            print('🌐 WebView loading: $url');
            _pageLoadCount++;
            
            // Check if we're on the success or failure page
            // eSewa redirects to success_url or failure_url with query parameters
            final isSuccessPage = url.contains('example.com/esewa/success');
            final isFailurePage = url.contains('example.com/esewa/failure');
            
            if (!_paymentProcessed) {
              if (isSuccessPage) {
                print('✅ Detected success page redirect: $url');
                _paymentProcessed = true;
                _handlePaymentSuccess(url);
              } else if (isFailurePage) {
                print('❌ Detected failure page redirect: $url');
                
                // Extract error details from URL if available
                final uri = Uri.parse(url);
                final errorCode = uri.queryParameters['error_code'];
                final errorMessage = uri.queryParameters['error_message'];
                final reason = uri.queryParameters['reason'];
                
                print('❌ Error Code: $errorCode');
                print('❌ Error Message: $errorMessage');
                print('❌ Reason: $reason');
                print('❌ All Query Params: ${uri.queryParameters}');
                
                _paymentProcessed = true;
                
                String failureMessage = 'Payment was declined or cancelled by eSewa';
                if (errorMessage != null && errorMessage.isNotEmpty) {
                  failureMessage = errorMessage;
                } else if (reason != null && reason.isNotEmpty) {
                  failureMessage = reason;
                }
                
                _handlePaymentFailure(failureMessage);
              } else {
                print('ℹ️ Still on payment page (load #$_pageLoadCount): $url');
              }
            }
          },
          onPageFinished: (String url) {
            print('✅ WebView loaded: $url');
            setState(() {
              _isLoading = false;
            });
            
            // Double-check on page finish
            final isSuccessPage = url.contains('example.com/esewa/success');
            
            if (!_paymentProcessed && isSuccessPage) {
              print('✅ Detected success page on finish: $url');
              _paymentProcessed = true;
              _handlePaymentSuccess(url);
            }
          },
          onWebResourceError: (WebResourceError error) {
            print('❌ WebView error: ${error.description}');
            print('❌ Error type: ${error.errorType}');
            print('❌ Error code: ${error.errorCode}');
            // Don't immediately fail on resource errors, eSewa might still load
            if (error.errorType == WebResourceErrorType.hostLookup || 
                error.errorType == WebResourceErrorType.timeout) {
              _handlePaymentFailure('Network error: ${error.description}');
            }
          },
          onHttpError: (HttpResponseError error) {
            print('❌ HTTP error: ${error.response?.statusCode}');
          },
        ),
      );

    // Create HTML form and submit it (same as your friend's React approach)
    _submitFormToEsewa();
  }

  void _submitFormToEsewa() {
    // Log form data for debugging
    print('📋 eSewa Form Data:');
    widget.formData.forEach((key, value) {
      print('  $key: $value');
    });
    
    // Verify signature message
    final totalAmount = widget.formData['total_amount'];
    final transactionUuid = widget.formData['transaction_uuid'];
    final productCode = widget.formData['product_code'];
    final expectedMessage = 'total_amount=$totalAmount,transaction_uuid=$transactionUuid,product_code=$productCode';
    print('🔍 Expected signature message: $expectedMessage');
    print('🔍 Actual signature: ${widget.formData['signature']}');
    
    final formFields = widget.formData.entries
        .map((entry) => '<input type="hidden" name="${entry.key}" value="${entry.value}">')
        .join('\n');
    
    // Create visible form fields for debugging
    final visibleFormFields = widget.formData.entries
        .map((entry) => '<div style="margin: 5px 0; font-size: 11px; color: #666;"><strong>${entry.key}:</strong> ${entry.value.length > 50 ? '${entry.value.substring(0, 50)}...' : entry.value}</div>')
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
            <div style="background: #60BB46; color: white; padding: 15px; border-radius: 8px; margin-bottom: 20px;">
                <h3 style="margin: 0;">Redirecting to eSewa...</h3>
            </div>
            <p>Please wait while we redirect you to eSewa payment gateway.</p>
            <div style="margin: 20px 0;">
                <div style="display: inline-block; width: 40px; height: 40px; border: 4px solid #f3f3f3; border-top: 4px solid #60BB46; border-radius: 50%; animation: spin 1s linear infinite;"></div>
            </div>
            <p style="color: #666; font-size: 12px; margin-top: 20px;">
                Test Credentials:<br>
                eSewa ID: 9806800001-5<br>
                Password: Nepal@123<br>
                MPIN: 1122
            </p>
            <details style="margin-top: 20px; text-align: left; max-width: 400px; margin-left: auto; margin-right: auto;">
                <summary style="cursor: pointer; color: #666; font-size: 12px;">Debug: Form Data</summary>
                <div style="background: #f5f5f5; padding: 10px; border-radius: 4px; margin-top: 10px;">
                    $visibleFormFields
                </div>
            </details>
        </div>
        <form id="esewaForm" action="${widget.paymentUrl}" method="POST">
            $formFields
        </form>
        <style>
            @keyframes spin {
                0% { transform: rotate(0deg); }
                100% { transform: rotate(360deg); }
            }
            body {
                margin: 0;
                padding: 0;
                font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, Oxygen, Ubuntu, Cantarell, sans-serif;
            }
        </style>
        <script>
            console.log('🚀 Submitting eSewa payment form...');
            console.log('Form action:', '${widget.paymentUrl}');
            console.log('Form data:', ${jsonEncode(widget.formData)});
            
            // Log when form is about to submit
            document.getElementById('esewaForm').addEventListener('submit', function(e) {
                console.log('📤 Form submitting to eSewa...');
            });
            
            // Auto-submit form after a short delay
            setTimeout(function() {
                console.log('📤 Submitting form now...');
                var form = document.getElementById('esewaForm');
                console.log('Form element:', form);
                console.log('Form action:', form.action);
                console.log('Form method:', form.method);
                form.submit();
            }, 2000);
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
    
    print('📋 Success URL query parameters:');
    queryParams.forEach((key, value) {
      print('  $key: $value');
    });
    
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
    
    if (!_paymentProcessed) {
      _paymentProcessed = true;
      
      // Show error dialog with details
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (ctx) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Row(
            children: [
              Icon(Icons.error_outline, color: Colors.red.shade700, size: 24),
              const SizedBox(width: 8),
              const Text('Payment Failed', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                message,
                style: const TextStyle(fontSize: 14),
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.orange.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.orange.shade200),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.info_outline, size: 16, color: Colors.orange.shade700),
                        const SizedBox(width: 8),
                        Text(
                          'Possible reasons:',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: Colors.orange.shade700,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '• Insufficient balance in eSewa account\n'
                      '• Incorrect MPIN entered\n'
                      '• Payment cancelled by user\n'
                      '• eSewa test environment issue',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey.shade700,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(ctx); // Close error dialog
                Navigator.of(context).pop({
                  'success': false,
                  'message': message,
                });
              },
              child: const Text(
                'Close',
                style: TextStyle(fontWeight: FontWeight.w600),
              ),
            ),
          ],
        ),
      );
    }
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
                  Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: const Text(
                      'eSewa',
                      style: TextStyle(
                        color: Color(0xFF60BB46),
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  const Expanded(
                    child: Text(
                      'Payment Gateway',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  IconButton(
                    onPressed: () {
                      // Confirm cancellation
                      showDialog(
                        context: context,
                        builder: (ctx) => AlertDialog(
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                          title: const Text(
                            'Cancel Payment?',
                            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                          ),
                          content: const Text(
                            'Are you sure you want to cancel this payment?',
                            style: TextStyle(fontSize: 14),
                          ),
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.pop(ctx),
                              child: Text(
                                'Continue Payment',
                                style: TextStyle(color: Colors.grey.shade600),
                              ),
                            ),
                            TextButton(
                              onPressed: () {
                                Navigator.pop(ctx); // Close confirmation
                                _handlePaymentFailure('Payment cancelled by user');
                              },
                              child: const Text(
                                'Cancel Payment',
                                style: TextStyle(
                                  color: Colors.red,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                          ],
                        ),
                      );
                    },
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
                    Container(
                      color: Colors.white,
                      child: const Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            CircularProgressIndicator(
                              valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF60BB46)),
                            ),
                            SizedBox(height: 16),
                            Text(
                              'Loading eSewa Payment...',
                              style: TextStyle(
                                fontSize: 14,
                                color: Colors.grey,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
            ),
            // Footer with test credentials
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.grey.shade50,
                border: Border(
                  top: BorderSide(color: Colors.grey.shade200),
                ),
              ),
              child: SafeArea(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.info_outline, size: 16, color: Colors.grey.shade600),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Test Mode: Use eSewa ID 9806800001-5, Password: Nepal@123, MPIN: 1122',
                            style: TextStyle(
                              fontSize: 11,
                              color: Colors.grey.shade600,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Icon(Icons.lock_outline, size: 16, color: Colors.grey.shade600),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Secure payment powered by eSewa',
                            style: TextStyle(
                              fontSize: 11,
                              color: Colors.grey.shade600,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
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