import 'package:flutter/material.dart';
import '../providers/subscription_provider.dart';
import '../presentation/screens/subscription_plans_screen.dart';

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