import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'dart:developer';
import '../main.dart' show navigatorKey;
import '../models/payment_notification.dart';
import '../models/expense_models.dart';
import '../providers/roomspace_provider.dart';
import '../features/home/widgets/add_expense_dialog.dart';
import '../services/smart_api_service.dart';
import '../services/api_service.dart';

/// Service to handle payment detection dialogs and notifications
class PaymentDialogService {
  static BuildContext? _currentContext;
  static bool _isAppInForeground = true;
  
  /// Set the current context for showing dialogs
  static void setContext(BuildContext context) {
    _currentContext = context;
  }
  
  /// Set app foreground state
  static void setAppForegroundState(bool isInForeground) {
    _isAppInForeground = isInForeground;
    log('App foreground state changed: $isInForeground');
  }
  
  /// Show payment detection dialog or notification
  static Future<void> showPaymentDetected(PaymentNotification payment) async {
    log('Payment detected: ${payment.appName} - Rs. ${payment.amount}');
    log('App foreground state: $_isAppInForeground');
    log('Context available: ${_currentContext != null}');

    // Prefer in-app dialog whenever app has any active navigator context.
    // This is more reliable than tab-specific contexts.
    final navCtx = navigatorKey.currentContext;
    if (navCtx != null && navCtx.mounted) {
      setContext(navCtx);
      log('Showing in-app dialog using global navigator context');
      await _showInAppDialog(payment);
      return;
    }

    if (_isAppInForeground && _currentContext != null) {
      log('Showing in-app dialog for payment');
      await _showInAppDialog(payment);
      return;
    }

    // App is in background or no dialog context available.
    log('App in background or context unavailable, letting system notification handle it');
    throw Exception('App in background - use system notification');
  }
  
  /// Show in-app dialog for payment detection
  static Future<void> _showInAppDialog(PaymentNotification payment) async {
    if (_currentContext == null) {
      throw Exception('Payment dialog context unavailable');
    }
    
    final context = _currentContext!;
    if (!context.mounted) {
      throw Exception('Payment dialog context is not mounted');
    }
    final amount = payment.amount?.toStringAsFixed(0) ?? 'Unknown';
    final merchant = payment.merchant ?? payment.appName;
    
    try {
      // Use HapticFeedback for better UX
      HapticFeedback.mediumImpact();
      
      final result = await showDialog<bool>(
        context: context,
        barrierDismissible: false,
        builder: (context) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.green.shade100,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  Icons.payment_rounded,
                  color: Colors.green.shade700,
                  size: 24,
                ),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Text(
                  'Payment Detected',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
                ),
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.grey.shade50,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.grey.shade200),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          'Amount:',
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.grey.shade600,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const Spacer(),
                        Text(
                          'Rs. $amount',
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                            color: Colors.green,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Text(
                          'From:',
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.grey.shade600,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const Spacer(),
                        Text(
                          merchant,
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'Would you like to add this as an expense in RoomEase?',
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey.shade700,
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: Text(
                'Cancel',
                style: TextStyle(
                  color: Colors.grey.shade600,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            ElevatedButton.icon(
              onPressed: () => Navigator.pop(context, true),
              icon: const Icon(Icons.add_circle_outline, size: 18),
              label: const Text('Add Expense'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green.shade700,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              ),
            ),
          ],
        ),
      );
      
      if (result == true) {
        await _showExpenseDialog(payment);
      }
    } catch (e) {
      log('Error showing payment dialog: $e');
      // Bubble up to PaymentNotificationService so it can fallback
      // to system notification instead of silently dropping this event.
      rethrow;
    }
  }
  
  /// Show expense dialog with pre-filled data
  static Future<void> _showExpenseDialog(PaymentNotification payment) async {
    if (_currentContext == null) return;
    
    final context = _currentContext!;
    
    try {
      // Get roomspace provider
      final roomspaceProvider = Provider.of<RoomspaceProvider>(context, listen: false);
      final activeRoomspace = roomspaceProvider.activeRoomspace;
      
      if (activeRoomspace == null) {
        // Show error - no active roomspace
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Please select a roomspace first'),
            backgroundColor: Colors.orange,
          ),
        );
        return;
      }
      
      // Get roommates from API
      final apiService = ApiService();
      final roomspaceResponse = await apiService.getRoomspaces();
      
      if (roomspaceResponse['success'] != true || roomspaceResponse['data'] == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Failed to load roomspace data'),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }
      
      // Find the active roomspace in the response
      final roomspaces = roomspaceResponse['data'] as List<dynamic>;
      final activeRoomspaceData = roomspaces.firstWhere(
        (rs) => rs['id'] == activeRoomspace.id,
        orElse: () => null,
      );
      
      if (activeRoomspaceData == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Active roomspace not found'),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }
      
      // Extract roommates from the roomspace data
      final members = activeRoomspaceData['members'] as List<dynamic>? ?? [];
      final roommates = members
          .whereType<Map<String, dynamic>>()
          .map((member) {
            final memberData = member;
            final user = memberData['user'] as Map<String, dynamic>?;
            return RoommateItem(
              id: memberData['user_id'] as String? ?? '',
              name: user?['name'] as String? ?? user?['email'] as String? ?? 'Unknown',
            );
          })
          .where((roommate) => roommate.id.isNotEmpty)
          .toList();
      
      if (roommates.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('No roommates found in active roomspace'),
            backgroundColor: Colors.orange,
          ),
        );
        return;
      }
      
      // Show expense dialog with pre-filled data
      await AddExpenseDialog.show(
        context,
        roommates: roommates,
        roomspaceId: activeRoomspace.id,
        paymentNotification: payment,
        onSubmit: (expense) async {
          try {
            final smartApi = SmartApiService();
            final requests = ExpenseCreateRequest.fromExpenseDataBatch(expense, activeRoomspace.id);
            for (final request in requests) {
              await smartApi.createExpense(request.toJson());
            }
            final isRecurring = expense.recurringConfig?.isRecurring == true;
            if (isRecurring && requests.length > 1) {
              final apiService = ApiService();
              final payerAmounts = Map<String, double>.from(expense.payerAmounts)
                ..removeWhere((_, v) => v <= 0);
              final fallbackPayer = expense.paidBy ??
                  (expense.selectedRoommateIds.isNotEmpty ? expense.selectedRoommateIds.first : '');
              if (fallbackPayer.isNotEmpty && payerAmounts.isEmpty) {
                payerAmounts[fallbackPayer] = expense.amount;
              }
              await apiService.createRecurringExpenseTemplate({
                'roomspace_id': activeRoomspace.id,
                'title': expense.title,
                'description': expense.description,
                'amount': expense.amount,
                'category': expense.category,
                'paid_by': fallbackPayer,
                'payer_amounts': payerAmounts,
                'split_type': expense.splitType.apiValue,
                'selected_roommates': expense.selectedRoommateIds,
                'custom_splits': expense.customSplits,
                'recurring_config': expense.recurringConfig!.toJson(),
              });
            }
            
            if (context.mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('Added: ${expense.title} · Rs. ${expense.amount.toStringAsFixed(2)}'),
                  backgroundColor: Colors.green,
                ),
              );
            }
          } catch (e) {
            if (context.mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('Failed to add expense: $e'),
                  backgroundColor: Colors.red,
                ),
              );
            }
          }
        },
      );
    } catch (e) {
      log('Error showing expense dialog: $e');
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }
}
