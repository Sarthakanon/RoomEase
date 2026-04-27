import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../models/payment_confirmation_models.dart';

class RecordPaymentDialog extends StatefulWidget {
  final List<Map<String, String>> roommates; // {id, name}
  final double? suggestedAmount;

  const RecordPaymentDialog({
    super.key,
    required this.roommates,
    this.suggestedAmount,
  });

  @override
  State<RecordPaymentDialog> createState() => _RecordPaymentDialogState();
}

class _RecordPaymentDialogState extends State<RecordPaymentDialog> {
  String? _selectedRoommateId;
  final _amountController = TextEditingController();
  final _notesController = TextEditingController();
  PaymentType _paymentType = PaymentType.partial;
  DateTime _paymentDate = DateTime.now();

  @override
  void initState() {
    super.initState();
    if (widget.suggestedAmount != null) {
      _amountController.text = widget.suggestedAmount!.toStringAsFixed(2);
    }
  }

  @override
  void dispose() {
    _amountController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text(
        'Record Payment',
        style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
      ),
      contentPadding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
      content: SingleChildScrollView(
        child: SizedBox(
          width: MediaQuery.of(context).size.width * 0.8,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Record a payment you made to a roommate',
                style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
              ),
              const SizedBox(height: 12),
              
              // Roommate selector
              DropdownButtonFormField<String>(
                value: _selectedRoommateId,
                style: const TextStyle(fontSize: 13, color: Colors.black87),
                decoration: const InputDecoration(
                  labelText: 'Paid to',
                  labelStyle: TextStyle(fontSize: 12),
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.person, size: 18),
                  contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  isDense: true,
                ),
                items: widget.roommates.map((roommate) {
                  return DropdownMenuItem(
                    value: roommate['id'],
                    child: Text(
                      roommate['name']!,
                      style: const TextStyle(fontSize: 13),
                    ),
                  );
                }).toList(),
                onChanged: (value) => setState(() => _selectedRoommateId = value),
              ),
              const SizedBox(height: 12),
              
              // Amount
              TextField(
                controller: _amountController,
                style: const TextStyle(fontSize: 13),
                decoration: const InputDecoration(
                  labelText: 'Amount',
                  labelStyle: TextStyle(fontSize: 12),
                  prefixText: 'Rs. ',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.currency_rupee, size: 18),
                  contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  isDense: true,
                ),
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                inputFormatters: [
                  FilteringTextInputFormatter.allow(RegExp(r'^\d+\.?\d{0,2}')),
                ],
              ),
              const SizedBox(height: 12),
              
              // Payment type
              const Text(
                'Payment Type',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 6),
              SegmentedButton<PaymentType>(
                style: SegmentedButton.styleFrom(
                  textStyle: const TextStyle(fontSize: 11),
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                ),
                segments: const [
                  ButtonSegment(
                    value: PaymentType.partial,
                    label: Text('Partial'),
                    icon: Icon(Icons.pie_chart_outline, size: 16),
                  ),
                  ButtonSegment(
                    value: PaymentType.full,
                    label: Text('Full'),
                    icon: Icon(Icons.check_circle_outline, size: 16),
                  ),
                ],
                selected: {_paymentType},
                onSelectionChanged: (Set<PaymentType> newSelection) {
                  setState(() => _paymentType = newSelection.first);
                },
              ),
              const SizedBox(height: 12),
              
              // Notes
              TextField(
                controller: _notesController,
                style: const TextStyle(fontSize: 13),
                decoration: const InputDecoration(
                  labelText: 'Notes (optional)',
                  labelStyle: TextStyle(fontSize: 12),
                  hintText: 'e.g., Rent payment for January',
                  hintStyle: TextStyle(fontSize: 11),
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.note, size: 18),
                  contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  isDense: true,
                ),
                maxLines: 2,
              ),
              const SizedBox(height: 12),
              
              // Date picker
              InkWell(
                onTap: _selectDate,
                child: InputDecorator(
                  decoration: const InputDecoration(
                    labelText: 'Payment Date',
                    labelStyle: TextStyle(fontSize: 12),
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.calendar_today, size: 18),
                    contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    isDense: true,
                  ),
                  child: Text(
                    _formatDate(_paymentDate),
                    style: const TextStyle(fontSize: 13),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
      actionsPadding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          style: TextButton.styleFrom(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          ),
          child: const Text(
            'Cancel',
            style: TextStyle(fontSize: 12),
          ),
        ),
        ElevatedButton(
          onPressed: _submit,
          style: ElevatedButton.styleFrom(
            backgroundColor: Theme.of(context).primaryColor,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
            textStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
          ),
          child: const Text('Record Payment'),
        ),
      ],
    );
  }

  Future<void> _selectDate() async {
    final date = await showDatePicker(
      context: context,
      initialDate: _paymentDate,
      firstDate: DateTime.now().subtract(const Duration(days: 365)),
      lastDate: DateTime.now(),
    );
    if (date != null) {
      setState(() => _paymentDate = date);
    }
  }

  void _submit() {
    if (_selectedRoommateId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a roommate')),
      );
      return;
    }

    final amount = double.tryParse(_amountController.text);
    if (amount == null || amount <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a valid amount')),
      );
      return;
    }

    final request = PaymentConfirmationRequest(
      toUserId: _selectedRoommateId!,
      amount: amount,
      paymentType: _paymentType,
      notes: _notesController.text.isEmpty ? null : _notesController.text,
      paymentDate: _paymentDate,
    );

    Navigator.pop(context, request);
  }

  String _formatDate(DateTime date) {
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
    ];
    return '${months[date.month - 1]} ${date.day}, ${date.year}';
  }
}
