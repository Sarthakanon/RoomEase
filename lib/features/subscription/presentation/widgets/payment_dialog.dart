import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/subscription_models.dart';
import '../../providers/subscription_provider.dart';
import '../../../../services/stripe_payment_service.dart';

class PaymentDialog extends StatefulWidget {
  final SubscriptionPlanInfo planInfo;
  final bool isYearly;
  final Function(bool success) onPaymentComplete;

  const PaymentDialog({
    super.key,
    required this.planInfo,
    required this.isYearly,
    required this.onPaymentComplete,
  });

  @override
  State<PaymentDialog> createState() => _PaymentDialogState();
}

class _PaymentDialogState extends State<PaymentDialog> {
  final String _selectedPaymentMethod = 'stripe';
  bool _isProcessing = false;
  final StripePaymentService _stripeService = StripePaymentService();

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isTablet = screenWidth > 600;
    final isDesktop = screenWidth > 1200;
    
    final price = widget.isYearly ? widget.planInfo.yearlyPrice : widget.planInfo.monthlyPrice;
    
    // Responsive sizing
    final dialogPadding = isDesktop ? 32.0 : (isTablet ? 28.0 : 24.0);
    final maxWidth = isDesktop ? 500.0 : (isTablet ? 450.0 : 400.0);
    final titleFontSize = isDesktop ? 24.0 : (isTablet ? 22.0 : 20.0);
    final buttonPadding = isDesktop ? 20.0 : (isTablet ? 18.0 : 16.0);
    
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        constraints: BoxConstraints(maxWidth: maxWidth),
        padding: EdgeInsets.all(dialogPadding),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Upgrade to ${widget.planInfo.name}',
                    style: TextStyle(
                      fontSize: titleFontSize,
                      fontWeight: FontWeight.w700,
                      color: const Color(0xFF1A1A2E),
                    ),
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.of(context).pop(),
                  icon: Icon(Icons.close, size: isTablet ? 28 : 24),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                ),
              ],
            ),
            SizedBox(height: isTablet ? 20 : 16),

            // Plan summary
            Container(
              width: double.infinity,
              padding: EdgeInsets.all(isTablet ? 20 : 16),
              decoration: BoxDecoration(
                color: Colors.grey.shade50,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.planInfo.name,
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: isTablet ? 18 : 16,
                    ),
                  ),
                  SizedBox(height: isTablet ? 6 : 4),
                  Text(
                    widget.isYearly ? 'Yearly billing' : 'Monthly billing',
                    style: TextStyle(
                      color: Colors.grey.shade600,
                      fontSize: isTablet ? 16 : 14,
                    ),
                  ),
                  SizedBox(height: isTablet ? 12 : 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Total:',
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: isTablet ? 18 : 16,
                        ),
                      ),
                      Text(
                        '₹${price.toInt()}',
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: isTablet ? 20 : 18,
                          color: const Color(0xFF1A1A2E),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            SizedBox(height: isTablet ? 32 : 24),

            // Payment methods
            Text(
              'Payment Method',
              style: TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: isTablet ? 18 : 16,
                color: const Color(0xFF1A1A2E),
              ),
            ),
            SizedBox(height: isTablet ? 16 : 12),

            _buildPaymentMethodTile(
              'stripe',
              'Stripe Payment',
              Icons.credit_card,
              isTablet,
            ),

            SizedBox(height: isTablet ? 32 : 24),

            // Terms
            Text(
              'Payment will be processed through eSewa. By proceeding, you agree to our Terms of Service and Privacy Policy. Your subscription will auto-renew unless cancelled.',
              style: TextStyle(
                fontSize: isTablet ? 14 : 12,
                color: Colors.grey.shade600,
              ),
            ),
            SizedBox(height: isTablet ? 32 : 24),

            // Direct eSewa Payment Button
            _isProcessing 
                ? Container(
                    width: double.infinity,
                    padding: EdgeInsets.symmetric(vertical: buttonPadding),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade300,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Center(
                      child: CircularProgressIndicator(),
                    ),
                  )
                : Column(
                    children: [
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: () => _processDirectPayment(),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF635BFF), // Stripe purple
                            foregroundColor: Colors.white,
                            padding: EdgeInsets.symmetric(vertical: buttonPadding),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(Icons.account_balance_wallet),
                              const SizedBox(width: 8),
                              Text(
                                'Pay ₹${price.toInt()} with Stripe',
                                style: TextStyle(
                                  fontSize: isTablet ? 16 : 14,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      
                      SizedBox(height: isTablet ? 12 : 8),
                      
                      // Test Mode: Skip Payment Button (for development)
                      SizedBox(
                        width: double.infinity,
                        child: OutlinedButton(
                          onPressed: () => _skipPaymentTestMode(),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: Colors.orange.shade700,
                            side: BorderSide(color: Colors.orange.shade300),
                            padding: EdgeInsets.symmetric(vertical: buttonPadding),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(Icons.science_outlined, size: 18),
                              const SizedBox(width: 8),
                              Text(
                                'Skip Payment (Test Mode)',
                                style: TextStyle(
                                  fontSize: isTablet ? 14 : 12,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
            
            SizedBox(height: isTablet ? 16 : 12),
            
            // Cancel button
            SizedBox(
              width: double.infinity,
              child: OutlinedButton(
                onPressed: _isProcessing ? null : () => Navigator.of(context).pop(),
                style: OutlinedButton.styleFrom(
                  padding: EdgeInsets.symmetric(vertical: buttonPadding),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                child: Text(
                  'Cancel',
                  style: TextStyle(fontSize: isTablet ? 16 : 14),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPaymentMethodTile(String method, String title, IconData icon, bool isTablet) {
    final isSelected = _selectedPaymentMethod == method;
    
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: EdgeInsets.all(isTablet ? 20 : 16),
      decoration: BoxDecoration(
        border: Border.all(
          color: isSelected ? const Color(0xFF635BFF) : Colors.grey.shade300,
          width: isSelected ? 2 : 1,
        ),
        borderRadius: BorderRadius.circular(8),
        color: isSelected ? const Color(0xFF635BFF).withValues(alpha: 0.1) : Colors.white,
      ),
      child: Row(
        children: [
          // Stripe-style icon
          Container(
            padding: EdgeInsets.all(isTablet ? 10 : 8),
            decoration: BoxDecoration(
              color: const Color(0xFF635BFF),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Icon(
              icon,
              color: Colors.white,
              size: isTablet ? 24 : 20,
            ),
          ),
          SizedBox(width: isTablet ? 16 : 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: isTablet ? 18 : 16,
                    color: isSelected ? const Color(0xFF635BFF) : Colors.grey.shade800,
                  ),
                ),
                SizedBox(height: isTablet ? 4 : 2),
                Text(
                  'Secure payment via Stripe',
                  style: TextStyle(
                    fontSize: isTablet ? 14 : 12,
                    color: Colors.grey.shade600,
                  ),
                ),
              ],
            ),
          ),
          if (isSelected)
            Icon(
              Icons.check_circle,
              color: const Color(0xFF635BFF),
              size: isTablet ? 28 : 24,
            ),
        ],
      ),
    );
  }

  Future<void> _processDirectPayment() async {
    setState(() => _isProcessing = true);

    try {
      final provider = context.read<SubscriptionProvider>();
      final price = widget.isYearly ? widget.planInfo.yearlyPrice : widget.planInfo.monthlyPrice;
      
      // Process subscription upgrade through Stripe
      final result = await _stripeService.processPayment(
        context: context,
        amount: price,
        productId: 'SUB-${DateTime.now().millisecondsSinceEpoch}',
        productName: '${widget.planInfo.name} - ${widget.isYearly ? "Yearly" : "Monthly"} Subscription',
      );

      if (result.success) {
        // Update subscription status in provider
        final success = await provider.upgradeSubscription(
          plan: widget.planInfo.plan,
          isYearly: widget.isYearly,
          paymentDetails: {
            'method': 'stripe',
            'transaction_id': result.transactionId,
            'payment_intent_id': result.paymentIntentId,
            'amount': price,
          },
        );

        if (success) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Subscription upgraded successfully!'),
                backgroundColor: Colors.green,
              ),
            );
            Navigator.of(context).pop();
          }
          widget.onPaymentComplete(true);
        } else {
          _handlePaymentFailure(provider.error ?? 'Failed to update subscription');
        }
      } else {
        _handlePaymentFailure(result.message ?? 'Payment failed');
      }
    } catch (e) {
      _handlePaymentFailure('Payment processing error: ${e.toString()}');
    } finally {
      if (mounted) {
        setState(() => _isProcessing = false);
      }
    }
  }

  /// Test mode: Skip payment and activate subscription immediately
  /// This is for development/testing purposes only
  Future<void> _skipPaymentTestMode() async {
    // Show confirmation dialog
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Icon(Icons.science_outlined, color: Colors.orange.shade700, size: 20),
            const SizedBox(width: 8),
            const Text('Test Mode', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
          ],
        ),
        content: const Text(
          'This will activate the Pro subscription without payment. This is for testing purposes only.',
          style: TextStyle(fontSize: 14),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('Cancel', style: TextStyle(color: Colors.grey.shade600)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text('Activate Pro', style: TextStyle(color: Colors.orange.shade700, fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    setState(() => _isProcessing = true);

    try {
      final provider = context.read<SubscriptionProvider>();
      
      // Update subscription status in provider (test mode)
      final success = await provider.upgradeSubscription(
        plan: widget.planInfo.plan,
        isYearly: widget.isYearly,
        paymentDetails: {
          'method': 'test_mode',
          'transaction_id': 'TEST-${DateTime.now().millisecondsSinceEpoch}',
          'amount': 0.0, // Free in test mode
        },
      );

      if (success) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Row(
                children: [
                  Icon(Icons.science_outlined, color: Colors.white, size: 18),
                  const SizedBox(width: 8),
                  const Expanded(
                    child: Text('Pro subscription activated (Test Mode)'),
                  ),
                ],
              ),
              backgroundColor: Colors.orange.shade700,
            ),
          );
          Navigator.of(context).pop();
        }
        widget.onPaymentComplete(true);
      } else {
        _handlePaymentFailure(provider.error ?? 'Failed to activate subscription');
      }
    } catch (e) {
      _handlePaymentFailure('Activation error: ${e.toString()}');
    } finally {
      if (mounted) {
        setState(() => _isProcessing = false);
      }
    }
  }

  void _handlePaymentFailure(String error) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Payment failed: $error'),
          backgroundColor: Colors.red,
        ),
      );
    }
    widget.onPaymentComplete(false);
  }
}