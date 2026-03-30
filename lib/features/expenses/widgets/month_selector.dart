import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class MonthSelector extends StatelessWidget {
  final DateTime selectedMonth;
  final ValueChanged<DateTime> onMonthChanged;
  
  const MonthSelector({
    super.key,
    required this.selectedMonth,
    required this.onMonthChanged,
  });
  
  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: const Color(0xFFF7F7FB),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: const Color(0xFFEEEEF2),
          width: 1,
        ),
      ),
      child: Row(
        children: [
          // Previous month button
          IconButton(
            key: const ValueKey('prev_month_btn'),
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
            icon: Icon(
              Icons.chevron_left_rounded,
              color: Theme.of(context).primaryColor,
              size: 20,
            ),
            onPressed: () => _changeMonth(-1),
            tooltip: 'Previous month',
          ),
          
          // Month and year display - tap to open calendar
          Expanded(
            child: InkWell(
              onTap: () => _showDatePicker(context),
              borderRadius: BorderRadius.circular(8),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      DateFormat('MMMM yyyy').format(selectedMonth),
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: const Color(0xFF1A1A2E),
                      ),
                    ),
                    const SizedBox(width: 6),
                    Icon(
                      Icons.calendar_today_rounded,
                      size: 13,
                      color: Theme.of(context).primaryColor,
                    ),
                  ],
                ),
              ),
            ),
          ),
          
          // Next month button
          IconButton(
            key: const ValueKey('next_month_btn'),
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
            icon: Icon(
              Icons.chevron_right_rounded,
              color: _canGoForward() 
                ? Theme.of(context).primaryColor 
                : Colors.grey.shade300,
              size: 20,
            ),
            onPressed: _canGoForward() ? () => _changeMonth(1) : null,
            tooltip: 'Next month',
          ),
        ],
      ),
    );
  }
  
  void _changeMonth(int delta) {
    final newMonth = DateTime(
      selectedMonth.year,
      selectedMonth.month + delta,
      1, // Always set to first day of month
    );
    
    // Don't allow future months
    if (!_canGoForward() && delta > 0) {
      return;
    }
    
    onMonthChanged(newMonth);
  }
  
  bool _canGoForward() {
    final now = DateTime.now();
    final currentMonth = DateTime(now.year, now.month, 1);
    final selected = DateTime(selectedMonth.year, selectedMonth.month, 1);
    
    return selected.isBefore(currentMonth);
  }
  
  Future<void> _showDatePicker(BuildContext context) async {
    final now = DateTime.now();
    
    // Show date picker for selecting specific date
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: selectedMonth,
      firstDate: DateTime(2020, 1, 1),
      lastDate: now,
      helpText: 'Select Date',
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: ColorScheme.light(
              primary: Theme.of(context).primaryColor,
            ),
          ),
          child: child!,
        );
      },
    );
    
    if (picked != null) {
      // Use the exact date picked (not just first day of month)
      onMonthChanged(picked);
    }
  }
}
