import 'package:flutter/material.dart';
import 'package:room_ease/models/expense_models.dart';
import 'package:room_ease/services/expense_service.dart';
import 'package:room_ease/features/expenses/presentation/edit_expense_screen.dart';
import 'package:firebase_auth/firebase_auth.dart';

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

  Future<void> _refreshExpense() async {
    if (_expense.id == null) return;

    setState(() => _isLoading = true);

    try {
      final updatedExpense = await _expenseService.getExpenseById(_expense.id!);
      setState(() {
        _expense = updatedExpense;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to refresh: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<void> _deleteExpense() async {
    if (_expense.id == null) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Delete Expense'),
        content: Text('Are you sure you want to delete "${_expense.title}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('Cancel', style: TextStyle(color: Colors.grey[600])),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    setState(() => _isLoading = true);

    try {
      await _expenseService.deleteExpense(_expense.id!);
      if (mounted) {
        Navigator.pop(context, true);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Expense deleted successfully'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to delete: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _editExpense() async {
    final result = await Navigator.push<ExpenseData>(
      context,
      MaterialPageRoute(
        builder: (context) => EditExpenseScreen(expense: _expense),
      ),
    );

    if (result != null) {
      setState(() {
        _expense = result;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final currentUser = FirebaseAuth.instance.currentUser;
    final isPaidByCurrentUser = _expense.paidBy == currentUser?.uid;
    final primaryColor = Theme.of(context).colorScheme.primary;

    // Only the payer can edit/delete
    final canEdit = isPaidByCurrentUser; 

    return Scaffold(
      backgroundColor: Colors.grey[50], // Light background for body
      body: _isLoading
          ? Center(child: CircularProgressIndicator(color: primaryColor))
          : SingleChildScrollView(
              child: Column(
                children: [
                  // 1. HEADER (Matches MobileDashboard style)
                  _buildHeader(context, primaryColor, canEdit),

                  // 2. BODY CONTENT
                  Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Info Chips
                        Row(
                          children: [
                            _buildInfoChip(
                              icon: _getCategoryIcon(_expense.category),
                              label: _expense.category,
                              color: Colors.orange,
                              bgColor: Colors.orange.withValues(alpha: 0.1),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: _buildInfoChip(
                                icon: Icons.person_outline,
                                label: isPaidByCurrentUser
                                    ? 'Paid by You'
                                    : 'Paid by ${_expense.payerName ?? 'Someone'}',
                                color: Colors.blue,
                                bgColor: Colors.blue.withValues(alpha: 0.1),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 20),

                        // Description (if exists)
                        if (_expense.description.isNotEmpty) ...[
                          Text(
                            "Description",
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: Colors.grey[800],
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            _expense.description,
                            style: TextStyle(
                              color: Colors.grey[600],
                              height: 1.5,
                            ),
                          ),
                          const SizedBox(height: 24),
                        ],

                        // Balance Card
                        _buildBalanceCard(context, isPaidByCurrentUser),
                        
                        const SizedBox(height: 24),

                        // Split Details List (Matches Roomspace Member List style)
                        Text(
                          "Split Details",
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Colors.grey[800],
                          ),
                        ),
                        const SizedBox(height: 12),
                        _buildSplitList(primaryColor),
                        
                        const SizedBox(height: 40),
                      ],
                    ),
                  ),
                ],
              ),
            ),
    );
  }

  Widget _buildHeader(BuildContext context, Color primaryColor, bool canEdit) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.only(
        left: 20,
        right: 20,
        top: 60,
        bottom: 30,
      ),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [primaryColor, primaryColor.withValues(alpha: 0.8)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: const BorderRadius.only(
          bottomLeft: Radius.circular(30),
          bottomRight: Radius.circular(30),
        ),
      ),
      child: Column(
        children: [
          // Actions Row (Top Right)
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              IconButton(
                onPressed: _refreshExpense,
                icon: const Icon(Icons.refresh, color: Colors.white),
                tooltip: 'Refresh',
              ),
              if (canEdit) ...[
                IconButton(
                  onPressed: _editExpense,
                  icon: const Icon(Icons.edit_outlined, color: Colors.white),
                  tooltip: 'Edit',
                ),
                IconButton(
                  onPressed: _deleteExpense,
                  icon: const Icon(Icons.delete_outline, color: Colors.white),
                  tooltip: 'Delete',
                ),
              ],
            ],
          ),
          
          const SizedBox(height: 10),
          
          // Main Content
          Text(
            _expense.title,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.9),
              fontSize: 16,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Rs. ${_expense.amount.toStringAsFixed(2)}',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 36,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              _formatDate(_expense.createdAt ?? DateTime.now()),
              style: const TextStyle(
                color: Colors.white,
                fontSize: 13,
                fontWeight: FontWeight.w500
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoChip({
    required IconData icon, 
    required String label, 
    required Color color, 
    required Color bgColor
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 20, color: color),
          const SizedBox(width: 8),
          Flexible(
            child: Text(
              label,
              style: TextStyle(
                color: color,
                fontWeight: FontWeight.bold,
                fontSize: 14,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBalanceCard(BuildContext context, bool isPaidByCurrentUser) {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null || _expense.splits == null) return const SizedBox.shrink();

    final currentUserSplit = _expense.splits!
        .where((split) => split.userUid == currentUser.uid)
        .firstOrNull;
    
    if (currentUserSplit == null) return const SizedBox.shrink();

    final userOwes = currentUserSplit.amount;
    final balance = isPaidByCurrentUser ? (_expense.amount - userOwes) : -userOwes;
    final isPositive = balance > 0;
    
    // Using dashboard colors
    final color = isPositive ? Colors.greenAccent : Colors.redAccent;
    final bgColor = isPositive ? const Color(0xFFECFDF5) : const Color(0xFFFEF2F2);
    final borderColor = isPositive ? const Color(0xFF10B981) : const Color(0xFFEF4444);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: borderColor.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                isPositive ? Icons.check_circle_outline : Icons.info_outline,
                color: borderColor,
              ),
              const SizedBox(width: 8),
              Text(
                isPositive ? 'You are owed' : 'You owe',
                style: TextStyle(
                  color: Colors.grey[700],
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'Rs. ${balance.abs().toStringAsFixed(2)}',
            style: TextStyle(
              color: borderColor,
              fontSize: 28,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSplitList(Color primaryColor) {
    if (_expense.splits == null || _expense.splits!.isEmpty) {
      return const Text("No split details available");
    }

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ListView.separated(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        itemCount: _expense.splits!.length,
        separatorBuilder: (_, __) =>
            Divider(height: 1, indent: 70, color: Colors.grey[100]),
        itemBuilder: (context, index) {
          final split = _expense.splits![index];
          final currentUser = FirebaseAuth.instance.currentUser;
          final isCurrentUser = split.userUid == currentUser?.uid;

          return Container(
            decoration: isCurrentUser
                ? BoxDecoration(
                    color: primaryColor.withValues(alpha: 0.05),
                    border: Border(
                      left: BorderSide(color: primaryColor, width: 3),
                    ),
                  )
                : null,
            child: ListTile(
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 8,
              ),
              leading: CircleAvatar(
                backgroundColor: isCurrentUser
                    ? primaryColor
                    : primaryColor.withValues(alpha: 0.1),
                child: Text(
                  (split.userName.isNotEmpty ? split.userName[0] : '?').toUpperCase(),
                  style: TextStyle(
                    color: isCurrentUser ? Colors.white : primaryColor,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              title: Text(
                isCurrentUser ? 'You' : split.userName,
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  color: isCurrentUser ? primaryColor : Colors.black87,
                ),
              ),
              subtitle: split.percentage != null
                  ? Text(
                      '${split.percentage!.toStringAsFixed(1)}%',
                      style: TextStyle(fontSize: 12, color: Colors.grey[500]),
                    )
                  : null,
              trailing: Text(
                'Rs. ${split.amount.toStringAsFixed(2)}',
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  IconData _getCategoryIcon(String category) {
    switch (category.toLowerCase()) {
      case 'groceries': return Icons.shopping_basket_rounded;
      case 'utilities': return Icons.bolt_rounded;
      case 'rent': return Icons.home_rounded;
      case 'food': return Icons.restaurant_rounded;
      case 'transport':
      case 'transportation': return Icons.directions_car_rounded;
      case 'entertainment': return Icons.movie_creation_rounded;
      default: return Icons.receipt_long_rounded;
    }
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final difference = now.difference(date);
    
    if (difference.inDays == 0) return 'Today';
    if (difference.inDays == 1) return 'Yesterday';
    return '${date.day}/${date.month}/${date.year}';
  }
}