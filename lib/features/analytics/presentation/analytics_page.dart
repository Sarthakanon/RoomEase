import 'package:flutter/material.dart';
import '../../../models/analytics_models.dart';
import '../../../services/analytics_service.dart';
import '../../../core/widgets/mobile_scaffold.dart';
import '../widgets/spending_trends_chart.dart';
import '../widgets/category_breakdown_chart.dart';
import '../widgets/recommendations_card.dart';
import '../widgets/anomaly_alert_card.dart';
import '../widgets/predictions_card.dart';
import '../widgets/skeleton_loader.dart';

/// Main analytics dashboard page
/// 
/// Displays spending insights including:
/// - Summary card with key metrics
/// - Tab switching between Personal and Roomspace views
/// - Spending trends, category breakdown, predictions, recommendations, and anomalies
class AnalyticsPage extends StatefulWidget {
  const AnalyticsPage({super.key});

  @override
  State<AnalyticsPage> createState() => _AnalyticsPageState();
}

class _AnalyticsPageState extends State<AnalyticsPage> with SingleTickerProviderStateMixin {
  final AnalyticsService _analyticsService = AnalyticsService();
  
  late TabController _tabController;
  bool _isLoading = true;
  String? _error;
  DateTime? _lastUpdated;
  bool _isUsingCache = false;
  
  // Personal analytics data
  AnalyticsSummary? _personalSummary;
  
