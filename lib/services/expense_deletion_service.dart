import 'dart:async';
import 'package:flutter/foundation.dart';
import '../models/expense_models.dart';
import 'real_time_data_service.dart';
import 'api_service.dart';

/// Service for managing expense deletion with approval workflow
class ExpenseDeletionService {
  static final ExpenseDeletionService _instance = ExpenseDeletionService._internal();
  factory ExpenseDeletionService() => _instance;
  ExpenseDeletionService._internal();

  final ApiService _apiService = ApiService();
  final RealTimeDataService _realTimeService = RealTimeDataService();

  // Stream controllers for deletion events
  final StreamController<DeletionRequestEvent> _deletionRequests = StreamController<DeletionRequestEvent>.broadcast();
  final StreamController<DeletionApprovalEvent> _deletionApprovals = StreamController<DeletionApprovalEvent>.broadcast();

  // Getters for streams
  Stream<DeletionRequestEvent> get deletionRequests => _deletionRequests.stream;
  Stream<DeletionApprovalEvent> get deletionApprovals => _deletionApprovals.stream;

  /// Request deletion of an expense (soft delete with approval workflow)
  Future<void> requestExpenseDeletion({
    required ExpenseData expense,
    required String requestedBy,
    required String reason,
  }) async {
    try {
      debugPrint('🗑️ Requesting deletion for expense: ${expense.title}');
      
      // Validate required fields
      if (expense.id == null) {
        throw Exception('Expense ID is required for deletion');
      }
      if (expense.roomspaceId == null) {
        throw Exception('Roomspace ID is required for deletion');
      }
      
      // Get all affected users from the expense splits
      final affectedUsers = <String>{};
      if (expense.splits != null) {
        affectedUsers.addAll(expense.splits!.map((s) => s.userUid));
      }
      if (expense.paidBy != null) {
        affectedUsers.add(expense.paidBy!);
      }

      // Create deletion request
      final deletionRequest = DeletionRequest(
        expenseId: expense.id!,
        expenseTitle: expense.title,
        expenseAmount: expense.amount,
        roomspaceId: expense.roomspaceId!,
        requestedBy: requestedBy,
        reason: reason,
        affectedUsers: affectedUsers.toList(),
        requestedAt: DateTime.now(),
        status: DeletionStatus.pending,
      );

      // Send to backend (you'll need to implement this endpoint)
      await _apiService.post('/api/expenses/${expense.id}/deletion-request', data: {
        'reason': reason,
        'affected_users': affectedUsers.toList(),
      });

      // Notify all affected users
      _deletionRequests.add(DeletionRequestEvent(
        request: deletionRequest,
        type: DeletionRequestType.created,
      ));

      // Send notifications to affected users
      for (final userId in affectedUsers) {
        if (userId != requestedBy) {
          _realTimeService.sendNotification(
            type: NotificationType.expenseUpdated,
            userId: userId,
            roomspaceId: expense.roomspaceId,
            message: 'Deletion requested for "${expense.title}" - Please approve or reject',
            data: {
              'deletion_request_id': deletionRequest.id,
              'expense_id': expense.id,
              'requested_by': requestedBy,
              'reason': reason,
            },
          );
        }
      }

      debugPrint('🗑️ Deletion request sent to ${affectedUsers.length} users');
    } catch (e) {
      debugPrint('❌ Error requesting expense deletion: $e');
      throw Exception('Failed to request expense deletion: $e');
    }
  }

  /// Approve or reject a deletion request
  Future<void> respondToDeletionRequest({
    required String deletionRequestId,
    required String userId,
    required bool approved,
    String? comment,
  }) async {
    try {
      debugPrint('🗑️ User $userId ${approved ? 'approved' : 'rejected'} deletion request $deletionRequestId');

      // Send response to backend
      await _apiService.post('/api/deletion-requests/$deletionRequestId/respond', data: {
        'approved': approved,
        'comment': comment,
      });

      // Notify about the response
      _deletionApprovals.add(DeletionApprovalEvent(
        requestId: deletionRequestId,
        userId: userId,
        approved: approved,
        comment: comment,
        respondedAt: DateTime.now(),
      ));

    } catch (e) {
      debugPrint('❌ Error responding to deletion request: $e');
      throw Exception('Failed to respond to deletion request: $e');
    }
  }

  /// Get pending deletion requests for a user
  Future<List<DeletionRequest>> getPendingDeletionRequests(String userId) async {
    try {
      final response = await _apiService.get('/api/deletion-requests/pending?user_id=$userId');
      
      if (response['success'] == true && response['data'] != null) {
        final List<dynamic> requestsData = response['data'];
        return requestsData.map((data) => DeletionRequest.fromJson(data)).toList();
      }
      
      return [];
    } catch (e) {
      debugPrint('❌ Error getting pending deletion requests: $e');
      return [];
    }
  }

  /// Get deletion history for a roomspace
  Future<List<DeletionHistoryItem>> getDeletionHistory(String roomspaceId) async {
    try {
      final response = await _apiService.get('/api/roomspaces/$roomspaceId/deletion-history');
      
      if (response['success'] == true && response['data'] != null) {
        final List<dynamic> historyData = response['data'];
        return historyData.map((data) => DeletionHistoryItem.fromJson(data)).toList();
      }
      
      return [];
    } catch (e) {
      debugPrint('❌ Error getting deletion history: $e');
      return [];
    }
  }

