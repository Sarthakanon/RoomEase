import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../models/payment_notification.dart';
import '../../../models/expense_models.dart';
import '../../../services/payment_parser_service.dart';
import '../../../utils/expense_calculation_utils.dart';

class AddExpenseDialog extends StatefulWidget {
  final List<RoommateItem> roommates;
  final String roomspaceId;
  final Function(ExpenseData) onSubmit;
  final PaymentNotification? paymentNotification;

  const AddExpenseDialog({
    super.key,
    required this.roommates,
    required this.roomspaceId,
    required this.onSubmit,
    this.paymentNotification,
  });

  static Future<void> show(
    BuildContext context, {
    required List<RoommateItem> roommates,
    required String roomspaceId,
    required Function(ExpenseData) onSubmit,
    PaymentNotification? paymentNotification,
  }) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => AddExpenseDialog(
        roommates: roommates,
        roomspaceId: roomspaceId,
        onSubmit: onSubmit,
        paymentNotification: paymentNotification,
      ),
    );
  }

  @override
  State<AddExpenseDialog> createState() => _AddExpenseDialogState();
}

class _AddExpenseDialogState extends State<AddExpenseDialog> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _amountController = TextEditingController();
  final _descriptionController = TextEditingController();

  String _selectedCategory = 'General';
  final Set<String> _selectedRoommates = {};
  SplitType _splitType = SplitType.equal;
  final Map<String, double> _customSplits =
      {}; // For percentage or exact amounts

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
      if (_selectedRoommates.isEmpty) {
        setState(() {
          _errorMessage = 'Please select at least one roommate';
        });
        return;
      }

      // Validate splits using the calculation utilities
      final totalAmount = double.parse(_amountController.text);
      final validationResult = ExpenseCalculationUtils.validateSplitData(
        _splitType,
        totalAmount,
        _selectedRoommates.toList(),
        _customSplits,
      );

      if (!validationResult.isValid) {
        setState(() {
          _errorMessage = validationResult.errorMessage;
        });
        return;
      }

      setState(() {
        _isSubmitting = true;
        _errorMessage = null;
      });

      try {
        final expense = ExpenseData(
          title: _titleController.text.trim(),
          amount: totalAmount,
          description: _descriptionController.text.trim(),
          category: _selectedCategory,
          selectedRoommateIds: _selectedRoommates.toList(),
          splitType: _splitType,
          customSplits: Map.from(_customSplits),
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
                      'Add Expense',
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
                        decoration: _inputDecoration('e.g., Grocery shopping'),
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

                      // Roommate multi-select
                      _buildLabel('Split with'),
                      const SizedBox(height: 8),
                      _buildRoommateSelector(primaryColor),

                      const SizedBox(height: 20),

                      // Split type selector
                      _buildLabel('Split type'),
                      const SizedBox(height: 8),
                      _buildSplitTypeSelector(primaryColor),

                      // Custom split inputs (shown when not equal)
                      if (_splitType != SplitType.equal &&
                          _selectedRoommates.isNotEmpty) ...[
                        const SizedBox(height: 16),
                        _buildCustomSplitInputs(primaryColor),
                      ],

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
                                  'Add Expense',
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

  Widget _buildRoommateSelector(Color primaryColor) {
    return GestureDetector(
      onTap: () => _showRoommateSelectionSheet(primaryColor),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.grey[50],
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.grey[200]!),
        ),
        child: Row(
          children: [
            Expanded(
              child: _selectedRoommates.isEmpty
                  ? Text(
                      'Select roommates',
                      style: TextStyle(color: Colors.grey[500]),
                    )
                  : Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: _selectedRoommates.map((id) {
                        final roommate = widget.roommates.firstWhere(
                          (r) => r.id == id,
                        );
                        return Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: primaryColor.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                roommate.name,
                                style: TextStyle(
                                  color: primaryColor,
                                  fontWeight: FontWeight.w500,
                                  fontSize: 13,
                                ),
                              ),
                              const SizedBox(width: 4),
                              GestureDetector(
                                onTap: () {
                                  setState(() {
                                    _selectedRoommates.remove(id);
                                  });
                                },
                                child: Icon(
                                  Icons.close,
                                  size: 16,
                                  color: primaryColor,
                                ),
                              ),
                            ],
                          ),
                        );
                      }).toList(),
                    ),
            ),
            Icon(Icons.arrow_drop_down, color: Colors.grey[600]),
          ],
        ),
      ),
    );
  }

  void _showRoommateSelectionSheet(Color primaryColor) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => StatefulBuilder(
        builder: (context, setSheetState) {
          return Container(
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Handle
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
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Select Roommates',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      TextButton(
                        onPressed: () {
                          setSheetState(() {
                            if (_selectedRoommates.length ==
                                widget.roommates.length) {
                              _selectedRoommates.clear();
                            } else {
                              _selectedRoommates.addAll(
                                widget.roommates.map((r) => r.id),
                              );
                            }
                          });
                          setState(() {});
                        },
                        child: Text(
                          _selectedRoommates.length == widget.roommates.length
                              ? 'Deselect All'
                              : 'Select All',
                          style: TextStyle(color: primaryColor),
                        ),
                      ),
                    ],
                  ),
                ),

                // Roommate list
                Flexible(
                  child: ListView.builder(
                    shrinkWrap: true,
                    itemCount: widget.roommates.length,
                    itemBuilder: (context, index) {
                      final roommate = widget.roommates[index];
                      final isSelected = _selectedRoommates.contains(
                        roommate.id,
                      );

                      return ListTile(
                        leading: CircleAvatar(
                          backgroundColor: primaryColor.withValues(alpha: 0.1),
                          backgroundImage: roommate.photoUrl != null
                              ? NetworkImage(roommate.photoUrl!)
                              : null,
                          child: roommate.photoUrl == null
                              ? Text(
                                  roommate.name[0].toUpperCase(),
                                  style: TextStyle(
                                    color: primaryColor,
                                    fontWeight: FontWeight.bold,
                                  ),
                                )
                              : null,
                        ),
                        title: Text(roommate.name),
                        subtitle: roommate.email != null
                            ? Text(
                                roommate.email!,
                                style: TextStyle(
                                  color: Colors.grey[500],
                                  fontSize: 12,
                                ),
                              )
                            : null,
                        trailing: Checkbox(
                          value: isSelected,
                          onChanged: (value) {
                            setSheetState(() {
                              if (value == true) {
                                _selectedRoommates.add(roommate.id);
                              } else {
                                _selectedRoommates.remove(roommate.id);
                              }
                            });
                            setState(() {});
                          },
                          activeColor: primaryColor,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(4),
                          ),
                        ),
                        onTap: () {
                          setSheetState(() {
                            if (isSelected) {
                              _selectedRoommates.remove(roommate.id);
                            } else {
                              _selectedRoommates.add(roommate.id);
                            }
                          });
                          setState(() {});
                        },
                      );
                    },
                  ),
                ),

                // Done button
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () => Navigator.pop(context),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: primaryColor,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: const Text('Done'),
                    ),
                  ),
                ),

                SizedBox(height: MediaQuery.of(context).padding.bottom),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildSplitTypeSelector(Color primaryColor) {
    return Row(
      children: SplitType.values.map((type) {
        final isSelected = _splitType == type;
        return Expanded(
          child: GestureDetector(
            onTap: () {
              setState(() {
                _splitType = type;
                // Initialize custom splits when switching to non-equal
                if (type != SplitType.equal) {
                  _initializeCustomSplits();
                }
              });
            },
            child: Container(
              margin: EdgeInsets.only(
                right: type != SplitType.values.last ? 8 : 0,
              ),
              padding: const EdgeInsets.symmetric(vertical: 12),
              decoration: BoxDecoration(
                color: isSelected ? primaryColor : Colors.grey[100],
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: isSelected ? primaryColor : Colors.grey[200]!,
                ),
              ),
              child: Column(
                children: [
                  Icon(
                    type.icon,
                    size: 20,
                    color: isSelected ? Colors.white : Colors.grey[600],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    type.label,
                    style: TextStyle(
                      fontSize: 12,
                      color: isSelected ? Colors.white : Colors.grey[700],
                      fontWeight: isSelected
                          ? FontWeight.w600
                          : FontWeight.normal,
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  void _initializeCustomSplits() {
    if (_selectedRoommates.isEmpty) return;

    final totalAmount = double.tryParse(_amountController.text) ?? 0;
    final customSplits = ExpenseCalculationUtils.initializeCustomSplits(
      _splitType,
      totalAmount,
      _selectedRoommates.toList(),
    );
    
    setState(() {
      _customSplits.clear();
      _customSplits.addAll(customSplits);
    });
  }

  Widget _buildCustomSplitInputs(Color primaryColor) {
    final totalAmount = double.tryParse(_amountController.text) ?? 0;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.grey[50],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey[200]!),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Summary row
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                _splitType == SplitType.percentage
                    ? 'Set percentages'
                    : 'Set amounts',
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  color: Colors.grey[700],
                ),
              ),
              _buildSplitSummary(primaryColor, totalAmount),
            ],
          ),
          const SizedBox(height: 12),

          // Individual inputs
          ..._selectedRoommates.map((id) {
            final roommate = widget.roommates.firstWhere((r) => r.id == id);
            return Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 16,
                    backgroundColor: primaryColor.withValues(alpha: 0.1),
                    backgroundImage: roommate.photoUrl != null
                        ? NetworkImage(roommate.photoUrl!)
                        : null,
                    child: roommate.photoUrl == null
                        ? Text(
                            roommate.name[0].toUpperCase(),
                            style: TextStyle(
                              color: primaryColor,
                              fontWeight: FontWeight.bold,
                              fontSize: 12,
                            ),
                          )
                        : null,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      roommate.name,
                      style: const TextStyle(fontWeight: FontWeight.w500),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(width: 10),
                  SizedBox(
                    width: 100,
                    child: TextFormField(
                      initialValue:
                          _customSplits[id]?.toStringAsFixed(
                            _splitType == SplitType.percentage ? 1 : 2,
                          ) ??
                          '0',
                      decoration: InputDecoration(
                        isDense: true,
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 10,
                        ),
                        suffixText: _splitType == SplitType.percentage
                            ? '%'
                            : null,
                        prefixText: _splitType == SplitType.exact
                            ? 'Rs. '
                            : null,
                        filled: true,
                        fillColor: Colors.white,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: BorderSide(color: Colors.grey[300]!),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: BorderSide(color: Colors.grey[300]!),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: BorderSide(color: primaryColor, width: 2),
                        ),
                      ),
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      inputFormatters: [
                        FilteringTextInputFormatter.allow(
                          RegExp(r'^\d+\.?\d{0,2}'),
                        ),
                      ],
                      onChanged: (value) {
                        setState(() {
                          _customSplits[id] = double.tryParse(value) ?? 0;
                        });
                      },
                    ),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _buildSplitSummary(Color primaryColor, double totalAmount) {
    if (_splitType == SplitType.percentage) {
      final total = _customSplits.values.fold(0.0, (a, b) => a + b);
      final isValid = (total - 100).abs() < 0.01;
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: isValid
              ? Colors.green.withValues(alpha: 0.1)
              : Colors.red.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(
          '${total.toStringAsFixed(1)}%',
          style: TextStyle(
            color: isValid ? Colors.green : Colors.red,
            fontWeight: FontWeight.w600,
            fontSize: 12,
          ),
        ),
      );
    } else {
      final total = _customSplits.values.fold(0.0, (a, b) => a + b);
      final isValid = (total - totalAmount).abs() < 0.01;
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: isValid
              ? Colors.green.withValues(alpha: 0.1)
              : Colors.red.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(
          '${ExpenseCalculationUtils.formatCurrency(total)} / ${ExpenseCalculationUtils.formatCurrency(totalAmount)}',
          style: TextStyle(
            color: isValid ? Colors.green : Colors.red,
            fontWeight: FontWeight.w600,
            fontSize: 12,
          ),
        ),
      );
    }
  }
}

// Data models
class RoommateItem {
  final String id;
  final String name;
  final String? email;
  final String? photoUrl;

  RoommateItem({
    required this.id,
    required this.name,
    this.email,
    this.photoUrl,
  });
}
