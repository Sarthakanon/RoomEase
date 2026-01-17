import 'package:flutter/material.dart';
import '../../../models/analytics_models.dart';
import '../../../services/analytics_service.dart';
import 'skeleton_loader.dart';

/// Anomaly alerts card widget
/// 
/// Displays flagged spending anomalies with:
/// - Anomaly explanations
/// - "Mark as Normal" action
/// - Visual indicators
class AnomalyAlertCard extends StatefulWidget {
  final String? roomspaceId;
  
  const AnomalyAlertCard({
    super.key,
    this.roomspaceId,
  });

  @override
  State<AnomalyAlertCard> createState() => _AnomalyAlertCardState();
}

class _AnomalyAlertCardState extends State<AnomalyAlertCard> {
  final AnalyticsService _analyticsService = AnalyticsService();
  
  bool _isLoading = true;
  String? _error;
  AnomaliesResponse? _anomalies;
  final Set<int> _dismissedAnomalies = {};
  
  @override
  void initState() {
    super.initState();
    _loadAnomalies();
  }
  
  Future<void> _loadAnomalies() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    
    try {
      final anomalies = await _analyticsService.getAnomalies(
        roomspaceId: widget.roomspaceId,
      );
      
      setState(() {
        _anomalies = anomalies;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }
  
  void _markAsNormal(Anomaly anomaly) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Mark as Normal'),
        content: const Text(
          'Are you sure this expense is normal? This will help improve future anomaly detection.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _dismissAnomaly(anomaly);
            },
            child: const Text('Mark as Normal'),
          ),
        ],
      ),
    );
  }
  
  void _dismissAnomaly(Anomaly anomaly) {
    setState(() {
      _dismissedAnomalies.add(anomaly.expenseId);
    });
    
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text('Anomaly marked as normal'),
        action: SnackBarAction(
          label: 'Undo',
          onPressed: () {
            setState(() {
              _dismissedAnomalies.remove(anomaly.expenseId);
            });
          },
        ),
      ),
    );
    
    // TODO: Send acknowledgment to backend
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
            // Header
            Row(
              children: [
                Icon(
                  Icons.warning_amber_rounded,
                  color: Colors.orange,
                  size: 24,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Unusual Spending',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                if (_anomalies != null && _anomalies!.count > 0)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.orange,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      '${_anomalies!.count}',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 16),
            
            // Content
            _buildContent(),
          ],
        ),
      ),
    );
  }
  
  Widget _buildContent() {
    if (_isLoading) {
      return Column(
        children: [
          const ListItemSkeletonLoader(),
        ],
      );
    }
    
    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            children: [
              Icon(
                Icons.error_outline_rounded,
                size: 48,
                color: Colors.grey[400],
              ),
              const SizedBox(height: 8),
              Text(
                'Failed to load anomalies',
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
                onPressed: _loadAnomalies,
                icon: const Icon(Icons.refresh_rounded, size: 18),
                label: const Text('Retry'),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                ),
              ),
            ],
          ),
        ),
      );
    }
    
    final visibleAnomalies = _anomalies?.anomalies
        .where((a) => !_dismissedAnomalies.contains(a.expenseId))
        .toList() ?? [];
    
    if (visibleAnomalies.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            children: [
              Icon(
                Icons.check_circle_outline_rounded,
                size: 48,
                color: Colors.green[400],
              ),
              const SizedBox(height: 8),
              Text(
                'No unusual spending detected',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Colors.grey[600],
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Your spending looks normal',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Colors.grey[500],
                ),
              ),
            ],
          ),
        ),
      );
    }
    
    return Column(
      children: visibleAnomalies.map((anomaly) {
        return _buildAnomalyItem(anomaly);
      }).toList(),
    );
  }
  
  Widget _buildAnomalyItem(Anomaly anomaly) {
    final severityColor = _getSeverityColor(anomaly.anomalyScore);
    
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: severityColor.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: severityColor.withValues(alpha: 0.3),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header with severity indicator
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: severityColor,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.warning_rounded,
                  color: Colors.white,
                  size: 16,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _getCategoryDisplayName(anomaly.category),
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      _formatDate(anomaly.date),
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Colors.grey[600],
                      ),
                    ),
                  ],
                ),
              ),
              Text(
                'Rs. ${anomaly.amount.toStringAsFixed(2)}',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: severityColor,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          
          // Reason
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.info_outline_rounded,
                  size: 20,
                  color: severityColor,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    anomaly.reason,
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          
          // Comparison with average
          Row(
            children: [
              Expanded(
                child: _buildComparisonChip(
                  'Category Average',
                  'Rs. ${anomaly.categoryAverage.toStringAsFixed(2)}',
                  Colors.blue,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _buildComparisonChip(
                  'Difference',
                  '+Rs. ${(anomaly.amount - anomaly.categoryAverage).toStringAsFixed(2)}',
                  Colors.red,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          
          // Actions
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              TextButton.icon(
                onPressed: () => _markAsNormal(anomaly),
                icon: const Icon(Icons.check_circle_outline_rounded, size: 18),
                label: const Text('Mark as Normal'),
                style: TextButton.styleFrom(
                  foregroundColor: Colors.green,
                ),
              ),
              const SizedBox(width: 8),
              TextButton.icon(
                onPressed: () {
                  // TODO: Navigate to expense details
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('View expense details coming soon'),
                    ),
                  );
                },
                icon: const Icon(Icons.visibility_outlined, size: 18),
                label: const Text('View Details'),
                style: TextButton.styleFrom(
                  foregroundColor: Theme.of(context).colorScheme.primary,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
  
  Widget _buildComparisonChip(String label, String value, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 10,
              color: Colors.grey[600],
            ),
          ),
          const SizedBox(height: 2),
          Text(
            value,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
  
  Color _getSeverityColor(double anomalyScore) {
    if (anomalyScore >= 0.8) {
      return Colors.red;
    } else if (anomalyScore >= 0.5) {
      return Colors.orange;
    } else {
      return Colors.amber;
    }
  }
  
  String _getCategoryDisplayName(String category) {
    if (category.isEmpty) return 'General';
    
    return category
        .split('_')
        .map((word) => word.isEmpty ? '' : word[0].toUpperCase() + word.substring(1))
        .join(' ');
  }
  
  String _formatDate(String date) {
    try {
      final parsedDate = DateTime.parse(date);
      return '${_getMonthName(parsedDate.month)} ${parsedDate.day}, ${parsedDate.year}';
    } catch (e) {
      return date;
    }
  }
  
  String _getMonthName(int month) {
    const months = [
      'January', 'February', 'March', 'April', 'May', 'June',
      'July', 'August', 'September', 'October', 'November', 'December'
    ];
    return months[month - 1];
  }
}
