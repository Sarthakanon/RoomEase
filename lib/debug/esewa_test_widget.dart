import 'package:flutter/material.dart';
import '../services/esewa_direct_service.dart';

class EsewaTestWidget extends StatelessWidget {
  const EsewaTestWidget({super.key});

  @override
  Widget build(BuildContext context) {
    return FloatingActionButton(
      onPressed: () => _showEsewaTestDialog(context),
      backgroundColor: const Color(0xFF60BB46),
      child: const Icon(Icons.payment, color: Colors.white),
    );
  }

  void _showEsewaTestDialog(BuildContext context) {
    final esewaService = EsewaDirectService();
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('eSewa Direct API Test'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Direct eSewa ePay V2 Configuration:', style: TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              const Text('Product Code: EPAYTEST', style: TextStyle(fontSize: 12)),
              const Text('Secret Key: 8gBm/:&EnhH.1/q', style: TextStyle(fontSize: 12)),
              const Text('Payment URL: https://rc-epay.esewa.com.np/api/epay/main/v2/form', style: TextStyle(fontSize: 12)),
              const Text('Status URL: https://rc.esewa.com.np/api/epay/transaction/status/', style: TextStyle(fontSize: 12)),
              const SizedBox(height: 16),
              const Text('Test Credentials:', style: TextStyle(fontWeight: FontWeight.bold)),
              const Text('eSewa ID: 9806800001-5', style: TextStyle(fontSize: 12)),
              const Text('Password: Nepal@123', style: TextStyle(fontSize: 12)),
              const Text('MPIN: 1122', style: TextStyle(fontSize: 12)),
              const SizedBox(height: 16),
              const Text('Test Payment (₹10):', style: TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              ElevatedButton(
                onPressed: () => _testDirectEsewaPayment(context),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF60BB46),
                  foregroundColor: Colors.white,
                ),
                child: const Text('Test Direct eSewa Payment'),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  Future<void> _testDirectEsewaPayment(BuildContext context) async {
    final esewaService = EsewaDirectService();
    
    try {
      Navigator.of(context).pop(); // Close dialog first
      
      final result = await esewaService.processSubscriptionPayment(
        context: context,
        planId: 'test',
        amount: 10.0,
        planName: 'Test Payment',
      );
      
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(result.success ? 'Direct eSewa payment successful!' : 'Payment failed: ${result.message}'),
            backgroundColor: result.success ? Colors.green : Colors.red,
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Direct payment error: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }
}