import 'package:flutter/material.dart';
import '../../../models/expense_models.dart';
import '../../../models/recurring_expense_models.dart';
import '../../../widgets/enhanced_expense_tile.dart';

/// Dedicated screen for managing all recurring payments
class RecurringPaymentsScreen extends StatefulWidget {
  final List<ExpenseData> recurringExpenses;

  const RecurringPaymentsScreen({
    super.key,
    required this.recurringExpenses,
  });

  @override
  State<RecurringPaymentsScreen> createState() => _RecurringPaymentsScreenState();
}

class _RecurringPaymentsScreenState extends State<RecurringPaymentsScreen> {
  late List<ExpenseData> _recurringExpenses;
  String _sortBy = 'next_payment'; // next_payment, amount, frequency

  @override
  void initState() {
    super.initState();
    _recurringExpenses = List.from(widget.recurringExpenses);
    _sortExpenses();
  }

  void _sortExpenses() {
    switch (_sortBy) {
      case 'next_payment':
        _recurringExpenses.sort((a, b) {
          final nextA = a.recurringConfig?.getNextOccurrence(DateTime.now());
          final nextB = b.recurringConfig?.getNextOccurrence(DateTime.now());
          if (nextA == null && nextB == null) return 0;
          if (nextA == null) return 1;
          if (nextB == null) return -1;
          return nextA.compareTo(nextB);
        });
        break;
      case 'amount':
        _recurringExpenses.sort((a, b) => b.amount.compareTo(a.amount));
        break;
      case 'frequency':
        _recurringExpenses.sort((a, b) {
          final intervalA = a.recurringConfig?.interval?.days ?? 30;
          final intervalB = b.recurringConfig?.interval?.days ?? 30;
          return intervalA.compareTo(intervalB);
        });
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    final primaryColor = Colors.purple.shade700;
    final totalMonthlyAmount = _calculateMonthlyTotal();

    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      appBar: AppBar(
        title: const Text('Recurring Payments'),
        backgroundColor: primaryColor,
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          PopupMenuButton<String>(
            icon: const Icon(Icons.sort_rounded),
            onSelected: (value) {
              setState(() {
                _sortBy = value;
                _sortExpenses();
              });
            },
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: 'next_payment',
                child: Row(
                  children: [
                    Icon(Icons.schedule_rounded, size: 18),
                    SizedBox(width: 8),
                    Text('Next Payment'),
                  ],
                ),
              ),
              const PopupMenuItem(
                value: 'amount',
                child: Row(
                  children: [
                    Icon(Icons.attach_money_rounded, size: 18),
                    SizedBox(width: 8),
                    Text('Amount'),
                  ],
                ),
              ),
              const PopupMenuItem(
                value: 'frequency',
                child: Row(
                  children: [
                    Icon(Icons.repeat_rounded, size: 18),
                    SizedBox(width: 8),
                    Text('Frequency'),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
      body: Column(
        children: [
          // Summary Header
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: primaryColor,
              borderRadius: const BorderRadius.vertical(bottom: Radius.circular(20)),
            ),
            child: Column(
              children: [
                Text(
                  'Monthly Recurring Total',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.8),
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Rs. ${totalMonthlyAmount.toStringAsFixed(2)}',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 28,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  '${_recurringExpenses.length} active recurring payment${_recurringExpenses.length != 1 ? 's' : ''}',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.8),
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),

          // Recurring Payments List
          Expanded(
            child: _recurringExpenses.isEmpty
                ? _buildEmptyState()
                : ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: _recurringExpenses.length,
                    itemBuilder: (context, index) {
                      final expense = _recurringExpenses[index];
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: _buildRecurringPaymentCard(expense, primaryColor),
                      );
                    },
                  ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          // TODO: Navigate to create recurring payment
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Create new recurring payment - Coming soon!'),
              backgroundColor: Colors.orange,
            ),
          );
        },
        backgroundColor: primaryColor,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add_rounded),
        label: const Text('New Recurring'),
      ),
    );
  }

  Widget _buildRecurringPaymentCard(ExpenseData expense, Color primaryColor) {
    final config = expense.recurringConfig;
    final nextPayment = config?.getNextOccurrence(DateTime.now());
    final daysUntilNext = nextPayment?.difference(DateTime.now()).inDays;

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: primaryColor.withValues(alpha: 0.2)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          // Main Content
          InkWell(
            onTap: () => _showRecurringPaymentDetails(expense),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  Row(
                    children: [
                      // Icon
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: primaryColor.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Icon(
                          _getIcon(expense.category),
                          color: primaryColor,
                          size: 24,
                        ),
                      ),
                      const SizedBox(width: 16),
                      
                      // Content
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              expense.title,
                              style: const TextStyle(
                                fontWeight: FontWeight.w700,
                                fontSize: 16,
                                color: Color(0xFF1A1A2E),
                              ),
                            ),
                            const SizedBox(height: 4),
                            Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: primaryColor.withValues(alpha: 0.1),
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: Text(
                                    config?.interval?.label ?? 'Monthly',
                                    style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w700,
                                      color: primaryColor,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  expense.category,
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.grey.shade600,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      
                      // Amount
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                            'Rs. ${expense.amount.toStringAsFixed(0)}',
                            style: TextStyle(
                              fontWeight: FontWeight.w900,
                              fontSize: 18,
                              color: primaryColor,
                            ),
                          ),
                          if (daysUntilNext != null) ...[
                            Text(
                              daysUntilNext == 0 
                                  ? 'Due today'
                                  : daysUntilNext > 0 
                                      ? 'In $daysUntilNext day${daysUntilNext != 1 ? 's' : ''}'
                                      : 'Overdue',
                              style: TextStyle(
                                fontSize: 11,
                                color: daysUntilNext <= 0 
                                    ? Colors.red.shade600
                                    : daysUntilNext <= 3
                                        ? Colors.orange.shade600
                                        : Colors.grey.shade600,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ],
                  ),
                  
                  // Next Payment Info
                  if (nextPayment != null) ...[
                    const SizedBox(height: 12),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.grey.shade50,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            Icons.schedule_rounded,
                            size: 16,
                            color: Colors.grey.shade600,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'Next payment: ${_formatDate(nextPayment)}',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey.shade700,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
          
          // Action Buttons
          Container(
            decoration: BoxDecoration(
              color: Colors.grey.shade50,
              borderRadius: const BorderRadius.vertical(bottom: Radius.circular(16)),
            ),
            child: Row(
              children: [
                Expanded(
                  child: InkWell(
                    onTap: () => _editRecurringPayment(expense),
                    borderRadius: const BorderRadius.only(bottomLeft: Radius.circular(16)),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.edit_rounded, size: 16, color: Colors.blue.shade600),
                          const SizedBox(width: 4),
                          Text(
                            'Edit',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: Colors.blue.shade600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                Container(width: 1, height: 40, color: Colors.grey.shade300),
                Expanded(
                  child: InkWell(
                    onTap: () => _pauseRecurringPayment(expense),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.pause_rounded, size: 16, color: Colors.orange.shade600),
                          const SizedBox(width: 4),
                          Text(
                            'Pause',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: Colors.orange.shade600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                Container(width: 1, height: 40, color: Colors.grey.shade300),
                Expanded(
                  child: InkWell(
                    onTap: () => _deleteRecurringPayment(expense),
                    borderRadius: const BorderRadius.only(bottomRight: Radius.circular(16)),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.delete_outline_rounded, size: 16, color: Colors.red.shade600),
                          const SizedBox(width: 4),
                          Text(
                            'Delete',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: Colors.red.shade600,
                            ),
                          ),
                        ],
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

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.schedule_outlined,
              size: 64,
              color: Colors.grey.shade300,
            ),
            const SizedBox(height: 16),
            const Text(
              'No Recurring Payments',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: Color(0xFF1A1A2E),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Set up automatic payments for rent, utilities, and other regular expenses.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey.shade600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  double _calculateMonthlyTotal() {
    double total = 0.0;
    for (final expense in _recurringExpenses) {
      final config = expense.recurringConfig;
      if (config != null && config.interval != null) {
        final interval = config.interval!;
        if (interval == RecurringInterval.monthly) {
          total += expense.amount;
        } else if (interval == RecurringInterval.weekly) {
          total += expense.amount * 4.33; // Average weeks per month
        } else if (interval == RecurringInterval.yearly) {
          total += expense.amount / 12;
        }
      } else {
        // Default to monthly if no interval specified
        total += expense.amount;
      }
    }
    return total;
  }

  void _showRecurringPaymentDetails(ExpenseData expense) {
    // TODO: Show detailed recurring payment info
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Details for "${expense.title}" - Coming soon!'),
        backgroundColor: Colors.blue,
      ),
    );
  }

  void _editRecurringPayment(ExpenseData expense) {
    // TODO: Edit recurring payment
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Edit "${expense.title}" - Coming soon!'),
        backgroundColor: Colors.blue,
      ),
    );
  }

  void _pauseRecurringPayment(ExpenseData expense) {
    // TODO: Pause recurring payment
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Pause "${expense.title}" - Coming soon!'),
        backgroundColor: Colors.orange,
      ),
    );
  }

  void _deleteRecurringPayment(ExpenseData expense) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Delete Recurring Payment'),
        content: Text('Are you sure you want to delete "${expense.title}"? This will stop all future automatic payments.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              Navigator.pop(context);
              // TODO: Delete recurring payment
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('Delete "${expense.title}" - Coming soon!'),
                  backgroundColor: Colors.red,
                ),
              );
            },
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
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

  String _formatDate(DateTime date) {
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
    ];
    return '${months[date.month - 1]} ${date.day}';
  }
}