import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart';
import '../../../models/expense_models.dart';
import '../../../models/payment_notification.dart';
import '../../../services/payment_parser_service.dart';
import 'receipt_scanner_dialog.dart';

/// Premium, responsive dialog for adding personal expenses.
class PersonalExpenseDialog extends StatefulWidget {
  final Function(PersonalExpenseData) onSubmit;
  final PaymentNotification? paymentNotification;

  const PersonalExpenseDialog({
    super.key,
    required this.onSubmit,
    this.paymentNotification,
  });

  static Future<void> show(
    BuildContext context, {
    required Function(PersonalExpenseData) onSubmit,
    PaymentNotification? paymentNotification,
  }) {
    final width = MediaQuery.of(context).size.width;
    final isTablet = width > 600;

    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Padding(
        padding: EdgeInsets.symmetric(horizontal: isTablet ? width * 0.15 : 0),
        child: PersonalExpenseDialog(
          onSubmit: onSubmit,
          paymentNotification: paymentNotification,
        ),
      ),
    );
  }

  @override
  State<PersonalExpenseDialog> createState() => _PersonalExpenseDialogState();
}

class _PersonalExpenseDialogState extends State<PersonalExpenseDialog> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _amountController = TextEditingController();
  final _descriptionController = TextEditingController();

  String _selectedCategory = 'General';
  bool _isSubmitting = false;
  String? _errorMessage;

  final List<ExpenseCategory> _categories = [
    ExpenseCategory('General', Icons.receipt_long_rounded),
    ExpenseCategory('Groceries', Icons.shopping_basket_rounded),
    ExpenseCategory('Utilities', Icons.bolt_rounded),
    ExpenseCategory('Rent', Icons.home_rounded),
    ExpenseCategory('Food', Icons.restaurant_rounded),
    ExpenseCategory('Transport', Icons.directions_car_rounded),
    ExpenseCategory('Entertainment', Icons.movie_creation_rounded),
    ExpenseCategory('Other', Icons.more_horiz_rounded),
  ];

  @override
  void initState() {
    super.initState();
    _autoFillFromPaymentNotification();
  }

  void _autoFillFromPaymentNotification() {
    if (widget.paymentNotification == null || !mounted) return;
    
    try {
      final n = widget.paymentNotification!;
      if (n.amount != null) {
        _amountController.text = n.amount!.toStringAsFixed(0);
      }
      _titleController.text = n.merchant ?? 'Payment via ${n.appName}';
      
      final suggested = PaymentParserService.suggestExpenseCategory(n.merchant, n.rawText);
      _selectedCategory = _categories.any((c) => c.name == suggested) ? suggested : 'General';
      _descriptionController.text = 'Personal · From ${n.appName}';
    } catch (e) {
      // Handle any errors gracefully without affecting the UI
      debugPrint('Error auto-filling from payment notification: $e');
    }
  }

  Future<void> _scanReceipt() async {
    try {
      final result = await ReceiptScannerDialog.show(context);
      
      // Check if widget is still mounted before using the result
      if (result != null && mounted) {
        if (result.amount != null) {
          _amountController.text = result.amount!.toStringAsFixed(0);
        }
        if (result.merchant != null) {
          _titleController.text = result.merchant!;
        }
        _descriptionController.text = 'Scanned from receipt';
        
        // Only call setState if widget is still mounted
        if (mounted) {
          setState(() {});
        }
      }
    } catch (e) {
      // Handle any errors gracefully
      if (mounted) {
        setState(() {
          _errorMessage = 'Failed to scan receipt: ${e.toString()}';
        });
      }
    }
  }

  void _submit() async {
    if (!_formKey.currentState!.validate()) return;
    
    setState(() { 
      _isSubmitting = true; 
      _errorMessage = null; 
    });
    
    try {
      final expense = PersonalExpenseData(
        title: _titleController.text.trim(),
        amount: double.parse(_amountController.text),
        description: _descriptionController.text.trim(),
        category: _selectedCategory,
      );
      
      await widget.onSubmit(expense);
      
      // Check if widget is still mounted before using context
      if (mounted) {
        Navigator.pop(context);
      }
    } catch (e) {
      // Check if widget is still mounted before calling setState
      if (mounted) {
        setState(() { 
          _isSubmitting = false; 
          _errorMessage = e.toString(); 
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;
    final insets = MediaQuery.of(context).viewInsets;

    return Container(
      decoration: const BoxDecoration(color: Colors.white, borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildHandle(),
          _buildHeader(primary),
          Flexible(
            child: SingleChildScrollView(
              padding: EdgeInsets.fromLTRB(24, 8, 24, 24 + insets.bottom),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildField(controller: _titleController, label: 'TITLE', hint: 'e.g. Coffee', icon: Icons.title_rounded, validator: (v) => v!.isEmpty ? 'Title required' : null),
                    const SizedBox(height: 20),
                    _buildField(controller: _amountController, label: 'AMOUNT', hint: '0', icon: Icons.payments_outlined, isNumeric: true, prefix: 'Rs. ', validator: (v) => (double.tryParse(v ?? '') ?? 0) <= 0 ? 'Invalid' : null),
                    const SizedBox(height: 24),
                    _buildSectionLabel('CATEGORY'),
                    const SizedBox(height: 12),
                    _buildCategoryRow(primary),
                    const SizedBox(height: 20),
                    _buildField(controller: _descriptionController, label: 'DESCRIPTION (OPTIONAL)', hint: 'Add a note...', icon: Icons.notes_rounded, maxLines: 2),
                    const SizedBox(height: 32),
                    _buildSubmit(primary),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHandle() {
    return Container(margin: const EdgeInsets.only(top: 12), width: 40, height: 4, decoration: BoxDecoration(color: const Color(0xFFEEEEF2), borderRadius: BorderRadius.circular(2)));
  }

  Widget _buildHeader(Color primary) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 16, 16, 16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          const Text('Personal Expense', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: Color(0xFF1A1A2E))),
          Row(
            children: [
              IconButton(onPressed: _scanReceipt, icon: Icon(Icons.document_scanner_rounded, size: 20, color: primary)),
              IconButton(onPressed: () => Navigator.pop(context), icon: const Icon(Icons.close_rounded, size: 22, color: Color(0xFF1A1A2E))),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildField({required TextEditingController controller, required String label, required String hint, required IconData icon, bool isNumeric = false, String? prefix, int maxLines = 1, String? Function(String?)? validator}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionLabel(label),
        const SizedBox(height: 8),
        TextFormField(
          controller: controller, keyboardType: isNumeric ? const TextInputType.numberWithOptions(decimal: true) : null,
          maxLines: maxLines,
          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
          decoration: InputDecoration(
            hintText: hint, prefixText: prefix, hintStyle: TextStyle(color: Colors.grey.shade400, fontSize: 13), filled: true, fillColor: const Color(0xFFF7F7FB),
            prefixIcon: Icon(icon, size: 18, color: Colors.grey.shade400),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
          ),
          validator: validator,
        ),
      ],
    );
  }

  Widget _buildSectionLabel(String text) {
    return Text(text, style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: Colors.grey.shade400, letterSpacing: 0.8));
  }

  Widget _buildCategoryRow(Color primary) {
    return SizedBox(
      height: 40,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: _categories.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          final cat = _categories[index];
          final active = _selectedCategory == cat.name;
          return GestureDetector(
            onTap: () => setState(() => _selectedCategory = cat.name),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14),
              decoration: BoxDecoration(color: active ? primary : const Color(0xFFF7F7FB), borderRadius: BorderRadius.circular(20), border: Border.all(color: active ? primary : const Color(0xFFEEEEF2))),
              child: Row(children: [Icon(cat.icon, size: 16, color: active ? Colors.white : Colors.grey.shade600), const SizedBox(width: 8), Text(cat.name, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: active ? Colors.white : Colors.grey.shade600))]),
            ),
          );
        },
      ),
    );
  }

  Widget _buildSubmit(Color primary) {
    return Column(
      children: [
        if (_errorMessage != null) Padding(padding: const EdgeInsets.only(bottom: 16), child: Text(_errorMessage!, style: const TextStyle(color: Colors.red, fontSize: 12, fontWeight: FontWeight.w600))),
        SizedBox(width: double.infinity, height: 52, child: ElevatedButton(onPressed: _isSubmitting ? null : _submit, style: ElevatedButton.styleFrom(backgroundColor: primary, foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)), elevation: 0), child: _isSubmitting ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)) : const Text('Add Expense', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700)))),
      ],
    );
  }

  @override
  void dispose() {
    _titleController.dispose();
    _amountController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }
}