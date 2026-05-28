import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:provider/provider.dart';
import '../models/expense_models.dart';
import '../models/recurring_expense_models.dart';
import '../features/home/widgets/add_expense_dialog.dart';
import '../features/home/widgets/personal_expense_dialog.dart';
import '../services/expense_service.dart';
import '../services/expense_history_service.dart';
import '../services/smart_api_service.dart';
import '../widgets/expense_details_dialog.dart';
import '../providers/roomspace_provider.dart';
import '../services/cached_api_service.dart';

/// Enhanced expense tile with recurring tags and edit functionality
class EnhancedExpenseTile extends StatelessWidget {
  final ExpenseData expense;
  final Color themeColor;
  final bool isPersonal;
  final VoidCallback? onUpdated;

  const EnhancedExpenseTile({
    super.key,
    required this.expense,
    required this.themeColor,
    this.isPersonal = false,
    this.onUpdated,
  });

  @override
  Widget build(BuildContext context) {
    final isRecurring = expense.recurringConfig?.isRecurring ?? false;
    
    // Enhanced debug logging for recurring status
    debugPrint('🔄 Enhanced Expense Tile Debug:');
    debugPrint('   - Title: "${expense.title}"');
    debugPrint('   - ID: ${expense.id}');
    debugPrint('   - Raw JSON recurring_config: ${expense.recurringConfig?.toJson()}');
    debugPrint('   - Is Recurring: $isRecurring');
    debugPrint('   - Config Interval: ${expense.recurringConfig?.interval?.label}');
    debugPrint('   - Config Start Date: ${expense.recurringConfig?.startDate}');
    
    // Force show recurring tag for testing (remove this later)
    final forceShowRecurring = expense.title.toLowerCase().contains('recurring') || 
                              expense.title.toLowerCase().contains('monthly') ||
                              expense.title.toLowerCase().contains('rent');
    
    debugPrint('   - Force Show Recurring (for testing): $forceShowRecurring');
    
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFEEEEF2)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: InkWell(
        onTap: () => _showExpenseOptions(context),
        borderRadius: BorderRadius.circular(14),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            children: [
              Row(
                children: [
                  // Icon container
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: themeColor.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(
                      _getIcon(expense.category),
                      color: themeColor,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 14),
                  
                  // Content
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                expense.title,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w700,
                                  fontSize: 14,
                                  color: Color(0xFF1A1A2E),
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            // Show recurring tag if expense is recurring OR for testing purposes
                            if (isRecurring || forceShowRecurring) ...[
                              const SizedBox(width: 8),
                              _buildRecurringTag(),
                            ],
                          ],
                        ),
                        const SizedBox(height: 2),
                        Text(
                          expense.category + 
                          (isPersonal ? '' : ' • ${expense.payerName ?? 'Self'}'),
                          style: TextStyle(
                            fontSize: 11,
                            color: Colors.grey.shade500,
                          ),
                        ),
                      ],
                    ),
                  ),
                  
                  // Amount and date
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        'Rs. ${expense.amount.toStringAsFixed(0)}',
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 14,
                          color: themeColor,
                        ),
                      ),
                      if (expense.createdAt != null)
                        Text(
                          _formatDate(expense.createdAt!),
                          style: TextStyle(
                            fontSize: 10,
                            color: Colors.grey.shade400,
                          ),
                        ),
                    ],
                  ),
                ],
              ),
              
              // Recurring info (if applicable)
              if (isRecurring && expense.recurringConfig != null)
                _buildRecurringInfo(expense.recurringConfig!),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildRecurringTag() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.purple.shade600,
        borderRadius: BorderRadius.circular(6),
        boxShadow: [
          BoxShadow(
            color: Colors.purple.shade200,
            blurRadius: 4,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.repeat_rounded,
            size: 12,
            color: Colors.white,
          ),
          const SizedBox(width: 4),
          Text(
            'RECURRING',
            style: TextStyle(
              fontSize: 9,
              fontWeight: FontWeight.w800,
              color: Colors.white,
              letterSpacing: 0.5,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRecurringInfo(RecurringExpenseConfig config) {
    return Container(
      margin: const EdgeInsets.only(top: 8),
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: Colors.purple.shade50,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.purple.shade100, width: 0.5),
      ),
      child: Row(
        children: [
          Icon(
            Icons.schedule_rounded,
            size: 12,
            color: Colors.purple.shade600,
          ),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              'Repeats ${config.interval?.label.toLowerCase() ?? 'monthly'}${config.endDate != null 
                  ? ' until ${_formatDate(config.endDate!)}'
                  : config.maxOccurrences != null
                      ? ' for ${config.maxOccurrences} times'
                      : ''}',
              style: TextStyle(
                fontSize: 10,
                color: Colors.purple.shade700,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showExpenseOptions(BuildContext context) {
    // Get current user
    final currentUser = FirebaseAuth.instance.currentUser;
    final isCreator = currentUser != null &&
        (expense.paidBy == currentUser.uid || expense.createdBy == currentUser.uid);
    
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Handle bar
            Container(
              width: 36,
              height: 4,
              margin: const EdgeInsets.symmetric(vertical: 12),
              decoration: BoxDecoration(
                color: Colors.grey.shade300,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            
            // Title
            Padding(
              padding: const EdgeInsets.all(16),
              child: Text(
                expense.title,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                ),
                textAlign: TextAlign.center,
              ),
            ),
            
            // View Details - Always available
            ListTile(
              leading: Icon(Icons.visibility_rounded, color: themeColor),
              title: const Text('View Details'),
              onTap: () {
                Navigator.pop(context);
                _viewExpenseDetails(context);
              },
            ),
            
            // Edit - Only for creator
            if (isCreator || isPersonal) ...[
              ListTile(
                leading: Icon(Icons.edit_rounded, color: Colors.blue.shade600),
                title: const Text('Edit Expense'),
                onTap: () {
                  Navigator.pop(context);
                  _editExpense(context);
                },
              ),
            ],
            
            // Delete - Only for creator
            if (isCreator || isPersonal) ...[
              ListTile(
                leading: Icon(Icons.delete_outline_rounded, color: Colors.red.shade600),
                title: const Text('Delete Expense'),
                onTap: () {
                  Navigator.pop(context);
                  _confirmDeletion(context);
                },
              ),
            ],
            
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  void _viewExpenseDetails(BuildContext context) {
    ExpenseDetailsDialog.show(
      context,
      expense: expense,
      isPersonal: isPersonal,
    );
  }

  void _editExpense(BuildContext context) {
    debugPrint('🔧 Edit expense called for: ${expense.title}');
    debugPrint('🔧 Is personal: $isPersonal');
    debugPrint('🔧 Expense ID: ${expense.id}');
    
    if (isPersonal) {
      _editPersonalExpense(context);
    } else {
      _editSharedExpense(context);
    }
  }

  void _editPersonalExpense(BuildContext context) {
    // Convert ExpenseData to PersonalExpenseData for editing
    final personalExpenseData = PersonalExpenseData(
      id: expense.id,
      title: expense.title,
      amount: expense.amount,
      description: expense.description,
      category: expense.category,
      createdAt: expense.createdAt,
    );

    PersonalExpenseDialog.show(
      context,
      initialData: personalExpenseData,
      onSubmit: (updatedExpense) async {
        try {
          // TODO: Implement personal expense update API
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Personal expense editing coming soon!'),
              backgroundColor: Colors.orange,
            ),
          );
          return;
        } catch (e) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Failed to update expense: $e'),
              backgroundColor: Colors.red,
            ),
          );
        }
      },
    );
  }

  void _editSharedExpense(BuildContext context) async {
    try {
      // Debug: Print expense information
      debugPrint('🔧 Editing expense: ${expense.title}');
      debugPrint('🔧 Expense roomspace ID: ${expense.roomspaceId}');
      
      // Use the expense's roomspace ID, or fall back to current active roomspace
      String? roomspaceId = expense.roomspaceId;
      
      if (roomspaceId == null) {
        debugPrint('🔧 No roomspace ID in expense, using current active roomspace');
        final roomspaceProvider = Provider.of<RoomspaceProvider>(context, listen: false);
        roomspaceId = roomspaceProvider.getActiveRoomspaceId();
        
        if (roomspaceId == null) {
          debugPrint('❌ No active roomspace available');
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Unable to edit expense: No active roomspace')),
          );
          return;
        }
      }

      debugPrint('🔧 Using roomspace ID: $roomspaceId');
      debugPrint('🔧 Loading roomspaces...');
      final cachedApiService = CachedApiService();
      final res = await cachedApiService.getRoomspaces();
      
      debugPrint('🔧 Available roomspaces: ${(res['data'] as List).map((r) => r['id']).toList()}');
      
      // Find the roomspace that matches the roomspace ID
      final roomspaceData = (res['data'] as List).cast<Map<String, dynamic>>().firstWhere(
        (r) => r['id'].toString() == roomspaceId,
        orElse: () => <String, dynamic>{},
      );
      
      if (roomspaceData.isEmpty) {
        debugPrint('❌ Roomspace not found for ID: $roomspaceId');
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Unable to edit expense: Roomspace not found')),
        );
        return;
      }
      
      debugPrint('✅ Found roomspace: ${roomspaceData['name']}');
      
      final roommates = (roomspaceData['members'] as List).map((m) => RoommateItem(
        id: m['user_id'] ?? '',
        name: m['user']?['name'] ?? m['user']?['email'] ?? 'Unknown',
        email: m['user']?['email'],
      )).toList();

      debugPrint('🔧 Roommates: ${roommates.map((r) => r.name).toList()}');

      // Show add expense dialog with pre-filled data for editing
      AddExpenseDialog.show(
        context,
        roommates: roommates,
        roomspaceId: roomspaceId,
        initialData: expense, // Pass existing expense data
        onSubmit: (updatedExpense) async {
          try {
            debugPrint('🔧 Updating expense...');
            
            // Ensure we have a valid roomspace ID
            final validRoomspaceId = roomspaceId ?? expense.roomspaceId;
            if (validRoomspaceId == null) {
              debugPrint('❌ No valid roomspace ID available for expense update');
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Unable to update expense: No roomspace ID')),
              );
              return;
            }
            
            // Update expense via API
            final updateRequest = ExpenseCreateRequest.fromExpenseData(
              updatedExpense,
              validRoomspaceId,
            );
            
            await SmartApiService().updateExpense(expense.id!, updateRequest.toJson());

            if (onUpdated != null) onUpdated!();
            
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Expense updated successfully! Teammates have been notified.'),
                backgroundColor: Colors.green,
              ),
            );
          } catch (e) {
            debugPrint('❌ Failed to update expense: $e');
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Failed to update expense: $e'),
                backgroundColor: Colors.red,
              ),
            );
          }
        },
      );
    } catch (e) {
      debugPrint('❌ Error in _editSharedExpense: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to load expense data: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void _confirmDeletion(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Icon(Icons.warning_rounded, color: Colors.orange.shade600),
            const SizedBox(width: 12),
            const Text('Delete Expense'),
          ],
        ),
        content: Text(
          'Are you sure you want to delete "${expense.title}"?\n\nThis action cannot be undone.',
          style: const TextStyle(fontSize: 16),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              Navigator.pop(context);
              _performDeletion(context);
            },
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  void _performDeletion(BuildContext context) async {
    try {
      // Check if expense has an ID
      if (expense.id == null) {
        _showErrorDialog(
          context,
          'Cannot Delete',
          'Expense ID is missing. Please try again.',
        );
        return;
      }
      
      // Get current user
      final currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser == null) {
        _showErrorDialog(
          context,
          'Authentication Required',
          'Please login to delete expenses.',
        );
        return;
      }
      
      // Delete the expense
      await ExpenseService().deleteExpense(expense.id!);
      
      // Log the deletion to history (if roomspace expense)
      if (expense.roomspaceId != null) {
        try {
          final ExpenseHistoryService historyService = ExpenseHistoryService();
          await historyService.logExpenseDeleted(
            roomspaceId: expense.roomspaceId!,
            expenseId: expense.id.toString(),
            title: expense.title,
            amount: expense.amount,
            deletedBy: currentUser.uid,
          );
        } catch (e) {
          debugPrint('Failed to log deletion to history: $e');
        }
      }
      
      // If successful, show success message and refresh
      if (onUpdated != null) onUpdated!();
      
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Expense deleted successfully'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      _showErrorDialog(
        context,
        'Deletion Failed',
        'Failed to delete expense: ${e.toString().replaceAll('Exception: ', '')}',
      );
    }
  }

  void _showErrorDialog(BuildContext context, String title, String message) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Icon(Icons.error_outline, color: Colors.red.shade600, size: 28),
            const SizedBox(width: 12),
            Text(title),
          ],
        ),
        content: Text(
          message,
          style: const TextStyle(fontSize: 16, height: 1.5),
        ),
        actions: [
          FilledButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK'),
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
    final now = DateTime.now();
    final difference = now.difference(date);
    
    if (difference.inDays == 0) return 'Today';
    if (difference.inDays == 1) return 'Yesterday';
    if (difference.inDays < 7) return '${difference.inDays}d ago';
    
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
    ];
    return '${months[date.month - 1]} ${date.day}';
  }
}
