import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../models/recurring_expense_models.dart';

/// Widget for configuring recurring payment settings
class RecurringPaymentWidget extends StatefulWidget {
  final RecurringExpenseConfig initialConfig;
  final ValueChanged<RecurringExpenseConfig> onConfigChanged;

  const RecurringPaymentWidget({
    super.key,
    required this.initialConfig,
    required this.onConfigChanged,
  });

  @override
  State<RecurringPaymentWidget> createState() => _RecurringPaymentWidgetState();
}

class _RecurringPaymentWidgetState extends State<RecurringPaymentWidget> {
  late RecurringExpenseConfig _config;

  @override
  void initState() {
    super.initState();
    _config = widget.initialConfig;
  }

  void _updateConfig(RecurringExpenseConfig newConfig) {
    setState(() {
      _config = newConfig;
    });
    widget.onConfigChanged(newConfig);
  }

  @override
  Widget build(BuildContext context) {
    final primaryColor = Theme.of(context).colorScheme.primary;
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Recurring Payment Checkbox
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: const Color(0xFFF7F7FB),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xFFEEEEF2)),
          ),
          child: Row(
            children: [
              Checkbox(
                value: _config.isRecurring,
                onChanged: (value) {
                  _updateConfig(_config.copyWith(
                    isRecurring: value ?? false,
                    interval: value == true ? RecurringInterval.monthly : null,
                    startDate: value == true ? DateTime.now() : null,
                  ));
                },
                activeColor: primaryColor,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Recurring Payment',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF1A1A2E),
                      ),
                    ),
                    Text(
                      'Automatically create this expense at regular intervals',
                      style: TextStyle(
                        fontSize: 11,
                        color: Colors.grey.shade500,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        
        // Recurring Configuration (shown when enabled)
        if (_config.isRecurring) ...[
          const SizedBox(height: 16),
          _buildRecurringConfiguration(primaryColor),
        ],
      ],
    );
  }

  Widget _buildRecurringConfiguration(Color primaryColor) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFEEEEF2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Interval Selection
          _buildSectionLabel('REPEAT EVERY'),
          const SizedBox(height: 8),
          _buildIntervalSelector(primaryColor),
          
          const SizedBox(height: 20),
          
          // Start Date
          _buildSectionLabel('START DATE'),
          const SizedBox(height: 8),
          _buildDateSelector(
            label: 'Select start date',
            date: _config.startDate,
            onDateSelected: (date) {
              _updateConfig(_config.copyWith(startDate: date));
            },
          ),
          
          const SizedBox(height: 20),
          
          // Advanced Options
          _buildAdvancedOptions(primaryColor),
        ],
      ),
    );
  }

  Widget _buildSectionLabel(String text) {
    return Text(
      text,
      style: TextStyle(
        fontSize: 10,
        fontWeight: FontWeight.w800,
        color: Colors.grey.shade400,
        letterSpacing: 0.8,
      ),
    );
  }

  Widget _buildIntervalSelector(Color primaryColor) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      decoration: BoxDecoration(
        color: const Color(0xFFF7F7FB),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFEEEEF2)),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<RecurringInterval>(
          value: _config.interval,
          isExpanded: true,
          icon: Icon(Icons.arrow_drop_down, color: Colors.grey.shade600),
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: Color(0xFF1A1A2E),
          ),
          items: RecurringInterval.values.map((interval) {
            return DropdownMenuItem<RecurringInterval>(
              value: interval,
              child: Row(
                children: [
                  Icon(
                    _getIntervalIcon(interval),
                    size: 18,
                    color: primaryColor,
                  ),
                  const SizedBox(width: 12),
                  Text(interval.label),
                ],
              ),
            );
          }).toList(),
          onChanged: (value) {
            if (value != null) {
              _updateConfig(_config.copyWith(interval: value));
            }
          },
        ),
      ),
    );
  }

  Widget _buildDateSelector({
    required String label,
    required DateTime? date,
    required ValueChanged<DateTime> onDateSelected,
  }) {
    return InkWell(
      onTap: () => _selectDate(onDateSelected),
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: const Color(0xFFF7F7FB),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFFEEEEF2)),
        ),
        child: Row(
          children: [
            Icon(
              Icons.calendar_today_rounded,
              size: 18,
              color: Colors.grey.shade600,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                date != null 
                    ? DateFormat('MMM dd, yyyy').format(date)
                    : label,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: date != null 
                      ? const Color(0xFF1A1A2E)
                      : Colors.grey.shade400,
                ),
              ),
            ),
            Icon(
              Icons.arrow_forward_ios_rounded,
              size: 14,
              color: Colors.grey.shade400,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAdvancedOptions(Color primaryColor) {
    return ExpansionTile(
      title: const Text(
        'Advanced Options',
        style: TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w600,
          color: Color(0xFF1A1A2E),
        ),
      ),
      tilePadding: EdgeInsets.zero,
      childrenPadding: const EdgeInsets.only(top: 8),
      children: [
        // End Date Option
        Row(
          children: [
            Checkbox(
              value: _config.endDate != null,
              onChanged: (value) {
                _updateConfig(_config.copyWith(
                  endDate: value == true ? DateTime.now().add(const Duration(days: 365)) : null,
                ));
              },
              activeColor: primaryColor,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(4),
              ),
            ),
            const SizedBox(width: 8),
            const Expanded(
              child: Text(
                'Set end date',
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
              ),
            ),
          ],
        ),
        
        if (_config.endDate != null) ...[
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.only(left: 40),
            child: _buildDateSelector(
              label: 'Select end date',
              date: _config.endDate,
              onDateSelected: (date) {
                _updateConfig(_config.copyWith(endDate: date));
              },
            ),
          ),
        ],
        
        const SizedBox(height: 16),
        
        // Notification Settings
        Row(
          children: [
            Checkbox(
              value: _config.notifyBeforeCreation,
              onChanged: (value) {
                _updateConfig(_config.copyWith(
                  notifyBeforeCreation: value ?? true,
                ));
              },
              activeColor: primaryColor,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(4),
              ),
            ),
            const SizedBox(width: 8),
            const Expanded(
              child: Text(
                'Notify before creating expense',
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
              ),
            ),
          ],
        ),
        
        if (_config.notifyBeforeCreation) ...[
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.only(left: 40),
            child: Row(
              children: [
                const Text(
                  'Notify',
                  style: TextStyle(fontSize: 12, color: Colors.grey),
                ),
                const SizedBox(width: 8),
                Container(
                  width: 60,
                  height: 36,
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF7F7FB),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: const Color(0xFFEEEEF2)),
                  ),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<int>(
                      value: _config.notificationDaysBefore,
                      isExpanded: true,
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF1A1A2E),
                      ),
                      items: [1, 2, 3, 7].map((days) {
                        return DropdownMenuItem<int>(
                          value: days,
                          child: Text('$days'),
                        );
                      }).toList(),
                      onChanged: (value) {
                        if (value != null) {
                          _updateConfig(_config.copyWith(
                            notificationDaysBefore: value,
                          ));
                        }
                      },
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                const Text(
                  'day(s) before',
                  style: TextStyle(fontSize: 12, color: Colors.grey),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }

  Future<void> _selectDate(ValueChanged<DateTime> onDateSelected) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365 * 5)),
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
      onDateSelected(picked);
    }
  }

  IconData _getIntervalIcon(RecurringInterval interval) {
    switch (interval) {
      case RecurringInterval.weekly:
        return Icons.calendar_view_week_rounded;
      case RecurringInterval.monthly:
        return Icons.calendar_view_month_rounded;
      case RecurringInterval.yearly:
        return Icons.calendar_today_rounded;
    }
  }
}