import '../models/expense_models.dart';
import '../models/balance_models.dart';
import 'expense_service.dart';
import 'api_service.dart';

class BalanceService {
  static final BalanceService _instance = BalanceService._internal();
  factory BalanceService() => _instance;
  BalanceService._internal();

  final ExpenseService _expenseService = ExpenseService();
  final ApiService _apiService = ApiService();

  /// Calculates balance summary for a roomspace
  /// 
  /// Returns [BalanceSummary] with overall balance information
  Future<BalanceSummary> getRoomspaceBalanceSummary(String roomspaceId) async {
    try {
      // Get all expenses for the roomspace
      final response = await _expenseService.getRoomspaceExpenses(roomspaceId);
      final expenses = response.expenses;

      // Calculate balances
      final balances = _calculateBalances(expenses);
      
      // Get roomspace members for additional context
      final membersResponse = await _apiService.getRoomspaceMembers(roomspaceId);
      final members = membersResponse['success'] == true && membersResponse['data'] != null
          ? List<Map<String, dynamic>>.from(membersResponse['data'])
          : <Map<String, dynamic>>[];

      return BalanceSummary(
        roomspaceId: roomspaceId,
        totalExpenses: expenses.fold(0.0, (sum, expense) => sum + expense.amount),
        expenseCount: expenses.length,
        userBalances: balances,
        members: members,
        lastUpdated: DateTime.now(),
      );
    } catch (e) {
      throw Exception('Failed to calculate balance summary: ${e.toString()}');
    }
  }

  /// Calculates individual user balances from expenses
  /// 
  /// Returns a map of user ID to their balance (positive = owed money, negative = owes money)
  Map<String, double> _calculateBalances(List<ExpenseData> expenses) {
    final Map<String, double> balances = {};

    for (final expense in expenses) {
      if (expense.splits == null || expense.paidBy == null) continue;

      // Initialize payer balance if not exists
      balances[expense.paidBy!] ??= 0.0;

      // Payer gets credit for the full amount
      balances[expense.paidBy!] = (balances[expense.paidBy!] ?? 0.0) + expense.amount;

      // Each person in the split owes their portion
      for (final split in expense.splits!) {
        balances[split.userUid] ??= 0.0;
        balances[split.userUid] = (balances[split.userUid] ?? 0.0) - split.amount;
      }
    }

    return balances;
  }

  /// Gets detailed balance information between two users
  /// 
  /// Returns [UserBalance] with detailed breakdown
  Future<UserBalance> getUserBalance(String roomspaceId, String userId) async {
    try {
      final summary = await getRoomspaceBalanceSummary(roomspaceId);
      final userBalance = summary.userBalances[userId] ?? 0.0;
      
      // Get expenses where user was involved
      final response = await _expenseService.getRoomspaceExpenses(roomspaceId);
      final userExpenses = response.expenses.where((expense) {
        return expense.paidBy == userId || 
               (expense.splits?.any((split) => split.userUid == userId) ?? false);
      }).toList();

      // Calculate what user paid vs what they owe
      double totalPaid = 0.0;
      double totalOwed = 0.0;

      for (final expense in userExpenses) {
        if (expense.paidBy == userId) {
          totalPaid += expense.amount;
        }
        
        final userSplit = expense.splits?.firstWhere(
          (split) => split.userUid == userId,
          orElse: () => ExpenseSplit(userUid: '', userName: '', amount: 0),
        );
        
        if (userSplit != null && userSplit.amount > 0) {
          totalOwed += userSplit.amount;
        }
      }

      return UserBalance(
        userId: userId,
        roomspaceId: roomspaceId,
        balance: userBalance,
        totalPaid: totalPaid,
        totalOwed: totalOwed,
        expenseCount: userExpenses.length,
        lastUpdated: DateTime.now(),
      );
    } catch (e) {
      throw Exception('Failed to get user balance: ${e.toString()}');
    }
  }

