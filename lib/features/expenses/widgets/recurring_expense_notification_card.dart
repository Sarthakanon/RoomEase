import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../models/recurring_expense_models.dart';
import '../../../services/recurring_expense_service.dart';

/// Card widget for displaying recurring expense notifications
class RecurringExpenseNotificationCard extends StatefulWidget {
  final RecurringExpenseNotification notification;
  final VoidCallback? onProcessed;

  const RecurringExpenseNotificationCard({
    super.key,
    required this.notification,
    this.onProcessed,
  });

  @override
  State<RecurringExpenseNotificationCard> createState() => _RecurringExpenseNotificationCardState();
}

class _RecurringExpenseNotificationCardState extends State<RecurringExpenseNotificationCard> {
  final RecurringExpenseService _recurringService = RecurringExpenseService();
  bool _isProcessing = false;

  @override
  Widget build(BuildContext context) {
    final primaryColor = Theme.of(context).colorScheme.primary;
    
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: primaryColor.withValues(alpha: 0.2)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildHeader(primaryColor),
            const SizedBox(height: 12),
            _buildDetails(),
            const SizedBox(height: 16),
            _buildActions(primaryColor),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(Color primaryColor) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: primaryColor.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(
            Icons.schedule_rounded,
            color: primaryColor,
            size: 20,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                widget.notification.title,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF1A1A2E),
                ),
              ),
              Text(
                'Recurring expense due',
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey.shade600,
                ),
              ),
            ],
          ),
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: primaryColor.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(
            'Rs. ${widget.notification.amount.toStringAsFixed(0)}',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: primaryColor,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildDetails() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFF7F7FB),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Expanded(
            child: _buildDetailItem(
              'Scheduled Date',
              DateFormat('MMM dd, yyyy').format(widget.notification.scheduledDate),
              Icons.calendar_today_rounded,
            ),
          ),
          Container(
            width: 1,
            height: 24,
            color: Colors.grey.shade300,
          ),
          Expanded(
            child: _buildDetailItem(
              'Notification',
              DateFormat('MMM dd').format(widget.notification.notificationDate),
              Icons.notifications_rounded,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailItem(String label, String value, IconData icon) {
    return Row(
      children: [
        Icon(
          icon,
          size: 16,
          color: Colors.grey.shade600,
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(
                  fontSize: 10,
                  color: Colors.grey.shade500,
                  fontWeight: FontWeight.w600,
                ),
              ),
              Text(
                value,
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF1A1A2E),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildActions(Color primaryColor) {
    if (_isProcessing) {
      return const Center(
        child: CircularProgressIndicator(),
      );
    }

    return Row(
      children: [
        Expanded(
          child: _buildActionButton(
            'Create Now',
            Icons.add_rounded,
            primaryColor,
            () => _processNotification('create_now'),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _buildActionButton(
            'Schedule Later',
            Icons.schedule_rounded,
            Colors.orange,
            () => _showScheduleLaterDialog(),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _buildActionButton(
            'Skip Once',
            Icons.skip_next_rounded,
            Colors.grey.shade600,
            () => _processNotification('skip_once'),
          ),
        ),
        const SizedBox(width: 8),
        _buildIconButton(
          Icons.close_rounded,
          Colors.red,
          () => _processNotification('cancel'),
        ),
      ],
    );
  }

  Widget _buildActionButton(
    String label,
    IconData icon,
    Color color,
    VoidCallback onPressed,
  ) {
    return ElevatedButton.icon(
      onPressed: onPressed,
      icon: Icon(icon, size: 16),
      label: Text(
        label,
        style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600),
      ),
      style: ElevatedButton.styleFrom(
        backgroundColor: color,
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(vertical: 8),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
        ),
        elevation: 0,
      ),
    );
  }

  Widget _buildIconButton(
    IconData icon,
    Color color,
    VoidCallback onPressed,
  ) {
    return SizedBox(
      width: 36,
      height: 36,
      child: ElevatedButton(
        onPressed: onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: color,
          foregroundColor: Colors.white,
          padding: EdgeInsets.zero,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
          elevation: 0,
        ),
        child: Icon(icon, size: 16),
      ),
    );
  }

  Future<void> _processNotification(String action) async {
    setState(() {
      _isProcessing = true;
    });

    try {
      await _recurringService.processRecurringExpenseNotification(
        widget.notification.id!,
        action,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(_getActionMessage(action)),
            backgroundColor: Colors.green,
          ),
        );
        
        widget.onProcessed?.call();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to process notification: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isProcessing = false;
        });
      }
    }
  }

  Future<void> _showScheduleLaterDialog() async {
    final DateTime? selectedDate = await showDatePicker(
      context: context,
      initialDate: widget.notification.scheduledDate.add(const Duration(days: 1)),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
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

    if (selectedDate != null) {
      setState(() {
        _isProcessing = true;
      });

      try {
        await _recurringService.processRecurringExpenseNotification(
          widget.notification.id!,
          'schedule_later',
          scheduledDate: selectedDate,
        );

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'Expense rescheduled to ${DateFormat('MMM dd, yyyy').format(selectedDate)}',
              ),
              backgroundColor: Colors.green,
            ),
          );
          
          widget.onProcessed?.call();
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Failed to reschedule: ${e.toString()}'),
              backgroundColor: Colors.red,
            ),
          );
        }
      } finally {
        if (mounted) {
          setState(() {
            _isProcessing = false;
          });
        }
      }
    }
  }

  String _getActionMessage(String action) {
    switch (action) {
      case 'create_now':
        return 'Expense created successfully!';
      case 'skip_once':
        return 'Expense skipped for this occurrence';
      case 'cancel':
        return 'Recurring expense cancelled';
      default:
        return 'Action completed';
    }
  }
}