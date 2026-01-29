import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class MonthSelector extends StatelessWidget {
  final DateTime selectedMonth;
  final ValueChanged<DateTime> onMonthChanged;
  
  const MonthSelector({
    Key? key,
    required this.selectedMonth,
    required this.onMonthChanged,
  }) : super(key: key);
  
  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            Theme.of(context).primaryColor.withOpacity(0.1),
            Theme.of(context).primaryColor.withOpacity(0.05),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: Theme.of(context).primaryColor.withOpacity(0.3),
          width: 1,
        ),
      ),
      child: Row(
        children: [
          // Previous month button
          IconButton(
            icon: Icon(
              Icons.chevron_left,
              color: Theme.of(context).primaryColor,
            ),
            onPressed: () => _changeMonth(-1),
            tooltip: 'Previous month',
          ),
          
          // Month and year display
          Expanded(
            child: InkWell(
              onTap: () => _showMonthPicker(context),
              borderRadius: BorderRadius.circular(8),
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Column(
                  children: [
                    Text(
                      DateFormat('MMMM yyyy').format(selectedMonth),
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: Theme.of(context).primaryColor,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Tap to select',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 11,
                        color: Theme.of(context).primaryColor.withOpacity(0.6),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          
          // Next month button
          IconButton(
            icon: Icon(
              Icons.chevron_right,
              color: _canGoForward() 
                ? Theme.of(context).primaryColor 
                : Theme.of(context).disabledColor,
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
      1,
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
  
  Future<void> _showMonthPicker(BuildContext context) async {
    final now = DateTime.now();
    
    // Show a custom month/year picker dialog
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: selectedMonth,
      firstDate: DateTime(2020, 1),
      lastDate: now,
      initialDatePickerMode: DatePickerMode.day,
      helpText: 'Select Month',
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
      // Set to first day of the selected month
      final newMonth = DateTime(picked.year, picked.month, 1);
      onMonthChanged(newMonth);
    }
  }
}