  /// Calculates settlement suggestions to minimize transactions
  /// 
  /// Returns list of [Settlement] suggestions
  List<Settlement> calculateSettlements(Map<String, double> balances, List<Map<String, dynamic>> members) {
    final List<Settlement> settlements = [];
    
    // Separate creditors (positive balance) and debtors (negative balance)
    final creditors = <String, double>{};
    final debtors = <String, double>{};
    
    for (final entry in balances.entries) {
      if (entry.value > 0.01) { // Small threshold to avoid floating point issues
        creditors[entry.key] = entry.value;
      } else if (entry.value < -0.01) {
        debtors[entry.key] = -entry.value; // Make positive for easier calculation
      }
    }
    
    // Create settlements using greedy algorithm
    final creditorList = creditors.entries.toList();
    final debtorList = debtors.entries.toList();
    
    int creditorIndex = 0;
    int debtorIndex = 0;
    
    while (creditorIndex < creditorList.length && debtorIndex < debtorList.length) {
      final creditor = creditorList[creditorIndex];
      final debtor = debtorList[debtorIndex];
      
      final settlementAmount = [creditor.value, debtor.value].reduce((a, b) => a < b ? a : b);
      
      // Find member names
      final creditorName = _findMemberName(creditor.key, members);
      final debtorName = _findMemberName(debtor.key, members);
      
      settlements.add(Settlement(
        fromUserId: debtor.key,
        fromUserName: debtorName,
        toUserId: creditor.key,
        toUserName: creditorName,
        amount: settlementAmount,
      ));
      
      // Update remaining amounts
      creditorList[creditorIndex] = MapEntry(creditor.key, creditor.value - settlementAmount);
      debtorList[debtorIndex] = MapEntry(debtor.key, debtor.value - settlementAmount);
      
      // Move to next if current is settled
      if (creditorList[creditorIndex].value <= 0.01) {
        creditorIndex++;
      }
      if (debtorList[debtorIndex].value <= 0.01) {
        debtorIndex++;
      }
    }
    
    return settlements;
  }

  String _findMemberName(String userId, List<Map<String, dynamic>> members) {
    final member = members.firstWhere(
      (m) => (m['user_id'] ?? m['firebase_uid']) == userId,
      orElse: () => <String, dynamic>{},
    );
    return member['name'] ?? 'Unknown User';
  }

  /// Gets expense statistics for a roomspace
  /// 
  /// Returns [ExpenseStats] with category breakdown and trends
  Future<ExpenseStats> getExpenseStats(String roomspaceId) async {
    try {
      final response = await _expenseService.getRoomspaceExpenses(roomspaceId);
      final expenses = response.expenses;

      // Calculate category totals
      final Map<String, double> categoryTotals = {};
      final Map<String, int> categoryCounts = {};
      
      for (final expense in expenses) {
        categoryTotals[expense.category] = (categoryTotals[expense.category] ?? 0) + expense.amount;
        categoryCounts[expense.category] = (categoryCounts[expense.category] ?? 0) + 1;
      }

      // Calculate monthly trends (last 6 months)
      final now = DateTime.now();
      final Map<String, double> monthlyTotals = {};
      
      for (int i = 0; i < 6; i++) {
        final month = DateTime(now.year, now.month - i, 1);
        final monthKey = '${month.year}-${month.month.toString().padLeft(2, '0')}';
        monthlyTotals[monthKey] = 0.0;
      }
      
      for (final expense in expenses) {
        if (expense.createdAt != null) {
          final expenseMonth = expense.createdAt!;
          final monthKey = '${expenseMonth.year}-${expenseMonth.month.toString().padLeft(2, '0')}';
          if (monthlyTotals.containsKey(monthKey)) {
            monthlyTotals[monthKey] = monthlyTotals[monthKey]! + expense.amount;
          }
        }
      }

      return ExpenseStats(
        roomspaceId: roomspaceId,
        totalAmount: expenses.fold(0.0, (sum, expense) => sum + expense.amount),
        totalCount: expenses.length,
        categoryBreakdown: categoryTotals,
        categoryCounts: categoryCounts,
        monthlyTrends: monthlyTotals,
        averageExpense: expenses.isNotEmpty 
            ? expenses.fold(0.0, (sum, expense) => sum + expense.amount) / expenses.length
            : 0.0,
        lastUpdated: DateTime.now(),
      );
    } catch (e) {
      throw Exception('Failed to get expense statistics: ${e.toString()}');
    }
  }
}