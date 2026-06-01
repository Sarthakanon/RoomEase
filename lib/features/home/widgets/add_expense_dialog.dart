import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../../models/payment_notification.dart';
import '../../../models/expense_models.dart';
import '../../../models/recurring_expense_models.dart';
import '../../../providers/roomspace_provider.dart';
import '../../../services/payment_parser_service.dart';
import '../../../utils/expense_calculation_utils.dart';
import 'receipt_scanner_dialog.dart';
import 'recurring_payment_widget.dart';

/// Premium, responsive dialog for adding shared expenses.
class AddExpenseDialog extends StatefulWidget {
  final List<RoommateItem> roommates;
  final String roomspaceId;
  final Function(ExpenseData) onSubmit;
  final PaymentNotification? paymentNotification;
  final ExpenseData? initialData; // For editing existing expenses

  const AddExpenseDialog({
    super.key,
    required this.roommates,
    required this.roomspaceId,
    required this.onSubmit,
    this.paymentNotification,
    this.initialData,
  });

  static Future<void> show(
    BuildContext context, {
    required List<RoommateItem> roommates,
    required String roomspaceId,
    required Function(ExpenseData) onSubmit,
    PaymentNotification? paymentNotification,
    ExpenseData? initialData,
  }) {
    final width = MediaQuery.of(context).size.width;
    final isTablet = width > 600;

    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Padding(
        padding: EdgeInsets.symmetric(horizontal: isTablet ? width * 0.15 : 0),
        child: AddExpenseDialog(
          roommates: roommates,
          roomspaceId: roomspaceId,
          onSubmit: onSubmit,
          paymentNotification: paymentNotification,
          initialData: initialData,
        ),
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
  final Set<String> _selectedPayers = {};
  final Map<String, double> _payerAmounts = {};
  SplitType _splitType = SplitType.equal;
  final Map<String, double> _customSplits = {};
  RecurringExpenseConfig _recurringConfig = RecurringExpenseConfig();

  bool _isSubmitting = false;
  String? _errorMessage;
  RoomspaceProvider? _roomspaceProvider;
  ScaffoldMessengerState? _scaffoldMessenger;

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

  bool get _isEditing => widget.initialData != null;

  String _roommateNameById(String id) {
    for (final r in widget.roommates) {
      if (r.id == id) return r.name;
    }
    return 'Unknown';
  }

  @override
  void initState() {
    super.initState();
    _autoFillFromInitialData();
    _autoFillFromPaymentNotification();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Cache references while the element tree is stable to avoid ancestor
    // lookups from a deactivated context after route transitions.
    _roomspaceProvider ??= Provider.of<RoomspaceProvider>(context, listen: false);
    _scaffoldMessenger ??= ScaffoldMessenger.maybeOf(context);
  }

  void _autoFillFromInitialData() {
    if (widget.initialData == null || !mounted) return;
    
    try {
      final expense = widget.initialData!;
      
      debugPrint('🔧 AddExpenseDialog: Auto-filling from initial data');
      debugPrint('🔧 Expense: ${expense.title}, Amount: ${expense.amount}');
      debugPrint('🔧 Roomspace ID: ${expense.roomspaceId}');
      debugPrint('🔧 Splits: ${expense.splits?.length ?? 0}');
      
      // Fill basic fields
      _titleController.text = expense.title;
      _amountController.text = expense.amount.toStringAsFixed(0);
      _descriptionController.text = expense.description;
      _selectedCategory = expense.category;
      _splitType = expense.splitType;
      if (expense.payerAmounts.isNotEmpty) {
        _selectedPayers.addAll(
          expense.payerAmounts.keys.where(
            (id) => widget.roommates.any((r) => r.id == id),
          ),
        );
        _payerAmounts.addAll(expense.payerAmounts);
      } else if (expense.paidBy != null && expense.paidBy!.isNotEmpty) {
        final paidBy = expense.paidBy!;
        if (widget.roommates.any((r) => r.id == paidBy)) {
          _selectedPayers.add(paidBy);
          _payerAmounts[paidBy] = expense.amount;
        }
      }
      
      // Fill selected roommates
      if (expense.splits != null) {
        _selectedRoommates.addAll(expense.splits!.map((s) => s.userUid));
        debugPrint('🔧 Selected roommates from splits: ${_selectedRoommates.toList()}');
      } else {
        _selectedRoommates.addAll(expense.selectedRoommateIds);
        debugPrint('🔧 Selected roommates from IDs: ${_selectedRoommates.toList()}');
      }
      
      // Fill custom splits if applicable
      if (expense.customSplits.isNotEmpty) {
        _customSplits.addAll(expense.customSplits);
      } else if (expense.splits != null && _splitType != SplitType.equal) {
        for (final split in expense.splits!) {
          if (_splitType == SplitType.percentage) {
            _customSplits[split.userUid] = split.percentage ?? 0.0;
          } else {
            _customSplits[split.userUid] = split.amount;
          }
        }
      }
      
      // Fill recurring config
      if (expense.recurringConfig != null) {
        _recurringConfig = expense.recurringConfig!;
      }
      
      debugPrint('✅ Pre-filled expense data for editing: ${expense.title}');
    } catch (e) {
      debugPrint('❌ Error auto-filling from initial data: $e');
    }
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
      _descriptionController.text = 'From ${n.appName}';
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
    // Check if widget is still mounted at the start
    if (!mounted) return;
    
    if (!_formKey.currentState!.validate()) return;
    
    if (_selectedPayers.isEmpty) {
      if (mounted) {
        setState(() => _errorMessage = 'Select at least one payer');
      }
      return;
    }
    
    if (_selectedRoommates.isEmpty) {
      if (mounted) {
        setState(() => _errorMessage = 'Select at least one roommate to split with');
      }
      return;
    }
    
    // Check if only one person is selected (solo expense)
    if (_selectedRoommates.length == 1) {
      _showSoloExpenseDialog();
      return;
    }

    final totalAmount = double.parse(_amountController.text);
    final paidTotal = _selectedPayers.fold<double>(0.0, (sum, uid) {
      return sum + (_payerAmounts[uid] ?? 0);
    });
    if ((paidTotal - totalAmount).abs() > 0.01) {
      if (mounted) {
        setState(
          () => _errorMessage =
              'Paid amounts must add up to Rs. ${totalAmount.toStringAsFixed(2)}',
        );
      }
      return;
    }
    final validation = ExpenseCalculationUtils.validateSplitData(
      _splitType, 
      totalAmount, 
      _selectedRoommates.toList(), 
      _customSplits
    );
    
    if (!validation.isValid) {
      if (mounted) {
        setState(() => _errorMessage = validation.errorMessage);
      }
      return;
    }

    if (mounted) {
      setState(() {
        _isSubmitting = true;
        _errorMessage = null;
      });
    }
    
    try {
      final expense = ExpenseData(
        title: _titleController.text.trim(),
        amount: totalAmount,
        description: _descriptionController.text.trim(),
        category: _selectedCategory,
        selectedRoommateIds: _selectedRoommates.toList(),
        splitType: _splitType,
        customSplits: Map.from(_customSplits),
        paidBy: _selectedPayers.isNotEmpty ? _selectedPayers.first : null,
        payerAmounts: {
          for (final uid in _selectedPayers) uid: (_payerAmounts[uid] ?? 0),
        },
        recurringConfig: _recurringConfig.isRecurring ? _recurringConfig : null,
      );
      
      // Close dialog first to avoid using this context across async gaps.
      if (mounted) {
        Navigator.of(context).pop();
      }

      // Submit after closing; use parent handlers/messenger for any feedback.
      Future.microtask(() async {
        try {
          await widget.onSubmit(expense);
        } catch (e) {
          _scaffoldMessenger?.showSnackBar(
            SnackBar(
              content: Text('Failed to add expense: $e'),
              backgroundColor: Colors.red,
            ),
          );
        }
      });
    } catch (e) {
      if (mounted) {
        setState(() {
          _isSubmitting = false;
          _errorMessage = e.toString();
        });
      }
    }
  }
  
  void _showSoloExpenseDialog() {
    // Check if widget is still mounted before showing dialog
    if (!mounted) return;
    
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Icon(Icons.info_outline, color: Theme.of(dialogContext).colorScheme.primary),
            const SizedBox(width: 12),
            const Text('Personal Expense', style: TextStyle(fontSize: 18)),
          ],
        ),
        content: const Text(
          'This expense is only for you. Would you like to add it as a personal expense instead?',
          style: TextStyle(fontSize: 14),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              // Capture dependencies before closing routes so we don't
              // read ancestors from a deactivated context.
              final provider = _roomspaceProvider;
              final messenger = _scaffoldMessenger;

              Navigator.of(dialogContext).pop(); // Close info dialog
              if (mounted) {
                Navigator.of(context).pop(); // Close add-expense sheet
              }

              _switchToPersonalAndAddExpense(
                roomspaceProvider: provider,
                scaffoldMessenger: messenger,
              );
            },
            child: const Text('Switch to Personal'),
          ),
        ],
      ),
    );
  }
  
  void _switchToPersonalAndAddExpense({
    RoomspaceProvider? roomspaceProvider,
    ScaffoldMessengerState? scaffoldMessenger,
  }) async {
    try {
      // Switch to personal space
      await roomspaceProvider?.switchToPersonalSpace();
      
      scaffoldMessenger?.showSnackBar(
        const SnackBar(
          content: Text('Switched to Personal Space. Add your expense now.'),
          duration: Duration(seconds: 2),
        ),
      );
    } catch (e) {
      // Handle any errors gracefully
      scaffoldMessenger?.showSnackBar(
        SnackBar(
          content: Text('Error switching to personal space: $e'),
          backgroundColor: Colors.red,
        ),
      );
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
                    _buildField(
                      controller: _titleController, 
                      label: 'TITLE', 
                      hint: 'e.g. Electricity Bill', 
                      icon: Icons.title_rounded, 
                      maxLength: 25,
                      validator: (v) => v!.isEmpty ? 'Title required' : null
                    ),
                    const SizedBox(height: 20),
                    _buildField(
                      controller: _amountController, 
                      label: 'AMOUNT', 
                      hint: '0', 
                      icon: Icons.payments_outlined, 
                      isNumeric: true, 
                      prefix: 'Rs.',
                      maxLength: 10,
                      inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d*'))],
                      validator: (v) => (double.tryParse(v ?? '') ?? 0) <= 0 ? 'Invalid amount' : null
                    ),
                    const SizedBox(height: 24),
                    _buildSectionLabel('CATEGORY'),
                    const SizedBox(height: 12),
                    _buildCategoryRow(primary),
                    const SizedBox(height: 24),
                    _buildSectionLabel('SPLIT WITH'),
                    const SizedBox(height: 4),
                    Text(
                      'Select who should share this expense',
                      style: TextStyle(fontSize: 11, color: Colors.grey.shade500),
                    ),
                    const SizedBox(height: 8),
                    _buildRoommateChipArea(primary),
                    const SizedBox(height: 24),
                    _buildSectionLabel('PAID BY'),
                    const SizedBox(height: 8),
                    _buildPaidBySelector(primary),
                    const SizedBox(height: 24),
                    _buildSectionLabel('SPLIT TYPE'),
                    const SizedBox(height: 12),
                    _buildSplitTypeSelector(primary),
                    if (_splitType != SplitType.equal && _selectedRoommates.isNotEmpty) ...[
                      const SizedBox(height: 20),
                      _buildCustomInputs(primary),
                    ],
                    const SizedBox(height: 24),
                    _buildSectionLabel('RECURRING PAYMENT'),
                    const SizedBox(height: 8),
                    RecurringPaymentWidget(
                      initialConfig: _recurringConfig,
                      onConfigChanged: (config) {
                        setState(() {
                          _recurringConfig = config;
                        });
                      },
                    ),
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
          Text(_isEditing ? 'Edit Expense' : 'Add Expense', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: Color(0xFF1A1A2E))),
          Row(
            children: [
              IconButton(
                key: const ValueKey('scan_receipt_btn'),
                onPressed: _scanReceipt, 
                icon: Icon(Icons.document_scanner_rounded, size: 20, color: primary), 
                tooltip: 'Scan Receipt'
              ),
              IconButton(
                key: const ValueKey('close_dialog_btn'),
                onPressed: () => Navigator.pop(context), 
                icon: const Icon(Icons.close_rounded, size: 22, color: Color(0xFF1A1A2E))
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildField({required TextEditingController controller, required String label, required String hint, required IconData icon, bool isNumeric = false, String? prefix, String? Function(String?)? validator, int? maxLength, List<TextInputFormatter>? inputFormatters}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionLabel(label),
        const SizedBox(height: 8),
        TextFormField(
          controller: controller, 
          keyboardType: isNumeric ? const TextInputType.numberWithOptions(decimal: true) : null,
          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
          maxLength: maxLength,
          inputFormatters: inputFormatters,
          decoration: InputDecoration(
            hintText: hint, 
            hintStyle: TextStyle(color: Colors.grey.shade400, fontSize: 13), 
            filled: true, 
            fillColor: const Color(0xFFF7F7FB),
            prefixIcon: prefix == null
                ? Icon(icon, size: 18, color: Colors.grey.shade400)
                : Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const SizedBox(width: 12),
                      Icon(icon, size: 18, color: Colors.grey.shade400),
                      const SizedBox(width: 8),
                      Text(
                        prefix,
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: Colors.grey.shade400,
                        ),
                      ),
                      const SizedBox(width: 8),
                    ],
                  ),
            prefixIconConstraints: prefix == null
                ? null
                : const BoxConstraints(minWidth: 0, minHeight: 0),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
            counterText: '', // Hide character counter
          ),
          validator: validator,
        ),
      ],
    );
  }

  Widget _buildSectionLabel(String text) {
    return Text(text, style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: Colors.grey.shade400, letterSpacing: 0.8));
  }

  Widget _buildPaidBySelector(Color primary) {
    final availablePayers = widget.roommates
        .where((r) => _selectedRoommates.contains(r.id))
        .toList();

    _selectedPayers.removeWhere((uid) => !_selectedRoommates.contains(uid));
    _payerAmounts.removeWhere((uid, _) => !_selectedRoommates.contains(uid));

    if (availablePayers.length == 1 && _selectedPayers.isEmpty) {
      final onlyId = availablePayers.first.id;
      _selectedPayers.add(onlyId);
      _payerAmounts[onlyId] = double.tryParse(_amountController.text) ?? 0;
    }

    final paidTotal = _selectedPayers.fold<double>(0.0, (sum, uid) => sum + (_payerAmounts[uid] ?? 0));
    final targetTotal = double.tryParse(_amountController.text) ?? 0.0;
    final diff = targetTotal - paidTotal;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        InkWell(
          onTap: availablePayers.isEmpty ? null : () => _pickPayers(primary, availablePayers),
          borderRadius: BorderRadius.circular(12),
          child: Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFFF7F7FB),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFEEEEF2)),
            ),
            child: _selectedPayers.isEmpty
                ? Text(
                    availablePayers.isEmpty ? 'Select roommates first' : 'Tap to select payer(s)',
                    style: TextStyle(fontSize: 13, color: Colors.grey.shade400),
                  )
                : Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: _selectedPayers.map((id) {
                      final rmName = _roommateNameById(id);
                      return Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(
                          color: primary.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          rmName,
                          style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: primary),
                        ),
                      );
                    }).toList(),
                  ),
          ),
        ),
        if (_selectedPayers.isNotEmpty) ...[
          const SizedBox(height: 10),
          ..._selectedPayers.map((uid) {
            final rmName = _roommateNameById(uid);
            final current = _payerAmounts[uid] ?? 0;
            return Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      rmName,
                      style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                    ),
                  ),
                  SizedBox(
                    width: 120,
                    child: TextFormField(
                      initialValue: current > 0 ? current.toStringAsFixed(2) : '',
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      inputFormatters: [
                        FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d{0,2}')),
                      ],
                      decoration: InputDecoration(
                        hintText: '0.00',
                        prefixText: 'Rs. ',
                        contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                        filled: true,
                        fillColor: Colors.white,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: BorderSide.none,
                        ),
                      ),
                      onChanged: (v) {
                        _payerAmounts[uid] = double.tryParse(v) ?? 0;
                        if (mounted) setState(() {});
                      },
                    ),
                  ),
                ],
              ),
            );
          }),
          Text(
            diff.abs() <= 0.01
                ? 'Paid total matches expense'
                : 'Remaining to allocate: Rs. ${diff.toStringAsFixed(2)}',
            style: TextStyle(
              fontSize: 11,
              color: diff.abs() <= 0.01 ? Colors.green.shade700 : Colors.orange.shade700,
            ),
          ),
        ],
      ],
    );
  }

  void _pickPayers(Color primary, List<RoommateItem> availablePayers) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => StatefulBuilder(
        builder: (context, setAltState) {
          return Container(
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _buildHandle(),
                Padding(
                  padding: const EdgeInsets.all(20),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Select Payer(s)', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
                      TextButton(
                        onPressed: () {
                          setAltState(() {
                            if (_selectedPayers.length == availablePayers.length) {
                              _selectedPayers.clear();
                            } else {
                              _selectedPayers
                                ..clear()
                                ..addAll(availablePayers.map((r) => r.id));
                            }
                          });
                          setState(() {});
                        },
                        child: Text(
                          _selectedPayers.length == availablePayers.length ? 'None' : 'All',
                          style: TextStyle(color: primary),
                        ),
                      ),
                    ],
                  ),
                ),
                Flexible(
                  child: ListView.builder(
                    shrinkWrap: true,
                    itemCount: availablePayers.length,
                    itemBuilder: (context, i) {
                      final r = availablePayers[i];
                      final active = _selectedPayers.contains(r.id);
                      return ListTile(
                        leading: CircleAvatar(
                          radius: 14,
                          backgroundColor: active ? primary : const Color(0xFFF0F0F3),
                          child: Text(
                            r.name[0].toUpperCase(),
                            style: TextStyle(
                              fontSize: 11,
                              color: active ? Colors.white : primary,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        title: Text(r.name),
                        trailing: Checkbox(
                          value: active,
                          activeColor: primary,
                          onChanged: (v) {
                            setAltState(() {
                              if (v == true) {
                                _selectedPayers.add(r.id);
                                _payerAmounts.putIfAbsent(r.id, () => 0);
                              } else {
                                _selectedPayers.remove(r.id);
                                _payerAmounts.remove(r.id);
                              }
                            });
                            setState(() {});
                          },
                        ),
                      );
                    },
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(20),
                  child: SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: ElevatedButton(
                      onPressed: () {
                        final totalAmount = double.tryParse(_amountController.text) ?? 0.0;
                        if (_selectedPayers.length == 1) {
                          final only = _selectedPayers.first;
                          _payerAmounts[only] = totalAmount;
                        } else if (_selectedPayers.isNotEmpty) {
                          final already = _selectedPayers.fold<double>(0, (s, uid) => s + (_payerAmounts[uid] ?? 0));
                          if ((already - 0).abs() < 0.01) {
                            final even = _selectedPayers.isEmpty ? 0.0 : totalAmount / _selectedPayers.length;
                            for (final uid in _selectedPayers) {
                              _payerAmounts[uid] = even;
                            }
                          }
                        }
                        Navigator.pop(context);
                        if (mounted) setState(() {});
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: primary,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        elevation: 0,
                      ),
                      child: const Text('Confirm'),
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
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

  Widget _buildRoommateChipArea(Color primary) {
    return InkWell(
      onTap: () => _pickRoommates(primary),
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(12),
        width: double.infinity,
        decoration: BoxDecoration(color: const Color(0xFFF7F7FB), borderRadius: BorderRadius.circular(12), border: Border.all(color: const Color(0xFFEEEEF2))),
        child: _selectedRoommates.isEmpty 
          ? Text('Tap to select roommates', style: TextStyle(fontSize: 13, color: Colors.grey.shade400))
          : Wrap(spacing: 8, runSpacing: 8, children: _selectedRoommates.map((id) {
              final rmName = _roommateNameById(id);
              return Container(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6), decoration: BoxDecoration(color: primary.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(10)), child: Text(rmName, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: primary)));
            }).toList()),
      ),
    );
  }

  void _pickRoommates(Color primary) {
    showModalBottomSheet(context: context, backgroundColor: Colors.transparent, builder: (context) => StatefulBuilder(builder: (context, setAltState) {
      return Container(decoration: const BoxDecoration(color: Colors.white, borderRadius: BorderRadius.vertical(top: Radius.circular(20))), child: Column(mainAxisSize: MainAxisSize.min, children: [
        _buildHandle(),
        Padding(padding: const EdgeInsets.all(20), child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [const Text('Select Roommates', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)), TextButton(onPressed: () { setAltState(() { if (_selectedRoommates.length == widget.roommates.length) {
          _selectedRoommates.clear();
        } else {
          _selectedRoommates.addAll(widget.roommates.map((r) => r.id));
        } }); setState(() {}); }, child: Text(_selectedRoommates.length == widget.roommates.length ? 'None' : 'All', style: TextStyle(color: primary)))] )),
        Flexible(child: ListView.builder(shrinkWrap: true, itemCount: widget.roommates.length, itemBuilder: (context, i) {
          final r = widget.roommates[i];
          final active = _selectedRoommates.contains(r.id);
          return ListTile(leading: CircleAvatar(radius: 14, backgroundColor: active ? primary : const Color(0xFFF0F0F3), child: Text(r.name[0].toUpperCase(), style: TextStyle(fontSize: 11, color: active ? Colors.white : primary, fontWeight: FontWeight.bold))), title: Text(r.name, style: TextStyle(fontSize: 14, fontWeight: active ? FontWeight.w700 : FontWeight.w500)), trailing: Checkbox(value: active, activeColor: primary, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)), onChanged: (v) { setAltState(() { if (v!) {
            _selectedRoommates.add(r.id);
          } else {
            _selectedRoommates.remove(r.id);
          } }); setState(() {}); }), onTap: () { setAltState(() { if (active) {
            _selectedRoommates.remove(r.id);
          } else {
            _selectedRoommates.add(r.id);
          } }); setState(() {}); });
        })),
        Padding(padding: const EdgeInsets.all(20), child: SizedBox(width: double.infinity, height: 48, child: ElevatedButton(onPressed: () => Navigator.pop(context), style: ElevatedButton.styleFrom(backgroundColor: primary, foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)), elevation: 0), child: const Text('Confirm'))))
      ]));
    }));
  }

  Widget _buildSplitTypeSelector(Color primary) {
    return Row(children: SplitType.values.map((t) {
      final active = _splitType == t;
      return Expanded(child: GestureDetector(onTap: () => setState(() { _splitType = t; if (t != SplitType.equal) _initializeCustomSplits(); }), child: Container(margin: EdgeInsets.only(right: t == SplitType.equal ? 4 : (t == SplitType.percentage ? 4 : 0), left: t == SplitType.exact ? 4 : (t == SplitType.percentage ? 4 : 0)), padding: const EdgeInsets.symmetric(vertical: 10), decoration: BoxDecoration(color: active ? primary : const Color(0xFFF7F7FB), borderRadius: BorderRadius.circular(10), border: Border.all(color: active ? primary : const Color(0xFFEEEEF2))), child: Center(child: Text(t.label.split(' ').first, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: active ? Colors.white : Colors.grey.shade600))))));
    }).toList());
  }

  Widget _buildCustomInputs(Color primary) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: const Color(0xFFF7F7FB), borderRadius: BorderRadius.circular(12), border: Border.all(color: const Color(0xFFEEEEF2))),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: _selectedRoommates.map((id) {
        final rmName = _roommateNameById(id);
        return Padding(padding: const EdgeInsets.only(bottom: 12), child: Row(children: [
          Expanded(child: Text(rmName, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600))),
          SizedBox(width: 80, height: 36, child: TextFormField(
            initialValue: _customSplits[id]?.toStringAsFixed(0) ?? '0', 
            keyboardType: TextInputType.number, 
            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
            inputFormatters: _splitType == SplitType.percentage 
              ? [
                  FilteringTextInputFormatter.digitsOnly,
                  LengthLimitingTextInputFormatter(2), // Limit to 2 digits for percentage
                ]
              : [
                  FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d*')), // Allow decimals for exact amounts
                  LengthLimitingTextInputFormatter(8), // Limit to 8 characters for exact amounts
                ],
            decoration: InputDecoration(
              hintText: '0', 
              suffixText: _splitType == SplitType.percentage ? '%' : '', 
              contentPadding: const EdgeInsets.symmetric(horizontal: 12), 
              filled: true, 
              fillColor: Colors.white, 
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide.none)
            ), 
            onChanged: (v) => _customSplits[id] = double.tryParse(v) ?? 0
          )),
        ]));
      }).toList()),
    );
  }

  Widget _buildSubmit(Color primary) {
    return Column(
      children: [
        if (_errorMessage != null) Padding(padding: const EdgeInsets.only(bottom: 16), child: Text(_errorMessage!, style: const TextStyle(color: Colors.red, fontSize: 12, fontWeight: FontWeight.w600))),
        SizedBox(width: double.infinity, height: 52, child: ElevatedButton(onPressed: _isSubmitting ? null : _submit, style: ElevatedButton.styleFrom(backgroundColor: primary, foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)), elevation: 0), child: _isSubmitting ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)) : Text(_isEditing ? 'Update Expense' : 'Add Expense', style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700)))),
      ],
    );
  }

  void _initializeCustomSplits() {
    final amt = double.tryParse(_amountController.text) ?? 0;
    if (_selectedRoommates.isEmpty) return;
    if (_splitType == SplitType.percentage) {
      final p = 100.0 / _selectedRoommates.length;
      for (final id in _selectedRoommates) {
        _customSplits[id] = p;
      }
    } else if (_splitType == SplitType.exact && amt > 0) {
      final s = amt / _selectedRoommates.length;
      for (final id in _selectedRoommates) {
        _customSplits[id] = s;
      }
    }
  }
}
