import 'package:flutter/material.dart';
import '../../../models/analytics_models.dart';
import '../../../services/analytics_service.dart';
import 'skeleton_loader.dart';
import 'analytics_shared.dart';

class PredictionsCard extends StatefulWidget {
  final String? roomspaceId;
  const PredictionsCard({super.key, this.roomspaceId});

  @override
  State<PredictionsCard> createState() => _PredictionsCardState();
}

class _PredictionsCardState extends State<PredictionsCard> {
  final AnalyticsService _analyticsService = AnalyticsService();
  bool _isLoading = true;
  String? _error;
  PredictionResult? _predictions;

  @override
  void initState() {
    super.initState();
    _loadPredictions();
  }

  Future<void> _loadPredictions() async {
    if (!mounted) return;
    setState(() => _isLoading = true);
    try {
      final res = await _analyticsService.getPredictions(roomspaceId: widget.roomspaceId);
      if (mounted) {
        setState(() {
          _predictions = res;
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
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Future Projections',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: Color(0xFF1A1A2E), letterSpacing: -0.5)),
        const SizedBox(height: 16),
        _buildContent(),
      ],
    );
  }

  Widget _buildContent() {
    if (_isLoading) return const ChartSkeletonLoader();
    if (_error != null || _predictions == null) return const SizedBox();

    if (_predictions!.insufficientData) {
      return Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: const Color(0xFFEEEEF2)),
        ),
        child: Column(
          children: [
            const Icon(Icons.auto_graph_rounded, color: Colors.indigo, size: 36),
            const SizedBox(height: 12),
            const Text('Evolving Insights',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: Color(0xFF1A1A2E))),
            const SizedBox(height: 8),
            Text(_predictions!.message ?? 'AI is learning your spending habits. Keep tracking for precise forecasting.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.grey.shade500, fontSize: 12, height: 1.5)),
            const SizedBox(height: 20),
            ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: LinearProgressIndicator(
                value: (_predictions!.dataDays / 30).clamp(0.0, 1.0),
                backgroundColor: Colors.indigo.withOpacity(0.05),
                color: Colors.indigo,
                minHeight: 8,
              ),
            ),
            const SizedBox(height: 8),
            Text('${_predictions!.dataDays}/30 days collected', 
                style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: Colors.indigo.withOpacity(0.5))),
          ],
        ),
      );
    }

    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: _predictions!.predictions.length,
      itemBuilder: (context, index) => _buildPredictionItem(_predictions!.predictions[index]),
    );
  }

  Widget _buildPredictionItem(SpendingPrediction pred) {
    final change = ((pred.predictedAmount - pred.historicalAvg) / (pred.historicalAvg > 0 ? pred.historicalAvg : 1)) * 100;
    
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFEEEEF2)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(color: const Color(0xFFF8F9FF), borderRadius: BorderRadius.circular(12)),
            child: Icon(_getIcon(pred.category), color: Colors.indigo, size: 20),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(pred.category.toUpperCase().replaceAll('_', ' '), 
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 9, fontWeight: FontWeight.w900, color: Colors.grey.shade400, letterSpacing: 1.2)),
                FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text('Rs. ${pred.predictedAmount.toInt()}', 
                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: Color(0xFF1A1A2E))),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(change >= 0 ? '+${change.toStringAsFixed(1)}%' : '${change.toStringAsFixed(1)}%',
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.w900, color: change >= 0 ? Colors.redAccent : Colors.greenAccent.shade700)),
              const Text('vs Last Month', style: TextStyle(fontSize: 8, fontWeight: FontWeight.w600, color: Colors.grey)),
            ],
          ),
        ],
      ),
    );
  }

  IconData _getIcon(String cat) {
    final c = cat.toLowerCase();
    if (c.contains('food')) return Icons.restaurant;
    if (c.contains('bill')) return Icons.receipt_long;
    if (c.contains('travel')) return Icons.commute;
    return Icons.bubble_chart_rounded;
  }
}