  // Selected roomspace for roomspace view
  String? _selectedRoomspaceId;
  
  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _tabController.addListener(_onTabChanged);
    _loadPersonalAnalytics();
  }
  
  @override
  void dispose() {
    _tabController.removeListener(_onTabChanged);
    _tabController.dispose();
    super.dispose();
  }
  
  void _onTabChanged() {
    if (_tabController.index == 1 && _selectedRoomspaceId == null) {
      // TODO: Show roomspace selector when switching to roomspace tab
      // For now, just show empty state
    }
  }
  
  Future<void> _loadPersonalAnalytics() async {
    setState(() {
      _isLoading = true;
      _error = null;
      _isUsingCache = false;
    });
    
    try {
      final summary = await _analyticsService.getSummary();
      
      // Check if we're using cached data
      final cacheKey = _analyticsService.getSummaryCacheKey();
      final cacheTimestamp = await _analyticsService.getCacheTimestamp(cacheKey);
      
      setState(() {
        _personalSummary = summary;
        _isLoading = false;
        _lastUpdated = cacheTimestamp ?? DateTime.now();
        _isUsingCache = cacheTimestamp != null;
      });
    } catch (e) {
      // Try to get cache timestamp even on error
      final cacheKey = _analyticsService.getSummaryCacheKey();
      final cacheTimestamp = await _analyticsService.getCacheTimestamp(cacheKey);
      
      setState(() {
        _error = e.toString();
        _isLoading = false;
        _lastUpdated = cacheTimestamp;
        _isUsingCache = cacheTimestamp != null;
      });
    }
  }
  
  Future<void> _refreshAnalytics() async {
    await _loadPersonalAnalytics();
  }
  
  @override
  Widget build(BuildContext context) {
    return MobileScaffold(
      currentIndex: 3, // Analytics tab index
      showBottomNav: true,
      body: SafeArea(
        child: Column(
          children: [
            // Header
            _buildHeader(),
            
            // Tab bar
            _buildTabBar(),
            
            // Content
            Expanded(
              child: TabBarView(
                controller: _tabController,
                children: [
                  _buildPersonalView(),
                  _buildRoomspaceView(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
  
  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.all(20),
      color: Colors.white,
      child: Column(
        children: [
          Row(
            children: [
              Icon(
                Icons.analytics_rounded,
                size: 32,
                color: Theme.of(context).colorScheme.primary,
              ),
              const SizedBox(width: 12),
              Text(
                'Analytics',
                style: Theme.of(context).textTheme.displayMedium?.copyWith(
                  color: Theme.of(context).colorScheme.primary,
                ),
              ),
              const Spacer(),
              IconButton(
                icon: const Icon(Icons.refresh_rounded),
                onPressed: _refreshAnalytics,
                tooltip: 'Refresh',
              ),
            ],
          ),
          
          // Cache indicator banner
          if (_isUsingCache && _lastUpdated != null)
            Container(
              margin: const EdgeInsets.only(top: 12),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.blue.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: Colors.blue.withValues(alpha: 0.3),
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.offline_bolt_rounded,
                    size: 16,
                    color: Colors.blue,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Showing cached data from ${_formatCacheTime(_lastUpdated!)}',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Colors.blue[700],
                      ),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
  
  Widget _buildTabBar() {
    return Container(
      color: Colors.white,
      child: TabBar(
        controller: _tabController,
        labelColor: Theme.of(context).colorScheme.primary,
        unselectedLabelColor: Colors.grey,
        indicatorColor: Theme.of(context).colorScheme.primary,
        indicatorWeight: 3,
        tabs: const [
          Tab(
            icon: Icon(Icons.person_rounded),
            text: 'Personal',
          ),
          Tab(
            icon: Icon(Icons.group_rounded),
            text: 'Roomspace',
          ),
        ],
      ),
    );
  }
  
  Widget _buildPersonalView() {
    if (_isLoading) {
      return SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Summary skeleton
            const SummarySkeletonLoader(),
            const SizedBox(height: 24),
            
            // Chart skeletons
            const ChartSkeletonLoader(),
            const SizedBox(height: 16),
            const ChartSkeletonLoader(),
            const SizedBox(height: 16),
            
            // List item skeletons
            const ListItemSkeletonLoader(),
            const ListItemSkeletonLoader(),
          ],
        ),
      );
    }
    
    if (_error != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.error_outline_rounded,
              size: 64,
              color: Colors.grey[400],
            ),
            const SizedBox(height: 16),
            Text(
              'Failed to load analytics',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 8),
            Text(
              _error!,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Colors.grey,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: _refreshAnalytics,
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('Retry'),
            ),
          ],
        ),
      );
    }
    
    if (_personalSummary == null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.analytics_outlined,
              size: 64,
              color: Colors.grey[400],
            ),
            const SizedBox(height: 16),
            Text(
              'No analytics data available',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 8),
            Text(
              'Start adding expenses to see insights',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Colors.grey,
              ),
            ),
          ],
        ),
      );
    }
    
    return RefreshIndicator(
      onRefresh: _refreshAnalytics,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Summary card
            _buildSummaryCard(_personalSummary!),
            
            const SizedBox(height: 24),
            
            // Spending trends chart
            SpendingTrendsChart(roomspaceId: null),
            
            const SizedBox(height: 16),
            
            // Category breakdown
            CategoryBreakdownChart(categories: _personalSummary!.topCategories),
            
            const SizedBox(height: 16),
            
            // Predictions
            PredictionsCard(roomspaceId: null),
            
            const SizedBox(height: 16),
            
            // Recommendations
            RecommendationsCard(roomspaceId: null),
            
            const SizedBox(height: 16),
            
            // Anomaly alerts
            AnomalyAlertCard(roomspaceId: null),
          ],
        ),
      ),
    );
  }
  
  Widget _buildRoomspaceView() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.group_outlined,
            size: 64,
            color: Colors.grey[400],
          ),
          const SizedBox(height: 16),
          Text(
            'Roomspace Analytics',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 8),
          Text(
            'Select a roomspace to view analytics',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: Colors.grey,
            ),
          ),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: () {
              // TODO: Show roomspace selector
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Roomspace selector coming soon'),
                ),
              );
            },
            icon: const Icon(Icons.add_rounded),
            label: const Text('Select Roomspace'),
          ),
        ],
      ),
    );
  }
  
  Widget _buildSummaryCard(AnalyticsSummary summary) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.account_balance_wallet_rounded,
                  color: Theme.of(context).colorScheme.primary,
                  size: 28,
                ),
                const SizedBox(width: 12),
                Text(
                  'Spending Summary',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            
            // Total spent
            _buildMetricRow(
              'Total Spent',
              'Rs. ${summary.totalSpent.toStringAsFixed(2)}',
              Icons.payments_rounded,
              Colors.blue,
            ),
            const SizedBox(height: 16),
            
            // Predicted next month
            _buildMetricRow(
              'Predicted Next Month',
              'Rs. ${summary.predictedNextMonth.toStringAsFixed(2)}',
              Icons.trending_up_rounded,
              Colors.orange,
            ),
            const SizedBox(height: 16),
            
            // Savings potential
            _buildMetricRow(
              'Savings Potential',
              'Rs. ${summary.savingsPotential.toStringAsFixed(2)}',
              Icons.savings_rounded,
              Colors.green,
            ),
            const SizedBox(height: 16),
            
            // Spending trend
            _buildTrendIndicator(summary.spendingTrend),
          ],
        ),
      ),
    );
  }
  
  Widget _buildMetricRow(String label, String value, IconData icon, Color color) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, color: color, size: 20),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Colors.grey[600],
                ),
              ),
              const SizedBox(height: 4),
              Text(
                value,
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
  
  Widget _buildTrendIndicator(String trend) {
    IconData icon;
    Color color;
    String text;
    
    switch (trend.toLowerCase()) {
      case 'increasing':
        icon = Icons.trending_up_rounded;
        color = Colors.red;
        text = 'Spending is increasing';
        break;
      case 'decreasing':
        icon = Icons.trending_down_rounded;
        color = Colors.green;
        text = 'Spending is decreasing';
        break;
      default:
        icon = Icons.trending_flat_rounded;
        color = Colors.blue;
        text = 'Spending is stable';
    }
    
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(width: 8),
          Text(
            text,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: color,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
  
  String _formatCacheTime(DateTime cacheTime) {
    final now = DateTime.now();
    final difference = now.difference(cacheTime);
    
    if (difference.inMinutes < 1) {
      return 'just now';
    } else if (difference.inMinutes < 60) {
      return '${difference.inMinutes} minute${difference.inMinutes != 1 ? 's' : ''} ago';
    } else if (difference.inHours < 24) {
      return '${difference.inHours} hour${difference.inHours != 1 ? 's' : ''} ago';
    } else {
      return '${difference.inDays} day${difference.inDays != 1 ? 's' : ''} ago';
    }
  }
}
