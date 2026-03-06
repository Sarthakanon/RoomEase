import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/widgets/mobile_scaffold.dart';
import '../../../core/widgets/global_roomspace_selector.dart';
import '../../../services/api_service.dart';
import '../../../models/expense_models.dart';
import '../../../providers/roomspace_provider.dart';
import '../widgets/month_selector.dart';
import 'expense_list_screen.dart';
import 'personal_expenses_screen.dart';
import 'personal_expense_details_screen.dart';
import 'payment_confirmation_screen.dart';
import 'who_owes_who_screen.dart';
import 'report_preview_screen.dart';
import 'report_options_screen.dart';

/// Main expense screen — acts as a router for different expense-related views.
class ExpenseScreen extends StatefulWidget {
  const ExpenseScreen({super.key});

  @override
  State<ExpenseScreen> createState() => _ExpenseScreenState();
}

class _ExpenseScreenState extends State<ExpenseScreen> {
  final ApiService _apiService = ApiService();
  
  List<ExpenseData> _recentSharedExpenses = [];
  List<PersonalExpenseData> _recentPersonalExpenses = [];
  int _pendingPaymentsCount = 0;
  bool _isLoading = true;
  bool _hasError = false;
  String _errorMessage = '';
  String? _currentRoomspaceId;
  // Initialize with first day of current month
  late DateTime _selectedMonth = DateTime(DateTime.now().year, DateTime.now().month, 1);

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
        _pendingPaymentsCount = 0; // Clear pending payments
      } else {
        // Load both in roomspace mode
        await Future.wait([
          _loadRecentSharedExpenses(),
          _loadRecentPersonalExpenses(),
          _loadPendingPaymentsCount(),
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
          limit: 3, // Only show 3 on dashboard, full list available via 'View All'
          offset: 0,
          month: _selectedMonth, // Pass selected month
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
        limit: 3, // Only show 3 on dashboard, full list available via 'View All'
        offset: 0,
        month: _selectedMonth, // Pass selected month
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

  Future<void> _loadPendingPaymentsCount() async {
    try {
      final roomspaceProvider = Provider.of<RoomspaceProvider>(context, listen: false);
      final activeRoomspace = roomspaceProvider.activeRoomspace;
      
      if (activeRoomspace != null) {
        final response = await _apiService.dio.get(
          '/api/roomspaces/${activeRoomspace.id}/payments/pending',
        );
        
        if (response.statusCode == 200 && response.data['success'] == true) {
          final List<dynamic> payments = response.data['data'] ?? [];
          setState(() {
            _pendingPaymentsCount = payments.length;
          });
        }
      }
    } catch (e) {
      debugPrint('Error loading pending payments count: $e');
      setState(() {
        _pendingPaymentsCount = 0;
      });
    }
  }

  Future<void> _refreshData() async {
    await _loadInitialData();
  }
  
  void _onMonthChanged(DateTime newMonth) {
    setState(() {
      _selectedMonth = newMonth;
    });
    _loadInitialData();
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
      showAppBar: false,
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
            // ── Header Section ──
            _buildHeader(primaryColor),

            // ── Month Selector ──
            MonthSelector(
              selectedMonth: _selectedMonth,
              onMonthChanged: _onMonthChanged,
            ),

            // ── Body Content ──
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Shared Expenses
                  if (!isPersonalSpace) ...[
                    const SizedBox(height: 12),
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
                      primaryColor: primaryColor,
                    ),
                    _buildSharedList(primaryColor),
                    const SizedBox(height: 24),
                    
                    // Settle Up Actions (Who Owes Who + Pending Payments)
                    _buildSettleUpSection(primaryColor),
                    const SizedBox(height: 24),
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
                    primaryColor: Colors.orange.shade700,
                  ),
                  _buildPersonalList(),
                  
                  const SizedBox(height: 100), // Extra space for bottom nav
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
      padding: const EdgeInsets.fromLTRB(20, 56, 16, 20),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(bottom: BorderSide(color: Colors.grey.shade100)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Expanded(
                child: Text(
                  'Expenses',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF1A1A2E),
                  ),
                ),
              ),
              GlobalRoomspaceSelector(
                onRoomspaceChanged: _loadInitialData,
              ),
            ],
          ),
          const SizedBox(height: 16),
          _buildSpendingSummaryPanel(primaryColor),
        ],
      ),
    );
  }

  Widget _buildSpendingSummaryPanel(Color primaryColor) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFF7F7FB),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFEEEEF2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Activity Total',
            style: TextStyle(
              fontSize: 11,
              color: Colors.grey.shade500,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Rs. ${_totalRecentSpending.toStringAsFixed(2)}',
            style: const TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w900,
              color: Color(0xFF1A1A2E),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader({
    required String title, 
    required VoidCallback onTap,
    required Color primaryColor
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: Color(0xFF1A1A2E),
            ),
          ),
          TextButton(
            onPressed: onTap,
            style: TextButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              minimumSize: Size.zero,
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
            child: Text(
              'View All',
              style: TextStyle(
                color: primaryColor,
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSharedList(Color primaryColor) {
    if (_recentSharedExpenses.isEmpty) {
      return _buildEmptyState("No shared expenses yet", Icons.people_outline_rounded);
    }

    return Column(
      children: _recentSharedExpenses.map((expense) {
        return _ExpenseTile(
          title: expense.title,
          subtitle: expense.category,
          amount: 'Rs. ${expense.amount.toStringAsFixed(0)}',
          amountColor: primaryColor,
          date: _formatDate(expense.createdAt),
          icon: Icons.receipt_long_outlined,
          onTap: () {
            // No details view for shared yet, or could navigate to a summary
          },
        );
      }).toList(),
    );
  }

  Widget _buildPersonalList() {
    if (_recentPersonalExpenses.isEmpty) {
      return _buildEmptyState("No personal expenses yet", Icons.account_balance_wallet_outlined);
    }

    return Column(
      children: _recentPersonalExpenses.map((expense) {
        return _ExpenseTile(
          title: expense.title,
          subtitle: expense.category,
          amount: 'Rs. ${expense.amount.toStringAsFixed(0)}',
          amountColor: Colors.orange.shade700,
          date: _formatDate(expense.createdAt),
          icon: Icons.account_balance_wallet_outlined,
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => PersonalExpenseDetailsScreen(expense: expense),
              ),
            );
          },
        );
      }).toList(),
    );
  }

  Widget _buildSettleUpSection(Color primaryColor) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.only(bottom: 12),
          child: Text(
            "Management",
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: Color(0xFF1A1A2E),
            ),
          ),
        ),
        _ManagementActionCard(
          title: 'Balance Overview',
          subtitle: 'See who owes who and settle up',
          icon: Icons.people_rounded,
          color: Colors.indigo,
          onTap: () {
            final roomspaceId = Provider.of<RoomspaceProvider>(context, listen: false).getActiveRoomspaceId();
            if (roomspaceId != null) {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => WhoOwesWhoScreen(roomspaceId: roomspaceId),
                ),
              );
            }
          },
        ),
        const SizedBox(height: 12),
        _ManagementActionCard(
          title: 'Confirm Payments',
          subtitle: _pendingPaymentsCount > 0 
              ? '$_pendingPaymentsCount pending confirmation${_pendingPaymentsCount > 1 ? 's' : ''}'
              : 'Review and verify payments',
          icon: Icons.payment_rounded,
          color: Colors.blue.shade600,
          badgeCount: _pendingPaymentsCount,
          onTap: () {
            final roomspaceId = Provider.of<RoomspaceProvider>(context, listen: false).getActiveRoomspaceId();
            if (roomspaceId != null) {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => PaymentConfirmationScreen(roomspaceId: roomspaceId),
                ),
              ).then((_) => _loadPendingPaymentsCount());
            }
          },
        ),
        const SizedBox(height: 12),
        _ManagementActionCard(
          title: 'Generate Report',
          subtitle: 'Export expenses as professional PDF',
          icon: Icons.picture_as_pdf_rounded,
          color: Colors.red.shade700,
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => const ReportOptionsScreen()),
            );
          },
        ),
      ],
    );
  }

  Widget _buildEmptyState(String message, IconData icon) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
      decoration: BoxDecoration(
        color: const Color(0xFFF7F7FB),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFEEEEF2)),
      ),
      child: Column(
        children: [
          Icon(icon, color: Colors.grey.shade400, size: 28),
          const SizedBox(height: 8),
          Text(
            message,
            style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
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
            Icon(Icons.wifi_off_rounded, size: 48, color: Colors.grey.shade300),
            const SizedBox(height: 16),
            const Text(
              'Couldn\'t load expenses',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: Color(0xFF1A1A2E),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              _errorMessage,
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey.shade500, fontSize: 13),
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: _loadInitialData,
              child: const Text('Try Again'),
            ),
          ],
        ),
      ),
    );
  }

  String _formatDate(DateTime? date) {
    if (date == null) return '';
    final now = DateTime.now();
    final difference = now.difference(date);
    
    if (difference.inDays == 0) return 'Today';
    if (difference.inDays == 1) return 'Yesterday';
    if (difference.inDays < 7) return '${difference.inDays}d ago';
    
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
    ];
    return '${months[date.month - 1]} ${date.day}';
  }
}

