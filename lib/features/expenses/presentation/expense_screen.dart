import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/widgets/mobile_scaffold.dart';
import '../../../core/widgets/global_roomspace_selector.dart';
import '../../../services/api_service.dart';
import '../../../models/expense_models.dart';
import '../../../providers/roomspace_provider.dart';
import 'expense_list_screen.dart';
import 'personal_expenses_screen.dart';
import 'personal_expense_details_screen.dart';

class ExpenseScreen extends StatefulWidget {
  const ExpenseScreen({super.key});

  @override
  State<ExpenseScreen> createState() => _ExpenseScreenState();
}

class _ExpenseScreenState extends State<ExpenseScreen> {
  final ApiService _apiService = ApiService();
  
  List<ExpenseData> _recentSharedExpenses = [];
  List<PersonalExpenseData> _recentPersonalExpenses = [];
  bool _isLoading = true;
  bool _hasError = false;
  String _errorMessage = '';
  String? _currentRoomspaceId;

  @override
  void initState() {
    super.initState();
    _loadInitialData();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Listen for roomspace changes
    final roomspaceProvider = Provider.of<RoomspaceProvider>(context);
    final activeRoomspaceId = roomspaceProvider.getActiveRoomspaceId();
    final isPersonalSpace = roomspaceProvider.isPersonalSpace;
    
    // Reload data if roomspace changed or switched to/from personal space
    if (activeRoomspaceId != _currentRoomspaceId || isPersonalSpace) {
      _currentRoomspaceId = activeRoomspaceId;
      _loadInitialData();
    }
  }

  Future<void> _loadInitialData() async {
    setState(() {
      _isLoading = true;
      _hasError = false;
    });

    try {
      // Get roomspace provider to check if in personal space
      final roomspaceProvider = Provider.of<RoomspaceProvider>(context, listen: false);
      final isPersonalSpace = roomspaceProvider.isPersonalSpace;
      
      if (isPersonalSpace) {
        // Only load personal expenses in personal space
        await _loadRecentPersonalExpenses();
        _recentSharedExpenses = []; // Clear shared expenses
      } else {
        // Load both in roomspace mode
        await Future.wait([
          _loadRecentSharedExpenses(),
          _loadRecentPersonalExpenses(),
        ]);
      }
      
      setState(() {
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
        _hasError = true;
        _errorMessage = e.toString().replaceFirst('Exception: ', '');
      });
    }
  }

  Future<void> _loadRecentSharedExpenses() async {
    try {
      // Get active roomspace from provider
      final roomspaceProvider = Provider.of<RoomspaceProvider>(context, listen: false);
      final activeRoomspace = roomspaceProvider.activeRoomspace;
      
      if (activeRoomspace != null) {
        _currentRoomspaceId = activeRoomspace.id;
        
        final response = await _apiService.getRoomspaceExpenses(
          _currentRoomspaceId!,
          limit: 5,
          offset: 0,
        );

        if (response.containsKey('data')) {
          final data = response['data'];
          if (data != null && data is List) {
            _recentSharedExpenses = data
                .map((json) => ExpenseData.fromJson(json))
                .toList();
          }
        }
      }
    } catch (e) {
      debugPrint('Error loading shared expenses: $e');
    }
  }

  Future<void> _loadRecentPersonalExpenses() async {
    try {
      final response = await _apiService.getPersonalExpenses(
        limit: 5,
        offset: 0,
      );

      if (response.containsKey('data')) {
        final data = response['data'];
        if (data != null && data is List) {
          _recentPersonalExpenses = data
              .map((json) => PersonalExpenseData.fromJson(json))
              .toList();
        }
      }
    } catch (e) {
      debugPrint('Error loading personal expenses: $e');
    }
  }

  Future<void> _refreshData() async {
    await _loadInitialData();
  }

  double get _totalRecentSpending {
    double sharedSum = _recentSharedExpenses.fold(0, (sum, item) => sum + item.amount);
    double personalSum = _recentPersonalExpenses.fold(0, (sum, item) => sum + item.amount);
    return sharedSum + personalSum;
  }

  @override
  Widget build(BuildContext context) {
    final primaryColor = Theme.of(context).colorScheme.primary;

    return MobileScaffold(
      currentIndex: 2,
      showAppBar: false, // Disable AppBar for expense screen
      body: _isLoading
          ? Center(child: CircularProgressIndicator(color: primaryColor))
          : _hasError
              ? _buildErrorState(primaryColor)
              : _buildContent(primaryColor),
    );
  }

