import 'package:flutter/material.dart';
import '../../../models/analytics_models.dart';
import '../../../services/analytics_service.dart';
import 'skeleton_loader.dart';

/// AI-powered recommendations card widget
/// 
/// Displays budget recommendations with:
/// - AI-powered insights label
/// - Savings potential
/// - Feedback buttons (helpful/not helpful)
class RecommendationsCard extends StatefulWidget {
  final String? roomspaceId;
  
  const RecommendationsCard({
    super.key,
    this.roomspaceId,
  });

  @override
  State<RecommendationsCard> createState() => _RecommendationsCardState();
}

class _RecommendationsCardState extends State<RecommendationsCard> {
  final AnalyticsService _analyticsService = AnalyticsService();
  
  bool _isLoading = true;
  String? _error;
  RecommendationsResponse? _recommendations;
  final Map<String, String> _feedbackGiven = {}; // recommendationId -> feedbackType
  
  @override
  void initState() {
    super.initState();
    _loadRecommendations();
  }
  
  Future<void> _loadRecommendations() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    
    try {
      final recommendations = await _analyticsService.getRecommendations(
        roomspaceId: widget.roomspaceId,
      );
      
      setState(() {
        _recommendations = recommendations;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }
  
  Future<void> _submitFeedback(String recommendationId, String feedbackType) async {
    try {
      await _analyticsService.submitFeedback(
        recommendationId: recommendationId,
        feedbackType: feedbackType,
      );
      
      setState(() {
        _feedbackGiven[recommendationId] = feedbackType;
      });
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Thank you for your feedback!'),
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to submit feedback'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
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
            // Header with AI badge
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        Colors.purple.shade400,
                        Colors.blue.shade400,
                      ],
                    ),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.auto_awesome_rounded,
                        color: Colors.white,
                        size: 16,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        'AI-Powered',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Recommendations',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
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
                'Failed to load recommendations',
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
                onPressed: _loadRecommendations,
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
    
    if (_recommendations == null || _recommendations!.recommendations.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            children: [
              Icon(
                Icons.lightbulb_outline_rounded,
                size: 48,
                color: Colors.grey[400],
              ),
              const SizedBox(height: 8),
              Text(
                'No recommendations available',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Colors.grey[600],
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Keep tracking expenses to get insights',
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
      children: _recommendations!.recommendations.map((recommendation) {
        return _buildRecommendationItem(recommendation);
      }).toList(),
    );
  }
  
  Widget _buildRecommendationItem(Recommendation recommendation) {
    final hasFeedback = _feedbackGiven.containsKey(recommendation.id);
    final feedbackType = _feedbackGiven[recommendation.id];
    
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _getPriorityColor(recommendation.priority).withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: _getPriorityColor(recommendation.priority).withValues(alpha: 0.3),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Priority badge and type
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: _getPriorityColor(recommendation.priority),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  _getPriorityLabel(recommendation.priority),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  _getTypeLabel(recommendation.type),
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Colors.grey[600],
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          
          // Category
          Row(
            children: [
              Icon(
                _getCategoryIcon(recommendation.category),
                size: 20,
                color: Theme.of(context).colorScheme.primary,
              ),
              const SizedBox(width: 8),
              Text(
                _getCategoryDisplayName(recommendation.category),
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          
          // Description
          Text(
            recommendation.description,
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          const SizedBox(height: 12),
          
          // Savings potential
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.green.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.savings_rounded,
                  color: Colors.green,
                  size: 20,
                ),
                const SizedBox(width: 8),
                Text(
                  'Potential Savings: ',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Colors.grey[700],
                  ),
                ),
                Text(
                  'Rs. ${recommendation.potentialSavings.toStringAsFixed(2)}/month',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Colors.green,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          
          // Spending info
          Row(
            children: [
              Expanded(
                child: _buildInfoChip(
                  'Current',
                  'Rs. ${recommendation.currentSpending.toStringAsFixed(0)}',
                  Colors.orange,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _buildInfoChip(
                  'Suggested',
                  'Rs. ${recommendation.suggestedLimit.toStringAsFixed(0)}',
                  Colors.blue,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          
          // Feedback buttons
          if (!hasFeedback)
            Row(
              children: [
                Text(
                  'Was this helpful?',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Colors.grey[600],
                  ),
                ),
                const Spacer(),
                TextButton.icon(
                  onPressed: () => _submitFeedback(recommendation.id, 'helpful'),
                  icon: const Icon(Icons.thumb_up_outlined, size: 16),
                  label: const Text('Yes'),
                  style: TextButton.styleFrom(
                    foregroundColor: Colors.green,
                  ),
                ),
                TextButton.icon(
                  onPressed: () => _submitFeedback(recommendation.id, 'not_helpful'),
                  icon: const Icon(Icons.thumb_down_outlined, size: 16),
                  label: const Text('No'),
                  style: TextButton.styleFrom(
                    foregroundColor: Colors.red,
                  ),
                ),
              ],
            )
          else
            Row(
              children: [
                Icon(
                  feedbackType == 'helpful' 
                      ? Icons.thumb_up_rounded 
                      : Icons.thumb_down_rounded,
                  size: 16,
                  color: feedbackType == 'helpful' ? Colors.green : Colors.red,
                ),
                const SizedBox(width: 8),
                Text(
                  'Thank you for your feedback!',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Colors.grey[600],
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ],
            ),
        ],
      ),
    );
  }
  
  Widget _buildInfoChip(String label, String value, Color color) {
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
  
  Color _getPriorityColor(int priority) {
    switch (priority) {
      case 1:
        return Colors.red;
      case 2:
        return Colors.orange;
      case 3:
        return Colors.blue;
      default:
        return Colors.grey;
    }
  }
  
  String _getPriorityLabel(int priority) {
    switch (priority) {
      case 1:
        return 'HIGH';
      case 2:
        return 'MEDIUM';
      case 3:
        return 'LOW';
      default:
        return 'NORMAL';
    }
  }
  
  String _getTypeLabel(String type) {
    switch (type) {
      case 'budget_limit':
        return 'Budget Limit';
      case 'reduce_spending':
        return 'Reduce Spending';
      case 'savings_opportunity':
        return 'Savings Opportunity';
      default:
        return type;
    }
  }
  
  String _getCategoryDisplayName(String category) {
    if (category.isEmpty) return 'General';
    
    return category
        .split('_')
        .map((word) => word.isEmpty ? '' : word[0].toUpperCase() + word.substring(1))
        .join(' ');
  }
  
  IconData _getCategoryIcon(String category) {
    final categoryLower = category.toLowerCase();
    
    if (categoryLower.contains('food') || categoryLower.contains('grocery')) {
      return Icons.restaurant_rounded;
    } else if (categoryLower.contains('transport') || categoryLower.contains('travel')) {
      return Icons.directions_car_rounded;
    } else if (categoryLower.contains('utility') || categoryLower.contains('bill')) {
      return Icons.receipt_long_rounded;
    } else if (categoryLower.contains('entertainment')) {
      return Icons.movie_rounded;
    } else if (categoryLower.contains('health') || categoryLower.contains('medical')) {
      return Icons.local_hospital_rounded;
    } else if (categoryLower.contains('shopping')) {
      return Icons.shopping_bag_rounded;
    } else if (categoryLower.contains('education')) {
      return Icons.school_rounded;
    } else {
      return Icons.category_rounded;
    }
  }
}
