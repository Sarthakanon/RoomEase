import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import '../../../models/analytics_models.dart';
import '../../../services/analytics_service.dart';
import 'skeleton_loader.dart';
import 'analytics_shared.dart';

class SpendingTrendsChart extends StatefulWidget {
  final String? roomspaceId;
  const SpendingTrendsChart({super.key, this.roomspaceId});

  @override
  State<SpendingTrendsChart> createState() => _SpendingTrendsChartState();
}

class _SpendingTrendsChartState extends State<SpendingTrendsChart> {
  final AnalyticsService _analyticsService = AnalyticsService();
  TimeRange _selectedRange = TimeRange.oneMonth;
  bool _isLoading = true;
  String? _error;
  TrendsResponse? _trendsData;

  @override
  void initState() {
    super.initState();
    _loadTrends();
  }

  Future<void> _loadTrends() async {
    if (!mounted) return;
    setState(() => _isLoading = true);
    try {
      final now = DateTime.now();
      final startDate = _getStartDate(now, _selectedRange);
      final trends = await _analyticsService.getTrends(
        roomspaceId: widget.roomspaceId,
        startDate: _formatDate(startDate),
        endDate: _formatDate(now),
        groupBy: _getGroupBy(_selectedRange),
      );
      if (mounted) {
        setState(() {
          _trendsData = trends;
          _isLoading = false;
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

  DateTime _getStartDate(DateTime now, TimeRange range) {
    switch (range) {
      case TimeRange.oneMonth: return DateTime(now.year, now.month - 1, now.day);
      case TimeRange.threeMonths: return DateTime(now.year, now.month - 3, now.day);
      case TimeRange.sixMonths: return DateTime(now.year, now.month - 6, now.day);
      case TimeRange.oneYear: return DateTime(now.year - 1, now.month, now.day);
    }
  }

  String _getGroupBy(TimeRange range) => range == TimeRange.oneYear ? 'month' : (range == TimeRange.oneMonth ? 'day' : 'week');
  String _formatDate(DateTime date) => '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';

  @override
  Widget build(BuildContext context) {
    return AnalyticsCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: AnalyticsSectionHeader(
                  icon: Icons.show_chart_rounded,
                  title: 'Spending Trends',
                ),
              ),
              const SizedBox(width: 8),
              Flexible(child: _buildTimeRangeSelector()),
            ],
          ),
          const SizedBox(height: 24),
          SizedBox(height: 220, child: _buildChartContent()),
        ],
      ),
    );
  }

  Widget _buildTimeRangeSelector() {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: TimeRange.values.map((r) => _rangeBtn(r)).toList(),
      ),
    );
  }

  Widget _rangeBtn(TimeRange range) {
    final isSelected = _selectedRange == range;
    final labels = {TimeRange.oneMonth: '1M', TimeRange.threeMonths: '3M', TimeRange.sixMonths: '6M', TimeRange.oneYear: '1Y'};
    return GestureDetector(
      onTap: () {
        if (isSelected) return;
        setState(() => _selectedRange = range);
        _loadTrends();
      },
      child: Container(
        margin: const EdgeInsets.only(left: 4),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(color: isSelected ? Colors.indigo : Colors.transparent, borderRadius: BorderRadius.circular(6)),
        child: Text(labels[range]!, style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: isSelected ? Colors.white : Colors.grey)),
      ),
    );
  }

  Widget _buildChartContent() {
    if (_isLoading) return const SkeletonLoader(height: 220, width: double.infinity);
    if (_error != null || _trendsData == null || _trendsData!.trends.isEmpty) {
      return Center(child: Text('No data for this period', style: TextStyle(color: Colors.grey.shade400, fontSize: 12)));
    }
    return _buildLineChart();
  }

  Widget _buildLineChart() {
    final trends = _trendsData!.trends;
    final spots = List.generate(trends.length, (i) => FlSpot(i.toDouble(), trends[i].amount));
    final amounts = trends.map((t) => t.amount).toList();
    final maxY = (amounts.reduce((a, b) => a > b ? a : b) * 1.2).clamp(100.0, double.infinity);

    return LineChart(
      LineChartData(
        gridData: const FlGridData(show: true, drawVerticalLine: false),
        titlesData: FlTitlesData(
          rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 22,
              getTitlesWidget: (value, _) {
                final i = value.toInt();
                if (i < 0 || i >= trends.length || i % (trends.length / 4).ceil() != 0) return const SizedBox();
                return Text(_formatLabel(trends[i].date), style: TextStyle(fontSize: 8, color: Colors.grey.shade400));
              },
            ),
          ),
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 45,
              getTitlesWidget: (value, _) => FittedBox(
                fit: BoxFit.scaleDown,
                child: Text('${value.toInt()}', style: TextStyle(fontSize: 8, color: Colors.grey.shade400)),
              ),
            ),
          ),
        ),
        borderData: FlBorderData(show: false),
        lineBarsData: [
          LineChartBarData(
            spots: spots,
            isCurved: true,
            color: Colors.indigo,
            barWidth: 3,
            isStrokeCapRound: true,
            dotData: const FlDotData(show: false),
            belowBarData: BarAreaData(show: true, gradient: LinearGradient(colors: [Colors.indigo.withOpacity(0.1), Colors.indigo.withOpacity(0)], begin: Alignment.topCenter, end: Alignment.bottomCenter)),
          ),
        ],
        lineTouchData: LineTouchData(
          enabled: true,
          touchTooltipData: LineTouchTooltipData(
            getTooltipColor: (_) => const Color(0xFF1A1A2E),
            getTooltipItems: (touchedSpots) => touchedSpots.map((s) => 
              LineTooltipItem(
                'Rs. ${s.y.toInt()}', 
                const TextStyle(
                  color: Colors.white, 
                  fontSize: 10, 
                  fontWeight: FontWeight.bold
                )
              )
            ).toList(),
          ),
          handleBuiltInTouches: true,
        ),
      ),
    );
  }

  String _formatLabel(String date) {
    try {
      final d = DateTime.parse(date);
      return '${d.month}/${d.day}';
    } catch (_) { return ''; }
  }
}

enum TimeRange { oneMonth, threeMonths, sixMonths, oneYear }
