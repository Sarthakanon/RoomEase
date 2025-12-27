import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:room_ease/models/balance_models.dart';
import 'package:room_ease/services/balance_service.dart';
import 'package:room_ease/services/api_service.dart';

class BalanceScreen extends StatefulWidget {
  final String roomspaceId;
  final String roomspaceName;

  const BalanceScreen({
    super.key,
    required this.roomspaceId,
    required this.roomspaceName,
  });

  @override
  State<BalanceScreen> createState() => _BalanceScreenState();
}

class _BalanceScreenState extends State<BalanceScreen> with TickerProviderStateMixin {
  final BalanceService _balanceService = BalanceService();
  final ApiService _apiService = ApiService();
  
  late TabController _tabController;
  
  BalanceSummary? _balanceSummary;
  UserBalance? _userBalance;
  ExpenseStats? _expenseStats;
  List<Settlement>? _settlements;
  
  bool _isLoading = true;
  bool _hasError = false;
  String _errorMessage = '';

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _loadBalanceData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadBalanceData() async {
    setState(() {
      _isLoading = true;
      _hasError = false;
    });

    try {
      final currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser == null) {
        throw Exception('User not authenticated');
      }

      // Load all balance data in parallel
      final results = await Future.wait([
        _balanceService.getRoomspaceBalanceSummary(widget.roomspaceId),
        _balanceService.getUserBalance(widget.roomspaceId, currentUser.uid),
        _balanceService.getExpenseStats(widget.roomspaceId),
      ]);

      final balanceSummary = results[0] as BalanceSummary;
      final userBalance = results[1] as UserBalance;
      final expenseStats = results[2] as ExpenseStats;

      // Calculate settlements
      final settlements = _balanceService.calculateSettlements(
        balanceSummary.userBalances,
        balanceSummary.members,
      );

      setState(() {
        _balanceSummary = balanceSummary;
        _userBalance = userBalance;
        _expenseStats = expenseStats;
        _settlements = settlements;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
        _hasError = true;
        _errorMessage = e.toString();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('${widget.roomspaceName} Balance'),
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: 'Overview', icon: Icon(Icons.account_balance_wallet)),
            Tab(text: 'Settlements', icon: Icon(Icons.swap_horiz)),
            Tab(text: 'Statistics', icon: Icon(Icons.bar_chart)),
          ],
        ),
        actions: [
          IconButton(
            onPressed: _loadBalanceData,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _hasError
              ? _buildErrorState()
              : TabBarView(
                  controller: _tabController,
                  children: [
                    _buildOverviewTab(),
                    _buildSettlementsTab(),
                    _buildStatisticsTab(),
                  ],
                ),
    );
  }

