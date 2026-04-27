import 'package:flutter/material.dart';
import '../../models/subscription_models.dart';

class PlanCard extends StatelessWidget {
  final SubscriptionPlanInfo planInfo;
  final bool isYearly;
  final bool isCurrentPlan;
  final VoidCallback? onSelectPlan;

  const PlanCard({
    super.key,
    required this.planInfo,
    required this.isYearly,
    required this.isCurrentPlan,
    this.onSelectPlan,
  });

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isTablet = screenWidth > 600;
    final isDesktop = screenWidth > 1200;
    
    final price = isYearly ? planInfo.yearlyPrice : planInfo.monthlyPrice;
    final monthlyPrice = isYearly ? planInfo.yearlyPrice / 12 : planInfo.monthlyPrice;
    final isPopular = planInfo.badge == 'Popular';
    final isBestValue = planInfo.badge == 'Best Value';
    
    // Responsive sizing
    final cardPadding = isDesktop ? 24.0 : (isTablet ? 20.0 : 16.0);
    final titleFontSize = isDesktop ? 28.0 : (isTablet ? 26.0 : 24.0);
    final priceFontSize = isDesktop ? 36.0 : (isTablet ? 34.0 : 32.0);
    final buttonPadding = isDesktop ? 20.0 : (isTablet ? 18.0 : 16.0);
    
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isCurrentPlan 
              ? Colors.blue.shade300
              : isPopular || isBestValue
                  ? Theme.of(context).primaryColor
                  : Colors.grey.shade200,
          width: isCurrentPlan || isPopular || isBestValue ? 2 : 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header with badge
          if (planInfo.badge != null || isCurrentPlan)
            Container(
              width: double.infinity,
              padding: EdgeInsets.symmetric(vertical: isTablet ? 10 : 8),
              decoration: BoxDecoration(
                color: isCurrentPlan
                    ? Colors.blue.shade50
                    : isPopular
                        ? Colors.orange.shade50
                        : Colors.green.shade50,
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(15),
                  topRight: Radius.circular(15),
                ),
              ),
              child: Text(
                isCurrentPlan 
                    ? 'Current Plan'
                    : planInfo.badge!,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  color: isCurrentPlan
                      ? Colors.blue.shade700
                      : isPopular
                          ? Colors.orange.shade700
                          : Colors.green.shade700,
                  fontSize: isTablet ? 14 : 12,
                ),
              ),
            ),

          Padding(
            padding: EdgeInsets.all(cardPadding),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Plan name and description
                Text(
                  planInfo.name,
                  style: TextStyle(
                    fontSize: titleFontSize,
                    fontWeight: FontWeight.w700,
                    color: const Color(0xFF1A1A2E),
                  ),
                ),
                SizedBox(height: isTablet ? 6 : 4),
                Text(
                  planInfo.description,
                  style: TextStyle(
                    color: Colors.grey.shade600,
                    fontSize: isTablet ? 16 : 14,
                  ),
                ),
                SizedBox(height: isTablet ? 20 : 16),

                // Price
                if (planInfo.plan == SubscriptionPlan.free) ...[
                  Text(
                    'Free',
                    style: TextStyle(
                      fontSize: priceFontSize,
                      fontWeight: FontWeight.w700,
                      color: const Color(0xFF1A1A2E),
                    ),
                  ),
                  Text(
                    'Forever',
                    style: TextStyle(
                      color: Colors.grey,
                      fontSize: isTablet ? 16 : 14,
                    ),
                  ),
                ] else ...[
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        '₹${monthlyPrice.toInt()}',
                        style: TextStyle(
                          fontSize: priceFontSize,
                          fontWeight: FontWeight.w700,
                          color: const Color(0xFF1A1A2E),
                        ),
                      ),
                      Text(
                        '/month',
                        style: TextStyle(
                          color: Colors.grey,
                          fontSize: isTablet ? 16 : 14,
                        ),
                      ),
                    ],
                  ),
                  if (isYearly && price > 0) ...[
                    SizedBox(height: isTablet ? 6 : 4),
                    Text(
                      'Billed yearly (₹${price.toInt()})',
                      style: TextStyle(
                        color: Colors.grey.shade600,
                        fontSize: isTablet ? 14 : 12,
                      ),
                    ),
                  ],
                ],

                SizedBox(height: isTablet ? 24 : 20),

                // Features
                ...planInfo.features.map((feature) => Padding(
                  padding: EdgeInsets.only(bottom: isTablet ? 12 : 8),
                  child: Row(
                    children: [
                      Icon(
                        Icons.check_circle,
                        color: Colors.green.shade600,
                        size: isTablet ? 18 : 16,
                      ),
                      SizedBox(width: isTablet ? 12 : 8),
                      Expanded(
                        child: Text(
                          feature,
                          style: TextStyle(
                            fontSize: isTablet ? 16 : 14,
                            color: const Color(0xFF1A1A2E),
                          ),
                        ),
                      ),
                    ],
                  ),
                )).toList(),

                SizedBox(height: isTablet ? 32 : 24),

                // Action button
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: isCurrentPlan ? null : onSelectPlan,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: isCurrentPlan
                          ? Colors.grey.shade300
                          : planInfo.plan == SubscriptionPlan.free
                              ? Colors.grey.shade700
                              : Theme.of(context).primaryColor,
                      foregroundColor: Colors.white,
                      padding: EdgeInsets.symmetric(vertical: buttonPadding),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      elevation: 0,
                    ),
                    child: Text(
                      isCurrentPlan
                          ? 'Current Plan'
                          : planInfo.plan == SubscriptionPlan.free
                              ? 'Current Plan'
                              : 'Upgrade Now',
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: isTablet ? 18 : 16,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}