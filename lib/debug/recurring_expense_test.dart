import 'package:flutter/material.dart';
import '../models/expense_models.dart';
import '../models/recurring_expense_models.dart';
import '../widgets/enhanced_expense_tile.dart';

/// Debug screen to test recurring expense display
class RecurringExpenseTestScreen extends StatelessWidget {
  const RecurringExpenseTestScreen({super.key});

  @override
  Widget build(BuildContext context) {
    // Create test expenses with different recurring configurations
    final testExpenses = [
      // Non-recurring expense
      ExpenseData(
        id: 1,
        title: 'Regular Grocery Shopping',
        amount: 150.0,
        description: 'Weekly groceries',
        category: 'Groceries',
        selectedRoommateIds: ['user1', 'user2'],
        splitType: SplitType.equal,
        customSplits: {},
        roomspaceId: 'test-roomspace',
        paidBy: 'user1',
        createdAt: DateTime.now(),
        recurringConfig: null, // No recurring config
      ),
      
      // Monthly recurring expense
      ExpenseData(
        id: 2,
        title: 'Monthly Rent Payment',
        amount: 1200.0,
        description: 'Monthly rent for apartment',
        category: 'Rent',
        selectedRoommateIds: ['user1', 'user2', 'user3'],
        splitType: SplitType.equal,
        customSplits: {},
        roomspaceId: 'test-roomspace',
        paidBy: 'user1',
        createdAt: DateTime.now(),
        recurringConfig: RecurringExpenseConfig(
          isRecurring: true,
          interval: RecurringInterval.monthly,
          startDate: DateTime.now(),
          endDate: null,
          maxOccurrences: null,
          notifyBeforeCreation: true,
          notificationDaysBefore: 3,
        ),
      ),
      
      // Weekly recurring expense
      ExpenseData(
        id: 3,
        title: 'Weekly Cleaning Service',
        amount: 80.0,
        description: 'Professional cleaning service',
        category: 'Utilities',
        selectedRoommateIds: ['user1', 'user2'],
        splitType: SplitType.equal,
        customSplits: {},
        roomspaceId: 'test-roomspace',
        paidBy: 'user2',
        createdAt: DateTime.now(),
        recurringConfig: RecurringExpenseConfig(
          isRecurring: true,
          interval: RecurringInterval.weekly,
          startDate: DateTime.now(),
          endDate: DateTime.now().add(const Duration(days: 90)), // 3 months
          maxOccurrences: null,
          notifyBeforeCreation: true,
          notificationDaysBefore: 1,
        ),
      ),
      
      // Yearly recurring expense
      ExpenseData(
        id: 4,
        title: 'Annual Insurance Premium',
        amount: 2400.0,
        description: 'Home insurance annual payment',
        category: 'Utilities',
        selectedRoommateIds: ['user1', 'user2', 'user3'],
        splitType: SplitType.percentage,
        customSplits: {'user1': 50.0, 'user2': 30.0, 'user3': 20.0},
        roomspaceId: 'test-roomspace',
        paidBy: 'user1',
        createdAt: DateTime.now(),
        recurringConfig: RecurringExpenseConfig(
          isRecurring: true,
          interval: RecurringInterval.yearly,
          startDate: DateTime.now(),
          endDate: null,
          maxOccurrences: 5, // 5 years
          notifyBeforeCreation: true,
          notificationDaysBefore: 7,
        ),
      ),
    ];

    return Scaffold(
      appBar: AppBar(
        title: const Text('Recurring Expense Test'),
        backgroundColor: Colors.blue.shade600,
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Test Expenses with Recurring Tags',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: Color(0xFF1A1A2E),
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'This screen tests the display of recurring expense tags. Check the console for debug logs.',
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey,
              ),
            ),
            const SizedBox(height: 24),
            
            // Display test expenses
            ...testExpenses.map((expense) {
              return Padding(
                padding: const EdgeInsets.only(bottom: 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Expense ID: ${expense.id} - ${expense.recurringConfig?.isRecurring == true ? 'RECURRING' : 'ONE-TIME'}',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: expense.recurringConfig?.isRecurring == true 
                            ? Colors.purple.shade700 
                            : Colors.grey.shade600,
                      ),
                    ),
                    const SizedBox(height: 4),
                    EnhancedExpenseTile(
                      expense: expense,
                      themeColor: Colors.blue.shade600,
                      isPersonal: false,
                      onUpdated: () {
                        debugPrint('🔄 Test expense updated: ${expense.title}');
                      },
                    ),
                  ],
                ),
              );
            }).toList(),
            
            const SizedBox(height: 32),
            
            // Debug information
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.grey.shade100,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.grey.shade300),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Debug Information',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    '• Check the console/logs for detailed recurring expense debug information',
                    style: TextStyle(fontSize: 14),
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    '• Purple "RECURRING" tags should appear on expenses 2, 3, and 4',
                    style: TextStyle(fontSize: 14),
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    '• Expense 1 should NOT have a recurring tag',
                    style: TextStyle(fontSize: 14),
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    '• Tap on any expense to see the options menu',
                    style: TextStyle(fontSize: 14),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}