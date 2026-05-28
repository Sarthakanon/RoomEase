import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import '../../../models/payment_confirmation_models.dart';
import '../../../services/cloudinary_service.dart';

class RecordPaymentDialog extends StatefulWidget {
  final List<Map<String, String>> roommates; // {id, name}
  final double? suggestedAmount;
  final String? initialRoommateId;
  final Map<String, double>? remainingAmountsByUserId;

  const RecordPaymentDialog({
    super.key,
    required this.roommates,
    this.suggestedAmount,
    this.initialRoommateId,
    this.remainingAmountsByUserId,
  });

  @override
  State<RecordPaymentDialog> createState() => _RecordPaymentDialogState();
}

class _RecordPaymentDialogState extends State<RecordPaymentDialog> {
  String? _selectedRoommateId;
  final _amountController = TextEditingController();
  final _notesController = TextEditingController();
  PaymentType _paymentType = PaymentType.full;
  DateTime _paymentDate = DateTime.now();
  double _selectedRemainingAmount = 0.0;
  final ImagePicker _imagePicker = ImagePicker();
  final CloudinaryService _cloudinaryService = CloudinaryService();
  bool _isUploadingProof = false;
  String? _paymentProofUrl;

  Map<String, String>? get _selectedRoommate {
    if (_selectedRoommateId == null) return null;
    for (final roommate in widget.roommates) {
      if (roommate['id'] == _selectedRoommateId) return roommate;
    }
    return null;
  }

  @override
  void initState() {
    super.initState();
    _selectedRoommateId = widget.initialRoommateId;
    if (_selectedRoommateId != null) {
      _applySelectedRoommateDefaults(_selectedRoommateId!);
    } else if (widget.suggestedAmount != null) {
      _selectedRemainingAmount = widget.suggestedAmount!;
      _amountController.text = widget.suggestedAmount!.toStringAsFixed(2);
      _paymentType = PaymentType.full;
    }
    _amountController.addListener(_handleAmountChanged);
  }

  @override
  void dispose() {
    _amountController.removeListener(_handleAmountChanged);
    _amountController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  void _applySelectedRoommateDefaults(String roommateId) {
    final map = widget.remainingAmountsByUserId ?? {};
    final remaining = (map[roommateId] ?? widget.suggestedAmount ?? 0.0);
    _selectedRemainingAmount = remaining;
    _amountController.text = remaining > 0 ? remaining.toStringAsFixed(2) : '';
    _paymentType = PaymentType.full;
  }

  void _handleAmountChanged() {
    final amount = double.tryParse(_amountController.text) ?? 0.0;
    if (_selectedRemainingAmount <= 0.0) return;
    final shouldBeFull = (amount - _selectedRemainingAmount).abs() <= 0.01;
    final nextType = shouldBeFull ? PaymentType.full : PaymentType.partial;
    if (_paymentType != nextType && mounted) {
      setState(() => _paymentType = nextType);
    }
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
                initialValue: _selectedRoommateId,
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
                onChanged: (value) {
                  setState(() {
                    _selectedRoommateId = value;
                    if (value != null) {
                      _applySelectedRoommateDefaults(value);
                    }
                  });
                },
              ),
              if (_selectedRoommateId != null) ...[
                const SizedBox(height: 10),
                _buildSelectedRoommateQrSection(),
              ],
              const SizedBox(height: 12),
              
              // Amount
              TextField(
                controller: _amountController,
                enabled: _selectedRemainingAmount > 0,
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
              if (_selectedRoommateId != null && _selectedRemainingAmount <= 0) ...[
                const SizedBox(height: 6),
                const Text(
                  'No amount left to be settled to this roommate',
                  style: TextStyle(fontSize: 11, color: Colors.red),
                ),
              ],
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
                  final selected = newSelection.first;
                  setState(() {
                    _paymentType = selected;
                    if (selected == PaymentType.full && _selectedRemainingAmount > 0) {
                      _amountController.text = _selectedRemainingAmount.toStringAsFixed(2);
                    }
                  });
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
              _buildPaymentProofField(),
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

  Widget _buildPaymentProofField() {
    final hasProof = _paymentProofUrl != null && _paymentProofUrl!.isNotEmpty;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey.shade400),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Payment Screenshot (optional)',
            style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 8),
          if (hasProof)
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: Image.network(
                _paymentProofUrl!,
                height: 120,
                width: double.infinity,
                fit: BoxFit.cover,
              ),
            ),
          if (hasProof) const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _isUploadingProof ? null : _uploadPaymentProof,
                  icon: _isUploadingProof
                      ? const SizedBox(
                          width: 14,
                          height: 14,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : Icon(hasProof ? Icons.refresh_rounded : Icons.upload_rounded, size: 16),
                  label: Text(hasProof ? 'Replace Screenshot' : 'Upload Screenshot'),
                ),
              ),
              if (hasProof) ...[
                const SizedBox(width: 8),
                IconButton(
                  onPressed: _isUploadingProof ? null : () => setState(() => _paymentProofUrl = null),
                  icon: const Icon(Icons.close_rounded, size: 18),
                  tooltip: 'Remove screenshot',
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSelectedRoommateQrSection() {
    final roommate = _selectedRoommate;
    final roommateName = roommate?['name'] ?? 'Roommate';
    final qrUrl = roommate?['qr_image_url'] ?? '';
    final hasQr = qrUrl.isNotEmpty;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '$roommateName\'s QR',
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 8),
          if (hasQr)
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: Image.network(
                qrUrl,
                height: 160,
                width: double.infinity,
                fit: BoxFit.contain,
                errorBuilder: (_, __, ___) => const Text(
                  'Failed to load QR image',
                  style: TextStyle(fontSize: 11, color: Colors.red),
                ),
              ),
            )
          else
            const Text(
              'This roommate has not uploaded a QR yet.',
              style: TextStyle(fontSize: 11, color: Colors.grey),
            ),
        ],
      ),
    );
  }

  Future<void> _uploadPaymentProof() async {
    try {
      final pickedFile = await _imagePicker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 85,
      );
      if (pickedFile == null || !mounted) return;

      setState(() => _isUploadingProof = true);
      final uploadedUrl = await _cloudinaryService.uploadQrImage(File(pickedFile.path));
      if (!mounted) return;
      setState(() => _paymentProofUrl = uploadedUrl);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to upload screenshot: $e')),
      );
    } finally {
      if (mounted) setState(() => _isUploadingProof = false);
    }
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
    if (_selectedRemainingAmount <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No amount left to be settled to this roommate')),
      );
      return;
    }
    if (amount - _selectedRemainingAmount > 0.01) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Amount cannot exceed remaining due (Rs. ${_selectedRemainingAmount.toStringAsFixed(2)})')),
      );
      return;
    }

    final request = PaymentConfirmationRequest(
      toUserId: _selectedRoommateId!,
      amount: amount,
      paymentType: _paymentType,
      notes: _notesController.text.isEmpty ? null : _notesController.text,
      paymentProofUrl: _paymentProofUrl,
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
