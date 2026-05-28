import 'package:flutter/material.dart';
import 'recurring_expense_models.dart';

// Enhanced ExpenseData model for API integration
class RoommateItem {
  final String id;
  final String name;
  final String? email;

  RoommateItem({
    required this.id,
    required this.name,
    this.email,
  });
}

class ExpenseData {
  final String title;
  final double amount;
  final String description;
  final String category;
  final List<String> selectedRoommateIds;
  final SplitType splitType;
  final Map<String, double> customSplits;
  
  // New fields for API integration
  final int? id;
  final String? roomspaceId;  // Changed from int to String to support UUID
  final String? paidBy;
  final String? createdBy;
  final Map<String, double> payerAmounts;
  final DateTime? createdAt;
  final List<ExpenseSplit>? splits;
  final String? payerName;
  final RecurringExpenseConfig? recurringConfig;

  ExpenseData({
    required this.title,
    required this.amount,
    required this.description,
    required this.category,
    required this.selectedRoommateIds,
    required this.splitType,
    required this.customSplits,
    this.id,
    this.roomspaceId,
    this.paidBy,
    this.createdBy,
    this.payerAmounts = const {},
    this.createdAt,
    this.splits,
    this.payerName,
    this.recurringConfig,
  });

  // Factory constructor from API response
  factory ExpenseData.fromJson(Map<String, dynamic> json) {
    return ExpenseData(
      title: json['title'] ?? '',
      amount: (json['amount'] ?? 0.0).toDouble(),
      description: json['description'] ?? '',
      category: json['category'] ?? '',
      selectedRoommateIds: [], // Not needed for response data
      splitType: SplitType.fromString(json['split_type'] ?? 'EQUAL'),
      customSplits: {}, // Not needed for response data
      id: _parseIntSafely(json['id']),
      roomspaceId: json['roomspace_id']?.toString(),  // Handle as string for UUID support
      paidBy: json['paid_by'],
      createdBy: json['created_by'],
      payerAmounts: const {},
      createdAt: json['created_at'] != null 
          ? DateTime.parse(json['created_at']) 
          : null,
      splits: json['splits'] != null
          ? (json['splits'] as List)
              .map((split) => ExpenseSplit.fromJson(split))
              .toList()
          : null,
      payerName: json['payer_name'],
      recurringConfig: json['recurring_config'] != null
          ? RecurringExpenseConfig.fromJson(json['recurring_config'])
          : null,
    );
  }

  // Helper method to safely parse int from dynamic value
  static int? _parseIntSafely(dynamic value) {
    if (value == null) return null;
    if (value is int) return value;
    if (value is String) {
      return int.tryParse(value);
    }
    return null;
  }

  // Convert to JSON for API requests
  Map<String, dynamic> toJson() {
    return {
      'title': title,
      'amount': amount,
      'description': description,
      'category': category,
      'split_type': splitType.apiValue,
      'selected_roommates': selectedRoommateIds,
      if (customSplits.isNotEmpty) 'custom_splits': customSplits,
      if (recurringConfig != null) 'recurring_config': recurringConfig!.toJson(),
    };
  }
}

// ExpenseSplit model for API responses
class ExpenseSplit {
  final String userUid;
  final String userName;
  final double amount;
  final double? percentage;

  ExpenseSplit({
    required this.userUid,
    required this.userName,
    required this.amount,
    this.percentage,
  });

  factory ExpenseSplit.fromJson(Map<String, dynamic> json) {
    return ExpenseSplit(
      userUid: json['user_uid'] ?? '',
      userName: json['user_name'] ?? '',
      amount: (json['amount'] ?? 0.0).toDouble(),
      percentage: json['percentage']?.toDouble(),
    );
  }
}

// ExpenseCreateRequest model for API requests
class ExpenseCreateRequest {
  final String roomspaceId;  // Changed from int to String to support UUID
  final String title;
  final String description;
  final double amount;
  final String category;
  final String? paidBy;  // Who paid for this expense
  final String splitType;
  final List<String> selectedRoommates;
  final Map<String, double>? customSplits;
  final Map<String, double>? payerAmounts;
  final RecurringExpenseConfig? recurringConfig;

  ExpenseCreateRequest({
    required this.roomspaceId,
    required this.title,
    required this.description,
    required this.amount,
    required this.category,
    this.paidBy,
    required this.splitType,
    required this.selectedRoommates,
    this.customSplits,
    this.payerAmounts,
    this.recurringConfig,
  });

