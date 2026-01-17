import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import '../../../models/analytics_models.dart';
import '../../../services/analytics_service.dart';
import 'skeleton_loader.dart';

/// Interactive spending trends chart widget
/// 
/// Displays spending trends over time with:
/// - Line chart visualization
/// - Time range selector (1M, 3M, 6M, 1Y)
/// - Interactive tooltips
class SpendingTrendsChart extends StatefulWidget {
  final String? roomspaceId;
  
  const SpendingTrendsChart({
    super.key,
    this.roomspaceId,
  });

  @override
  State<SpendingTrendsChart> createState() => _SpendingTrendsChartState();
}

class _SpendingTrendsChartState extends State<SpendingTrendsChart> {
  final AnalyticsService _analyticsService = AnalyticsService();
  
  TimeRange _selectedRange = TimeRange.oneMonth;
  bool _isLoading = true;
  String? _error;
  TrendsResponse? _trendsData;
  DateTime? _cacheTimestamp;
  bool _isUsingCache = false;
  
  @override
  void initState() {
    super.initState();
    _loadTrends();
  }
  
  Future<void> _loadTrends() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    
    try {
      final now = DateTime.now();
      final startDate = _getStartDate(now, _selectedRange);
      final endDate = now;
      
      final trends = await _analyticsService.getTrends(
        roomspaceId: widget.roomspaceId,
        startDate: _formatDate(startDate),
        endDate: _formatDate(endDate),
        groupBy: _getGroupBy(_selectedRange),
      );
      
      setState(() {
        _trendsData = trends;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }
  
  DateTime _getStartDate(DateTime now, TimeRange range) {
    switch (range) {
      case TimeRange.oneMonth:
        return DateTime(now.year, now.month - 1, now.day);
      case TimeRange.threeMonths:
        return DateTime(now.year, now.month - 3, now.day);
      case TimeRange.sixMonths:
        return DateTime(now.year, now.month - 6, now.day);
      case TimeRange.oneYear:
        return DateTime(now.year - 1, now.month, now.day);
    }
  }
  
  String _getGroupBy(TimeRange range) {
    switch (range) {
      case TimeRange.oneMonth:
        return 'day';
      case TimeRange.threeMonths:
        return 'week';
      case TimeRange.sixMonths:
        return 'week';
      case TimeRange.oneYear:
        return 'month';
    }
  }
  
  String _formatDate(DateTime date) {
    return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
  }
  
  void _onRangeChanged(TimeRange range) {
    setState(() {
      _selectedRange = range;
    });
    _loadTrends();
  }
  
  @override
  Widget build(BuildContext context) {
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
            // Header with title and time range selector
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Icon(
                      Icons.show_chart_rounded,
                      color: Theme.of(context).colorScheme.primary,
                      size: 24,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Spending Trends',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 16),
            
            // Time range selector
            _buildTimeRangeSelector(),
            const SizedBox(height: 20),
            
            // Chart content
            SizedBox(
              height: 250,
              child: _buildChartContent(),
            ),
          ],
        ),
      ),
    );
  }
  
  Widget _buildTimeRangeSelector() {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          _buildRangeButton('1M', TimeRange.oneMonth),
          const SizedBox(width: 8),
          _buildRangeButton('3M', TimeRange.threeMonths),
          const SizedBox(width: 8),
          _buildRangeButton('6M', TimeRange.sixMonths),
          const SizedBox(width: 8),
          _buildRangeButton('1Y', TimeRange.oneYear),
        ],
      ),
    );
  }
  
  Widget _buildRangeButton(String label, TimeRange range) {
    final isSelected = _selectedRange == range;
    
    return InkWell(
      onTap: () => _onRangeChanged(range),
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected
              ? Theme.of(context).colorScheme.primary
              : Colors.grey[200],
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected ? Colors.white : Colors.grey[700],
            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
          ),
        ),
      ),
    );
  }
  
  Widget _buildChartContent() {
    if (_isLoading) {
      return Padding(
        padding: const EdgeInsets.all(20.0),
        child: SkeletonLoader(
          height: 210,
          width: double.infinity,
          borderRadius: BorderRadius.circular(12),
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
              size: 48,
              color: Colors.grey[400],
            ),
            const SizedBox(height: 8),
            Text(
              'Failed to load trends',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Colors.grey[600],
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Check your connection and try again',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Colors.grey[500],
              ),
            ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: _loadTrends,
              icon: const Icon(Icons.refresh_rounded, size: 18),
              label: const Text('Retry'),
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              ),
            ),
          ],
        ),
      );
    }
    
    if (_trendsData == null || _trendsData!.trends.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.show_chart_rounded,
              size: 48,
              color: Colors.grey[400],
            ),
            const SizedBox(height: 8),
            Text(
              'No spending data available',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Colors.grey[600],
              ),
            ),
          ],
        ),
      );
    }
    
    return _buildLineChart();
  }
  
  Widget _buildLineChart() {
    final trends = _trendsData!.trends;
    
    // Convert trends to chart spots
    final spots = <FlSpot>[];
    for (int i = 0; i < trends.length; i++) {
      spots.add(FlSpot(i.toDouble(), trends[i].amount));
    }
    
    // Calculate min and max for Y axis
    final amounts = trends.map((t) => t.amount).toList();
    final minY = amounts.isEmpty ? 0.0 : amounts.reduce((a, b) => a < b ? a : b);
    final maxY = amounts.isEmpty ? 100.0 : amounts.reduce((a, b) => a > b ? a : b);
    
    // Add padding to Y axis
    final yPadding = (maxY - minY) * 0.1;
    final adjustedMinY = (minY - yPadding).clamp(0.0, double.infinity);
    final adjustedMaxY = maxY + yPadding;
    
    return LineChart(
      LineChartData(
        gridData: FlGridData(
          show: true,
          drawVerticalLine: false,
          horizontalInterval: (adjustedMaxY - adjustedMinY) / 5,
          getDrawingHorizontalLine: (value) {
            return FlLine(
              color: Colors.grey[300],
              strokeWidth: 1,
            );
          },
        ),
        titlesData: FlTitlesData(
          show: true,
          rightTitles: const AxisTitles(
            sideTitles: SideTitles(showTitles: false),
          ),
          topTitles: const AxisTitles(
            sideTitles: SideTitles(showTitles: false),
          ),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 30,
              interval: _getBottomInterval(trends.length),
              getTitlesWidget: (value, meta) {
                final index = value.toInt();
                if (index < 0 || index >= trends.length) {
                  return const Text('');
                }
                
                return Padding(
                  padding: const EdgeInsets.only(top: 8.0),
                  child: Text(
                    _formatBottomLabel(trends[index].date),
                    style: TextStyle(
                      color: Colors.grey[600],
                      fontSize: 10,
                    ),
                  ),
                );
              },
            ),
          ),
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 50,
              interval: (adjustedMaxY - adjustedMinY) / 5,
              getTitlesWidget: (value, meta) {
                return Text(
                  'Rs. ${value.toInt()}',
                  style: TextStyle(
                    color: Colors.grey[600],
                    fontSize: 10,
                  ),
                );
              },
            ),
          ),
        ),
        borderData: FlBorderData(
          show: true,
          border: Border(
            bottom: BorderSide(color: Colors.grey[300]!),
            left: BorderSide(color: Colors.grey[300]!),
          ),
        ),
        minX: 0,
        maxX: (trends.length - 1).toDouble(),
        minY: adjustedMinY,
        maxY: adjustedMaxY,
        lineBarsData: [
          LineChartBarData(
            spots: spots,
            isCurved: true,
            color: Theme.of(context).colorScheme.primary,
            barWidth: 3,
            isStrokeCapRound: true,
            dotData: FlDotData(
              show: true,
              getDotPainter: (spot, percent, barData, index) {
                return FlDotCirclePainter(
                  radius: 4,
                  color: Theme.of(context).colorScheme.primary,
                  strokeWidth: 2,
                  strokeColor: Colors.white,
                );
              },
            ),
            belowBarData: BarAreaData(
              show: true,
              color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.1),
            ),
          ),
        ],
        lineTouchData: LineTouchData(
          enabled: true,
          touchTooltipData: LineTouchTooltipData(
            getTooltipItems: (touchedSpots) {
              return touchedSpots.map((spot) {
                final index = spot.x.toInt();
                if (index < 0 || index >= trends.length) {
                  return null;
                }
                
                final trend = trends[index];
                return LineTooltipItem(
                  '${_formatTooltipDate(trend.date)}\nRs. ${trend.amount.toStringAsFixed(2)}',
                  const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                  ),
                );
              }).toList();
            },
          ),
        ),
      ),
    );
  }
  
  double _getBottomInterval(int dataPoints) {
    if (dataPoints <= 7) return 1;
    if (dataPoints <= 14) return 2;
    if (dataPoints <= 30) return 5;
    return 10;
  }
  
  String _formatBottomLabel(String date) {
    try {
      final parsedDate = DateTime.parse(date);
      
      switch (_selectedRange) {
        case TimeRange.oneMonth:
          return parsedDate.day.toString();
        case TimeRange.threeMonths:
        case TimeRange.sixMonths:
          return '${parsedDate.month}/${parsedDate.day}';
        case TimeRange.oneYear:
          return _getMonthAbbr(parsedDate.month);
      }
    } catch (e) {
      return '';
    }
  }
  
  String _formatTooltipDate(String date) {
    try {
      final parsedDate = DateTime.parse(date);
      return '${_getMonthAbbr(parsedDate.month)} ${parsedDate.day}, ${parsedDate.year}';
    } catch (e) {
      return date;
    }
  }
  
  String _getMonthAbbr(int month) {
    const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 
                    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    return months[month - 1];
  }
}

/// Time range options for the chart
enum TimeRange {
  oneMonth,
  threeMonths,
  sixMonths,
  oneYear,
}
