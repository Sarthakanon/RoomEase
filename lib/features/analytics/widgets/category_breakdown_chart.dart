import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import '../../../models/analytics_models.dart';
import 'analytics_shared.dart';

class CategoryBreakdownChart extends StatefulWidget {
  final List<CategorySpend> categories;
  const CategoryBreakdownChart({super.key, required this.categories});

  @override
  State<CategoryBreakdownChart> createState() => _CategoryBreakdownChartState();
}

class _CategoryBreakdownChartState extends State<CategoryBreakdownChart> {
  int _touchedIndex = -1;

  static const List<Color> _palette = [
    Color(0xFF3F51B5), Color(0xFF7986CB), Color(0xFF455A64), Color(0xFF78909C),
    Color(0xFF546E7A), Color(0xFF90A4AE), Color(0xFF5C6BC0), Color(0xFF9FA8DA),
    Color(0xFF607D8B), Color(0xFFB0BEC5),
  ];

  @override
  Widget build(BuildContext context) {
    if (widget.categories.isEmpty) return const SizedBox();

    return AnalyticsCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AnalyticsSectionHeader(
            icon: Icons.donut_large_rounded,
            title: 'Category Breakdown',
          ),
          const SizedBox(height: 24),
          LayoutBuilder(builder: (context, constraints) {
            // Responsive layout: Stack legend below if width is small
            final isNarrow = constraints.maxWidth < 340;
            
            return isNarrow 
              ? Column(
                  children: [
                    _buildPieChart(size: 160),
                    const SizedBox(height: 20),
                    _buildLegend(limit: 5),
                  ],
                )
              : Row(
                  children: [
                    _buildPieChart(size: 130),
                    const SizedBox(width: 20),
                    Expanded(child: _buildLegend(limit: 4)),
                  ],
                );
          }),
          const SizedBox(height: 20),
          const Divider(height: 1, color: Color(0xFFEEEEF2)),
          _buildCategoryList(),
        ],
      ),
    );
  }

  Widget _buildPieChart({required double size}) {
    return SizedBox(
      width: size,
      height: size,
      child: PieChart(
        PieChartData(
          pieTouchData: PieTouchData(
            touchCallback: (event, response) {
              setState(() {
                if (!event.isInterestedForInteractions || response == null || response.touchedSection == null) {
                  _touchedIndex = -1;
                  return;
                }
                _touchedIndex = response.touchedSection!.touchedSectionIndex;
              });
            },
          ),
          borderData: FlBorderData(show: false),
          sectionsSpace: 3,
          centerSpaceRadius: size * 0.25,
          sections: _buildPieSections(size * 0.35),
        ),
      ),
    );
  }

  List<PieChartSectionData> _buildPieSections(double radius) {
    return List.generate(widget.categories.length, (index) {
      final cat = widget.categories[index];
      final isTouched = index == _touchedIndex;
      return PieChartSectionData(
        color: _palette[index % _palette.length],
        value: cat.percentage,
        title: isTouched ? '${cat.percentage.toInt()}%' : '',
        radius: isTouched ? radius + 8 : radius,
        titleStyle: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.white),
      );
    });
  }

  Widget _buildLegend({required int limit}) {
    final displayList = widget.categories.take(limit).toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: displayList.asMap().entries.map((entry) {
        final i = entry.key;
        final cat = entry.value;
        return Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Row(
            children: [
              Container(width: 8, height: 8, decoration: BoxDecoration(color: _palette[i % _palette.paletteLength], shape: BoxShape.circle)),
              const SizedBox(width: 8),
              Expanded(child: Text(_displayName(cat.category), maxLines: 1, overflow: TextOverflow.ellipsis, 
                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Colors.grey.shade600))),
              Text('${cat.percentage.toInt()}%', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: Colors.grey.shade500)),
            ],
          ),
        );
      }).toList(),
    );
  }

  Widget _buildCategoryList() {
    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: widget.categories.length,
      itemBuilder: (context, i) {
        final cat = widget.categories[i];
        final color = _palette[i % _palette.length];
        return InkWell(
          onTap: () {}, // Detail view can be added later
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: Row(
              children: [
                Container(width: 3, height: 24, decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(2))),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(_displayName(cat.category), style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: Color(0xFF1A1A2E))),
                      Text('${cat.count} payments', style: TextStyle(fontSize: 11, color: Colors.grey.shade400)),
                    ],
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text('Rs. ${cat.amount.toInt()}', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: Color(0xFF1A1A2E))),
                    Text('${cat.percentage.toStringAsFixed(1)}%', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: Colors.indigo.shade300)),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  String _displayName(String cat) => cat.isEmpty ? 'Other' : cat.split('_').map((s) => s[0].toUpperCase() + s.substring(1)).join(' ');
}

extension PaletteExtension on List<Color> {
  int get paletteLength => length; // Helper for mapping
}
