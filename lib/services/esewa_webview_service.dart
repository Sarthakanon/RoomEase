import 'dart:async';
import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'dart:math';

/// Custom eSewa payment implementation using WebView
/// This bypasses the esewa_flutter SDK issues and gives us more control
class EsewaWebViewService {
  static final EsewaWebViewService _instance = EsewaWebViewService._internal();
  factory EsewaWebViewService() => _instance;
  EsewaWebViewService._internal();

  // eSewa Test Configuration
  static const String _merchantCode = 'EPAYTEST';
  static const String _testBaseUrl = 'https://rc-epay.esewa.com.np/api/epay/main/v2/form';
  static const String _successUrl = 'https://esewa.com.np/#/success';
  static const String _failureUrl = 'https://esewa.com.np/#/failure';

  /// Process payment using custom WebView
  Future<EsewaPaymentResult> processPayment({
    required BuildContext context,
    required double amount,
    required String productId,
    required String productName,
  }) async {
    final completer = Completer<EsewaPaymentResult>();
    
    // Generate unique product ID
    final pid = '$productId-${DateTime.now().millisecondsSinceEpoch}-${Random().nextInt(9999)}';
    
    // Build eSewa payment URL
    final paymentUrl = _buildPaymentUrl(
      amount: amount,
      productId: pid,
    );

    print('🔧 eSewa Payment URL: $paymentUrl');
    print('💰 Amount: ₹$amount');
    print('📦 Product ID: $pid');
    print('🏪 Merchant: $_merchantCode');

    // Show WebView in full screen
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => _EsewaPaymentScreen(
          paymentUrl: paymentUrl,
          onResult: (result) {
            if (!completer.isCompleted) {
              completer.complete(EsewaPaymentResult(
                success: result.success,
                transactionId: pid,
                amount: amount,
                message: result.message,
                refId: result.refId,
              ));
            }
          },
        ),
      ),
    );

    return completer.future;
  }

  /// Build eSewa payment URL with all required parameters
  String _buildPaymentUrl({
    required double amount,
    required String productId,
  }) {
    final params = {
      'amt': amount.toStringAsFixed(2),
      'psc': '0', // Service charge
      'pdc': '0', // Delivery charge
      'txAmt': '0', // Tax amount
      'tAmt': amount.toStringAsFixed(2), // Total amount
      'pid': productId,
      'scd': _merchantCode,
      'su': _successUrl,
      'fu': _failureUrl,
    };

    final queryString = params.entries
        .map((e) => '${Uri.encodeComponent(e.key)}=${Uri.encodeComponent(e.value)}')
        .join('&');

    return '$_testBaseUrl?$queryString';
  }
}

/// eSewa Payment Screen with WebView
class _EsewaPaymentScreen extends StatefulWidget {
  final String paymentUrl;
  final Function(EsewaPaymentResult) onResult;

  const _EsewaPaymentScreen({
    required this.paymentUrl,
    required this.onResult,
  });

  @override
  State<_EsewaPaymentScreen> createState() => _EsewaPaymentScreenState();
}

class _EsewaPaymentScreenState extends State<_EsewaPaymentScreen> {
  late final WebViewController _controller;
  bool _isLoading = true;
  
  // eSewa URLs for comparison
  static const String _successUrl = 'https://esewa.com.np/#/success';
  static const String _failureUrl = 'https://esewa.com.np/#/failure';

  @override
  void initState() {
    super.initState();
    _initializeWebView();
  }

  void _initializeWebView() {
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(Colors.white)
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageStarted: (url) {
            print('🌐 WebView loading: $url');
            setState(() {
              _isLoading = true;
            });
          },
          onPageFinished: (url) {
            print('✅ WebView loaded: $url');
            setState(() {
              _isLoading = false;
            });
            _checkPaymentStatus(url);
          },
          onWebResourceError: (error) {
            print('❌ WebView error: ${error.description}');
            setState(() => _isLoading = false);
          },
          onNavigationRequest: (request) {
            print('🔄 Navigation request: ${request.url}');
            return NavigationDecision.navigate;
          },
        ),
      )
      ..loadRequest(Uri.parse(widget.paymentUrl));
  }

  void _checkPaymentStatus(String url) {
    print('🔍 Checking payment status for URL: $url');
    
    // Only check if we're actually ON the success/failure page, not if it's just a parameter
    // The actual redirect URLs will be exactly these or start with these
    final isActualSuccessPage = url == _successUrl || 
                                 url.startsWith('https://esewa.com.np/#/success') ||
                                 url.startsWith('https://esewa.com.np/success');
    
    final isActualFailurePage = url == _failureUrl || 
                                url.startsWith('https://esewa.com.np/#/failure') ||
                                url.startsWith('https://esewa.com.np/failure');
    
    // Check if payment was successful
    if (isActualSuccessPage) {
      print('✅ Payment successful! Redirected to success page');
      
      // Extract transaction details from URL if available
      final uri = Uri.parse(url);
      final refId = uri.queryParameters['refId'] ?? 
                    uri.queryParameters['oid'] ?? 
                    uri.queryParameters['txnId'];
      
      widget.onResult(EsewaPaymentResult(
        success: true,
        transactionId: '',
        amount: 0,
        message: 'Payment completed successfully',
        refId: refId,
      ));
      
      Navigator.of(context).pop();
    }
    // Check if payment failed
    else if (isActualFailurePage) {
      print('❌ Payment failed! Redirected to failure page');
      
      widget.onResult(EsewaPaymentResult(
        success: false,
        transactionId: '',
        amount: 0,
        message: 'Payment cancelled or failed',
        refId: null,
      ));
      
      Navigator.of(context).pop();
    } else {
      print('ℹ️ Still on payment page, waiting for user action...');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: const Color(0xFF60BB46),
        foregroundColor: Colors.white,
        elevation: 0,
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(4),
              ),
              child: const Text(
                'eSewa',
                style: TextStyle(
                  color: Color(0xFF60BB46),
                  fontWeight: FontWeight.w800,
                  fontSize: 16,
                ),
              ),
            ),
            const SizedBox(width: 8),
            const Text(
              'Payment',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
            ),
          ],
        ),
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () {
            // Confirm cancellation
            showDialog(
              context: context,
              builder: (context) => AlertDialog(
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
                    onPressed: () => Navigator.pop(context),
                    child: Text(
                      'Continue Payment',
                      style: TextStyle(color: Colors.grey.shade600),
                    ),
                  ),
                  TextButton(
                    onPressed: () {
                      Navigator.pop(context); // Close dialog
                      widget.onResult(EsewaPaymentResult(
                        success: false,
                        transactionId: '',
                        amount: 0,
                        message: 'Payment cancelled by user',
                        refId: null,
                      ));
                      Navigator.pop(context); // Close payment screen
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
        ),
      ),
      body: Stack(
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
                      color: Color(0xFF60BB46),
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
      bottomNavigationBar: Container(
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
    );
  }
}

/// eSewa payment result model
class EsewaPaymentResult {
  final bool success;
  final String transactionId;
  final double amount;
  final String message;
  final String? refId;

  EsewaPaymentResult({
    required this.success,
    required this.transactionId,
    required this.amount,
    required this.message,
    this.refId,
  });
}
