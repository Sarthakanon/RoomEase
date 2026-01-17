import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import '../../../models/analytics_models.dart';

/// Category breakdown pie chart widget
/// 
/// Displays spending breakdown by category with:
/// - Pie chart visualization
/// - Category percentages
/// - Drill-down to category details
class CategoryBreakdownChart extends StatefulWidget {
  final List<CategorySpend> categories;
  
  const CategoryBreakdownChart({
    super.key,
    required this.categories,
  });

  @override
  State<CategoryBreakdownChart> createState() => _CategoryBreakdownChartState();
}

class _CategoryBreakdownChartState extends State<CategoryBreakdownChart> {
  int _touchedIndex = -1;
  
  @override
  Widget build(BuildContext context) {
    if (widget.categories.isEmpty) {
      return Card(
        elevation: 2,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        child: Container(
          height: 300,
          padding: const EdgeInsets.all(20),
          child: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.pie_chart_outline_rounded,
                  size: 48,
                  color: Colors.grey[400],
                ),
                const SizedBox(height: 8),
                Text(
                  'No category data available',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Colors.grey[600],
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }
    
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
                  Icons.pie_chart_rounded,
                  color: Theme.of(context).colorScheme.primary,
                  size: 24,
                ),
                const SizedBox(width: 8),
                Text(
                  'Category Breakdown',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            
            // Chart and legend
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Pie chart
                Expanded(
                  flex: 2,
                  child: AspectRatio(
                    aspectRatio: 1,
                    child: PieChart(
                      PieChartData(
                        pieTouchData: PieTouchData(
                          touchCallback: (FlTouchEvent event, pieTouchResponse) {
                            setState(() {
                              if (!event.isInterestedForInteractions ||
                                  pieTouchResponse == null ||
                                  pieTouchResponse.touchedSection == null) {
                                _touchedIndex = -1;
                                return;
                              }
                              _touchedIndex = pieTouchResponse
                                  .touchedSection!.touchedSectionIndex;
                            });
                          },
                        ),
                        borderData: FlBorderData(show: false),
                        sectionsSpace: 2,
                        centerSpaceRadius: 40,
                        sections: _buildPieSections(),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 20),
                
                // Legend
                Expanded(
                  flex: 1,
                  child: _buildLegend(),
                ),
              ],
            ),
            const SizedBox(height: 20),
            
            // Category list
            _buildCategoryList(),
          ],
        ),
      ),
    );
  }
  
  List<PieChartSectionData> _buildPieSections() {
    final colors = _getCategoryColors();
    
    return List.generate(widget.categories.length, (index) {
      final category = widget.categories[index];
      final isTouched = index == _touchedIndex;
      final fontSize = isTouched ? 16.0 : 12.0;
      final radius = isTouched ? 65.0 : 55.0;
      
      return PieChartSectionData(
        color: colors[index % colors.length],
        value: category.percentage,
        title: '${category.percentage.toStringAsFixed(1)}%',
        radius: radius,
        titleStyle: TextStyle(
          fontSize: fontSize,
          fontWeight: FontWeight.bold,
          color: Colors.white,
        ),
      );
    });
  }
  
  Widget _buildLegend() {
    final colors = _getCategoryColors();
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: List.generate(
        widget.categories.length.clamp(0, 5), // Show max 5 in legend
        (index) {
          final category = widget.categories[index];
          return Padding(
            padding: const EdgeInsets.only(bottom: 8.0),
            child: Row(
              children: [
                Container(
                  width: 12,
                  height: 12,
                  decoration: BoxDecoration(
                    color: colors[index % colors.length],
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    _getCategoryDisplayName(category.category),
                    style: Theme.of(context).textTheme.bodySmall,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
  
  Widget _buildCategoryList() {
    final colors = _getCategoryColors();
    
    return Column(
      children: [
        Divider(color: Colors.grey[300]),
        const SizedBox(height: 12),
        ...List.generate(widget.categories.length, (index) {
          final category = widget.categories[index];
          return _buildCategoryItem(
            category,
            colors[index % colors.length],
          );
        }),
      ],
    );
  }
  
  Widget _buildCategoryItem(CategorySpend category, Color color) {
    return InkWell(
      onTap: () {
        _showCategoryDetails(category);
      },
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8.0),
        child: Row(
          children: [
            Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(
                color: color,
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _getCategoryDisplayName(category.category),
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  Text(
                    '${category.count} transaction${category.count != 1 ? 's' : ''}',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Colors.grey[600],
                    ),
                  ),
                ],
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  'Rs. ${category.amount.toStringAsFixed(2)}',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  '${category.percentage.toStringAsFixed(1)}%',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Colors.grey[600],
                  ),
                ),
              ],
            ),
            const SizedBox(width: 8),
            Icon(
              Icons.chevron_right_rounded,
              color: Colors.grey[400],
              size: 20,
            ),
          ],
        ),
      ),
    );
  }
  
  void _showCategoryDetails(CategorySpend category) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(
                    _getCategoryIcon(category.category),
                    color: Theme.of(context).colorScheme.primary,
                    size: 32,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      _getCategoryDisplayName(category.category),
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              _buildDetailRow('Total Amount', 'Rs. ${category.amount.toStringAsFixed(2)}'),
              const SizedBox(height: 12),
              _buildDetailRow('Percentage', '${category.percentage.toStringAsFixed(1)}%'),
              const SizedBox(height: 12),
              _buildDetailRow('Transactions', '${category.count}'),
              const SizedBox(height: 12),
              _buildDetailRow('Average', 'Rs. ${(category.amount / category.count).toStringAsFixed(2)}'),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () {
                    Navigator.pop(context);
                    // TODO: Navigate to expense list filtered by category
                  },
                  child: const Text('View Transactions'),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
  
  Widget _buildDetailRow(String label, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
            color: Colors.grey[600],
          ),
        ),
        Text(
          value,
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }
  
  List<Color> _getCategoryColors() {
    return [
      Colors.blue,
      Colors.green,
      Colors.orange,
      Colors.purple,
      Colors.red,
      Colors.teal,
      Colors.pink,
      Colors.indigo,
      Colors.amber,
      Colors.cyan,
    ];
  }
  
  String _getCategoryDisplayName(String category) {
    // Capitalize first letter and replace underscores with spaces
    if (category.isEmpty) return 'Other';
    
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
