import 'package:flutter/material.dart';
import 'package:room_ease/models/expense_models.dart';
import 'package:room_ease/services/expense_service.dart';
import 'package:room_ease/services/api_service.dart';
import 'package:room_ease/services/real_time_data_service.dart';

/// Professional, minimalist screen for editing shared expenses.
class EditExpenseScreen extends StatefulWidget {
  final ExpenseData expense;

  const EditExpenseScreen({super.key, required this.expense});

  @override
  State<EditExpenseScreen> createState() => _EditExpenseScreenState();
}

class _EditExpenseScreenState extends State<EditExpenseScreen> {
  final _formKey = GlobalKey<FormState>();
  final ExpenseService _expenseService = ExpenseService();
  final ApiService _apiService = ApiService();
  final RealTimeDataService _realTimeService = RealTimeDataService();
  
  late TextEditingController _titleController;
  late TextEditingController _descriptionController;
  late TextEditingController _amountController;
  
  late String _selectedCategory;
  late SplitType _selectedSplitType;
  List<Map<String, dynamic>> _roommates = [];
  List<String> _selectedRoommateIds = [];
  Map<String, double> _customSplits = {};
  
  bool _isLoading = false;
  bool _isLoadingRoommates = true;

  final List<String> _categories = ['General', 'Food', 'Groceries', 'Utilities', 'Rent', 'Entertainment', 'Transportation', 'Other'];

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController(text: widget.expense.title);
    _descriptionController = TextEditingController(text: widget.expense.description);
    _amountController = TextEditingController(text: widget.expense.amount.toStringAsFixed(0));
    _selectedCategory = widget.expense.category;
    _selectedSplitType = widget.expense.splitType;
    if (widget.expense.splits != null) {
      _selectedRoommateIds = widget.expense.splits!.map((s) => s.userUid).toList();
      if (_selectedSplitType != SplitType.equal) {
        for (final s in widget.expense.splits!) {
          _customSplits[s.userUid] = _selectedSplitType == SplitType.percentage ? (s.percentage ?? 0.0) : s.amount;
        }
      }
    }
    _loadRoommates();
  }

  Future<void> _loadRoommates() async {
    if (widget.expense.roomspaceId == null) return;
    try {
      final res = await _apiService.getRoomspaceMembers(widget.expense.roomspaceId!);
      if (res['success'] == true && res['data'] != null) {
        setState(() { _roommates = List<Map<String, dynamic>>.from(res['data']); _isLoadingRoommates = false; });
      }
    } catch (e) {
      setState(() => _isLoadingRoommates = false);
    }
  }

  Future<void> _update() async {
    if (!_formKey.currentState!.validate() || _selectedRoommateIds.isEmpty) return;
    setState(() => _isLoading = true);
    try {
      final req = ExpenseCreateRequest(
        roomspaceId: widget.expense.roomspaceId!,
        title: _titleController.text.trim(),
        description: _descriptionController.text.trim(),
        amount: double.parse(_amountController.text),
        category: _selectedCategory,
        splitType: _selectedSplitType.apiValue,
        selectedRoommates: _selectedRoommateIds,
        customSplits: _selectedSplitType != SplitType.equal ? _customSplits : null,
      );
      
      final updated = await _expenseService.updateExpense(widget.expense.id!, req);
      
      // Notify real-time service about the expense update
      if (widget.expense.roomspaceId != null) {
        final updatedExpenseData = {
          'id': widget.expense.id,
          'title': _titleController.text.trim(),
          'amount': double.parse(_amountController.text),
          'category': _selectedCategory,
          'roomspace_id': widget.expense.roomspaceId,
        };
        
        // Get all affected users (original + new selected roommates)
        final affectedUsers = <String>{};
        if (widget.expense.splits != null) {
          affectedUsers.addAll(widget.expense.splits!.map((s) => s.userUid));
        }
        affectedUsers.addAll(_selectedRoommateIds);
        
        _realTimeService.notifyExpenseUpdated(
          widget.expense.roomspaceId!,
          updatedExpenseData,
          affectedUsers.toList(),
        );
      }
      
      if (mounted) {
        // Show success message
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Expense updated successfully! Teammates have been notified.'),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 2),
          ),
        );
        Navigator.pop(context, true); // Return true to indicate success
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to update expense: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;
    final width = MediaQuery.of(context).size.width;

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white, elevation: 0,
        leading: IconButton(icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Color(0xFF1A1A2E), size: 18), onPressed: () => Navigator.pop(context)),
        title: const Text('Edit Expense', style: TextStyle(color: Color(0xFF1A1A2E), fontSize: 18, fontWeight: FontWeight.w700)),
        centerTitle: false,
        actions: [
          TextButton(onPressed: _isLoading ? null : _update, child: _isLoading ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2)) : Text('Save', style: TextStyle(color: primary, fontWeight: FontWeight.w700))),
          const SizedBox(width: 8),
        ],
        bottom: PreferredSize(preferredSize: const Size.fromHeight(1), child: Container(color: const Color(0xFFF0F0F0), height: 1)),
      ),
      body: _isLoadingRoommates 
        ? const Center(child: CircularProgressIndicator())
        : Center(
            child: SingleChildScrollView(
              padding: EdgeInsets.symmetric(horizontal: width > 600 ? width * 0.1 : 24, vertical: 24),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildField(controller: _titleController, label: 'TITLE', hint: 'Title', icon: Icons.title_rounded),
                    const SizedBox(height: 20),
                    _buildField(controller: _amountController, label: 'AMOUNT', hint: '0', icon: Icons.payments_outlined, isNumeric: true, prefix: 'Rs. '),
                    const SizedBox(height: 24),
                    _buildSectionLabel('CATEGORY'),
                    const SizedBox(height: 12),
                    _buildCategoryDropdown(),
                    const SizedBox(height: 24),
                    _buildSectionLabel('SPLIT TYPE'),
                    const SizedBox(height: 12),
                    _buildSplitSelector(primary),
                    const SizedBox(height: 24),
                    _buildSectionLabel('ROOMMATES'),
                    const SizedBox(height: 12),
                    _buildRoommateList(primary),
                    if (_selectedSplitType != SplitType.equal) ...[
                      const SizedBox(height: 24),
                      _buildCustomInputs(),
                    ],
                    const SizedBox(height: 32),
                    _buildField(controller: _descriptionController, label: 'DESCRIPTION', hint: 'Notes...', icon: Icons.notes_rounded, maxLines: 3),
                  ],
                ),
              ),
            ),
          ),
    );
  }

  Widget _buildField({required TextEditingController controller, required String label, required String hint, required IconData icon, bool isNumeric = false, String? prefix, int maxLines = 1}) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
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
        validator: (v) => v!.isEmpty ? 'Required' : null,
      ),
    ]);
  }

  Widget _buildSectionLabel(String text) {
    return Text(text, style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: Colors.grey.shade400, letterSpacing: 0.8));
  }

  Widget _buildCategoryDropdown() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(color: const Color(0xFFF7F7FB), borderRadius: BorderRadius.circular(12)),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: _selectedCategory, isExpanded: true, icon: const Icon(Icons.keyboard_arrow_down_rounded, size: 20),
          items: _categories.map((c) => DropdownMenuItem(value: c, child: Text(c, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600)))).toList(),
          onChanged: (v) => setState(() => _selectedCategory = v!),
        ),
      ),
    );
  }

  Widget _buildSplitSelector(Color primary) {
    return Row(children: SplitType.values.map((t) {
      final active = _selectedSplitType == t;
      return Expanded(child: GestureDetector(onTap: () => setState(() => _selectedSplitType = t), child: Container(margin: EdgeInsets.only(right: t == SplitType.equal ? 4 : (t == SplitType.percentage ? 4 : 0), left: t == SplitType.exact ? 4 : (t == SplitType.percentage ? 4 : 0)), padding: const EdgeInsets.symmetric(vertical: 10), decoration: BoxDecoration(color: active ? primary : const Color(0xFFF7F7FB), borderRadius: BorderRadius.circular(10), border: Border.all(color: active ? primary : const Color(0xFFEEEEF2))), child: Center(child: Text(t.label.split(' ').first, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: active ? Colors.white : Colors.grey.shade600))))));
    }).toList());
  }

  Widget _buildRoommateList(Color primary) {
    return Container(
      decoration: BoxDecoration(color: const Color(0xFFF7F7FB), borderRadius: BorderRadius.circular(12), border: Border.all(color: const Color(0xFFEEEEF2))),
      child: Column(children: _roommates.map((r) {
        final id = (r['user_id'] ?? r['firebase_uid']).toString();
        final active = _selectedRoommateIds.contains(id);
        return CheckboxListTile(title: Text(r['name'] ?? 'Member', style: TextStyle(fontSize: 14, fontWeight: active ? FontWeight.w700 : FontWeight.w500)), value: active, activeColor: primary, controlAffinity: ListTileControlAffinity.trailing, checkboxShape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)), onChanged: (v) => setState(() { if (v!) _selectedRoommateIds.add(id); else _selectedRoommateIds.remove(id); }));
      }).toList()),
    );
  }

  Widget _buildCustomInputs() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: const Color(0xFFF7F7FB), borderRadius: BorderRadius.circular(12), border: Border.all(color: const Color(0xFFEEEEF2))),
      child: Column(children: _selectedRoommateIds.map((id) {
        final r = _roommates.firstWhere((m) => (m['user_id'] ?? m['firebase_uid']).toString() == id, orElse: () => {});
        return Padding(padding: const EdgeInsets.only(bottom: 12), child: Row(children: [
          Expanded(child: Text(r['name'] ?? 'Member', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600))),
          SizedBox(width: 80, height: 36, child: TextFormField(initialValue: _customSplits[id]?.toStringAsFixed(0) ?? '0', keyboardType: TextInputType.number, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700), decoration: InputDecoration(hintText: '0', suffixText: _selectedSplitType == SplitType.percentage ? '%' : '', contentPadding: const EdgeInsets.symmetric(horizontal: 12), filled: true, fillColor: Colors.white, border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide.none)), onChanged: (v) => _customSplits[id] = double.tryParse(v) ?? 0)),
        ]));
      }).toList()),
    );
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _amountController.dispose();
    super.dispose();
  }
}