  Widget _buildErrorState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.error_outline,
              size: 64,
              color: Colors.grey[400],
            ),
            const SizedBox(height: 16),
            Text(
              'Failed to load balance data',
              style: TextStyle(
                fontSize: 18,
                color: Colors.grey[600],
              ),
            ),
            const SizedBox(height: 8),
            Text(
              _errorMessage,
              style: TextStyle(
                color: Colors.grey[500],
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _loadBalanceData,
              child: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildOverviewTab() {
    if (_balanceSummary == null || _userBalance == null) {
      return const Center(child: Text('No balance data available'));
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildUserBalanceCard(),
          const SizedBox(height: 16),
          _buildRoomspaceOverviewCard(),
          const SizedBox(height: 16),
          _buildAllBalancesCard(),
        ],
      ),
    );
  }

  Widget _buildUserBalanceCard() {
    final userBalance = _userBalance!;
    final isOwed = userBalance.isOwedMoney;
    final owes = userBalance.owesMoney;
    final isBalanced = userBalance.isBalanced;

    Color cardColor;
    IconData icon;
    String statusText;

    if (isOwed) {
      cardColor = Colors.green;
      icon = Icons.trending_up;
      statusText = 'You are owed money';
    } else if (owes) {
      cardColor = Colors.red;
      icon = Icons.trending_down;
      statusText = 'You owe money';
    } else {
      cardColor = Colors.blue;
      icon = Icons.check_circle;
      statusText = 'You\'re all settled up!';
    }

    return Card(
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          gradient: LinearGradient(
            colors: [cardColor.withOpacity(0.1), cardColor.withOpacity(0.05)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, color: cardColor, size: 28),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Your Balance',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: cardColor,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Text(
              '\$${userBalance.balance.abs().toStringAsFixed(2)}',
              style: TextStyle(
                fontSize: 32,
                fontWeight: FontWeight.bold,
                color: cardColor,
              ),
            ),
            Text(
              statusText,
              style: TextStyle(
                fontSize: 16,
                color: cardColor.withOpacity(0.8),
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: _buildBalanceDetail(
                    'Total Paid',
                    '\$${userBalance.totalPaid.toStringAsFixed(2)}',
                    Icons.payment,
                  ),
                ),
                Expanded(
                  child: _buildBalanceDetail(
                    'Total Owed',
                    '\$${userBalance.totalOwed.toStringAsFixed(2)}',
                    Icons.receipt,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBalanceDetail(String label, String value, IconData icon) {
    return Column(
      children: [
        Icon(icon, color: Colors.grey[600], size: 20),
        const SizedBox(height: 4),
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: Colors.grey[600],
          ),
        ),
        Text(
          value,
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }

  Widget _buildRoomspaceOverviewCard() {
    final summary = _balanceSummary!;
    
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Roomspace Overview',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: _buildOverviewStat(
                    'Total Expenses',
                    '\$${summary.totalExpenses.toStringAsFixed(2)}',
                    Icons.receipt_long,
                    Colors.blue,
                  ),
                ),
                Expanded(
                  child: _buildOverviewStat(
                    'Expense Count',
                    summary.expenseCount.toString(),
                    Icons.numbers,
                    Colors.orange,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _buildOverviewStat(
                    'Average',
                    '\$${summary.averageExpense.toStringAsFixed(2)}',
                    Icons.trending_up,
                    Colors.green,
                  ),
                ),
                Expanded(
                  child: _buildOverviewStat(
                    'Members',
                    summary.members.length.toString(),
                    Icons.people,
                    Colors.purple,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildOverviewStat(String label, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(12),
      margin: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 24),
          const SizedBox(height: 8),
          Text(
            value,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey[600],
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildAllBalancesCard() {
    final summary = _balanceSummary!;
    final currentUser = FirebaseAuth.instance.currentUser;
    
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'All Balances',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            ...summary.userBalances.entries.map((entry) {
              final userId = entry.key;
              final balance = entry.value;
              final isCurrentUser = userId == currentUser?.uid;
              
              final member = summary.members.firstWhere(
                (m) => (m['user_id'] ?? m['firebase_uid']) == userId,
                orElse: () => {'name': 'Unknown User'},
              );
              final userName = member['name'] ?? 'Unknown User';
              
              return _buildBalanceItem(
                userName,
                balance,
                isCurrentUser,
              );
            }),
          ],
        ),
      ),
    );
  }

  Widget _buildBalanceItem(String userName, double balance, bool isCurrentUser) {
    Color balanceColor;
    IconData icon;
    
    if (balance > 0.01) {
      balanceColor = Colors.green;
      icon = Icons.arrow_upward;
    } else if (balance < -0.01) {
      balanceColor = Colors.red;
      icon = Icons.arrow_downward;
    } else {
      balanceColor = Colors.grey;
      icon = Icons.check;
    }
    
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isCurrentUser 
            ? Theme.of(context).primaryColor.withOpacity(0.1)
            : Colors.grey[50],
        borderRadius: BorderRadius.circular(8),
        border: isCurrentUser 
            ? Border.all(color: Theme.of(context).primaryColor.withOpacity(0.3))
            : null,
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 16,
            backgroundColor: isCurrentUser 
                ? Theme.of(context).primaryColor
                : Colors.grey[400],
            child: Text(
              userName.isNotEmpty ? userName[0].toUpperCase() : '?',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 12,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              isCurrentUser ? 'You' : userName,
              style: TextStyle(
                fontWeight: FontWeight.w600,
                color: isCurrentUser 
                    ? Theme.of(context).primaryColor
                    : null,
              ),
            ),
          ),
          Icon(icon, color: balanceColor, size: 16),
          const SizedBox(width: 4),
          Text(
            '\$${balance.abs().toStringAsFixed(2)}',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: balanceColor,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSettlementsTab() {
    if (_settlements == null || _settlements!.isEmpty) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.check_circle_outline,
              size: 64,
              color: Colors.green,
            ),
            SizedBox(height: 16),
            Text(
              'All Settled Up!',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Colors.green,
              ),
            ),
            SizedBox(height: 8),
            Text(
              'No settlements needed at this time.',
              style: TextStyle(
                color: Colors.grey,
              ),
            ),
          ],
        ),
      );
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Suggested Settlements',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'These settlements will minimize the number of transactions needed to balance everyone out.',
                    style: TextStyle(
                      color: Colors.grey[600],
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          ..._settlements!.map((settlement) => _buildSettlementCard(settlement)),
        ],
      ),
    );
  }

  Widget _buildSettlementCard(Settlement settlement) {
    final currentUser = FirebaseAuth.instance.currentUser;
    final isCurrentUserInvolved = settlement.fromUserId == currentUser?.uid || 
                                  settlement.toUserId == currentUser?.uid;
    
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          border: isCurrentUserInvolved 
              ? Border.all(color: Theme.of(context).primaryColor.withOpacity(0.3))
              : null,
          color: isCurrentUserInvolved 
              ? Theme.of(context).primaryColor.withOpacity(0.05)
              : null,
        ),
        child: Row(
          children: [
            // From user
            CircleAvatar(
              radius: 20,
              backgroundColor: Colors.red[100],
              child: Text(
                settlement.fromUserName.isNotEmpty 
                    ? settlement.fromUserName[0].toUpperCase() 
                    : '?',
                style: TextStyle(
                  color: Colors.red[700],
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            const SizedBox(width: 12),
            
            // From user name
            Expanded(
              child: Text(
                settlement.fromUserId == currentUser?.uid 
                    ? 'You' 
                    : settlement.fromUserName,
                style: const TextStyle(
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            
            // Arrow and amount
            Column(
              children: [
                Icon(
                  Icons.arrow_forward,
                  color: Colors.grey[600],
                ),
                Text(
                  '\$${settlement.amount.toStringAsFixed(2)}',
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
              ],
            ),
            
            const SizedBox(width: 12),
            
            // To user name
            Expanded(
              child: Text(
                settlement.toUserId == currentUser?.uid 
                    ? 'You' 
                    : settlement.toUserName,
                style: const TextStyle(
                  fontWeight: FontWeight.w600,
                ),
                textAlign: TextAlign.end,
              ),
            ),
            
            const SizedBox(width: 12),
            
            // To user
            CircleAvatar(
              radius: 20,
              backgroundColor: Colors.green[100],
              child: Text(
                settlement.toUserName.isNotEmpty 
                    ? settlement.toUserName[0].toUpperCase() 
                    : '?',
                style: TextStyle(
                  color: Colors.green[700],
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatisticsTab() {
    if (_expenseStats == null) {
      return const Center(child: Text('No statistics available'));
    }

    final stats = _expenseStats!;
    
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildCategoryBreakdownCard(stats),
          const SizedBox(height: 16),
          _buildMonthlyTrendsCard(stats),
        ],
      ),
    );
  }

  Widget _buildCategoryBreakdownCard(ExpenseStats stats) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Category Breakdown',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            ...stats.categoriesByAmount.take(5).map((entry) {
              final percentage = (entry.value / stats.totalAmount) * 100;
              return _buildCategoryItem(entry.key, entry.value, percentage);
            }),
          ],
        ),
      ),
    );
  }

  Widget _buildCategoryItem(String category, double amount, double percentage) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                category,
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
              Text(
                '\$${amount.toStringAsFixed(2)} (${percentage.toStringAsFixed(1)}%)',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
            ],
          ),
          const SizedBox(height: 4),
          LinearProgressIndicator(
            value: percentage / 100,
            backgroundColor: Colors.grey[200],
            valueColor: AlwaysStoppedAnimation<Color>(
              Theme.of(context).primaryColor,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMonthlyTrendsCard(ExpenseStats stats) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Monthly Trends (Last 6 Months)',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            ...stats.monthlyTrendsSorted.map((entry) {
              final monthName = _formatMonth(entry.key);
              return _buildMonthItem(monthName, entry.value);
            }),
          ],
        ),
      ),
    );
  }

  Widget _buildMonthItem(String month, double amount) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.grey[50],
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            month,
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
          Text(
            '\$${amount.toStringAsFixed(2)}',
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }

  String _formatMonth(String monthKey) {
    final parts = monthKey.split('-');
    if (parts.length != 2) return monthKey;
    
    final year = parts[0];
    final month = int.tryParse(parts[1]) ?? 1;
    
    const monthNames = [
      '', 'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
    ];
    
    return '${monthNames[month]} $year';
  }
}