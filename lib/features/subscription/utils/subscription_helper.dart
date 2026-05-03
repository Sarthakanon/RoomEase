import 'package:flutter/material.dart';
import '../providers/subscription_provider.dart';
import '../presentation/screens/subscription_plans_screen.dart';
import '../models/subscription_models.dart';

class SubscriptionHelper {
  /// Check if user can create roomspace and show upgrade screen if needed
  static Future<bool> checkAndHandleRoomspaceLimit(
    BuildContext context,
    SubscriptionProvider provider, {
    String action = 'create',
  }) async {
    final canProceed = action == 'create' 
        ? await provider.canCreateRoomspace()
        : await provider.canJoinRoomspace();

    if (!canProceed) {
      _showUpgradeScreen(
        context,
        reason: 'You\'ve reached your roomspace limit. Upgrade to ${action} more roomspaces.',
      );
      return false;
    }

    return true;
  }

  /// Check if user can access export features
  static bool canExport(SubscriptionProvider provider) {
    return provider.currentLimits.exportFeatures;
  }

  /// Check if user can access advanced reports
  static bool canAccessAdvancedReports(SubscriptionProvider provider) {
    return provider.currentLimits.advancedReports;
  }

  /// Check if user has priority support
  static bool hasPrioritySupport(SubscriptionProvider provider) {
    return provider.currentLimits.prioritySupport;
  }

  /// Show upgrade dialog for blocked feature
  static void showFeatureBlockedDialog(
    BuildContext context, {
    required String featureName,
    String? description,
  }) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [Colors.amber.shade600, Colors.orange.shade600],
                ),
                borderRadius: BorderRadius.circular(4),
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.star, size: 12, color: Colors.white),
                  SizedBox(width: 2),
                  Text(
                    'PRO',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            const Expanded(
              child: Text(
                'Upgrade Required',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '$featureName is only available in the Pro plan.',
              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
            ),
            if (description != null) ...[
              const SizedBox(height: 8),
              Text(
                description,
                style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
              ),
            ],
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.amber.shade50,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.amber.shade200),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Pro Plan Benefits:',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: Colors.amber.shade900,
                    ),
                  ),
                  const SizedBox(height: 6),
                  ...SubscriptionLimits.pro.toFeatureList().map((feature) => Padding(
                    padding: const EdgeInsets.only(bottom: 4),
                    child: Row(
                      children: [
                        Icon(Icons.check_circle, size: 14, color: Colors.amber.shade700),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            feature,
                            style: TextStyle(
                              fontSize: 11,
                              color: Colors.grey.shade700,
                            ),
                          ),
                        ),
                      ],
                    ),
                  )),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Maybe Later', style: TextStyle(color: Colors.grey.shade600)),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _showUpgradeScreen(context, reason: '$featureName requires Pro plan');
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.amber.shade600,
              foregroundColor: Colors.white,
            ),
            child: const Text('Upgrade to Pro', style: TextStyle(fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
  }

  /// Show upgrade screen with reason
  static void _showUpgradeScreen(BuildContext context, {String? reason}) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => SubscriptionPlansScreen(
          reason: reason,
        ),
      ),
    );
  }

  /// Show upgrade screen as modal
  static void showUpgradeModal(BuildContext context, {String? reason}) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        height: MediaQuery.of(context).size.height * 0.9,
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: SubscriptionPlansScreen(
          showBackButton: false,
          reason: reason,
        ),
      ),
    );
  }

  /// Get upgrade reason based on current usage
  static String getRoomspaceLimitReason(SubscriptionProvider provider) {
    final usage = provider.roomspaceUsage;
    if (usage == null) return 'Upgrade to create more roomspaces';
    
    final current = usage['current'] as int;
    final max = usage['max'] as int;
    
    return 'You\'ve used $current of $max roomspaces. Upgrade to create more.';
  }
}

/// Extension to convert limits to feature list
extension SubscriptionLimitsExtension on SubscriptionLimits {
  List<String> toFeatureList() {
    return [
      'Up to $maxRoomspaces roomspaces',
      'Up to $maxMembersPerRoomspace members per room',
      if (exportFeatures) 'Export to PDF/Excel',
      if (advancedReports) 'Advanced reports',
      if (prioritySupport) 'Priority support',
    ];
  }
}