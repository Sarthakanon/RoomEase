import 'package:flutter/material.dart';
import '../models/expense_models.dart';
import '../models/recurring_expense_models.dart';

/// Bottom sheet showing detailed information about a recurring payment
class RecurringPaymentDetailsSheet extends StatelessWidget {
  final ExpenseData expense;

  const RecurringPaymentDetailsSheet({
    super.key,
    required this.expense,
  });

  @override
  Widget build(BuildContext context) {
    final config = expense.recurringConfig;
    final primaryColor = Colors.purple.shade700;
    final nextPayment = config?.getNextOccurrence(DateTime.now());
    final daysUntilNext = nextPayment?.difference(DateTime.now()).inDays;

    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Handle
          Container(
            width: 36,
            height: 4,
            margin: const EdgeInsets.symmetric(vertical: 12),
            decoration: BoxDecoration(
              color: Colors.grey.shade300,
              borderRadius: BorderRadius.circular(2),
            ),
          ),

          // Header
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: primaryColor.withValues(alpha: 0.1),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
            ),
            child: Column(
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: primaryColor.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(
                        _getIcon(expense.category),
                        color: primaryColor,
                        size: 28,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            expense.title,
                            style: const TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.w700,
                              color: Color(0xFF1A1A2E),
                            ),
                          ),
                          const SizedBox(height: 4),
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(
                                  color: primaryColor,
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const Icon(
                                      Icons.repeat_rounded,
                                      size: 12,
                                      color: Colors.white,
                                    ),
                                    const SizedBox(width: 4),
                                    Text(
                                      config?.interval?.label ?? 'Monthly',
                                      style: const TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.w700,
                                        color: Colors.white,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 8),
                              Text(
                                expense.category,
                                style: TextStyle(
                                  fontSize: 14,
                                  color: Colors.grey.shade600,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(Icons.close_rounded),
                      style: IconButton.styleFrom(
                        backgroundColor: Colors.white.withValues(alpha: 0.8),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Text(
                  'Rs. ${expense.amount.toStringAsFixed(2)}',
                  style: TextStyle(
                    fontSize: 32,
                    fontWeight: FontWeight.w900,
                    color: primaryColor,
                  ),
                ),
              ],
            ),
          ),

          // Content
          Flexible(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Next Payment Info
                  if (nextPayment != null) ...[
                    _buildInfoCard(
                      'Next Payment',
                      _formatDateTime(nextPayment),
                      Icons.schedule_rounded,
                      daysUntilNext != null && daysUntilNext <= 3 
                          ? Colors.orange.shade600 
                          : primaryColor,
                      subtitle: daysUntilNext != null
                          ? daysUntilNext == 0 
                              ? 'Due today!'
                              : daysUntilNext > 0 
                                  ? 'In $daysUntilNext day${daysUntilNext != 1 ? 's' : ''}'
                                  : '${daysUntilNext.abs()} day${daysUntilNext.abs() != 1 ? 's' : ''} overdue'
                          : null,
                    ),
                    const SizedBox(height: 16),
                  ],

                  // Frequency Details
                  _buildInfoCard(
                    'Payment Frequency',
                    config?.interval?.label ?? 'Monthly',
                    Icons.repeat_rounded,
                    primaryColor,
                    subtitle: _getFrequencyDescription(config?.interval),
                  ),
                  const SizedBox(height: 16),

                  // Duration Info
                  if (config?.endDate != null || config?.maxOccurrences != null) ...[
                    _buildInfoCard(
                      'Duration',
                      config?.endDate != null 
                          ? 'Until ${_formatDate(config!.endDate!)}'
                          : '${config?.maxOccurrences} payments total',
                      Icons.event_rounded,
                      primaryColor,
                    ),
                    const SizedBox(height: 16),
                  ],

                  // Notification Settings
                  _buildInfoCard(
                    'Notifications',
                    config?.notifyBeforeCreation == true 
                        ? '${config?.notificationDaysBefore ?? 1} day${(config?.notificationDaysBefore ?? 1) != 1 ? 's' : ''} before'
                        : 'Disabled',
                    Icons.notifications_rounded,
                    config?.notifyBeforeCreation == true 
                        ? primaryColor 
                        : Colors.grey.shade600,
                  ),
                  const SizedBox(height: 16),

                  // Description
                  if (expense.description.isNotEmpty) ...[
                    _buildInfoCard(
                      'Description',
                      expense.description,
                      Icons.notes_rounded,
                      primaryColor,
                    ),
                    const SizedBox(height: 16),
                  ],

                  // Split Information
                  if (expense.splits != null && expense.splits!.isNotEmpty) ...[
                    _buildSplitInfo(),
                    const SizedBox(height: 16),
                  ],

                  // Monthly Impact
                  _buildMonthlyImpactCard(),
                ],
              ),
            ),
          ),

          // Actions
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.grey.shade50,
              borderRadius: const BorderRadius.vertical(bottom: Radius.circular(24)),
            ),
            child: Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () {
                      Navigator.pop(context);
                      // TODO: Edit recurring payment
                    },
                    icon: const Icon(Icons.edit_rounded, size: 18),
                    label: const Text('Edit'),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: FilledButton.icon(
                    onPressed: () {
                      Navigator.pop(context);
                      // TODO: Pause/Resume recurring payment
                    },
                    icon: const Icon(Icons.pause_rounded, size: 18),
                    label: const Text('Pause'),
                    style: FilledButton.styleFrom(
                      backgroundColor: Colors.orange.shade600,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
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

  Widget _buildInfoCard(
    String title,
    String value,
    IconData icon,
    Color color, {
    String? subtitle,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: color, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: Colors.grey.shade600,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF1A1A2E),
                  ),
                ),
                if (subtitle != null) ...[
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: 12,
                      color: color,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSplitInfo() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
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
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.blue.shade100,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(Icons.pie_chart_rounded, color: Colors.blue.shade700, size: 20),
              ),
              const SizedBox(width: 12),
              Text(
                'Split Details',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: Colors.grey.shade600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ...expense.splits!.map((split) => Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 12,
                  backgroundColor: Colors.blue.shade200,
                  child: Text(
                    split.userName.isNotEmpty ? split.userName[0].toUpperCase() : '?',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      color: Colors.blue.shade700,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    split.userName,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                Text(
                  'Rs. ${split.amount.toStringAsFixed(2)}',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: Colors.blue.shade700,
                  ),
                ),
              ],
            ),
          )).toList(),
        ],
      ),
    );
  }

  Widget _buildMonthlyImpactCard() {
    final config = expense.recurringConfig;
    double monthlyAmount = expense.amount;
    
    if (config?.interval != null) {
      final interval = config!.interval!;
      if (interval == RecurringInterval.weekly) {
        monthlyAmount = expense.amount * 4.33; // Average weeks per month
      } else if (interval == RecurringInterval.yearly) {
        monthlyAmount = expense.amount / 12;
      }
      // Monthly is already correct, no change needed
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.green.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.green.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.green.shade100,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(Icons.trending_up_rounded, color: Colors.green.shade700, size: 20),
              ),
              const SizedBox(width: 12),
              Text(
                'Monthly Impact',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: Colors.grey.shade600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'Rs. ${monthlyAmount.toStringAsFixed(2)}',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w900,
              color: Colors.green.shade700,
            ),
          ),
          Text(
            'Average monthly cost for this recurring payment',
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey.shade600,
            ),
          ),
        ],
      ),
    );
  }

  String _getFrequencyDescription(RecurringInterval? interval) {
    if (interval == null) return 'Every 30 days';
    
    if (interval == RecurringInterval.weekly) {
      return 'Every 7 days';
    } else if (interval == RecurringInterval.monthly) {
      return 'Every 30 days';
    } else if (interval == RecurringInterval.yearly) {
      return 'Every 365 days';
    }
    
    return 'Every 30 days'; // Default fallback
  }

  IconData _getIcon(String category) {
    switch (category.toLowerCase()) {
      case 'groceries':
        return Icons.shopping_basket_outlined;
      case 'utilities':
        return Icons.bolt_rounded;
      case 'rent':
        return Icons.home_outlined;
      case 'food':
        return Icons.restaurant_rounded;
      case 'transport':
        return Icons.directions_car_rounded;
      case 'entertainment':
        return Icons.movie_creation_rounded;
      default:
        return Icons.receipt_long_outlined;
    }
  }

  String _formatDateTime(DateTime date) {
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
    ];
    
    final now = DateTime.now();
    final difference = now.difference(date);
    
    if (difference.inDays == 0) {
      return 'Today at ${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
    } else if (difference.inDays == 1) {
      return 'Tomorrow';
    } else if (difference.inDays == -1) {
      return 'Yesterday';
    } else {
      return '${months[date.month - 1]} ${date.day}, ${date.year}';
    }
  }

  String _formatDate(DateTime date) {
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
    ];
    return '${months[date.month - 1]} ${date.day}, ${date.year}';
  }
}