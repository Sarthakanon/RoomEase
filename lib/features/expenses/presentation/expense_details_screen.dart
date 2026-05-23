import 'package:flutter/material.dart';
import 'package:room_ease/models/expense_models.dart';
import 'package:room_ease/services/expense_service.dart';
import 'package:room_ease/features/expenses/presentation/edit_expense_screen.dart';
import 'package:firebase_auth/firebase_auth.dart';

/// Screen displaying comprehensive details of a specific expense.
class ExpenseDetailsScreen extends StatefulWidget {
  final ExpenseData expense;

  const ExpenseDetailsScreen({
    super.key,
    required this.expense,
  });

  @override
  State<ExpenseDetailsScreen> createState() => _ExpenseDetailsScreenState();
}

class _ExpenseDetailsScreenState extends State<ExpenseDetailsScreen> {
  final ExpenseService _expenseService = ExpenseService();
  late ExpenseData _expense;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _expense = widget.expense;
  }

  Future<void> _deleteExpense() async {
    if (_expense.id == null) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Delete Expense', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
        content: Text('Delete "${_expense.title}"?', style: const TextStyle(fontSize: 14)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: Text('Cancel', style: TextStyle(color: Colors.grey.shade600))),
          TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('Delete', style: TextStyle(color: Color(0xFFC62828), fontWeight: FontWeight.w700))),
        ],
      ),
    );
    if (confirmed != true) return;
    setState(() => _isLoading = true);
    try {
      await _expenseService.deleteExpense(_expense.id!);
      if (mounted) Navigator.pop(context, true);
    } catch (_) {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _editExpense() async {
    final res = await Navigator.push<ExpenseData>(context, MaterialPageRoute(builder: (context) => EditExpenseScreen(expense: _expense)));
    if (res != null) setState(() => _expense = res);
  }

  @override
  Widget build(BuildContext context) {
    final primaryColor = Theme.of(context).colorScheme.primary;
    final isMe = _expense.paidBy == FirebaseAuth.instance.currentUser?.uid;

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        title: const Text('Details', style: TextStyle(color: Color(0xFF1A1A2E), fontWeight: FontWeight.w700, fontSize: 17)),
        leading: IconButton(icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Color(0xFF1A1A2E), size: 18), onPressed: () => Navigator.pop(context)),
        actions: [
          if (isMe) ...[
            IconButton(icon: Icon(Icons.edit_outlined, color: Colors.grey.shade600, size: 20), onPressed: _editExpense),
            IconButton(icon: Icon(Icons.delete_outline_rounded, color: Colors.grey.shade600, size: 20), onPressed: _deleteExpense),
          ],
        ],
        bottom: PreferredSize(preferredSize: const Size.fromHeight(1), child: Container(color: const Color(0xFFF0F0F0), height: 1)),
      ),
      body: _isLoading 
        ? Center(child: CircularProgressIndicator(color: primaryColor))
        : SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildSummary(primaryColor),
                const SizedBox(height: 32),
                _buildSectionTitle('INFORMATION'),
                const SizedBox(height: 12),
                _buildInfoGrid(isMe),
                if (_expense.description.isNotEmpty) ...[
                  const SizedBox(height: 24),
                  _buildSectionTitle('DESCRIPTION'),
                  const SizedBox(height: 8),
                  Text(_expense.description, style: TextStyle(color: Colors.grey.shade600, fontSize: 13, height: 1.5)),
                ],
                const SizedBox(height: 32),
                _buildSectionTitle('SPLIT DETAILS'),
                const SizedBox(height: 12),
                _buildSplitList(primaryColor),
                const SizedBox(height: 40),
              ],
            ),
          ),
    );
  }

  Widget _buildSummary(Color primary) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(color: const Color(0xFFF7F7FB), borderRadius: BorderRadius.circular(16), border: Border.all(color: const Color(0xFFEEEEF2))),
      child: Column(
        children: [
          Text(_expense.title, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Colors.grey.shade500)),
          const SizedBox(height: 4),
          Text('Rs. ${_expense.amount.toStringAsFixed(0)}', style: TextStyle(fontSize: 32, fontWeight: FontWeight.w900, color: primary)),
          const SizedBox(height: 4),
          Text(_formatDate(_expense.createdAt ?? DateTime.now()), style: TextStyle(fontSize: 11, color: Colors.grey.shade400)),
        ],
      ),
    );
  }

  Widget _buildInfoGrid(bool isMe) {
    return Row(
      children: [
        Expanded(child: _buildInfoItem(Icons.category_outlined, _expense.category, Colors.orange)),
        const SizedBox(width: 12),
        Expanded(child: _buildInfoItem(Icons.person_outline_rounded, isMe ? 'Paid by You' : 'Paid by ${_expense.payerName ?? 'Self'}', Colors.blue)),
      ],
    );
  }

  Widget _buildInfoItem(IconData icon, String label, Color color) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), border: Border.all(color: const Color(0xFFEEEEF2))),
      child: Row(
        children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(width: 8),
          Expanded(child: Text(label, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF1A1A2E)), overflow: TextOverflow.ellipsis)),
        ],
      ),
    );
  }

  Widget _buildSplitList(Color primary) {
    final splits = _expense.splits ?? [];
    return Container(
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), border: Border.all(color: const Color(0xFFEEEEF2))),
      child: ListView.separated(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        itemCount: splits.length,
        separatorBuilder: (_, __) => Divider(height: 1, color: const Color(0xFFF0F0F3), indent: 56),
        itemBuilder: (context, index) {
          final split = splits[index];
          final isMe = split.userUid == FirebaseAuth.instance.currentUser?.uid;

          return ListTile(
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            leading: CircleAvatar(
              radius: 14,
              backgroundColor: isMe ? primary : primary.withValues(alpha: 0.1),
              child: Text(split.userName[0].toUpperCase(), style: TextStyle(color: isMe ? Colors.white : primary, fontWeight: FontWeight.w700, fontSize: 11)),
            ),
            title: Text(isMe ? 'You' : split.userName, style: TextStyle(fontSize: 13, fontWeight: isMe ? FontWeight.w700 : FontWeight.w500, color: const Color(0xFF1A1A2E))),
            subtitle: split.percentage != null ? Text('${split.percentage!.toStringAsFixed(0)}%', style: TextStyle(fontSize: 10, color: Colors.grey.shade400)) : null,
            trailing: Text('Rs. ${split.amount.toStringAsFixed(0)}', style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: Color(0xFF1A1A2E))),
          );
        },
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Text(title, style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: Colors.grey.shade400, letterSpacing: 0.8));
  }

  String _formatDate(DateTime d) {
    final n = DateTime.now();
    if (n.difference(d).inDays == 0) return 'Today';
    if (n.difference(d).inDays == 1) return 'Yesterday';
    return '${d.day}/${d.month}/${d.year}';
  }
}
