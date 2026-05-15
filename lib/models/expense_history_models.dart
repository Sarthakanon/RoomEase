import 'package:flutter/material.dart';

/// Types of expense history events
enum ExpenseHistoryType {
  expenseCreated,
  expenseEdited,
  expenseDeleted,
  paymentConfirmed,
  settlementMade,
  memberAdded,
  memberRemoved,
}

/// Expense history item model
class ExpenseHistoryItem {
  final String id;
  final ExpenseHistoryType type;
  final String title;
  final String description;
  final String performedBy;
  final String performedByName;
  final DateTime timestamp;
  final double? amount;
  final Map<String, dynamic>? metadata;

  ExpenseHistoryItem({
    required this.id,
    required this.type,
    required this.title,
    required this.description,
    required this.performedBy,
    required this.performedByName,
    required this.timestamp,
    this.amount,
    this.metadata,
  });

  factory ExpenseHistoryItem.fromJson(Map<String, dynamic> json) {
    return ExpenseHistoryItem(
      id: json['id']?.toString() ?? '',
      type: _parseType(json['type'] ?? ''),
      title: json['title'] ?? '',
      description: json['description'] ?? '',
      performedBy: json['performed_by'] ?? '',
      performedByName: json['performed_by_name'] ?? 'Unknown',
      timestamp: DateTime.parse(json['timestamp'] ?? DateTime.now().toIso8601String()),
      amount: json['amount']?.toDouble(),
      metadata: json['metadata'] as Map<String, dynamic>?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'type': type.name,
      'title': title,
      'description': description,
      'performed_by': performedBy,
      'performed_by_name': performedByName,
      'timestamp': timestamp.toIso8601String(),
      'amount': amount,
      'metadata': metadata,
    };
  }

  static ExpenseHistoryType _parseType(String type) {
    switch (type.toLowerCase()) {
      case 'expense_created':
        return ExpenseHistoryType.expenseCreated;
      case 'expense_edited':
        return ExpenseHistoryType.expenseEdited;
      case 'expense_deleted':
        return ExpenseHistoryType.expenseDeleted;
      case 'payment_confirmed':
        return ExpenseHistoryType.paymentConfirmed;
      case 'settlement_made':
        return ExpenseHistoryType.settlementMade;
      case 'member_added':
        return ExpenseHistoryType.memberAdded;
      case 'member_removed':
        return ExpenseHistoryType.memberRemoved;
      default:
        return ExpenseHistoryType.expenseCreated;
    }
  }

  /// Get icon for history type
  IconData get icon {
    switch (type) {
      case ExpenseHistoryType.expenseCreated:
        return Icons.add_circle_outline;
      case ExpenseHistoryType.expenseEdited:
        return Icons.edit_outlined;
      case ExpenseHistoryType.expenseDeleted:
        return Icons.delete_outline;
      case ExpenseHistoryType.paymentConfirmed:
        return Icons.check_circle_outline;
      case ExpenseHistoryType.settlementMade:
        return Icons.account_balance_wallet_outlined;
      case ExpenseHistoryType.memberAdded:
        return Icons.person_add_outlined;
      case ExpenseHistoryType.memberRemoved:
        return Icons.person_remove_outlined;
    }
  }

  /// Get color for history type
  Color get color {
    switch (type) {
      case ExpenseHistoryType.expenseCreated:
        return Colors.green;
      case ExpenseHistoryType.expenseEdited:
        return Colors.blue;
      case ExpenseHistoryType.expenseDeleted:
        return Colors.red;
      case ExpenseHistoryType.paymentConfirmed:
        return Colors.teal;
      case ExpenseHistoryType.settlementMade:
        return Colors.purple;
      case ExpenseHistoryType.memberAdded:
        return Colors.indigo;
      case ExpenseHistoryType.memberRemoved:
        return Colors.orange;
    }
  }

  /// Get display text for history type
  String get typeLabel {
    switch (type) {
      case ExpenseHistoryType.expenseCreated:
        return 'Created';
      case ExpenseHistoryType.expenseEdited:
        return 'Edited';
      case ExpenseHistoryType.expenseDeleted:
        return 'Deleted';
      case ExpenseHistoryType.paymentConfirmed:
        return 'Payment Confirmed';
      case ExpenseHistoryType.settlementMade:
        return 'Settlement';
      case ExpenseHistoryType.memberAdded:
        return 'Member Added';
      case ExpenseHistoryType.memberRemoved:
        return 'Member Removed';
    }
  }
}
