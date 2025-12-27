/// Models for balance calculations and settlements

/// Summary of balances for a roomspace
class BalanceSummary {
  final String roomspaceId;
  final double totalExpenses;
  final int expenseCount;
  final Map<String, double> userBalances; // userId -> balance (+ = owed, - = owes)
  final List<Map<String, dynamic>> members;
  final DateTime lastUpdated;

  BalanceSummary({
    required this.roomspaceId,
    required this.totalExpenses,
    required this.expenseCount,
    required this.userBalances,
    required this.members,
    required this.lastUpdated,
  });

  /// Gets users who are owed money (positive balance)
  Map<String, double> get creditors {
    return Map.fromEntries(
      userBalances.entries.where((entry) => entry.value > 0.01),
    );
  }

  /// Gets users who owe money (negative balance)
  Map<String, double> get debtors {
    return Map.fromEntries(
      userBalances.entries.where((entry) => entry.value < -0.01),
    );
  }

  /// Gets users with balanced accounts (near zero)
  Map<String, double> get balanced {
    return Map.fromEntries(
      userBalances.entries.where((entry) => entry.value.abs() <= 0.01),
    );
  }

  /// Total amount owed across all users
  double get totalOwed {
    return creditors.values.fold(0.0, (sum, amount) => sum + amount);
  }

  /// Average expense amount
  double get averageExpense {
    return expenseCount > 0 ? totalExpenses / expenseCount : 0.0;
  }
}

/// Detailed balance information for a specific user
class UserBalance {
  final String userId;
  final String roomspaceId;
  final double balance; // Positive = owed money, Negative = owes money
  final double totalPaid; // Total amount user has paid
  final double totalOwed; // Total amount user owes
  final int expenseCount; // Number of expenses user is involved in
  final DateTime lastUpdated;

  UserBalance({
    required this.userId,
    required this.roomspaceId,
    required this.balance,
    required this.totalPaid,
    required this.totalOwed,
    required this.expenseCount,
    required this.lastUpdated,
  });

  /// Whether user is owed money
  bool get isOwedMoney => balance > 0.01;

  /// Whether user owes money
  bool get owesMoney => balance < -0.01;

  /// Whether user's account is balanced
  bool get isBalanced => balance.abs() <= 0.01;

  /// Net contribution (paid - owed)
  double get netContribution => totalPaid - totalOwed;
}

/// Settlement suggestion between two users
class Settlement {
  final String fromUserId; // User who should pay
  final String fromUserName;
  final String toUserId; // User who should receive
  final String toUserName;
  final double amount;

  Settlement({
    required this.fromUserId,
    required this.fromUserName,
    required this.toUserId,
    required this.toUserName,
    required this.amount,
  });

  /// Description of the settlement
  String get description {
    return '$fromUserName should pay \$${amount.toStringAsFixed(2)} to $toUserName';
  }
}

/// Statistics about expenses in a roomspace
class ExpenseStats {
  final String roomspaceId;
  final double totalAmount;
  final int totalCount;
  final Map<String, double> categoryBreakdown; // category -> total amount
  final Map<String, int> categoryCounts; // category -> count
  final Map<String, double> monthlyTrends; // month -> total amount
  final double averageExpense;
  final DateTime lastUpdated;

  ExpenseStats({
    required this.roomspaceId,
    required this.totalAmount,
    required this.totalCount,
    required this.categoryBreakdown,
    required this.categoryCounts,
    required this.monthlyTrends,
    required this.averageExpense,
    required this.lastUpdated,
  });

  /// Most expensive category
  String get topCategory {
    if (categoryBreakdown.isEmpty) return 'None';
    return categoryBreakdown.entries
        .reduce((a, b) => a.value > b.value ? a : b)
        .key;
  }

  /// Most frequent category
  String get mostFrequentCategory {
    if (categoryCounts.isEmpty) return 'None';
    return categoryCounts.entries
        .reduce((a, b) => a.value > b.value ? a : b)
        .key;
  }

  /// Categories sorted by amount (descending)
  List<MapEntry<String, double>> get categoriesByAmount {
    final entries = categoryBreakdown.entries.toList();
    entries.sort((a, b) => b.value.compareTo(a.value));
    return entries;
  }

  /// Monthly trend data sorted by month (most recent first)
  List<MapEntry<String, double>> get monthlyTrendsSorted {
    final entries = monthlyTrends.entries.toList();
    entries.sort((a, b) => b.key.compareTo(a.key));
    return entries;
  }
}

/// Balance change event for tracking
class BalanceChange {
  final String userId;
  final String roomspaceId;
  final double previousBalance;
  final double newBalance;
  final double change;
  final String reason; // e.g., "Expense added", "Expense deleted"
  final DateTime timestamp;

  BalanceChange({
    required this.userId,
    required this.roomspaceId,
    required this.previousBalance,
    required this.newBalance,
    required this.change,
    required this.reason,
    required this.timestamp,
  });

  /// Whether this was a positive change (user's balance improved)
  bool get isPositiveChange => change > 0;

  /// Description of the change
  String get description {
    final changeAmount = change.abs().toStringAsFixed(2);
    if (isPositiveChange) {
      return 'Balance improved by \$${changeAmount} - $reason';
    } else {
      return 'Balance decreased by \$${changeAmount} - $reason';
    }
  }
}