  Map<String, dynamic> toJson() {
    final json = {
      'roomspace_id': roomspaceId,
      'title': title,
      'description': description,
      'amount': amount,
      'category': category,
      'split_type': splitType,
      'selected_roommates': selectedRoommates,
    };
    
    if (paidBy != null) {
      json['paid_by'] = paidBy!;
    }
    
    if (customSplits != null && customSplits!.isNotEmpty) {
      json['custom_splits'] = customSplits!;
    }
    if (payerAmounts != null && payerAmounts!.isNotEmpty) {
      json['payer_amounts'] = payerAmounts!;
    }
    
    if (recurringConfig != null) {
      json['recurring_config'] = recurringConfig!.toJson();
    }
    
    return json;
  }

  // Factory constructor from ExpenseData
  factory ExpenseCreateRequest.fromExpenseData(
    ExpenseData expenseData,
    String roomspaceId,  // Changed from int to String
  ) {
    return ExpenseCreateRequest(
      roomspaceId: roomspaceId,
      title: expenseData.title,
      description: expenseData.description,
      amount: expenseData.amount,
      category: expenseData.category,
      paidBy: expenseData.paidBy,
      splitType: expenseData.splitType.apiValue,
      selectedRoommates: expenseData.selectedRoommateIds,
      customSplits: expenseData.customSplits.isNotEmpty 
          ? expenseData.customSplits 
          : null,
      payerAmounts: expenseData.payerAmounts.isNotEmpty ? expenseData.payerAmounts : null,
      recurringConfig: expenseData.recurringConfig,
    );
  }

  /// Builds one or more backend-compatible requests from an ExpenseData object.
  /// For multi-payer expenses, it creates proportional sub-expenses so balances remain exact.
  static List<ExpenseCreateRequest> fromExpenseDataBatch(
    ExpenseData expenseData,
    String roomspaceId,
  ) {
    final payerAmounts = Map<String, double>.from(expenseData.payerAmounts)
      ..removeWhere((_, amount) => amount <= 0);

    if (payerAmounts.isEmpty || payerAmounts.length == 1) {
      return [ExpenseCreateRequest.fromExpenseData(expenseData, roomspaceId)];
    }

    final participants = expenseData.selectedRoommateIds.toSet().toList();
    final participantSplits = _calculateParticipantSplits(expenseData, participants);
    final totalCents = (expenseData.amount * 100).round();

    final requests = <ExpenseCreateRequest>[];
    final payerEntries = payerAmounts.entries.toList();
    int assignedPayerCents = 0;

    for (int i = 0; i < payerEntries.length; i++) {
      final payer = payerEntries[i];
      int payerCents;
      if (i == payerEntries.length - 1) {
        payerCents = totalCents - assignedPayerCents;
      } else {
        payerCents = (payer.value * 100).round();
        assignedPayerCents += payerCents;
      }
      if (payerCents <= 0) continue;

      final payerAmount = payerCents / 100.0;
      final subSplits = _allocateProportionalSplit(participantSplits, payerCents);
      final customSplits = <String, double>{
        for (final entry in subSplits.entries) entry.key: entry.value / 100.0,
      };

      requests.add(
        ExpenseCreateRequest(
          roomspaceId: roomspaceId,
          title: payerEntries.length > 1
              ? '${expenseData.title} (${i + 1}/${payerEntries.length})'
              : expenseData.title,
          description: expenseData.description,
          amount: payerAmount,
          category: expenseData.category,
          paidBy: payer.key,
          splitType: SplitType.exact.apiValue,
          selectedRoommates: participants,
          customSplits: customSplits,
          recurringConfig: null,
        ),
      );
    }

    return requests.isEmpty
        ? [ExpenseCreateRequest.fromExpenseData(expenseData, roomspaceId)]
        : requests;
  }