  /// Recover a soft-deleted expense
  Future<void> recoverExpense(String expenseId, String recoveredBy) async {
    try {
      debugPrint('🔄 Recovering expense: $expenseId');

      await _apiService.post('/api/expenses/$expenseId/recover', data: {
        'recovered_by': recoveredBy,
      });

      // Notify about recovery
      _realTimeService.notifyExpenseCreated('', {'recovered': true, 'expense_id': expenseId});

      debugPrint('✅ Expense recovered successfully');
    } catch (e) {
      debugPrint('❌ Error recovering expense: $e');
      throw Exception('Failed to recover expense: $e');
    }
  }

  void dispose() {
    _deletionRequests.close();
    _deletionApprovals.close();
  }
}

/// Deletion request model
class DeletionRequest {
  final String? id;
  final int expenseId;
  final String expenseTitle;
  final double expenseAmount;
  final String roomspaceId;
  final String requestedBy;
  final String reason;
  final List<String> affectedUsers;
  final DateTime requestedAt;
  final DeletionStatus status;
  final List<DeletionApproval> approvals;

  DeletionRequest({
    this.id,
    required this.expenseId,
    required this.expenseTitle,
    required this.expenseAmount,
    required this.roomspaceId,
    required this.requestedBy,
    required this.reason,
    required this.affectedUsers,
    required this.requestedAt,
    required this.status,
    this.approvals = const [],
  });

  factory DeletionRequest.fromJson(Map<String, dynamic> json) {
    return DeletionRequest(
      id: json['id']?.toString(),
      expenseId: json['expense_id'],
      expenseTitle: json['expense_title'] ?? '',
      expenseAmount: (json['expense_amount'] ?? 0.0).toDouble(),
      roomspaceId: json['roomspace_id'] ?? '',
      requestedBy: json['requested_by'] ?? '',
      reason: json['reason'] ?? '',
      affectedUsers: List<String>.from(json['affected_users'] ?? []),
      requestedAt: DateTime.parse(json['requested_at']),
      status: DeletionStatus.fromString(json['status'] ?? 'pending'),
      approvals: (json['approvals'] as List<dynamic>? ?? [])
          .map((a) => DeletionApproval.fromJson(a))
          .toList(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'expense_id': expenseId,
      'expense_title': expenseTitle,
      'expense_amount': expenseAmount,
      'roomspace_id': roomspaceId,
      'requested_by': requestedBy,
      'reason': reason,
      'affected_users': affectedUsers,
      'requested_at': requestedAt.toUtc().toIso8601String(),
      'status': status.value,
      'approvals': approvals.map((a) => a.toJson()).toList(),
    };
  }

  /// Check if all affected users have responded
  bool get isFullyResponded {
    final respondedUsers = approvals.map((a) => a.userId).toSet();
    return affectedUsers.every((user) => respondedUsers.contains(user));
  }

  /// Check if all responses are approvals
  bool get isFullyApproved {
    return isFullyResponded && approvals.every((a) => a.approved);
  }
}

/// Deletion approval model
class DeletionApproval {
  final String userId;
  final String userName;
  final bool approved;
  final String? comment;
  final DateTime respondedAt;

  DeletionApproval({
    required this.userId,
    required this.userName,
    required this.approved,
    this.comment,
    required this.respondedAt,
  });

  factory DeletionApproval.fromJson(Map<String, dynamic> json) {
    return DeletionApproval(
      userId: json['user_id'] ?? '',
      userName: json['user_name'] ?? '',
      approved: json['approved'] ?? false,
      comment: json['comment'],
      respondedAt: DateTime.parse(json['responded_at']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'user_id': userId,
      'user_name': userName,
      'approved': approved,
      'comment': comment,
      'responded_at': respondedAt.toUtc().toIso8601String(),
    };
  }
}

/// Deletion history item
class DeletionHistoryItem {
  final String expenseTitle;
  final double expenseAmount;
  final String deletedBy;
  final DateTime deletedAt;
  final String reason;
  final bool canRecover;
  final String? expenseId;

  DeletionHistoryItem({
    required this.expenseTitle,
    required this.expenseAmount,
    required this.deletedBy,
    required this.deletedAt,
    required this.reason,
    this.canRecover = true,
    this.expenseId,
  });

  factory DeletionHistoryItem.fromJson(Map<String, dynamic> json) {
    return DeletionHistoryItem(
      expenseTitle: json['expense_title'] ?? '',
      expenseAmount: (json['expense_amount'] ?? 0.0).toDouble(),
      deletedBy: json['deleted_by'] ?? '',
      deletedAt: DateTime.parse(json['deleted_at']),
      reason: json['reason'] ?? '',
      canRecover: json['can_recover'] ?? true,
      expenseId: json['expense_id']?.toString(),
    );
  }
}

/// Deletion status enum
enum DeletionStatus {
  pending('pending'),
  approved('approved'),
  rejected('rejected'),
  completed('completed');

  const DeletionStatus(this.value);
  final String value;

  static DeletionStatus fromString(String value) {
    return DeletionStatus.values.firstWhere(
      (status) => status.value == value,
      orElse: () => DeletionStatus.pending,
    );
  }
}

/// Deletion request event types
enum DeletionRequestType {
  created,
  updated,
  completed,
}

/// Deletion request event
class DeletionRequestEvent {
  final DeletionRequest request;
  final DeletionRequestType type;

  DeletionRequestEvent({
    required this.request,
    required this.type,
  });
}

/// Deletion approval event
class DeletionApprovalEvent {
  final String requestId;
  final String userId;
  final bool approved;
  final String? comment;
  final DateTime respondedAt;

  DeletionApprovalEvent({
    required this.requestId,
    required this.userId,
    required this.approved,
    this.comment,
    required this.respondedAt,
  });
}