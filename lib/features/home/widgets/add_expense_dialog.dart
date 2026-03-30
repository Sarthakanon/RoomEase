import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:provider/provider.dart';
import '../../../models/payment_notification.dart';
import '../../../models/expense_models.dart';
import '../../../providers/roomspace_provider.dart';
import '../../../services/payment_parser_service.dart';
import '../../../utils/expense_calculation_utils.dart';
import 'receipt_scanner_dialog.dart';

/// Premium, responsive dialog for adding shared expenses.
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
  String? _paidBy; // Who actually paid for this expense
  SplitType _splitType = SplitType.equal;
  final Map<String, double> _customSplits = {};

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
    if (!_formKey.currentState!.validate()) return;
    
    if (_paidBy == null) {
      if (mounted) {
        setState(() => _errorMessage = 'Select who paid for this expense');
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
        paidBy: _paidBy, // Include who paid
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
  
  void _showSoloExpenseDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Icon(Icons.info_outline, color: Theme.of(context).colorScheme.primary),
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
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              Navigator.pop(context); // Close dialog
              Navigator.pop(context); // Close expense dialog
              _switchToPersonalAndAddExpense();
            },
            child: const Text('Switch to Personal'),
          ),
        ],
      ),
    );
  }
  
  void _switchToPersonalAndAddExpense() async {
    // Import provider
    final roomspaceProvider = Provider.of<RoomspaceProvider>(context, listen: false);
    
    // Switch to personal space
    await roomspaceProvider.switchToPersonalSpace();
    
    // Show snackbar
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Switched to Personal Space. Add your expense now.'),
          duration: Duration(seconds: 2),
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
                    _buildField(controller: _titleController, label: 'TITLE', hint: 'e.g. Electricity Bill', icon: Icons.title_rounded, validator: (v) => v!.isEmpty ? 'Title required' : null),
                    const SizedBox(height: 20),
                    _buildField(controller: _amountController, label: 'AMOUNT', hint: '0', icon: Icons.payments_outlined, isNumeric: true, prefix: 'Rs. ', validator: (v) => (double.tryParse(v ?? '') ?? 0) <= 0 ? 'Invalid amount' : null),
                    const SizedBox(height: 24),
                    _buildSectionLabel('PAID BY'),
                    const SizedBox(height: 8),
                    _buildPaidBySelector(primary),
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
                    _buildSectionLabel('SPLIT TYPE'),
                    const SizedBox(height: 12),
                    _buildSplitTypeSelector(primary),
                    if (_splitType != SplitType.equal && _selectedRoommates.isNotEmpty) ...[
                      const SizedBox(height: 20),
                      _buildCustomInputs(primary),
                    ],
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
          const Text('Add Expense', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: Color(0xFF1A1A2E))),
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

  Widget _buildField({required TextEditingController controller, required String label, required String hint, required IconData icon, bool isNumeric = false, String? prefix, String? Function(String?)? validator}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionLabel(label),
        const SizedBox(height: 8),
        TextFormField(
          controller: controller, keyboardType: isNumeric ? const TextInputType.numberWithOptions(decimal: true) : null,
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

  Widget _buildPaidBySelector(Color primary) {
    // Only show roommates who are selected in the split
    final availablePayers = widget.roommates
        .where((r) => _selectedRoommates.contains(r.id))
        .toList();
    
    // Auto-select if only one roommate is selected
    if (availablePayers.length == 1 && _paidBy != availablePayers.first.id) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        setState(() {
          _paidBy = availablePayers.first.id;
        });
      });
    }
    
    // Clear paidBy if the selected payer is no longer in the split
    if (_paidBy != null && !_selectedRoommates.contains(_paidBy)) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        setState(() {
          _paidBy = null;
        });
      });
    }
    
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      decoration: BoxDecoration(
        color: const Color(0xFFF7F7FB),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFEEEEF2)),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: _paidBy,
          hint: Text(
            availablePayers.isEmpty 
                ? 'Select roommates first' 
                : 'Who paid?',
            style: TextStyle(color: Colors.grey.shade400, fontSize: 13),
          ),
          isExpanded: true,
          icon: Icon(Icons.arrow_drop_down, color: Colors.grey.shade600),
          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Color(0xFF1A1A2E)),
          items: availablePayers.map((roommate) {
            return DropdownMenuItem<String>(
              value: roommate.id,
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 12,
                    backgroundColor: primary.withValues(alpha: 0.1),
                    child: Text(
                      roommate.name[0].toUpperCase(),
                      style: TextStyle(fontSize: 10, color: primary, fontWeight: FontWeight.bold),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Text(roommate.name),
                ],
              ),
            );
          }).toList(),
          onChanged: availablePayers.isEmpty ? null : (value) {
            setState(() {
              _paidBy = value;
            });
          },
        ),
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
              final rm = widget.roommates.firstWhere((r) => r.id == id);
              return Container(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6), decoration: BoxDecoration(color: primary.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(10)), child: Text(rm.name, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: primary)));
            }).toList()),
      ),
    );
  }

  void _pickRoommates(Color primary) {
    showModalBottomSheet(context: context, backgroundColor: Colors.transparent, builder: (context) => StatefulBuilder(builder: (context, setAltState) {
      return Container(decoration: const BoxDecoration(color: Colors.white, borderRadius: BorderRadius.vertical(top: Radius.circular(20))), child: Column(mainAxisSize: MainAxisSize.min, children: [
        _buildHandle(),
        Padding(padding: const EdgeInsets.all(20), child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [const Text('Select Roommates', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)), TextButton(onPressed: () { setAltState(() { if (_selectedRoommates.length == widget.roommates.length) _selectedRoommates.clear(); else _selectedRoommates.addAll(widget.roommates.map((r) => r.id)); }); setState(() {}); }, child: Text(_selectedRoommates.length == widget.roommates.length ? 'None' : 'All', style: TextStyle(color: primary)))] )),
        Flexible(child: ListView.builder(shrinkWrap: true, itemCount: widget.roommates.length, itemBuilder: (context, i) {
          final r = widget.roommates[i];
          final active = _selectedRoommates.contains(r.id);
          return ListTile(leading: CircleAvatar(radius: 14, backgroundColor: active ? primary : const Color(0xFFF0F0F3), child: Text(r.name[0].toUpperCase(), style: TextStyle(fontSize: 11, color: active ? Colors.white : primary, fontWeight: FontWeight.bold))), title: Text(r.name, style: TextStyle(fontSize: 14, fontWeight: active ? FontWeight.w700 : FontWeight.w500)), trailing: Checkbox(value: active, activeColor: primary, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)), onChanged: (v) { setAltState(() { if (v!) _selectedRoommates.add(r.id); else _selectedRoommates.remove(r.id); }); setState(() {}); }), onTap: () { setAltState(() { if (active) _selectedRoommates.remove(r.id); else _selectedRoommates.add(r.id); }); setState(() {}); });
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
        final rm = widget.roommates.firstWhere((r) => r.id == id);
        return Padding(padding: const EdgeInsets.only(bottom: 12), child: Row(children: [
          Expanded(child: Text(rm.name, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600))),
          SizedBox(width: 80, height: 36, child: TextFormField(initialValue: _customSplits[id]?.toStringAsFixed(0) ?? '0', keyboardType: TextInputType.number, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700), decoration: InputDecoration(hintText: '0', suffixText: _splitType == SplitType.percentage ? '%' : '', contentPadding: const EdgeInsets.symmetric(horizontal: 12), filled: true, fillColor: Colors.white, border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide.none)), onChanged: (v) => _customSplits[id] = double.tryParse(v) ?? 0)),
        ]));
      }).toList()),
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

  void _initializeCustomSplits() {
    final amt = double.tryParse(_amountController.text) ?? 0;
    if (_selectedRoommates.isEmpty) return;
    if (_splitType == SplitType.percentage) {
      final p = 100.0 / _selectedRoommates.length;
      for (final id in _selectedRoommates) _customSplits[id] = p;
    } else if (_splitType == SplitType.exact && amt > 0) {
      final s = amt / _selectedRoommates.length;
      for (final id in _selectedRoommates) _customSplits[id] = s;
    }
  }
}