  static Map<String, double> _calculateParticipantSplits(
    ExpenseData expenseData,
    List<String> participants,
  ) {
    if (participants.isEmpty) return const {};

    if (expenseData.splitType == SplitType.equal) {
      final totalCents = (expenseData.amount * 100).round();
      final base = totalCents ~/ participants.length;
      final remainder = totalCents % participants.length;
      final map = <String, double>{};
      for (int i = 0; i < participants.length; i++) {
        map[participants[i]] = (base + (i < remainder ? 1 : 0)) / 100.0;
      }
      return map;
    }

    if (expenseData.splitType == SplitType.percentage) {
      final map = <String, double>{};
      double allocated = 0;
      String? maxKey;
      double maxValue = -1;
      for (final uid in participants) {
        final p = expenseData.customSplits[uid] ?? 0;
        final amount = ((expenseData.amount * p / 100.0) * 100).round() / 100.0;
        map[uid] = amount;
        allocated += amount;
        if (amount > maxValue) {
          maxValue = amount;
          maxKey = uid;
        }
      }
      final diff = ((expenseData.amount - allocated) * 100).round() / 100.0;
      if (maxKey != null && diff.abs() > 0) {
        map[maxKey] = ((map[maxKey] ?? 0) + diff);
      }
      return map;
    }

    return {
      for (final uid in participants) uid: expenseData.customSplits[uid] ?? 0,
    };
  }

  static Map<String, int> _allocateProportionalSplit(
    Map<String, double> participantSplits,
    int totalCents,
  ) {
    final result = <String, int>{};
    final remainders = <MapEntry<String, double>>[];
    int assigned = 0;

    final totalBase = participantSplits.values.fold<double>(0, (a, b) => a + b);
    if (totalBase <= 0) return result;

    participantSplits.forEach((uid, splitAmount) {
      final exact = (splitAmount / totalBase) * totalCents;
      final base = exact.floor();
      result[uid] = base;
      assigned += base;
      remainders.add(MapEntry(uid, exact - base));
    });

    int remaining = totalCents - assigned;
    remainders.sort((a, b) => b.value.compareTo(a.value));
    int idx = 0;
    while (remaining > 0 && remainders.isNotEmpty) {
      final uid = remainders[idx % remainders.length].key;
      result[uid] = (result[uid] ?? 0) + 1;
      remaining--;
      idx++;
    }
    return result;
  }
}

// Enhanced SplitType enum with API integration
enum SplitType {
  equal('Equal', Icons.drag_handle, 'EQUAL'),
  percentage('Percentage', Icons.percent, 'PERCENTAGE'),
  exact('Exact', Icons.attach_money, 'EXACT');

  final String label;
  final IconData icon;
  final String apiValue;

  const SplitType(this.label, this.icon, this.apiValue);

  static SplitType fromString(String value) {
    switch (value.toUpperCase()) {
      case 'EQUAL':
        return SplitType.equal;
      case 'PERCENTAGE':
        return SplitType.percentage;
      case 'EXACT':
        return SplitType.exact;
      default:
        return SplitType.equal;
    }
  }
}

// ExpenseCategory model (keeping existing structure)
class ExpenseCategory {
  final String name;
  final IconData icon;

  ExpenseCategory(this.name, this.icon);
}

// Personal Expense Data model (simplified version without roommate splitting)
class PersonalExpenseData {
  final String title;
  final double amount;
  final String description;
  final String category;
  
  // Fields for API integration
  final int? id;
  final DateTime? createdAt;

  PersonalExpenseData({
    required this.title,
    required this.amount,
    required this.description,
    required this.category,
    this.id,
    this.createdAt,
  });

  // Factory constructor from API response
  factory PersonalExpenseData.fromJson(Map<String, dynamic> json) {
    return PersonalExpenseData(
      title: json['title'] ?? '',
      amount: (json['amount'] ?? 0.0).toDouble(),
      description: json['description'] ?? '',
      category: json['category'] ?? '',
      id: ExpenseData._parseIntSafely(json['id']),
      createdAt: json['created_at'] != null 
          ? DateTime.parse(json['created_at']) 
          : null,
    );
  }

  // Convert to JSON for API requests
  Map<String, dynamic> toJson() {
    return {
      'title': title,
      'amount': amount,
      'description': description,
      'category': category,
    };
  }
}

// Personal Expense Create Request model for API requests
class PersonalExpenseCreateRequest {
  final String title;
  final String description;
  final double amount;
  final String category;

  PersonalExpenseCreateRequest({
    required this.title,
    required this.description,
    required this.amount,
    required this.category,
  });

  Map<String, dynamic> toJson() {
    return {
      'title': title,
      'description': description,
      'amount': amount,
      'category': category,
    };
  }

  // Factory constructor from PersonalExpenseData
  factory PersonalExpenseCreateRequest.fromExpenseData(
    PersonalExpenseData expenseData,
  ) {
    return PersonalExpenseCreateRequest(
      title: expenseData.title,
      description: expenseData.description,
      amount: expenseData.amount,
      category: expenseData.category,
    );
  }
}
