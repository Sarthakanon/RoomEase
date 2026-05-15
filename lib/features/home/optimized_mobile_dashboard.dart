import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/widgets/mobile_scaffold.dart';
import '../../core/widgets/global_roomspace_selector.dart';
import '../../core/widgets/skeleton_loader.dart';
import '../../providers/roomspace_provider.dart';
import '../../services/cached_api_service.dart';
import '../../services/performance_service.dart';
import '../../services/loading_service.dart';
import '../../widgets/optimized_future_builder.dart';
import 'widgets/balance_details_dialog.dart';

/// Optimized Home dashboard with caching and performance improvements
class OptimizedMobileDashboard extends StatefulWidget {
  const OptimizedMobileDashboard({super.key});

  @override
  State<OptimizedMobileDashboard> createState() => _OptimizedMobileDashboardState();
}

class _OptimizedMobileDashboardState extends State<OptimizedMobileDashboard>
    with WidgetsBindingObserver, AutomaticKeepAliveClientMixin {
  
  final CachedApiService _cachedApiService = CachedApiService();
  final PerformanceService _performanceService = PerformanceService();

  late Future<Map<String, dynamic>> _dashboardDataFuture;

  @override
  bool get wantKeepAlive => true; // Keep state alive when switching tabs

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _loadDashboardData();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      // Refresh data when app comes back to foreground
      _refreshData();
    }
  }

  void _loadDashboardData() {
    setState(() {
      _dashboardDataFuture = _performanceService.getDashboardData();
    });
  }

  void _refreshData() {
    setState(() {
      _dashboardDataFuture = _performanceService.getDashboardData();
    });
  }

  @override
  Widget build(BuildContext context) {
    super.build(context); // Required for AutomaticKeepAliveClientMixin
    
    return Consumer<LoadingService>(
      builder: (context, loadingService, child) {
        return MobileScaffold(
          title: 'Dashboard',
          actions: [
            IconButton(
              icon: const Icon(Icons.refresh),
              onPressed: _refreshData,
              tooltip: 'Refresh',
            ),
          ],
          body: RefreshIndicator(
            onRefresh: () async {
              await _performanceService.refreshAllData();
              _refreshData();
            },
            child: OptimizedFutureBuilder<Map<String, dynamic>>(
              future: _dashboardDataFuture,
              timeout: const Duration(seconds: 30),
              loadingBuilder: (context) => _buildLoadingSkeleton(),
              errorBuilder: (context, error) => _buildErrorState(error),
              builder: (context, dashboardData) {
                return _buildDashboardContent(dashboardData);
              },
            ),
          ),
        );
      },
    );
  }

  Widget _buildLoadingSkeleton() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          // Roomspace selector skeleton
          const SkeletonLoader(height: 60, borderRadius: BorderRadius.all(Radius.circular(12))),
          const SizedBox(height: 20),
          
          // Balance cards skeleton
          Row(
            children: [
              Expanded(child: const SkeletonLoader(height: 100, borderRadius: BorderRadius.all(Radius.circular(12)))),
              const SizedBox(width: 12),
              Expanded(child: const SkeletonLoader(height: 100, borderRadius: BorderRadius.all(Radius.circular(12)))),
            ],
          ),
          const SizedBox(height: 20),
          
          // Quick actions skeleton
          const SkeletonLoader(height: 80, borderRadius: BorderRadius.all(Radius.circular(12))),
          const SizedBox(height: 20),
          
          // Recent expenses skeleton
          ...List.generate(3, (index) => Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: const SkeletonLoader(height: 70, borderRadius: BorderRadius.all(Radius.circular(12))),
          )),
        ],
      ),
    );
  }

  Widget _buildErrorState(Object error) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.error_outline,
              size: 64,
              color: Colors.red[400],
            ),
            const SizedBox(height: 16),
            Text(
              'Failed to load dashboard',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                color: Colors.red[700],
              ),
            ),
            const SizedBox(height: 8),
            Text(
              error.toString().contains('timeout') 
                  ? 'Request timed out. Please check your connection.'
                  : 'Please check your internet connection and try again.',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Colors.grey[600],
              ),
            ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: _refreshData,
              icon: const Icon(Icons.refresh),
              label: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDashboardContent(Map<String, dynamic> dashboardData) {
    final roomspacesData = dashboardData['roomspaces'] as Map<String, dynamic>;
    final profileData = dashboardData['profile'] as Map<String, dynamic>;
    final recentExpensesData = dashboardData['recent_expenses'] as Map<String, dynamic>;

    final roomspaces = (roomspacesData['data'] as List<dynamic>? ?? [])
        .cast<Map<String, dynamic>>();
    
    final hasRoomspace = roomspaces.isNotEmpty;
    final activeRoomspaceId =
        Provider.of<RoomspaceProvider>(context, listen: false)
            .getActiveRoomspaceId();

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Welcome message
          _buildWelcomeSection(profileData),
          const SizedBox(height: 20),

          // Roomspace selector
          if (hasRoomspace) ...[
            GlobalRoomspaceSelector(
              onRoomspaceChanged: () {
                // Trigger refresh when roomspace changes
                _refreshData();
              },
            ),
            const SizedBox(height: 20),
          ],

          // Balance summary (only if has roomspace)
          if (hasRoomspace && activeRoomspaceId != null)
            _buildBalanceSection(activeRoomspaceId),

          // Quick actions
          _buildQuickActions(hasRoomspace),
          const SizedBox(height: 20),

          // Recent expenses
          _buildRecentExpensesSection(recentExpensesData, hasRoomspace),
        ],
      ),
    );
  }

  Widget _buildWelcomeSection(Map<String, dynamic> profileData) {
    final userData = profileData['data'] as Map<String, dynamic>? ?? {};
    final userName = userData['name'] as String? ?? 'User';

    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            CircleAvatar(
              radius: 24,
              backgroundColor: Theme.of(context).primaryColor,
              child: Text(
                userName.isNotEmpty ? userName[0].toUpperCase() : 'U',
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Welcome back,',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Colors.grey[600],
                    ),
                  ),
                  Text(
                    userName,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBalanceSection(String roomspaceId) {
    return OptimizedFutureBuilder<Map<String, dynamic>>(
      future: _cachedApiService.getRoomspaceBalances(roomspaceId),
      timeout: const Duration(seconds: 15),
      loadingBuilder: (context) => Row(
        children: [
          Expanded(child: const SkeletonLoader(height: 100, borderRadius: BorderRadius.all(Radius.circular(12)))),
          const SizedBox(width: 12),
          Expanded(child: const SkeletonLoader(height: 100, borderRadius: BorderRadius.all(Radius.circular(12)))),
        ],
      ),
      builder: (context, balanceData) {
        final balances = balanceData['data'] as Map<String, dynamic>? ?? {};
        final youOwe = (balances['you_owe'] as num?)?.toDouble() ?? 0.0;
        final youAreOwed = (balances['you_are_owed'] as num?)?.toDouble() ?? 0.0;
        final netYouOwe = (youOwe - youAreOwed).clamp(0.0, double.infinity);
        final netYouAreOwed = (youAreOwed - youOwe).clamp(0.0, double.infinity);

        return Row(
          children: [
            Expanded(
              child: _buildBalanceCard(
                'You Owe',
                netYouOwe,
                Colors.red,
                Icons.arrow_upward,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildBalanceCard(
                'You Are Owed',
                netYouAreOwed,
                Colors.green,
                Icons.arrow_downward,
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildBalanceCard(String title, double amount, Color color, IconData icon) {
    return Card(
      elevation: 2,
      child: InkWell(
        onTap: () {
          final activeRoomspaceId =
              Provider.of<RoomspaceProvider>(context, listen: false)
                  .getActiveRoomspaceId();
          if (activeRoomspaceId != null) {
            BalanceDetailsDialog.show(
              context,
              roomspaceId: activeRoomspaceId,
              isOwed: amount > 0, // Determine based on amount
              actualBalance: amount,
            );
          }
        },
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(icon, color: color, size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      title,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: Colors.grey[600],
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                '₹${amount.toStringAsFixed(2)}',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  color: color,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildQuickActions(bool hasRoomspace) {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Quick Actions',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                if (hasRoomspace) ...[
                  Expanded(
                    child: _buildActionButton(
                      'Add Expense',
                      Icons.add_circle,
                      Colors.blue,
                      () => _showAddExpenseDialog(),
                    ),
                  ),
                  const SizedBox(width: 12),
                ],
                Expanded(
                  child: _buildActionButton(
                    'Personal Expense',
                    Icons.person,
                    Colors.green,
                    () => _showPersonalExpenseDialog(),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildActionButton(
                    'Scan Receipt',
                    Icons.camera_alt,
                    Colors.orange,
                    () => _showReceiptScanner(),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActionButton(String label, IconData icon, Color color, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Column(
          children: [
            Icon(icon, color: color, size: 24),
            const SizedBox(height: 4),
            Text(
              label,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: color,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRecentExpensesSection(Map<String, dynamic> recentExpensesData, bool hasRoomspace) {
    final expenses = (recentExpensesData['data'] as List<dynamic>? ?? [])
        .cast<Map<String, dynamic>>();

    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Recent Expenses',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                TextButton(
                  onPressed: () {
                    Navigator.pushNamed(context, '/expense-list');
                  },
                  child: const Text('View All'),
                ),
              ],
            ),
            const SizedBox(height: 12),
            if (expenses.isEmpty)
              Center(
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Text(
                    'No recent expenses',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Colors.grey[600],
                    ),
                  ),
                ),
              )
            else
              ...expenses.take(3).map((expense) => _buildExpenseItem(expense)),
          ],
        ),
      ),
    );
  }

  Widget _buildExpenseItem(Map<String, dynamic> expense) {
    final amount = (expense['amount'] as num?)?.toDouble() ?? 0.0;
    final description = expense['description'] as String? ?? 'No description';
    final category = expense['category'] as String? ?? 'Other';
    
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          CircleAvatar(
            radius: 16,
            backgroundColor: Theme.of(context).primaryColor.withValues(alpha: 0.1),
            child: Icon(
              _getCategoryIcon(category),
              size: 16,
              color: Theme.of(context).primaryColor,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  description,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w500,
                  ),
                ),
                Text(
                  category,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Colors.grey[600],
                  ),
                ),
              ],
            ),
          ),
          Text(
            '₹${amount.toStringAsFixed(2)}',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              fontWeight: FontWeight.bold,
              color: Theme.of(context).primaryColor,
            ),
          ),
        ],
      ),
    );
  }

  IconData _getCategoryIcon(String category) {
    switch (category.toLowerCase()) {
      case 'food':
        return Icons.restaurant;
      case 'groceries':
        return Icons.shopping_cart;
      case 'utilities':
        return Icons.electrical_services;
      case 'transport':
        return Icons.directions_car;
      case 'entertainment':
        return Icons.movie;
      default:
        return Icons.receipt;
    }
  }

  void _showAddExpenseDialog() {
    // TODO: Fix AddExpenseDialog parameters
    // showDialog(
    //   context: context,
    //   builder: (context) => const AddExpenseDialog(),
    // ).then((_) => _refreshData());
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Add expense feature needs to be implemented')),
    );
  }

  void _showPersonalExpenseDialog() {
    // TODO: Fix PersonalExpenseDialog parameters
    // showDialog(
    //   context: context,
    //   builder: (context) => const PersonalExpenseDialog(),
    // ).then((_) => _refreshData());
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Personal expense feature needs to be implemented')),
    );
  }

  void _showReceiptScanner() {
    // TODO: Fix ReceiptScannerDialog parameters
    // showDialog(
    //   context: context,
    //   builder: (context) => const ReceiptScannerDialog(),
    // ).then((_) => _refreshData());
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Receipt scanner feature needs to be implemented')),
    );
  }
}
