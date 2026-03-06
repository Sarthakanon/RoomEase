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

  AnalyticsSummary? _summary;
  String? _currentRoomspaceId;

  @override
  void initState() {
    super.initState();
    _loadAnalytics();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final roomspaceProvider = Provider.of<RoomspaceProvider>(context);
    final activeRoomspaceId = roomspaceProvider.getActiveRoomspaceId();

    if (activeRoomspaceId != _currentRoomspaceId && activeRoomspaceId != null) {
      _currentRoomspaceId = activeRoomspaceId;
      _loadAnalytics();
    }
  }

  Future<void> _loadAnalytics() async {
    if (!mounted) return;
    final roomspaceProvider = Provider.of<RoomspaceProvider>(context, listen: false);
    final activeRoomspaceId = roomspaceProvider.getActiveRoomspaceId();

    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final summary = await _analyticsService.getSummary(roomspaceId: activeRoomspaceId);
      final cacheKey = _analyticsService.getSummaryCacheKey(roomspaceId: activeRoomspaceId);
      final cacheTimestamp = await _analyticsService.getCacheTimestamp(cacheKey);

      if (mounted) {
        setState(() {
          _summary = summary;
          _isLoading = false;
          _lastUpdated = cacheTimestamp ?? DateTime.now();
          _isUsingCache = cacheTimestamp != null;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString();
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final roomspaceProvider = Provider.of<RoomspaceProvider>(context);
    final activeRoomspace = roomspaceProvider.activeRoomspace;

    return MobileScaffold(
      currentIndex: 3,
      showBottomNav: true,
      showAppBar: false,
      body: SafeArea(
        child: Container(
          color: const Color(0xFFF8F9FA),
          child: Column(
            children: [
              _buildHeader(activeRoomspace?.name),
              Expanded(child: _buildAnalyticsView()),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(String? roomspaceName) {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 16, 12, 16),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.only(
          bottomLeft: Radius.circular(24),
          bottomRight: Radius.circular(24),
        ),
        boxShadow: [
          BoxShadow(color: Color(0x0A000000), blurRadius: 10, offset: Offset(0, 4)),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text('Analytics',
                      style: TextStyle(fontWeight: FontWeight.w900, color: Color(0xFF1A1A2E), fontSize: 22, letterSpacing: -0.5)),
                ),
                if (roomspaceName != null)
                  Text(roomspaceName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(color: Colors.grey.shade500, fontSize: 13, fontWeight: FontWeight.w600)),
              ],
            ),
          ),
          const SizedBox(width: 8),
          const GlobalRoomspaceSelector(),
        ],
      ),
    );
  }

  Widget _buildAnalyticsView() {
    final roomspaceProvider = Provider.of<RoomspaceProvider>(context, listen: false);
    final activeRoomspaceId = roomspaceProvider.getActiveRoomspaceId();

    if (_isLoading) {
      return ListView(
        padding: const EdgeInsets.all(16),
        children: const [
          SummarySkeletonLoader(),
          SizedBox(height: 16),
          ChartSkeletonLoader(),
          SizedBox(height: 16),
          ListItemSkeletonLoader(),
          ListItemSkeletonLoader(),
        ],
      );
    }

    if (_error != null || _summary == null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.query_stats_rounded, size: 64, color: Colors.indigo.withOpacity(0.1)),
              const SizedBox(height: 16),
              Text('No analytics found',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.grey.shade400, fontSize: 16, fontWeight: FontWeight.w600)),
              const SizedBox(height: 8),
              TextButton(onPressed: _loadAnalytics, child: const Text('Retry Refresh')),
            ],
          ),
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadAnalytics,
      color: Colors.indigo,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildHealthScore(_summary!),
            const SizedBox(height: 20),
            _buildSmartInsightBubble(_summary!),
            const SizedBox(height: 24),
            _buildMetricsGrid(_summary!),
            const SizedBox(height: 24),
            SpendingTrendsChart(roomspaceId: activeRoomspaceId),
            const SizedBox(height: 24),
            CategoryBreakdownChart(categories: _summary!.topCategories),
            const SizedBox(height: 24),
            RecommendationsCard(roomspaceId: activeRoomspaceId),
            const SizedBox(height: 24),
            PredictionsCard(roomspaceId: activeRoomspaceId),
            const SizedBox(height: 24),
            AnomalyAlertCard(roomspaceId: activeRoomspaceId),
          ],
        ),
      ),
    );
  }

  Widget _buildHealthScore(AnalyticsSummary summary) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isUltraNarrow = screenWidth < 340;

    double score = 75.0;
    if (summary.spendingTrend.toLowerCase() == 'increasing') score -= 15;
    if (summary.totalSpent > summary.predictedNextMonth) score += 10;
    score = score.clamp(5, 100);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 28),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A2E),
        borderRadius: BorderRadius.circular(28),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.12), blurRadius: 20, offset: const Offset(0, 8)),
        ],
      ),
      child: Wrap(
        alignment: WrapAlignment.spaceBetween,
        crossAxisAlignment: WrapCrossAlignment.center,
        spacing: 16,
        runSpacing: 20,
        children: [
          SizedBox(
            width: isUltraNarrow ? double.infinity : screenWidth * 0.48,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('FINANCIAL HEALTH',
                    style: TextStyle(color: Colors.white38, fontSize: 10, fontWeight: FontWeight.w900, letterSpacing: 1.5)),
                const SizedBox(height: 6),
                FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(_getHealthStatus(score),
                      style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.w900, letterSpacing: -0.5)),
                ),
                const SizedBox(height: 18),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.08), borderRadius: BorderRadius.circular(12)),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.auto_awesome_rounded, color: Colors.amber, size: 14),
                      const SizedBox(width: 8),
                      const Flexible(
                        child: Text('AI GENERATED SCORE',
                            style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w800, letterSpacing: 0.5)),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          _CircularProgressWithText(score: score),
        ],
      ),
    );
  }

  Widget _buildSmartInsightBubble(AnalyticsSummary summary) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFEEEEF2)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: const BoxDecoration(color: Color(0xFFFFF8E1), shape: BoxShape.circle),
            child: const Icon(Icons.auto_awesome_rounded, color: Colors.orange, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('AI OBSERVATION',
                    style: TextStyle(fontSize: 9, fontWeight: FontWeight.w900, color: Colors.grey, letterSpacing: 1.0)),
                const SizedBox(height: 4),
                Text(_generateDynamicInsight(summary),
                    style: const TextStyle(fontSize: 13, color: Color(0xFF1A1A2E), fontWeight: FontWeight.w600, height: 1.5)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMetricsGrid(AnalyticsSummary summary) {
    return LayoutBuilder(builder: (context, constraints) {
      final crossAxisCount = constraints.maxWidth > 500 ? 3 : 2;
      final childAspectRatio = constraints.maxWidth < 360 ? 1.2 : 1.45;

      return GridView.count(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        crossAxisCount: crossAxisCount,
        childAspectRatio: childAspectRatio,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
        children: [
          _buildStatCard('Total Spent', 'Rs. ${summary.totalSpent.toInt()}', Icons.account_balance_wallet_rounded,
              Colors.indigoAccent),
          _buildStatCard('Next Prediction', 'Rs. ${summary.predictedNextMonth.toInt()}', Icons.insights_rounded,
              Colors.tealAccent.shade700),
          _buildStatCard('Estimated Save', 'Rs. ${summary.savingsPotential.toInt()}', Icons.eco_rounded,
              Colors.greenAccent.shade700),
          _buildStatCard('Trend Status', summary.spendingTrend.toUpperCase(), Icons.trending_up_rounded, Colors.orangeAccent),
        ],
      );
    });
  }

  Widget _buildStatCard(String title, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFEEEEF2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Container(
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(8)),
            child: Icon(icon, color: color, size: 16),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(value,
                    style:
                        const TextStyle(fontWeight: FontWeight.w900, fontSize: 16, color: Color(0xFF1A1A2E), letterSpacing: -0.5)),
              ),
              const SizedBox(height: 2),
              Text(title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(color: Colors.grey.shade400, fontSize: 9, fontWeight: FontWeight.w700)),
            ],
          ),
        ],
      ),
    );
  }

  String _getHealthStatus(double score) {
    if (score >= 80) return 'Top Tier Savvy';
    if (score >= 60) return 'Stable Hands';
    if (score >= 40) return 'Needs Revision';
    return 'Action Required';
  }

  String _generateDynamicInsight(AnalyticsSummary summary) {
    if (summary.spendingTrend.toLowerCase() == 'increasing') {
      final topCat = summary.topCategories.isNotEmpty ? summary.topCategories.first.category.replaceAll('_', ' ') : 'spending';
      return 'Spending is ramping up. Review $topCat to stay on track.';
    }
    if (summary.savingsPotential > 1000) {
      return 'AI identified Rs. ${summary.savingsPotential.toInt()} in potential savings this month. Check Smart Suggestions below.';
    }
    return 'Your financial flow looks balanced. Consider setting up a rainy day fund with current surpluses.';
  }
}

class _CircularProgressWithText extends StatelessWidget {
  final double score;
  const _CircularProgressWithText({required this.score});

  @override
  Widget build(BuildContext context) {
    Color scoreColor = Colors.redAccent;
    if (score >= 80) {
      scoreColor = Colors.greenAccent.shade400;
    } else if (score >= 60) {
      scoreColor = Colors.blueAccent.shade200;
    } else if (score >= 40) {
      scoreColor = Colors.orangeAccent;
    }

    return Stack(
      alignment: Alignment.center,
      children: [
        SizedBox(
          height: 70,
          width: 70,
          child: CircularProgressIndicator(
            value: score / 100,
            strokeWidth: 7,
            backgroundColor: Colors.white.withOpacity(0.05),
            color: scoreColor,
            strokeCap: StrokeCap.round,
          ),
        ),
        Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('${score.toInt()}',
                style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w900, height: 1.0)),
            const Text('%', style: TextStyle(color: Colors.white24, fontSize: 10, fontWeight: FontWeight.bold)),
          ],
        ),
      ],
    );
  }
}
