import 'package:flutter/material.dart';
import '../../../models/analytics_models.dart';
import '../../../services/analytics_service.dart';
import 'skeleton_loader.dart';

class AnomalyAlertCard extends StatefulWidget {
  final String? roomspaceId;
  const AnomalyAlertCard({super.key, this.roomspaceId});

  @override
  State<AnomalyAlertCard> createState() => _AnomalyAlertCardState();
}

class _AnomalyAlertCardState extends State<AnomalyAlertCard> {
  final AnalyticsService _analyticsService = AnalyticsService();
  bool _isLoading = true;
  String? _error;
  AnomaliesResponse? _anomalies;
  final Set<int> _dismissed = {};

  @override
  void initState() {
    super.initState();
    _loadAnomalies();
  }

  @override
  void didUpdateWidget(covariant AnomalyAlertCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.roomspaceId != widget.roomspaceId) {
      _loadAnomalies();
    }
  }

  Future<void> _loadAnomalies() async {
    if (!mounted) return;
    setState(() => _isLoading = true);
    try {
      final res = await _analyticsService.getAnomalies(roomspaceId: widget.roomspaceId);
      if (mounted) {
        setState(() {
          _anomalies = res;
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

  @override
  Widget build(BuildContext context) {
    final visible = _anomalies?.anomalies.where((a) => !_dismissed.contains(a.expenseId)).toList() ?? [];
    if (visible.isEmpty && !_isLoading) return const SizedBox();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Spending Anomalies',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: Color(0xFF1A1A2E), letterSpacing: -0.5)),
        const SizedBox(height: 16),
        _buildContent(visible),
      ],
    );
  }

  Widget _buildContent(List<Anomaly> visible) {
    if (_isLoading) return const Column(children: [ListItemSkeletonLoader()]);
    if (_error != null) return const SizedBox();

    return Column(
      children: visible.map(_buildItem).toList(),
    );
  }

  Widget _buildItem(Anomaly anomaly) {
    final color = anomaly.anomalyScore >= 0.8 ? Colors.redAccent : Colors.orangeAccent;
    final diff = anomaly.amount - anomaly.categoryAverage;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.2)),
        boxShadow: [
          BoxShadow(color: color.withValues(alpha: 0.04), blurRadius: 12, offset: const Offset(0, 4)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(color: color.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(8)),
                child: Text('UNUSUAL SPEND',
                    style: TextStyle(fontSize: 9, fontWeight: FontWeight.w900, color: color, letterSpacing: 1.0)),
              ),
              const Spacer(),
              Text('Score: ${(anomaly.anomalyScore * 100).toInt()}%',
                  style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.grey.shade400)),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(anomaly.category.toUpperCase().replaceAll('_', ' '), 
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: Colors.grey, letterSpacing: 0.5)),
                    const SizedBox(height: 4),
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text('Rs. ${anomaly.amount.toInt()}', 
                          style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: Color(0xFF1A1A2E), letterSpacing: -0.5)),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text('+Rs. ${diff.toInt()}', 
                        style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w900, color: Colors.redAccent)),
                  ),
                  const Text('Above Avg', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: Colors.grey)),
                ],
              ),
            ],
          ),
          const SizedBox(height: 14),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(color: const Color(0xFFF8F9FA), borderRadius: BorderRadius.circular(12)),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.info_outline_rounded, size: 14, color: Colors.grey.shade400),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(anomaly.reason, 
                      style: TextStyle(fontSize: 12, color: Colors.grey.shade600, height: 1.4, fontStyle: FontStyle.italic)),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
