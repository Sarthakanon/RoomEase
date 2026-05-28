import 'package:flutter/material.dart';
import '../../../models/analytics_models.dart';
import '../../../services/analytics_service.dart';
import 'skeleton_loader.dart';

class RecommendationsCard extends StatefulWidget {
  final String? roomspaceId;
  const RecommendationsCard({super.key, this.roomspaceId});

  @override
  State<RecommendationsCard> createState() => _RecommendationsCardState();
}

class _RecommendationsCardState extends State<RecommendationsCard> {
  final AnalyticsService _analyticsService = AnalyticsService();
  bool _isLoading = true;
  String? _error;
  RecommendationsResponse? _recommendations;

  @override
  void initState() {
    super.initState();
    _loadRecommendations();
  }

  @override
  void didUpdateWidget(covariant RecommendationsCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.roomspaceId != widget.roomspaceId) {
      _loadRecommendations();
    }
  }

  Future<void> _loadRecommendations() async {
    if (!mounted) return;
    setState(() => _isLoading = true);
    try {
      final recs = await _analyticsService.getRecommendations(roomspaceId: widget.roomspaceId);
      if (mounted) {
        setState(() {
          _recommendations = recs;
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
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text('Smart Suggestions',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: Color(0xFF1A1A2E), letterSpacing: -0.5)),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(color: Colors.indigo.shade50.withValues(alpha: 0.5), borderRadius: BorderRadius.circular(12)),
              child: const Text('AI POWERED',
                  style: TextStyle(fontSize: 9, fontWeight: FontWeight.w900, color: Colors.indigo, letterSpacing: 0.8)),
            ),
          ],
        ),
        const SizedBox(height: 16),
        _buildContent(),
      ],
    );
  }

  Widget _buildContent() {
    if (_isLoading) return const ListItemSkeletonLoader();
    if (_error != null || _recommendations == null || _recommendations!.recommendations.isEmpty) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 32, horizontal: 24),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: const Color(0xFFEEEEF2)),
        ),
        child: Column(
          children: [
            Icon(Icons.auto_awesome_outlined, color: Colors.indigo.withValues(alpha: 0.1), size: 48),
            const SizedBox(height: 16),
            const Text('No new insights', style: TextStyle(fontWeight: FontWeight.w700, color: Color(0xFF1A1A2E))),
            const SizedBox(height: 4),
            Text('We\'ll alert you when AI finds saving opportunities.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.grey.shade400, fontSize: 13, height: 1.4)),
          ],
        ),
      );
    }

    return Column(
      children: _recommendations!.recommendations.map(_buildItem).toList(),
    );
  }

  Widget _buildItem(Recommendation rec) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: const Color(0xFFEEEEF2)),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.02), blurRadius: 15, offset: const Offset(0, 4)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _buildPriorityBadge(rec.priority),
              const Expanded(child: SizedBox()),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Colors.green.shade400, Colors.green.shade600],
                  ),
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.green.withValues(alpha: 0.3),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.savings_outlined, color: Colors.white, size: 14),
                    const SizedBox(width: 4),
                    Text(
                      'Save Rs. ${rec.potentialSavings.toInt()}',
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      const Color(0xFFEFF1FF),
                      Colors.indigo.shade50,
                    ],
                  ),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: Colors.indigo.withValues(alpha: 0.2),
                    width: 1,
                  ),
                ),
                child: Icon(_getCategoryIcon(rec.category), color: Colors.indigo, size: 22),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      rec.category.toUpperCase(),
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w900,
                        color: Colors.grey.shade500,
                        letterSpacing: 0.8,
                      ),
                    ),
                    const SizedBox(height: 8),
                    // Main suggestion as bullet point
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          margin: const EdgeInsets.only(top: 6),
                          width: 6,
                          height: 6,
                          decoration: BoxDecoration(
                            color: Colors.indigo,
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            rec.description,
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: Color(0xFF1A1A2E),
                              height: 1.5,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    // Spending comparison
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF8F9FA),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: Colors.grey.shade200,
                          width: 1,
                        ),
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Current',
                                  style: TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.w600,
                                    color: Colors.grey.shade600,
                                    letterSpacing: 0.3,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  'Rs. ${rec.currentSpending.toInt()}',
                                  style: TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w900,
                                    color: Colors.red.shade600,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              shape: BoxShape.circle,
                            ),
                            child: Icon(
                              Icons.arrow_forward_rounded,
                              size: 16,
                              color: Colors.grey.shade600,
                            ),
                          ),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                Text(
                                  'Target',
                                  style: TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.w600,
                                    color: Colors.grey.shade600,
                                    letterSpacing: 0.3,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  'Rs. ${rec.suggestedLimit.toInt()}',
                                  style: TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w900,
                                    color: Colors.green.shade600,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(
                          Icons.info_outline_rounded,
                          size: 14,
                          color: Colors.grey.shade600,
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            'Target value is an approximate AI estimate, not an exact amount.',
                            style: TextStyle(
                              fontSize: 11,
                              color: Colors.grey.shade600,
                              height: 1.35,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildPriorityBadge(int priority) {
    Color color = Colors.blueGrey;
    String label = 'LOW';
    if (priority == 1) {
      color = const Color(0xFFEF4444);
      label = 'CRITICAL';
    } else if (priority == 2) {
      color = const Color(0xFFF59E0B);
      label = 'MODERATE';
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(color: color.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(8)),
      child: Text(label, style: TextStyle(fontSize: 9, fontWeight: FontWeight.w900, color: color, letterSpacing: 0.5)),
    );
  }

  IconData _getCategoryIcon(String cat) {
    final c = cat.toLowerCase();
    if (c.contains('food')) return Icons.restaurant;
    if (c.contains('bill')) return Icons.receipt_long_rounded;
    if (c.contains('travel')) return Icons.commute_rounded;
    return Icons.lightbulb_outline_rounded;
  }
}
