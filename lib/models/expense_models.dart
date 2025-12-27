import 'package:flutter/material.dart';

// Enhanced ExpenseData model for API integration
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
  final DateTime? createdAt;
  final List<ExpenseSplit>? splits;
  final String? payerName;

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
    this.createdAt,
    this.splits,
    this.payerName,
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
      createdAt: json['created_at'] != null 
          ? DateTime.parse(json['created_at']) 
          : null,
      splits: json['splits'] != null
          ? (json['splits'] as List)
              .map((split) => ExpenseSplit.fromJson(split))
              .toList()
          : null,
      payerName: json['payer_name'],
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
  final String splitType;
  final List<String> selectedRoommates;
  final Map<String, double>? customSplits;

  ExpenseCreateRequest({
    required this.roomspaceId,
    required this.title,
    required this.description,
    required this.amount,
    required this.category,
    required this.splitType,
    required this.selectedRoommates,
    this.customSplits,
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
    
    if (customSplits != null && customSplits!.isNotEmpty) {
      json['custom_splits'] = customSplits!;
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
      splitType: expenseData.splitType.apiValue,
      selectedRoommates: expenseData.selectedRoommateIds,
      customSplits: expenseData.customSplits.isNotEmpty 
          ? expenseData.customSplits 
          : null,
    );
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