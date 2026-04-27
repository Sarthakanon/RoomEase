import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/subscription_models.dart';
import '../../providers/subscription_provider.dart';
import '../widgets/plan_card.dart';
import '../widgets/payment_dialog.dart';

class SubscriptionPlansScreen extends StatefulWidget {
  final bool showBackButton;
  final String? reason; // Why user is seeing this screen

  const SubscriptionPlansScreen({
    super.key,
    this.showBackButton = true,
    this.reason,
  });

  @override
  State<SubscriptionPlansScreen> createState() => _SubscriptionPlansScreenState();
}

class _SubscriptionPlansScreenState extends State<SubscriptionPlansScreen> {
  bool _isYearly = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<SubscriptionProvider>().initialize();
    });
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isTablet = screenWidth > 600;
    final isDesktop = screenWidth > 1200;
    
    // Responsive padding
    final horizontalPadding = isDesktop ? 32.0 : (isTablet ? 24.0 : 16.0);
    final maxWidth = isDesktop ? 800.0 : double.infinity;
    
    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      appBar: AppBar(
        title: Text(
          'Choose Your Plan',
          style: TextStyle(
            fontWeight: FontWeight.w700,
            color: const Color(0xFF1A1A2E),
            fontSize: isTablet ? 20 : 18,
          ),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        automaticallyImplyLeading: widget.showBackButton,
        iconTheme: const IconThemeData(color: Color(0xFF1A1A2E)),
      ),
      body: Consumer<SubscriptionProvider>(
        builder: (context, provider, child) {
          return Center(
            child: Container(
              constraints: BoxConstraints(maxWidth: maxWidth),
              child: SingleChildScrollView(
                padding: EdgeInsets.all(horizontalPadding),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Reason for upgrade (if provided)
                    if (widget.reason != null) ...[
                      Container(
                        width: double.infinity,
                        padding: EdgeInsets.all(isTablet ? 20 : 16),
                        decoration: BoxDecoration(
                          color: Colors.orange.shade50,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.orange.shade200),
                        ),
                        child: Row(
                          children: [
                            Icon(Icons.info_outline, 
                                 color: Colors.orange.shade700, 
                                 size: isTablet ? 24 : 20),
                            SizedBox(width: isTablet ? 16 : 12),
                            Expanded(
                              child: Text(
                                widget.reason!,
                                style: TextStyle(
                                  color: Colors.orange.shade700,
                                  fontWeight: FontWeight.w500,
                                  fontSize: isTablet ? 16 : 14,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      SizedBox(height: isTablet ? 32 : 24),
                    ],

                    // Current subscription info
                    if (provider.currentSubscription != null) ...[
                      _buildCurrentPlanCard(provider.currentSubscription!, isTablet),
                      SizedBox(height: isTablet ? 32 : 24),
                    ],

                    // Billing toggle
                    _buildBillingToggle(isTablet),
                    SizedBox(height: isTablet ? 32 : 24),

                    // Plan cards - responsive grid for larger screens
                    if (isDesktop) 
                      _buildDesktopPlanGrid(provider)
                    else if (isTablet)
                      _buildTabletPlanGrid(provider)
                    else
                      _buildMobilePlanList(provider),

                    SizedBox(height: isTablet ? 48 : 32),

                    // Features comparison
                    _buildFeaturesComparison(isTablet),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildCurrentPlanCard(UserSubscription subscription, bool isTablet) {
    final planInfo = SubscriptionPlanInfo.getPlanInfo(subscription.plan);
    
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(isTablet ? 20 : 16),
      decoration: BoxDecoration(
        color: Colors.blue.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.blue.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.check_circle, 
                   color: Colors.blue.shade600, 
                   size: isTablet ? 24 : 20),
              SizedBox(width: isTablet ? 12 : 8),
              Text(
                'Current Plan',
                style: TextStyle(
                  color: Colors.blue.shade700,
                  fontWeight: FontWeight.w600,
                  fontSize: isTablet ? 16 : 14,
                ),
              ),
            ],
          ),
          SizedBox(height: isTablet ? 12 : 8),
          Text(
            planInfo.name,
            style: TextStyle(
              fontSize: isTablet ? 22 : 18,
              fontWeight: FontWeight.w700,
              color: const Color(0xFF1A1A2E),
            ),
          ),
          if (subscription.endDate != null) ...[
            SizedBox(height: isTablet ? 6 : 4),
            Text(
              'Expires on ${_formatDate(subscription.endDate!)}',
              style: TextStyle(
                color: Colors.grey.shade600,
                fontSize: isTablet ? 15 : 13,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildBillingToggle(bool isTablet) {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: Colors.grey.shade200,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Expanded(
            child: GestureDetector(
              onTap: () => setState(() => _isYearly = false),
              child: Container(
                padding: EdgeInsets.symmetric(vertical: isTablet ? 16 : 12),
                decoration: BoxDecoration(
                  color: !_isYearly ? Colors.white : Colors.transparent,
                  borderRadius: BorderRadius.circular(6),
                  boxShadow: !_isYearly ? [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.1),
                      blurRadius: 4,
                      offset: const Offset(0, 2),
                    ),
                  ] : null,
                ),
                child: Text(
                  'Monthly',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: isTablet ? 16 : 14,
                    color: !_isYearly ? const Color(0xFF1A1A2E) : Colors.grey.shade600,
                  ),
                ),
              ),
            ),
          ),
          Expanded(
            child: GestureDetector(
              onTap: () => setState(() => _isYearly = true),
              child: Container(
                padding: EdgeInsets.symmetric(vertical: isTablet ? 16 : 12),
                decoration: BoxDecoration(
                  color: _isYearly ? Colors.white : Colors.transparent,
                  borderRadius: BorderRadius.circular(6),
                  boxShadow: _isYearly ? [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.1),
                      blurRadius: 4,
                      offset: const Offset(0, 2),
                    ),
                  ] : null,
                ),
                child: Column(
                  children: [
                    Text(
                      'Yearly',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: isTablet ? 16 : 14,
                        color: _isYearly ? const Color(0xFF1A1A2E) : Colors.grey.shade600,
                      ),
                    ),
                    if (_isYearly) ...[
                      SizedBox(height: isTablet ? 4 : 2),
                      Container(
                        padding: EdgeInsets.symmetric(
                          horizontal: isTablet ? 8 : 6, 
                          vertical: isTablet ? 3 : 2,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.green.shade100,
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          'Save 17%',
                          style: TextStyle(
                            fontSize: isTablet ? 12 : 10,
                            fontWeight: FontWeight.w600,
                            color: Colors.green.shade700,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // Mobile plan list (vertical)
  Widget _buildMobilePlanList(SubscriptionProvider provider) {
    return Column(
      children: SubscriptionPlanInfo.allPlans.map((planInfo) {
        final isCurrentPlan = provider.currentSubscription?.plan == planInfo.plan;
        return Padding(
          padding: const EdgeInsets.only(bottom: 16),
          child: PlanCard(
            planInfo: planInfo,
            isYearly: _isYearly,
            isCurrentPlan: isCurrentPlan,
            onSelectPlan: isCurrentPlan ? null : () => _selectPlan(planInfo),
          ),
        );
      }).toList(),
    );
  }

  // Tablet plan grid (2 columns)
  Widget _buildTabletPlanGrid(SubscriptionProvider provider) {
    final plans = SubscriptionPlanInfo.allPlans;
    return Column(
      children: [
        // First row - Free and Premium
        Row(
          children: [
            Expanded(
              child: _buildPlanCardForGrid(plans[0], provider),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: _buildPlanCardForGrid(plans[1], provider),
            ),
          ],
        ),
        const SizedBox(height: 16),
        // Second row - Pro (centered)
        Row(
          children: [
            const Expanded(child: SizedBox()),
            Expanded(
              flex: 2,
              child: _buildPlanCardForGrid(plans[2], provider),
            ),
            const Expanded(child: SizedBox()),
          ],
        ),
      ],
    );
  }

  // Desktop plan grid (3 columns)
  Widget _buildDesktopPlanGrid(SubscriptionProvider provider) {
    return Row(
      children: SubscriptionPlanInfo.allPlans.map((planInfo) {
        final isLast = planInfo == SubscriptionPlanInfo.allPlans.last;
        return Expanded(
          child: Padding(
            padding: EdgeInsets.only(right: isLast ? 0 : 16),
            child: _buildPlanCardForGrid(planInfo, provider),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildPlanCardForGrid(SubscriptionPlanInfo planInfo, SubscriptionProvider provider) {
    final isCurrentPlan = provider.currentSubscription?.plan == planInfo.plan;
    return PlanCard(
      planInfo: planInfo,
      isYearly: _isYearly,
      isCurrentPlan: isCurrentPlan,
      onSelectPlan: isCurrentPlan ? null : () => _selectPlan(planInfo),
    );
  }

  Widget _buildFeaturesComparison(bool isTablet) {
    return Container(
      padding: EdgeInsets.all(isTablet ? 24 : 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Why upgrade?',
            style: TextStyle(
              fontSize: isTablet ? 22 : 18,
              fontWeight: FontWeight.w700,
              color: const Color(0xFF1A1A2E),
            ),
          ),
          SizedBox(height: isTablet ? 20 : 16),
          _buildFeatureRow('More roomspaces', 'Manage multiple living spaces', isTablet),
          _buildFeatureRow('Advanced analytics', 'Detailed spending insights', isTablet),
          _buildFeatureRow('Custom categories', 'Organize expenses your way', isTablet),
          _buildFeatureRow('Export reports', 'PDF and Excel downloads', isTablet),
          _buildFeatureRow('Priority support', 'Get help when you need it', isTablet),
        ],
      ),
    );
  }

  Widget _buildFeatureRow(String title, String description, bool isTablet) {
    return Padding(
      padding: EdgeInsets.only(bottom: isTablet ? 16 : 12),
      child: Row(
        children: [
          Icon(Icons.check_circle, 
               color: Colors.green.shade600, 
               size: isTablet ? 24 : 20),
          SizedBox(width: isTablet ? 16 : 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: isTablet ? 16 : 14,
                    color: const Color(0xFF1A1A2E),
                  ),
                ),
                Text(
                  description,
                  style: TextStyle(
                    fontSize: isTablet ? 14 : 13,
                    color: Colors.grey.shade600,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _selectPlan(SubscriptionPlanInfo planInfo) {
    if (planInfo.plan == SubscriptionPlan.free) return;

    showDialog(
      context: context,
      builder: (context) => PaymentDialog(
        planInfo: planInfo,
        isYearly: _isYearly,
        onPaymentComplete: (success) {
          if (success) {
            Navigator.of(context).pop(); // Close dialog
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Successfully upgraded to ${planInfo.name}!'),
                backgroundColor: Colors.green,
              ),
            );
            if (!widget.showBackButton) {
              Navigator.of(context).pop(); // Close screen if modal
            }
          }
        },
      ),
    );
  }

  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year}';
  }
}