import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/subscription_models.dart';
import '../../providers/subscription_provider.dart';
import '../screens/subscription_plans_screen.dart';

class SubscriptionStatusCard extends StatelessWidget {
  const SubscriptionStatusCard({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<SubscriptionProvider>(
      builder: (context, provider, child) {
        if (provider.isLoading) {
          return _buildLoadingCard();
        }

        final subscription = provider.currentSubscription;
        if (subscription == null) {
          return _buildErrorCard(context);
        }

        return _buildSubscriptionCard(context, subscription, provider);
      },
    );
  }

  Widget _buildLoadingCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: const Row(
        children: [
          SizedBox(
            width: 20,
            height: 20,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
          SizedBox(width: 12),
          Text(
            'Loading subscription...',
            style: TextStyle(
              fontWeight: FontWeight.w500,
              color: Color(0xFF1A1A2E),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorCard(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Icon(Icons.error_outline, color: Colors.red.shade600, size: 20),
          const SizedBox(width: 12),
          const Expanded(
            child: Text(
              'Failed to load subscription',
              style: TextStyle(
                fontWeight: FontWeight.w500,
                color: Color(0xFF1A1A2E),
              ),
            ),
          ),
          TextButton(
            onPressed: () => context.read<SubscriptionProvider>().refresh(),
            child: const Text('Retry'),
          ),
        ],
      ),
    );
  }

  Widget _buildSubscriptionCard(
    BuildContext context,
    UserSubscription subscription,
    SubscriptionProvider provider,
  ) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isTablet = screenWidth > 600;
    
    final planInfo = SubscriptionPlanInfo.getPlanInfo(subscription.plan);
    final isNearExpiry = subscription.isNearExpiry;
    final usage = provider.roomspaceUsage;

    // Responsive sizing
    final cardPadding = isTablet ? 20.0 : 16.0;
    final titleFontSize = isTablet ? 18.0 : 16.0;
    final buttonPadding = isTablet ? 16.0 : 12.0;

    return GestureDetector(
      onTap: () => _navigateToPlans(context),
      child: Container(
        padding: EdgeInsets.all(cardPadding),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: subscription.isFree 
                ? Colors.grey.shade200
                : Theme.of(context).primaryColor.withValues(alpha: 0.3),
          ),
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
            // Header
            Row(
              children: [
                Container(
                  padding: EdgeInsets.symmetric(
                    horizontal: isTablet ? 10 : 8, 
                    vertical: isTablet ? 6 : 4,
                  ),
                  decoration: BoxDecoration(
                    color: subscription.isFree 
                        ? Colors.grey.shade100
                        : Theme.of(context).primaryColor.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    planInfo.name.toUpperCase(),
                    style: TextStyle(
                      fontSize: isTablet ? 12 : 11,
                      fontWeight: FontWeight.w700,
                      color: subscription.isFree 
                          ? Colors.grey.shade600
                          : Theme.of(context).primaryColor,
                    ),
                  ),
                ),
                const Spacer(),
                Icon(
                  Icons.arrow_forward_ios,
                  size: isTablet ? 18 : 16,
                  color: Colors.grey.shade400,
                ),
              ],
            ),
            SizedBox(height: isTablet ? 16 : 12),

            // Plan name and description
            Text(
              subscription.isFree ? 'Free Plan' : '${planInfo.name} Plan',
              style: TextStyle(
                fontSize: titleFontSize,
                fontWeight: FontWeight.w700,
                color: const Color(0xFF1A1A2E),
              ),
            ),
            SizedBox(height: isTablet ? 6 : 4),
            Text(
              subscription.isFree 
                  ? 'Upgrade to unlock more features'
                  : planInfo.description,
              style: TextStyle(
                fontSize: isTablet ? 14 : 13,
                color: Colors.grey.shade600,
              ),
            ),

            // Expiry warning
            if (isNearExpiry) ...[
              SizedBox(height: isTablet ? 12 : 8),
              Container(
                padding: EdgeInsets.symmetric(
                  horizontal: isTablet ? 10 : 8, 
                  vertical: isTablet ? 6 : 4,
                ),
                decoration: BoxDecoration(
                  color: Colors.orange.shade50,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.warning_amber, 
                         color: Colors.orange.shade600, 
                         size: isTablet ? 16 : 14),
                    SizedBox(width: isTablet ? 6 : 4),
                    Text(
                      'Expires in ${subscription.daysUntilExpiry} days',
                      style: TextStyle(
                        fontSize: isTablet ? 12 : 11,
                        fontWeight: FontWeight.w600,
                        color: Colors.orange.shade700,
                      ),
                    ),
                  ],
                ),
              ),
            ],

            // Usage info
            if (usage != null) ...[
              SizedBox(height: isTablet ? 16 : 12),
              Row(
                children: [
                  Icon(Icons.home_work_outlined, 
                       size: isTablet ? 18 : 16, 
                       color: Colors.grey.shade600),
                  SizedBox(width: isTablet ? 8 : 6),
                  Text(
                    provider.roomspaceUsageText,
                    style: TextStyle(
                      fontSize: isTablet ? 14 : 12,
                      color: Colors.grey.shade600,
                    ),
                  ),
                ],
              ),
              if (provider.isNearRoomspaceLimit) ...[
                SizedBox(height: isTablet ? 6 : 4),
                LinearProgressIndicator(
                  value: provider.roomspaceUsagePercentage / 100,
                  backgroundColor: Colors.grey.shade200,
                  valueColor: AlwaysStoppedAnimation<Color>(
                    provider.roomspaceUsagePercentage >= 90 
                        ? Colors.red.shade400
                        : Colors.orange.shade400,
                  ),
                ),
              ],
            ],

            // Upgrade button for free users
            if (subscription.isFree) ...[
              SizedBox(height: isTablet ? 16 : 12),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () => _navigateToPlans(context),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Theme.of(context).primaryColor,
                    foregroundColor: Colors.white,
                    padding: EdgeInsets.symmetric(vertical: buttonPadding),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  child: Text(
                    'Upgrade Now',
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: isTablet ? 16 : 14,
                    ),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  void _navigateToPlans(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => const SubscriptionPlansScreen(),
      ),
    );
  }
}