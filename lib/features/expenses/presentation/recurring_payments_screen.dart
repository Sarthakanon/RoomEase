import 'package:flutter/material.dart';
import '../../../models/expense_models.dart';
import '../../../models/recurring_expense_models.dart';
import '../../../services/api_service.dart';
import '../../../services/recurring_expense_service.dart';

/// Dedicated screen for managing all recurring payments
class RecurringPaymentsScreen extends StatefulWidget {
  final String roomspaceId;
  final List<ExpenseData> recurringExpenses;

  const RecurringPaymentsScreen({
    super.key,
    required this.roomspaceId,
    required this.recurringExpenses,
  });

  @override
  State<RecurringPaymentsScreen> createState() => _RecurringPaymentsScreenState();
}

class _RecurringPaymentsScreenState extends State<RecurringPaymentsScreen> {
  final RecurringExpenseService _recurringService = RecurringExpenseService();
  final ApiService _apiService = ApiService();

  List<RecurringExpenseTemplate> _templates = [];
  List<RecurringExpenseNotification> _notifications = [];
  List<Map<String, String>> _roomspaceMembers = [];
  bool _isLoading = true;
  String? _error;
  String _sortBy = 'next_payment'; // next_payment, amount, frequency

  @override
  void initState() {
    super.initState();
    _loadTemplates();
  }

