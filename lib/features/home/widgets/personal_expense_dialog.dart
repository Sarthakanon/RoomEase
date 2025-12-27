import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../models/expense_models.dart';
import '../../../models/payment_notification.dart';
import '../../../services/payment_parser_service.dart';

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
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => PersonalExpenseDialog(
        onSubmit: onSubmit,
        paymentNotification: paymentNotification,
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
    ExpenseCategory('General', Icons.receipt_long),
    ExpenseCategory('Groceries', Icons.shopping_cart),
    ExpenseCategory('Utilities', Icons.bolt),
    ExpenseCategory('Rent', Icons.home),
    ExpenseCategory('Food', Icons.restaurant),
    ExpenseCategory('Transport', Icons.directions_car),
    ExpenseCategory('Entertainment', Icons.movie),
    ExpenseCategory('Other', Icons.more_horiz),
  ];

  @override
  void initState() {
    super.initState();
    _autoFillFromPaymentNotification();
  }

  @override
  void dispose() {
    _titleController.dispose();
    _amountController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  /// Auto-fill form fields from payment notification
  void _autoFillFromPaymentNotification() {
    if (widget.paymentNotification == null) return;

    final notification = widget.paymentNotification!;
    
    // Set amount
    if (notification.amount != null) {
      _amountController.text = notification.amount!.toStringAsFixed(2);
    }
    
    // Set title based on merchant or app name
    String title = '';
    if (notification.merchant != null && notification.merchant!.isNotEmpty) {
      title = 'Payment to ${notification.merchant}';
    } else {
      title = 'Payment via ${notification.appName}';
    }
    _titleController.text = title;
    
    // Set suggested category
    final suggestedCategory = PaymentParserService.suggestExpenseCategory(
      notification.merchant,
      notification.rawText,
    );
    
    // Find matching category
    final categoryMatch = _categories.firstWhere(
      (cat) => cat.name == suggestedCategory,
      orElse: () => _categories.first,
    );
    _selectedCategory = categoryMatch.name;
    
    // Set description with payment details
    _descriptionController.text = 'Auto-detected from ${notification.appName} notification';
  }

  void _submit() async {
    if (_formKey.currentState!.validate()) {
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
        
        if (mounted) {
          Navigator.pop(context);
        }
      } catch (e) {
        if (mounted) {
          setState(() {
            _errorMessage = 'Failed to add expense: ${e.toString()}';
          });
        }
      } finally {
        if (mounted) {
          setState(() {
            _isSubmitting = false;
          });
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final primaryColor = Theme.of(context).colorScheme.primary;
    final bottomPadding = MediaQuery.of(context).viewInsets.bottom;

    return Container(
      margin: const EdgeInsets.only(top: 60),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Padding(
        padding: EdgeInsets.only(bottom: bottomPadding),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Handle bar
              Container(
                margin: const EdgeInsets.only(top: 12),
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(2),
                ),
              ),

              // Header
              Padding(
                padding: const EdgeInsets.all(20),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Add Personal Expense',
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    IconButton(
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(Icons.close),
                      style: IconButton.styleFrom(
                        backgroundColor: Colors.grey[100],
                      ),
                    ),
                  ],
                ),
              ),

              // Form
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Title field
                      _buildLabel('Title'),
                      const SizedBox(height: 8),
                      TextFormField(
                        controller: _titleController,
                        decoration: _inputDecoration('e.g., Coffee, Lunch'),
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) {
                            return 'Please enter a title';
                          }
                          return null;
                        },
                      ),

                      const SizedBox(height: 20),

                      // Amount field
                      _buildLabel('Amount'),
                      const SizedBox(height: 8),
                      TextFormField(
                        controller: _amountController,
                        decoration: _inputDecoration(
                          '0.00',
                          prefixText: 'Rs. ',
                        ),
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                        inputFormatters: [
                          FilteringTextInputFormatter.allow(
                            RegExp(r'^\d+\.?\d{0,2}'),
                          ),
                        ],
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Please enter an amount';
                          }
                          final amount = double.tryParse(value);
                          if (amount == null || amount <= 0) {
                            return 'Please enter a valid amount';
                          }
                          return null;
                        },
                      ),

                      const SizedBox(height: 20),

                      // Category selector
                      _buildLabel('Category'),
                      const SizedBox(height: 8),
                      _buildCategorySelector(primaryColor),

                      const SizedBox(height: 20),

                      // Description field (optional)
                      _buildLabel('Description (optional)'),
                      const SizedBox(height: 8),
                      TextFormField(
                        controller: _descriptionController,
                        decoration: _inputDecoration('Add a note...'),
                        maxLines: 2,
                      ),

                      const SizedBox(height: 24),

                      // Error message display
                      if (_errorMessage != null) ...[
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.red.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: Colors.red.withValues(alpha: 0.3)),
                          ),
                          child: Row(
                            children: [
                              Icon(
                                Icons.error_outline,
                                color: Colors.red,
                                size: 20,
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  _errorMessage!,
                                  style: TextStyle(
                                    color: Colors.red,
                                    fontSize: 14,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 16),
                      ],

                      // Submit button
                      SizedBox(
                        width: double.infinity,
                        height: 56,
                        child: ElevatedButton(
                          onPressed: _isSubmitting ? null : _submit,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: primaryColor,
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                            elevation: 0,
                            disabledBackgroundColor: Colors.grey[300],
                          ),
                          child: _isSubmitting
                              ? Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    SizedBox(
                                      width: 20,
                                      height: 20,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        valueColor: AlwaysStoppedAnimation<Color>(
                                          Colors.white,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    const Text(
                                      'Adding Expense...',
                                      style: TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ],
                                )
                              : const Text(
                                  'Add Personal Expense',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                        ),
                      ),

                      const SizedBox(height: 20),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLabel(String text) {
    return Text(
      text,
      style: TextStyle(
        fontSize: 14,
        fontWeight: FontWeight.w600,
        color: Colors.grey[700],
      ),
    );
  }

  InputDecoration _inputDecoration(String hint, {String? prefixText}) {
    return InputDecoration(
      hintText: hint,
      prefixText: prefixText,
      prefixStyle: TextStyle(
        color: Colors.grey[600],
        fontSize: 16,
      ),
      filled: true,
      fillColor: Colors.grey[50],
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: Colors.grey[200]!),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: Colors.grey[200]!),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(
          color: Theme.of(context).colorScheme.primary,
          width: 2,
        ),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
    );
  }

  Widget _buildCategorySelector(Color primaryColor) {
    return SizedBox(
      height: 44,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: _categories.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          final category = _categories[index];
          final isSelected = _selectedCategory == category.name;

          return GestureDetector(
            onTap: () => setState(() => _selectedCategory = category.name),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              decoration: BoxDecoration(
                color: isSelected ? primaryColor : Colors.grey[100],
                borderRadius: BorderRadius.circular(22),
              ),
              child: Row(
                children: [
                  Icon(
                    category.icon,
                    size: 18,
                    color: isSelected ? Colors.white : Colors.grey[600],
                  ),
                  const SizedBox(width: 6),
                  Text(
                    category.name,
                    style: TextStyle(
                      color: isSelected ? Colors.white : Colors.grey[700],
                      fontWeight: isSelected
                          ? FontWeight.w600
                          : FontWeight.normal,
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}