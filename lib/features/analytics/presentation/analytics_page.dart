import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../models/analytics_models.dart';
import '../../../services/analytics_service.dart';
import '../../../core/widgets/mobile_scaffold.dart';
import '../../../core/widgets/global_roomspace_selector.dart';
import '../../../providers/roomspace_provider.dart';
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
/// - Roomspace-specific analytics filtered by active roomspace
/// - Spending trends, category breakdown, predictions, recommendations, and anomalies
class AnalyticsPage extends StatefulWidget {
  const AnalyticsPage({super.key});

  @override
  State<AnalyticsPage> createState() => _AnalyticsPageState();
}

class _AnalyticsPageState extends State<AnalyticsPage> {
  final AnalyticsService _analyticsService = AnalyticsService();
  
  bool _isLoading = true;
  String? _error;
  DateTime? _lastUpdated;
  bool _isUsingCache = false;
  
  // Analytics data for active roomspace
  AnalyticsSummary? _summary;
  String? _currentRoomspaceId;
  
  @override
  void initState() {
    super.initState();
    // Load analytics after first frame to access provider
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadAnalytics();
    });
  }
  
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    
    // Listen for roomspace changes
    final roomspaceProvider = Provider.of<RoomspaceProvider>(context);
    final activeRoomspaceId = roomspaceProvider.getActiveRoomspaceId();
    
    // Reload analytics if roomspace changed
    if (activeRoomspaceId != _currentRoomspaceId && activeRoomspaceId != null) {
      _currentRoomspaceId = activeRoomspaceId;
      _loadAnalytics();
    }
  }
  
  Future<void> _loadAnalytics() async {
    final roomspaceProvider = Provider.of<RoomspaceProvider>(context, listen: false);
    final activeRoomspaceId = roomspaceProvider.getActiveRoomspaceId();
    
    // Allow loading analytics even without active roomspace (for personal expenses)
    setState(() {
      _isLoading = true;
      _error = null;
      _isUsingCache = false;
    });
    
    try {
      final summary = await _analyticsService.getSummary(
        roomspaceId: activeRoomspaceId, // null means personal expenses
      );
      
      // Check if we're using cached data
      final cacheKey = _analyticsService.getSummaryCacheKey(
        roomspaceId: activeRoomspaceId,
      );
      final cacheTimestamp = await _analyticsService.getCacheTimestamp(cacheKey);
      
      setState(() {
        _summary = summary;
        _isLoading = false;
        _lastUpdated = cacheTimestamp ?? DateTime.now();
        _isUsingCache = cacheTimestamp != null;
      });
    } catch (e) {
      // Try to get cache timestamp even on error
      final cacheKey = _analyticsService.getSummaryCacheKey(
        roomspaceId: activeRoomspaceId,
      );
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
    await _loadAnalytics();
  }
  
  @override
  Widget build(BuildContext context) {
    final roomspaceProvider = Provider.of<RoomspaceProvider>(context);
    final activeRoomspace = roomspaceProvider.activeRoomspace;
    
    return MobileScaffold(
      currentIndex: 3, // Analytics tab index
      showBottomNav: true,
      showAppBar: false, // Disable default AppBar
      body: SafeArea(
        child: Column(
          children: [
            // Header with roomspace name
            _buildHeader(activeRoomspace?.name),
            
            // Content
            Expanded(
              child: _buildAnalyticsView(),
            ),
          ],
        ),
      ),
    );
  }
  
  Widget _buildHeader(String? roomspaceName) {
    final roomspaceProvider = Provider.of<RoomspaceProvider>(context);
    final activeRoomspace = roomspaceProvider.activeRoomspace;
    
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
              Expanded(
                child: Text(
                  'Analytics',
                  style: Theme.of(context).textTheme.displayMedium?.copyWith(
                    color: Theme.of(context).colorScheme.primary,
                  ),
                ),
              ),
              IconButton(
                icon: const Icon(Icons.refresh_rounded),
                onPressed: _refreshAnalytics,
                tooltip: 'Refresh',
                padding: const EdgeInsets.all(12),
              ),
              const SizedBox(width: 8),
              GlobalRoomspaceSelector(
                onRoomspaceChanged: () {
                  _loadAnalytics();
                },
              ),
            ],
          ),
          
          // Cache indicator banner
          if (_isUsingCache && _lastUpdated != null)
            Container(
              margin: const EdgeInsets.only(top: 12),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
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
                  const SizedBox(width: 10),
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
  
  Widget _buildAnalyticsView() {
    final roomspaceProvider = Provider.of<RoomspaceProvider>(context, listen: false);
    final activeRoomspaceId = roomspaceProvider.getActiveRoomspaceId();
    
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
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              ),
            ),
          ],
        ),
      );
    }
    
    if (_summary == null) {
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
            _buildSummaryCard(_summary!),
            
            const SizedBox(height: 24),
            
            // Spending trends chart
            SpendingTrendsChart(roomspaceId: activeRoomspaceId),
            
            const SizedBox(height: 16),
            
            // Category breakdown
            CategoryBreakdownChart(categories: _summary!.topCategories),
            
            const SizedBox(height: 16),
            
            // Predictions
            PredictionsCard(roomspaceId: activeRoomspaceId),
            
            const SizedBox(height: 16),
            
            // Recommendations
            RecommendationsCard(roomspaceId: activeRoomspaceId),
            
            const SizedBox(height: 16),
            
            // Anomaly alerts
            AnomalyAlertCard(roomspaceId: activeRoomspaceId),
          ],
        ),
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