/// Simplified expense tile reused across the screen
class _ExpenseTile extends StatelessWidget {
  final String title;
  final String subtitle;
  final String amount;
  final Color amountColor;
  final String date;
  final IconData icon;
  final VoidCallback onTap;

  const _ExpenseTile({
    required this.title,
    required this.subtitle,
    required this.amount,
    required this.amountColor,
    required this.date,
    required this.icon,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFEEEEF2)),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: const Color(0xFFF7F7FB),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, size: 18, color: Colors.grey.shade600),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                      overflow: TextOverflow.ellipsis,
                    ),
                    Text(
                      subtitle,
                      style: TextStyle(fontSize: 11, color: Colors.grey.shade500),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    amount,
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 13,
                      color: amountColor,
                    ),
                  ),
                  Text(
                    date,
                    style: TextStyle(fontSize: 10, color: Colors.grey.shade400),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Action card for Management section (Who Owes Who / Confirm Payments)
class _ManagementActionCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final Color color;
  final int? badgeCount;
  final VoidCallback onTap;

  const _ManagementActionCard({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.color,
    this.badgeCount,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFEEEEF2)),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    Icon(icon, size: 24, color: color),
                    if (badgeCount != null && badgeCount! > 0)
                      Positioned(
                        right: -4,
                        top: -4,
                        child: Container(
                          padding: const EdgeInsets.all(4),
                          decoration: const BoxDecoration(
                            color: Colors.red,
                            shape: BoxShape.circle,
                          ),
                          constraints: const BoxConstraints(minWidth: 16, minHeight: 16),
                          child: Text(
                            '$badgeCount',
                            style: const TextStyle(color: Colors.white, fontSize: 8, fontWeight: FontWeight.bold),
                            textAlign: TextAlign.center,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
                    ),
                    Text(
                      subtitle,
                      style: TextStyle(fontSize: 12, color: Colors.grey.shade500),
                    ),
                  ],
                ),
              ),
              Icon(Icons.arrow_forward_ios_rounded, size: 14, color: Colors.grey.shade400),
            ],
          ),
        ),
      ),
    );
  }
}