  Future<void> _loadTemplates() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final results = await Future.wait([
        _recurringService.getRecurringExpenseTemplates(widget.roomspaceId),
        _loadRoomspaceMembers(),
        _recurringService.getRecurringExpenseNotifications(),
      ]);
      final templates = results[0] as List<RecurringExpenseTemplate>;
      final members = results[1] as List<Map<String, String>>;
      final notifications = results[2] as List<RecurringExpenseNotification>;
      setState(() {
        _templates = templates;
        _roomspaceMembers = members;
        _notifications = notifications;
        _sortTemplates();
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString().replaceAll('Exception: ', '');
        _isLoading = false;
      });
    }
  }

  Future<List<Map<String, String>>> _loadRoomspaceMembers() async {
    try {
      final response = await _apiService.getRoomspaceMembers(widget.roomspaceId);
      final List<dynamic> rawMembers = response['data'] as List<dynamic>? ?? [];
      return rawMembers.map((m) {
        final map = Map<String, dynamic>.from(m as Map);
        final user = map['user'] is Map ? Map<String, dynamic>.from(map['user'] as Map) : <String, dynamic>{};
        final uid = (map['user_id'] ?? map['firebase_uid'] ?? user['firebase_uid'] ?? '').toString();
        final name = (user['name'] ?? map['name'] ?? uid).toString();
        return {'id': uid, 'name': name};
      }).where((m) => (m['id'] ?? '').isNotEmpty).toList();
    } catch (_) {
      return [];
    }
  }

  void _sortTemplates() {
    switch (_sortBy) {
      case 'next_payment':
        _templates.sort((a, b) {
          final nextA = a.getNextScheduledDateForDisplay();
          final nextB = b.getNextScheduledDateForDisplay();
          if (nextA == null && nextB == null) return 0;
          if (nextA == null) return 1;
          if (nextB == null) return -1;
          return nextA.compareTo(nextB);
        });
        break;
      case 'amount':
        _templates.sort((a, b) => b.amount.compareTo(a.amount));
        break;
      case 'frequency':
        _templates.sort((a, b) {
          final intervalA = a.recurringConfig.interval?.days ?? 30;
          final intervalB = b.recurringConfig.interval?.days ?? 30;
          return intervalA.compareTo(intervalB);
        });
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    final primaryColor = Colors.purple.shade700;
    final totalMonthlyAmount = _calculateMonthlyTotal();

    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      appBar: AppBar(
        title: const Text('Recurring Payments'),
        backgroundColor: primaryColor,
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          IconButton(
            onPressed: _loadTemplates,
            icon: const Icon(Icons.refresh_rounded),
            tooltip: 'Refresh',
          ),
          PopupMenuButton<String>(
            icon: const Icon(Icons.sort_rounded),
            onSelected: (value) {
              setState(() {
                _sortBy = value;
                _sortTemplates();
              });
            },
            itemBuilder: (context) => const [
              PopupMenuItem(
                value: 'next_payment',
                child: Row(
                  children: [
                    Icon(Icons.schedule_rounded, size: 18),
                    SizedBox(width: 8),
                    Text('Next Payment'),
                  ],
                ),
              ),
              PopupMenuItem(
                value: 'amount',
                child: Row(
                  children: [
                    Icon(Icons.attach_money_rounded, size: 18),
                    SizedBox(width: 8),
                    Text('Amount'),
                  ],
                ),
              ),
              PopupMenuItem(
                value: 'frequency',
                child: Row(
                  children: [
                    Icon(Icons.repeat_rounded, size: 18),
                    SizedBox(width: 8),
                    Text('Frequency'),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
      body: Column(
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: primaryColor,
              borderRadius: const BorderRadius.vertical(bottom: Radius.circular(20)),
            ),
            child: Column(
              children: [
                Text(
                  'Monthly Recurring Total',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.8),
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Rs. ${totalMonthlyAmount.toStringAsFixed(2)}',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 28,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  '${_templates.length} active recurring payment${_templates.length != 1 ? 's' : ''}',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.8),
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          Expanded(child: _buildBody(primaryColor)),
        ],
      ),
    );
  }

  Widget _buildBody(Color primaryColor) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.error_outline_rounded, size: 52, color: Colors.redAccent),
              const SizedBox(height: 12),
              Text(_error!, textAlign: TextAlign.center),
              const SizedBox(height: 12),
              FilledButton(onPressed: _loadTemplates, child: const Text('Retry')),
            ],
          ),
        ),
      );
    }

    if (_templates.isEmpty) {
      return _buildEmptyState();
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _templates.length,
      itemBuilder: (context, index) {
        final template = _templates[index];
        return Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: _buildRecurringPaymentCard(template, primaryColor),
        );
      },
    );
  }

  Widget _buildRecurringPaymentCard(RecurringExpenseTemplate template, Color primaryColor) {
    final nextPayment = template.getNextScheduledDateForDisplay();
    final daysUntilNext = _calendarDaysUntil(nextPayment);
    final pendingForTemplate = _notifications.where((n) => n.templateId == (template.id ?? -1) && !n.isProcessed).toList()
      ..sort((a, b) => a.scheduledDate.compareTo(b.scheduledDate));
    final dueNotification = pendingForTemplate.isNotEmpty ? pendingForTemplate.first : null;
    final dueDays = dueNotification == null ? null : _calendarDaysUntil(dueNotification.scheduledDate);

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: primaryColor.withValues(alpha: 0.2)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          InkWell(
            onTap: () => _showRecurringPaymentDetails(template),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: primaryColor.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Icon(
                          _getIcon(template.category),
                          color: primaryColor,
                          size: 24,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              template.title,
                              style: const TextStyle(
                                fontWeight: FontWeight.w700,
                                fontSize: 16,
                                color: Color(0xFF1A1A2E),
                              ),
                            ),
                            const SizedBox(height: 4),
                            Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: primaryColor.withValues(alpha: 0.1),
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: Text(
                                    template.recurringConfig.interval?.label ?? 'Monthly',
                                    style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w700,
                                      color: primaryColor,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  template.category,
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.grey.shade600,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                            'Rs. ${template.amount.toStringAsFixed(0)}',
                            style: TextStyle(
                              fontWeight: FontWeight.w900,
                              fontSize: 18,
                              color: primaryColor,
                            ),
                          ),
                          if (daysUntilNext != null)
                            Text(
                              daysUntilNext == 0
                                  ? 'Due today'
                                  : daysUntilNext > 0
                                      ? 'In $daysUntilNext day${daysUntilNext != 1 ? 's' : ''}'
                                      : 'Pending action',
                              style: TextStyle(
                                fontSize: 11,
                                color: daysUntilNext <= 0
                                    ? Colors.red.shade600
                                    : daysUntilNext <= 3
                                        ? Colors.orange.shade600
                                        : Colors.grey.shade600,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                        ],
                      ),
                    ],
                  ),
                  if (nextPayment != null) ...[
                    const SizedBox(height: 12),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.grey.shade50,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.schedule_rounded, size: 16, color: Colors.grey.shade600),
                          const SizedBox(width: 8),
                          Text(
                            'Next payment: ${_formatDate(nextPayment)}',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey.shade700,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                  if (dueNotification != null) ...[
                    const SizedBox(height: 10),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: Colors.orange.shade50,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.orange.shade200),
                      ),
                      child: Text(
                        dueDays == 0
                            ? 'Recurring payment is due today. Re-add or cancel below.'
                            : dueDays != null && dueDays > 0
                                ? 'Recurring payment reminder set ($dueDays day${dueDays == 1 ? '' : 's'} left).'
                                : 'Recurring payment is awaiting your action.',
                        style: TextStyle(fontSize: 12, color: Colors.orange.shade800, fontWeight: FontWeight.w600),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
          Container(
            decoration: BoxDecoration(
              color: Colors.grey.shade50,
              borderRadius: const BorderRadius.vertical(bottom: Radius.circular(16)),
            ),
            child: template.canUndoDelete
                ? InkWell(
                    onTap: () => _undoDeleteRecurringPayment(template),
                    borderRadius: const BorderRadius.vertical(bottom: Radius.circular(16)),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.undo_rounded, size: 16, color: Colors.green.shade700),
                          const SizedBox(width: 6),
                          Text(
                            'Undo Delete (available 24h)',
                            style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Colors.green.shade700),
                          ),
                        ],
                      ),
                    ),
                  )
                : Row(
                    children: [
                      Expanded(
                        child: InkWell(
                          onTap: template.isDeleted ? null : () => _editRecurringPayment(template),
                          borderRadius: const BorderRadius.only(bottomLeft: Radius.circular(16)),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.edit_rounded, size: 16, color: Colors.blue.shade600),
                                const SizedBox(width: 4),
                                Text('Edit', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.blue.shade600)),
                              ],
                            ),
                          ),
                        ),
                      ),
                      Container(width: 1, height: 40, color: Colors.grey.shade300),
                      Expanded(
                        child: InkWell(
                          onTap: template.isDeleted ? null : () => _togglePauseResume(template),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  template.isActive ? Icons.pause_rounded : Icons.play_arrow_rounded,
                                  size: 16,
                                  color: template.isActive ? Colors.orange.shade600 : Colors.green.shade600,
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  template.isActive ? 'Pause' : 'Resume',
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                    color: template.isActive ? Colors.orange.shade600 : Colors.green.shade600,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                      Container(width: 1, height: 40, color: Colors.grey.shade300),
                      Expanded(
                        child: InkWell(
                          onTap: template.isDeleted ? null : () => _deleteRecurringPayment(template),
                          borderRadius: const BorderRadius.only(bottomRight: Radius.circular(16)),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.delete_outline_rounded, size: 16, color: Colors.red.shade600),
                                const SizedBox(width: 4),
                                Text('Delete', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.red.shade600)),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
          ),
          if (dueNotification != null) ...[
            const SizedBox(height: 8),
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
              child: Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => _processNotificationForTemplate(dueNotification, 'cancel'),
                      icon: const Icon(Icons.cancel_rounded, size: 16),
                      label: const Text('Cancel'),
                      style: OutlinedButton.styleFrom(foregroundColor: Colors.red.shade700),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () => _processNotificationForTemplate(dueNotification, 'create_now'),
                      icon: const Icon(Icons.add_rounded, size: 16),
                      label: const Text('Re-add'),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  int? _calendarDaysUntil(DateTime? targetDate) {
    if (targetDate == null) return null;
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final target = DateTime(targetDate.year, targetDate.month, targetDate.day);
    return target.difference(today).inDays;
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.schedule_outlined, size: 64, color: Colors.grey.shade300),
            const SizedBox(height: 16),
            const Text(
              'No Recurring Payments',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: Color(0xFF1A1A2E)),
            ),
            const SizedBox(height: 8),
            Text(
              'Set up automatic payments for rent, utilities, and other regular expenses.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 14, color: Colors.grey.shade600),
            ),
          ],
        ),
      ),
    );
  }

  double _calculateMonthlyTotal() {
    double total = 0.0;
    for (final t in _templates.where((e) => e.isActive)) {
      final interval = t.recurringConfig.interval;
      if (interval == RecurringInterval.monthly) {
        total += t.amount;
      } else if (interval == RecurringInterval.weekly) {
        total += t.amount * 4.33;
      } else if (interval == RecurringInterval.yearly) {
        total += t.amount / 12;
      } else {
        total += t.amount;
      }
    }
    return total;
  }

  void _showRecurringPaymentDetails(RecurringExpenseTemplate template) {
    final config = template.recurringConfig;
    final next = template.getNextScheduledDateForDisplay();
    final activeText = template.isActive ? 'Active' : 'Paused';

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(template.title),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Status: $activeText'),
            Text('Amount: Rs. ${template.amount.toStringAsFixed(2)}'),
            Text('Category: ${template.category}'),
            Text('Frequency: ${config.interval?.label ?? 'Monthly'}'),
            if (next != null) Text('Next: ${_formatDate(next)}'),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Close')),
        ],
      ),
    );
  }

  Future<void> _editRecurringPayment(RecurringExpenseTemplate template) async {
    final titleCtrl = TextEditingController(text: template.title);
    final descCtrl = TextEditingController(text: template.description);
    final amountCtrl = TextEditingController(text: template.amount.toStringAsFixed(2));
    final categoryCtrl = TextEditingController(text: template.category);
    RecurringInterval selected = template.recurringConfig.interval ?? RecurringInterval.monthly;
    DateTime selectedNextDate = template.getNextScheduledDateForDisplay() ?? DateTime.now().add(const Duration(days: 1));
    String selectedPaidBy = template.paidBy.isNotEmpty ? template.paidBy : template.createdBy;
    Set<String> selectedPayers = template.payerAmounts.keys.toSet();
    final payerAmounts = Map<String, double>.from(template.payerAmounts);
    Set<String> selectedRoommateIds = template.selectedRoommates.toSet();
    if (selectedRoommateIds.isEmpty) {
      selectedRoommateIds = _roomspaceMembers.map((m) => m['id'] ?? '').where((id) => id.isNotEmpty).toSet();
    }
    if (selectedPayers.isEmpty) {
      selectedPayers = {selectedPaidBy};
      payerAmounts[selectedPaidBy] = template.amount;
    }

    final payerCandidates = _roomspaceMembers.where((m) {
      final id = m['id'] ?? '';
      return id.isNotEmpty && selectedRoommateIds.contains(id);
    }).toList();
    final hasSelectedPayer = payerCandidates.any((m) => m['id'] == selectedPaidBy);
    if (!hasSelectedPayer && selectedPaidBy.isNotEmpty) {
      payerCandidates.add({'id': selectedPaidBy, 'name': selectedPaidBy});
    }

    final updated = await showDialog<RecurringExpenseTemplate>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setLocal) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Text('Edit Recurring Payment'),
          content: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(controller: titleCtrl, decoration: const InputDecoration(labelText: 'Title')),
                  const SizedBox(height: 10),
                  TextField(controller: descCtrl, decoration: const InputDecoration(labelText: 'Description')),
                  const SizedBox(height: 10),
                  TextField(
                    controller: amountCtrl,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    decoration: const InputDecoration(labelText: 'Amount'),
                  ),
                  const SizedBox(height: 10),
                  TextField(controller: categoryCtrl, decoration: const InputDecoration(labelText: 'Category')),
                  const SizedBox(height: 10),
                  DropdownButtonFormField<RecurringInterval>(
                    value: selected,
                    decoration: const InputDecoration(labelText: 'Frequency'),
                    items: RecurringInterval.values
                        .map((e) => DropdownMenuItem(value: e, child: Text(e.label)))
                        .toList(),
                    onChanged: (v) {
                      if (v != null) setLocal(() => selected = v);
                    },
                  ),
                  const SizedBox(height: 10),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Text('Included Roommates', style: TextStyle(fontWeight: FontWeight.w700, color: Colors.grey.shade700)),
                  ),
                  const SizedBox(height: 6),
                  ..._roomspaceMembers.map((m) {
                    final id = m['id'] ?? '';
                    final name = m['name'] ?? id;
                    final checked = selectedRoommateIds.contains(id);
                    return CheckboxListTile(
                      dense: true,
                      contentPadding: EdgeInsets.zero,
                      value: checked,
                      title: Text(name, style: const TextStyle(fontSize: 13)),
                      onChanged: (v) {
                        setLocal(() {
                          if (v == true) {
                            selectedRoommateIds.add(id);
                          } else {
                            selectedRoommateIds.remove(id);
                            selectedPayers.remove(id);
                            payerAmounts.remove(id);
                          }
                          if (!selectedRoommateIds.contains(selectedPaidBy) && selectedRoommateIds.isNotEmpty) {
                            selectedPaidBy = selectedRoommateIds.first;
                          }
                        });
                      },
                    );
                  }),
                  const SizedBox(height: 8),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Text('Paid by (multi-select)', style: TextStyle(fontWeight: FontWeight.w700, color: Colors.grey.shade700)),
                  ),
                  const SizedBox(height: 6),
                  ..._roomspaceMembers
                      .where((m) => selectedRoommateIds.contains(m['id']))
                      .map((m) {
                    final id = m['id'] ?? '';
                    final name = m['name'] ?? id;
                    final isSelected = selectedPayers.contains(id);
                    return Row(
                      children: [
                        Checkbox(
                          value: isSelected,
                          onChanged: (v) {
                            setLocal(() {
                              if (v == true) {
                                selectedPayers.add(id);
                                payerAmounts.putIfAbsent(id, () => 0.0);
                              } else {
                                selectedPayers.remove(id);
                                payerAmounts.remove(id);
                              }
                              if (selectedPayers.isNotEmpty && !selectedPayers.contains(selectedPaidBy)) {
                                selectedPaidBy = selectedPayers.first;
                              }
                            });
                          },
                        ),
                        Expanded(child: Text(name, style: const TextStyle(fontSize: 13))),
                        SizedBox(
                          width: 120,
                          child: TextFormField(
                            initialValue: (payerAmounts[id] ?? 0) > 0 ? (payerAmounts[id] ?? 0).toStringAsFixed(2) : '',
                            enabled: isSelected,
                            keyboardType: const TextInputType.numberWithOptions(decimal: true),
                            decoration: const InputDecoration(labelText: 'Amount'),
                            onChanged: (v) => payerAmounts[id] = double.tryParse(v) ?? 0.0,
                          ),
                        ),
                      ],
                    );
                  }),
                  const SizedBox(height: 8),
                  DropdownButtonFormField<String>(
                    value: selectedPaidBy.isNotEmpty ? selectedPaidBy : null,
                    decoration: const InputDecoration(labelText: 'Paid by'),
                    items: _roomspaceMembers
                        .where((m) => selectedPayers.contains(m['id']))
                        .map((m) => DropdownMenuItem<String>(
                              value: m['id'],
                              child: Text(m['name'] ?? m['id'] ?? ''),
                            ))
                        .toList(),
                    onChanged: (value) {
                      if (value != null) {
                        setLocal(() => selectedPaidBy = value);
                      }
                    },
                  ),
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      const Icon(Icons.event_rounded, size: 18),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Next payment: ${_formatDate(selectedNextDate)}',
                          style: const TextStyle(fontWeight: FontWeight.w600),
                        ),
                      ),
                      TextButton(
                        onPressed: () async {
                          final picked = await showDatePicker(
                            context: context,
                            initialDate: selectedNextDate,
                            firstDate: DateTime.now().subtract(const Duration(days: 365)),
                            lastDate: DateTime.now().add(const Duration(days: 3650)),
                          );
                          if (picked != null) {
                            setLocal(() => selectedNextDate = picked);
                          }
                        },
                        child: const Text('Change'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
            FilledButton(
              onPressed: () {
                final amount = double.tryParse(amountCtrl.text.trim());
                if (amount == null || amount <= 0 || selectedRoommateIds.isEmpty) return;
                if (selectedPayers.isEmpty) return;
                final totalPaid = selectedPayers.fold<double>(0.0, (sum, uid) => sum + (payerAmounts[uid] ?? 0.0));
                if ((totalPaid - amount).abs() > 0.01) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Paid amounts must add up to Rs. ${amount.toStringAsFixed(2)}')),
                  );
                  return;
                }
                final List<String> roommates = selectedRoommateIds.toList();
                Map<String, double> updatedSplits = Map<String, double>.from(template.customSplits);
                updatedSplits.removeWhere((k, _) => !selectedRoommateIds.contains(k));
                for (final uid in roommates) {
                  updatedSplits.putIfAbsent(uid, () => 0.0);
                }

                if (template.splitType.toUpperCase() == 'EQUAL') {
                  updatedSplits = {};
                } else if (template.splitType.toUpperCase() == 'PERCENTAGE') {
                  final equalPercent = 100.0 / roommates.length;
                  updatedSplits = {for (final uid in roommates) uid: equalPercent};
                } else if (template.splitType.toUpperCase() == 'EXACT') {
                  final equalAmount = amount / roommates.length;
                  updatedSplits = {for (final uid in roommates) uid: equalAmount};
                }
                Navigator.pop(
                  context,
                  template.copyWith(
                    title: titleCtrl.text.trim(),
                    description: descCtrl.text.trim(),
                    amount: amount,
                    category: categoryCtrl.text.trim(),
                    paidBy: selectedPaidBy,
                    payerAmounts: {
                      for (final uid in selectedPayers) uid: (payerAmounts[uid] ?? 0.0),
                    },
                    selectedRoommates: roommates,
                    customSplits: updatedSplits,
                    recurringConfig: template.recurringConfig.copyWith(interval: selected),
                  ),
                );
              },
              child: const Text('Save'),
            ),
          ],
        ),
      ),
    );

    if (updated == null || template.id == null) return;

    try {
      await _recurringService.updateRecurringExpenseTemplate(
        template.id!,
        updated,
        nextScheduledDate: selectedNextDate,
      );
      await _loadTemplates();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Recurring payment updated')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to update recurring payment: $e')),
      );
    }
  }

  Future<void> _processNotificationForTemplate(RecurringExpenseNotification notification, String action) async {
    if (notification.id == null) return;
    try {
      await _recurringService.processRecurringExpenseNotification(notification.id!, action);
      await _loadTemplates();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(action == 'create_now' ? 'Recurring payment re-added' : 'Recurring payment cancelled')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed: $e')),
      );
    }
  }

  Future<void> _togglePauseResume(RecurringExpenseTemplate template) async {
    if (template.id == null) return;
    try {
      await _recurringService.updateRecurringExpenseTemplate(
        template.id!,
        template.copyWith(isActive: !template.isActive),
      );
      await _loadTemplates();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(template.isActive ? 'Recurring payment paused' : 'Recurring payment resumed')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed: $e')),
      );
    }
  }

  Future<void> _deleteRecurringPayment(RecurringExpenseTemplate template) async {
    if (template.id == null) return;
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Delete Recurring Payment'),
        content: Text('Are you sure you want to delete "${template.title}"? This will stop all future automatic payments.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    try {
      await _recurringService.deleteRecurringExpenseTemplate(template.id!);
      await _loadTemplates();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Recurring payment deleted. You can undo within 24 hours.')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to delete recurring payment: $e')),
      );
    }
  }

  Future<void> _undoDeleteRecurringPayment(RecurringExpenseTemplate template) async {
    if (template.id == null) return;
    try {
      await _recurringService.restoreRecurringExpenseTemplate(template.id!);
      await _loadTemplates();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Recurring payment restored')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to restore recurring payment: $e')),
      );
    }
  }

  IconData _getIcon(String category) {
    switch (category.toLowerCase()) {
      case 'groceries':
        return Icons.shopping_basket_outlined;
      case 'utilities':
        return Icons.bolt_rounded;
      case 'rent':
        return Icons.home_outlined;
      case 'food':
        return Icons.restaurant_rounded;
      case 'transport':
        return Icons.directions_car_rounded;
      case 'entertainment':
        return Icons.movie_creation_rounded;
      default:
        return Icons.receipt_long_outlined;
    }
  }

  String _formatDate(DateTime date) {
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
    ];
    return '${months[date.month - 1]} ${date.day}';
  }
}
