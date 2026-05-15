import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../../services/api_service.dart';
import '../../../services/smart_api_service.dart';
import '../../../models/expense_models.dart';
import '../../../models/balance_models.dart';

class BalanceBreakdownScreen extends StatefulWidget {
  final String roomspaceId;

  const BalanceBreakdownScreen({
    super.key,
    required this.roomspaceId,
  });

  @override
  State<BalanceBreakdownScreen> createState() => _BalanceBreakdownScreenState();
}

class _BalanceBreakdownScreenState extends State<BalanceBreakdownScreen> {
  final ApiService _apiService = ApiService();
  final SmartApiService _smartApi = SmartApiService();
  bool _isLoading = true;
  String? _error;
  
  List<ExpenseData> _allExpenses = [];
  List<Settlement> _settlements = [];
  String? _currentUserId;
  
  // Use backend calculated values from the same endpoint as dashboard
  double _youOwe = 0.0;
  double _youAreOwed = 0.0;
  double _yourBalance = 0.0;
  double _totalPaid = 0.0;
  double _settlementsReceived = 0.0;
  double _settlementsPaid = 0.0;

  @override
  void initState() {
    super.initState();
    _currentUserId = FirebaseAuth.instance.currentUser?.uid;
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      // Load balances from the same endpoint used by dashboard
      final balanceResponse = await _smartApi.getRoomspaceBalances(widget.roomspaceId);
      final balanceData = balanceResponse['data'] as Map<String, dynamic>? ?? {};
      _youOwe = (balanceData['you_owe'] as num?)?.toDouble() ?? 0.0;
      _youAreOwed = (balanceData['you_are_owed'] as num?)?.toDouble() ?? 0.0;
      _yourBalance = (balanceData['your_balance'] as num?)?.toDouble() ?? (_youAreOwed - _youOwe);

      // Load expenses for display
      final expensesResponse = await _apiService.getRecentExpenses(
        roomspaceId: widget.roomspaceId,
        limit: 1000,
      );

      // Load settlements for display
      final settlementsResponse = await _apiService.getSettlements(
        roomspaceId: widget.roomspaceId,
        limit: 100,
      );

      if (expensesResponse['success'] == true && expensesResponse['data'] != null) {
        _allExpenses = (expensesResponse['data'] as List)
            .map((e) => ExpenseData.fromJson(e))
            .toList();
      }

      if (settlementsResponse['success'] == true && settlementsResponse['data'] != null) {
        _settlements = (settlementsResponse['data'] as List)
            .map((s) => Settlement.fromJson(s))
            .toList();
      }

      _calculateSettlementTotals();

      setState(() => _isLoading = false);
    } catch (e) {
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  void _calculateSettlementTotals() {
    _settlementsReceived = 0.0;
    _settlementsPaid = 0.0;
    _totalPaid = 0.0;

    // Calculate settlement totals for display
    for (final settlement in _settlements) {
      if (settlement.toUserId == _currentUserId) {
        _settlementsReceived += settlement.amount;
      } else if (settlement.fromUserId == _currentUserId) {
        _settlementsPaid += settlement.amount;
      }
    }

    for (final expense in _allExpenses) {
      if (expense.paidBy == _currentUserId) {
        _totalPaid += expense.amount;
      }
    }
    
    // Debug logging
    print('=== BALANCE BREAKDOWN (Dashboard-aligned) ===');
    print('you_owe: $_youOwe');
    print('you_are_owed: $_youAreOwed');
    print('your_balance: $_yourBalance');
    print('Total Paid (from expenses): $_totalPaid');
    print('Settlements Paid: $_settlementsPaid');
    print('Settlements Received: $_settlementsReceived');
    print('==============================================');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded, color: Color(0xFF1A1A2E)),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Balance Breakdown',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: Color(0xFF1A1A2E),
          ),
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? _buildErrorState()
              : _buildContent(),
    );
  }

  Widget _buildContent() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildFinalBalanceCard(),
          const SizedBox(height: 24),
          _buildNetAdjustmentCard(),
          const SizedBox(height: 24),
          _buildCalculationSteps(),
          const SizedBox(height: 24),
          _buildExpensesList(),
          if (_settlements.isNotEmpty) ...[
            const SizedBox(height: 24),
            _buildSettlementsList(),
          ],
        ],
      ),
    );
  }

  Widget _buildNetAdjustmentCard() {
    final netPayable = (_youOwe - _youAreOwed).clamp(0.0, double.infinity);
    final netReceivable = (_youAreOwed - _youOwe).clamp(0.0, double.infinity);

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFFF7F7FB),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFEEEEF2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Mutual Adjustment (Overall)',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: Color(0xFF1A1A2E),
            ),
          ),
          const SizedBox(height: 14),
          _buildCalculationStep(
            'You Owe (raw total)',
            _youOwe,
            Colors.red.shade700,
            Icons.remove_circle_outline,
            isPositive: false,
          ),
          _buildCalculationStep(
            'You Are Owed (raw total)',
            _youAreOwed,
            Colors.green.shade700,
            Icons.add_circle_outline,
            isPositive: true,
          ),
          const SizedBox(height: 10),
          Divider(color: Colors.grey.shade300),
          const SizedBox(height: 10),
          Text(
            netPayable > 0
                ? 'Final payable after adjustment: Rs. ${netPayable.toStringAsFixed(0)}'
                : 'Final receivable after adjustment: Rs. ${netReceivable.toStringAsFixed(0)}',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w800,
              color: netPayable > 0 ? const Color(0xFFC62828) : const Color(0xFF2E7D32),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFinalBalanceCard() {
    final amountToPay = (_youOwe - _youAreOwed).clamp(0.0, double.infinity);
    final color = const Color(0xFFC62828);

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.red.shade50, Colors.red.shade100],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Column(
        children: [
          Text(
            'You Need to Pay',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: color,
            ),
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.currency_rupee, color: color, size: 32),
              Text(
                amountToPay.toStringAsFixed(2),
                style: TextStyle(
                  fontSize: 40,
                  fontWeight: FontWeight.w900,
                  color: color,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'Net after mutual adjustment',
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey.shade600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCalculationSteps() {
    final totalPaid = _totalPaid;
    final totalOwed = _youOwe;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFFF7F7FB),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFEEEEF2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.calculate_outlined, color: Colors.blue.shade700, size: 20),
              const SizedBox(width: 8),
              const Expanded(
                child: Text(
                  'How Your Balance is Calculated',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF1A1A2E),
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          _buildCalculationStep(
            'Total You Paid',
            totalPaid,
            Colors.green.shade700,
            Icons.add_circle_outline,
            isPositive: true,
          ),
          _buildCalculationStep(
            'Your Share of Expenses',
            totalOwed,
            Colors.red.shade700,
            Icons.remove_circle_outline,
            isPositive: false,
          ),
          if (_settlementsPaid > 0)
            _buildCalculationStep(
              'Settlements You Paid',
              _settlementsPaid,
              Colors.purple.shade700,
              Icons.add_circle_outline,
              isPositive: true,
            ),
          if (_settlementsReceived > 0)
            _buildCalculationStep(
              'Settlements Received',
              _settlementsReceived,
              Colors.orange.shade700,
              Icons.remove_circle_outline,
              isPositive: false,
            ),
        ],
      ),
    );
  }

  Widget _buildCalculationStep(
    String label,
    double amount,
    Color color,
    IconData icon, {
    required bool isPositive,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, size: 16, color: color),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              label,
              style: const TextStyle(
                fontSize: 12,
                color: Color(0xFF1A1A2E),
              ),
              overflow: TextOverflow.ellipsis,
              maxLines: 1,
            ),
          ),
          const SizedBox(width: 4),
          Text(
            '${isPositive ? '+' : '-'} ${amount.toStringAsFixed(0)}',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildExpensesList() {
    final expensesPaid = _allExpenses.where((e) => e.paidBy == _currentUserId).toList();
    final expensesOwed = _allExpenses.where((e) => e.paidBy != _currentUserId).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Expense Details',
          style: TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w700,
            color: Color(0xFF1A1A2E),
          ),
        ),
        const SizedBox(height: 12),
        if (expensesPaid.isNotEmpty) ...[
          _buildExpenseSection(
            'Expenses You Paid',
            expensesPaid,
            Colors.green.shade700,
            Icons.arrow_upward,
          ),
          const SizedBox(height: 16),
        ],
        if (expensesOwed.isNotEmpty)
          _buildExpenseSection(
            'Expenses Others Paid',
            expensesOwed,
            Colors.red.shade700,
            Icons.arrow_downward,
          ),
      ],
    );
  }

  Widget _buildExpenseSection(
    String title,
    List<ExpenseData> expenses,
    Color color,
    IconData icon,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, size: 16, color: color),
            const SizedBox(width: 8),
            Text(
              title,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: color,
              ),
            ),
            const SizedBox(width: 8),
            Text(
              '(${expenses.length})',
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey.shade500,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        ...expenses.map((expense) => _buildExpenseItem(expense, color)),
      ],
    );
  }

  Widget _buildExpenseItem(ExpenseData expense, Color color) {
    final mySplit = expense.splits?.firstWhere(
      (s) => s.userUid == _currentUserId,
      orElse: () => ExpenseSplit(userUid: '', amount: 0, userName: ''),
    );

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFEEEEF2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  expense.title,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF1A1A2E),
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                _formatDate(expense.createdAt),
                style: TextStyle(
                  fontSize: 10,
                  color: Colors.grey.shade400,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            'Total: Rs. ${expense.amount.toStringAsFixed(0)} • Your share: Rs. ${mySplit?.amount.toStringAsFixed(0) ?? '0'}',
            style: TextStyle(
              fontSize: 11,
              color: Colors.grey.shade500,
            ),
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  Widget _buildSettlementsList() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Settlements',
          style: TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w700,
            color: Color(0xFF1A1A2E),
          ),
        ),
        const SizedBox(height: 12),
        ..._settlements.map((settlement) => _buildSettlementItem(settlement)),
      ],
    );
  }

  Widget _buildSettlementItem(Settlement settlement) {
    final isReceived = settlement.toUserId == _currentUserId;
    final color = isReceived ? Colors.green.shade700 : Colors.orange.shade700;

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Row(
        children: [
          Icon(Icons.payments_outlined, size: 18, color: color),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  isReceived
                      ? '${settlement.fromUserName} paid you'
                      : 'You paid ${settlement.toUserName}',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: color,
                  ),
                ),
                if (settlement.createdAt != null)
                  Text(
                    _formatDate(settlement.createdAt!),
                    style: TextStyle(
                      fontSize: 10,
                      color: Colors.grey.shade500,
                    ),
                  ),
              ],
            ),
          ),
          Text(
            'Rs. ${settlement.amount.toStringAsFixed(0)}',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline, size: 64, color: Colors.grey.shade300),
            const SizedBox(height: 16),
            const Text(
              'Failed to Load Balance',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: Color(0xFF1A1A2E),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              _error ?? 'Unknown error',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 13, color: Colors.grey.shade500),
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: _loadData,
              child: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }

  String _formatDate(DateTime? date) {
    if (date == null) return '';
    final now = DateTime.now();
    final diff = now.difference(date);

    if (diff.inDays == 0) return 'Today';
    if (diff.inDays == 1) return 'Yesterday';
    if (diff.inDays < 7) return '${diff.inDays}d ago';

    const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    return '${months[date.month - 1]} ${date.day}';
  }
}
