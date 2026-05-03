import 'package:flutter/material.dart';

/// Badge to show that a feature is only available in Pro plan
class ProFeatureBadge extends StatelessWidget {
  final bool showIcon;
  final double fontSize;
  
  const ProFeatureBadge({
    super.key,
    this.showIcon = true,
    this.fontSize = 10,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.amber.shade600, Colors.orange.shade600],
        ),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (showIcon) ...[
            Icon(Icons.star, size: fontSize + 2, color: Colors.white),
            const SizedBox(width: 2),
          ],
          Text(
            'PRO',
            style: TextStyle(
              color: Colors.white,
              fontSize: fontSize,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.5,
            ),
          ),
        ],
      ),
    );
  }
}

/// Widget to block a feature for free users
class ProFeatureBlocker extends StatelessWidget {
  final Widget child;
  final bool isProUser;
  final String featureName;
  final VoidCallback? onUpgradePressed;
  
  const ProFeatureBlocker({
    super.key,
    required this.child,
    required this.isProUser,
    required this.featureName,
    this.onUpgradePressed,
  });

  @override
  Widget build(BuildContext context) {
    if (isProUser) {
      return child;
    }
    
    return Stack(
      children: [
        // Blurred/disabled child
        Opacity(
          opacity: 0.4,
          child: IgnorePointer(
            child: child,
          ),
        ),
        
        // Overlay with upgrade message
        Positioned.fill(
          child: Container(
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.7),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const ProFeatureBadge(fontSize: 14),
                  const SizedBox(height: 8),
                  Text(
                    '$featureName is a Pro feature',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 12),
                  ElevatedButton(
                    onPressed: onUpgradePressed ?? () => _showUpgradeDialog(context),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.amber.shade600,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                    ),
                    child: const Text(
                      'Upgrade to Pro',
                      style: TextStyle(fontWeight: FontWeight.w700),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
  
  void _showUpgradeDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            const ProFeatureBadge(),
            const SizedBox(width: 8),
            const Text('Upgrade Required', style: TextStyle(fontSize: 16)),
          ],
        ),
        content: Text(
          '$featureName is only available in the Pro plan. Upgrade now to unlock this and other premium features!',
          style: const TextStyle(fontSize: 14),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Maybe Later'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              Navigator.pushNamed(context, '/subscription-plans');
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.amber.shade600,
            ),
            child: const Text('Upgrade to Pro'),
          ),
        ],
      ),
    );
  }
}