  Widget _buildContent(Color primaryColor) {
    final roomspaceProvider = Provider.of<RoomspaceProvider>(context);
    final isPersonalSpace = roomspaceProvider.isPersonalSpace;
    
    return RefreshIndicator(
      onRefresh: _refreshData,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        child: Column(
          children: [
            // 1. Header Section
            _buildHeader(primaryColor),

            // 2. Body Content
            Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Shared Expenses - Only show in roomspace mode
                  if (!isPersonalSpace) ...[
                    _buildSectionHeader(
                      title: "Shared Expenses", 
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const ExpenseListScreen(
                            isPersonalExpenses: false,
                          ),
                        ),
                      ),
                      color: primaryColor,
                    ),
                    const SizedBox(height: 12),
                    _buildSharedList(primaryColor),
                    const SizedBox(height: 30),
                  ],

                  // Personal Expenses
                  _buildSectionHeader(
                    title: "Personal Expenses", 
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const PersonalExpensesScreen(),
                      ),
                    ),
                    color: Colors.orange,
                  ),
                  const SizedBox(height: 12),
                  _buildPersonalList(),
                  
                  const SizedBox(height: 80), // Bottom padding for nav bar
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(Color primaryColor) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.only(
        left: 20,
        right: 20,
        top: 60,
        bottom: 30,
      ),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [primaryColor, primaryColor.withValues(alpha: 0.8)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: const BorderRadius.only(
          bottomLeft: Radius.circular(30),
          bottomRight: Radius.circular(30),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Title and Global Selector Row
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Expenses',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                ),
              ),
              GlobalRoomspaceSelector(
                onRoomspaceChanged: () {
                  // Reload expense data
                  _loadInitialData();
                },
              ),
            ],
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.3),
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Recent Activity Total',
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.9),
                          fontSize: 13,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Rs. ${_totalRecentSpending.toStringAsFixed(2)}',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 24,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader({
    required String title, 
    required VoidCallback onTap,
    required Color color
  }) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          title,
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: Colors.grey[800],
          ),
        ),
        TextButton(
          onPressed: onTap,
          child: Text(
            'View All',
            style: TextStyle(
              color: color,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSharedList(Color primaryColor) {
    if (_recentSharedExpenses.isEmpty) {
      return _buildEmptyState("No shared expenses yet", Icons.people_outline);
    }

    return Column(
      children: _recentSharedExpenses.take(3).map((expense) {
        return _buildExpenseTile(
          title: expense.title,
          subtitle: expense.category,
          amount: expense.amount,
          date: expense.createdAt,
          icon: Icons.receipt_long,
          themeColor: primaryColor,
        );
      }).toList(),
    );
  }

  // FIXED METHOD BELOW
  Widget _buildPersonalList() {
    if (_recentPersonalExpenses.isEmpty) {
      return _buildEmptyState("No personal expenses yet", Icons.account_balance_wallet_outlined);
    }

    return Column(
      children: _recentPersonalExpenses.take(3).map((expense) {
        return GestureDetector(
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => PersonalExpenseDetailsScreen(expense: expense),
              ),
            );
          },
          child: _buildExpenseTile(
            title: expense.title,
            subtitle: expense.category,
            amount: expense.amount,
            date: expense.createdAt, // Changed from date to createdAt
            icon: Icons.account_balance_wallet,
            themeColor: Colors.orange,
          ),
        );
      }).toList(),
    );
  }

  Widget _buildExpenseTile({
    required String title,
    required String subtitle,
    required double amount,
    required DateTime? date,
    required IconData icon,
    required Color themeColor,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: themeColor.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: themeColor, size: 24),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  style: TextStyle(color: Colors.grey[500], fontSize: 13),
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                "Rs. ${amount.toStringAsFixed(2)}",
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                  color: themeColor,
                ),
              ),
              if (date != null)
                Text(
                  _formatDate(date),
                  style: TextStyle(color: Colors.grey[400], fontSize: 12),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState(String message, IconData icon) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.grey[50],
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey[200]!),
      ),
      child: Column(
        children: [
          Icon(icon, color: Colors.grey[400], size: 32),
          const SizedBox(height: 8),
          Text(
            message,
            style: TextStyle(color: Colors.grey[600], fontSize: 14),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorState(Color primaryColor) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline, size: 64, color: Colors.red[300]),
            const SizedBox(height: 16),
            Text(
              'Failed to load expenses',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.grey[800],
              ),
            ),
            const SizedBox(height: 8),
            Text(
              _errorMessage,
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey[600]),
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: _loadInitialData,
              style: ElevatedButton.styleFrom(
                backgroundColor: primaryColor,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              ),
              child: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final difference = now.difference(date);
    
    if (difference.inDays == 0) return 'Today';
    if (difference.inDays == 1) return 'Yesterday';
    if (difference.inDays < 7) return '${difference.inDays} days ago';
    
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
    ];
    return '${months[date.month - 1]} ${date.day}';
  }
}