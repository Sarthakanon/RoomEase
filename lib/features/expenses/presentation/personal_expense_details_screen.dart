import 'package:flutter/material.dart';
import 'package:room_ease/models/expense_models.dart';
import 'package:room_ease/services/api_service.dart';

/// Professional, minimalist screen for personal expense details.
class PersonalExpenseDetailsScreen extends StatefulWidget {
  final PersonalExpenseData expense;
  const PersonalExpenseDetailsScreen({super.key, required this.expense});

  @override
  State<PersonalExpenseDetailsScreen> createState() => _PersonalExpenseDetailsScreenState();
}

class _PersonalExpenseDetailsScreenState extends State<PersonalExpenseDetailsScreen> {
  final ApiService _apiService = ApiService();
  bool _isLoading = false;

  Future<void> _delete() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Delete Expense', style: TextStyle(fontWeight: FontWeight.w800)),
        content: const Text('Are you sure you want to remove this personal expense?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel', style: TextStyle(color: Colors.grey))),
          TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('Delete', style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold))),
        ],
      ),
    );
    if (confirmed != true) return;
    setState(() => _isLoading = true);
    try {
      await _apiService.deletePersonalExpense(widget.expense.id!);
      if (mounted) { Navigator.pop(context); ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Expense deleted'), backgroundColor: Colors.black87)); }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
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
        title: const Text('Expense Details', style: TextStyle(color: Color(0xFF1A1A2E), fontSize: 18, fontWeight: FontWeight.w700)),
        centerTitle: false,
        actions: [
          IconButton(onPressed: _delete, icon: const Icon(Icons.delete_outline_rounded, color: Colors.redAccent, size: 20)),
          const SizedBox(width: 8),
        ],
        bottom: PreferredSize(preferredSize: const Size.fromHeight(1), child: Container(color: const Color(0xFFF0F0F0), height: 1)),
      ),
      body: _isLoading ? const Center(child: CircularProgressIndicator()) : Center(
        child: SingleChildScrollView(
          padding: EdgeInsets.symmetric(horizontal: width > 600 ? width * 0.15 : 24, vertical: 32),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Container(padding: const EdgeInsets.all(20), decoration: BoxDecoration(color: const Color(0xFFF7F7FB), shape: BoxShape.circle), child: Icon(_getIcon(widget.expense.category), color: const Color(0xFF1A1A2E), size: 40)),
              const SizedBox(height: 24),
              Text(widget.expense.title, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: Color(0xFF1A1A2E))),
              const SizedBox(height: 8),
              Container(padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6), decoration: BoxDecoration(color: primary.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(12)), child: Text(widget.expense.category.toUpperCase(), style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: primary, letterSpacing: 0.8))),
              const SizedBox(height: 48),
              _buildInfoPanel(primary),
              const SizedBox(height: 32),
              if (widget.expense.description.isNotEmpty) ...[
                _buildSectionLabel('NOTES'),
                const SizedBox(height: 12),
                Container(width: double.infinity, padding: const EdgeInsets.all(20), decoration: BoxDecoration(color: const Color(0xFFF7F7FB), borderRadius: BorderRadius.circular(16), border: Border.all(color: const Color(0xFFEEEEF2))), child: Text(widget.expense.description, style: TextStyle(fontSize: 14, color: Colors.grey.shade700, height: 1.6))),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildInfoPanel(Color primary) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20), border: Border.all(color: const Color(0xFFEEEEF2)), boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.02), blurRadius: 20, offset: const Offset(0, 10))]),
      child: Column(children: [
        _buildRow('Amount', 'Rs. ${widget.expense.amount.toStringAsFixed(0)}', primary, isBold: true),
        const Padding(padding: EdgeInsets.symmetric(vertical: 16), child: Divider(height: 1, color: Color(0xFFF0F0F3))),
        _buildRow('Date', _fmtDate(widget.expense.createdAt), Colors.grey.shade700),
        const Padding(padding: EdgeInsets.symmetric(vertical: 16), child: Divider(height: 1, color: Color(0xFFF0F0F3))),
        _buildRow('Type', 'Personal', Colors.grey.shade700),
      ]),
    );
  }

  Widget _buildRow(String label, String value, Color valueColor, {bool isBold = false}) {
    return Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
      Text(label, style: TextStyle(fontSize: 13, color: Colors.grey.shade500, fontWeight: FontWeight.w500)),
      Text(value, style: TextStyle(fontSize: 15, fontWeight: isBold ? FontWeight.w800 : FontWeight.w700, color: valueColor)),
    ]);
  }

  Widget _buildSectionLabel(String text) {
    return Align(alignment: Alignment.centerLeft, child: Text(text, style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: Colors.grey.shade400, letterSpacing: 0.8)));
  }

  IconData _getIcon(String cat) {
    switch (cat.toLowerCase()) {
      case 'groceries': return Icons.shopping_basket_rounded;
      case 'utilities': return Icons.bolt_rounded;
      case 'rent': return Icons.home_rounded;
      case 'food': return Icons.restaurant_rounded;
      case 'transport': return Icons.directions_car_rounded;
      case 'entertainment': return Icons.movie_creation_rounded;
      default: return Icons.receipt_long_rounded;
    }
  }

  String _fmtDate(DateTime? d) {
    if (d == null) return 'N/A';
    return '${d.day} ${_getMonth(d.month)} ${d.year}';
  }

  String _getMonth(int m) {
    const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    return months[m - 1];
  }
}