import 'package:flutter/material.dart';
import '../../../services/expense_deletion_service.dart';

/// Screen showing deletion history with recovery options
class DeletionHistoryScreen extends StatefulWidget {
  final String roomspaceId;

  const DeletionHistoryScreen({
    super.key,
    required this.roomspaceId,
  });

  @override
  State<DeletionHistoryScreen> createState() => _DeletionHistoryScreenState();
}

class _DeletionHistoryScreenState extends State<DeletionHistoryScreen> {
  final ExpenseDeletionService _deletionService = ExpenseDeletionService();
  List<DeletionHistoryItem> _deletionHistory = [];
  bool _isLoading = true;
  bool _hasError = false;
  String _errorMessage = '';

  @override
  void initState() {
    super.initState();
    _loadDeletionHistory();
  }

  Future<void> _loadDeletionHistory() async {
    setState(() {
      _isLoading = true;
      _hasError = false;
    });

    try {
      final history = await _deletionService.getDeletionHistory(widget.roomspaceId);
      setState(() {
        _deletionHistory = history;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _hasError = true;
        _errorMessage = e.toString();
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        title: const Text(
          'Deletion History',
          style: TextStyle(
            color: Color(0xFF1A1A2E),
            fontWeight: FontWeight.w700,
            fontSize: 17,
          ),
        ),
        leading: IconButton(
          icon: const Icon(
            Icons.arrow_back_ios_new_rounded,
            color: Color(0xFF1A1A2E),
            size: 18,
          ),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          IconButton(
            icon: Icon(
              Icons.refresh_rounded,
              color: Colors.grey.shade600,
              size: 20,
            ),
            onPressed: _loadDeletionHistory,
          ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(color: const Color(0xFFF0F0F0), height: 1),
        ),
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(
        child: CircularProgressIndicator(),
      );
    }

    if (_hasError) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.error_outline_rounded,
                size: 48,
                color: Colors.grey.shade300,
              ),
              const SizedBox(height: 16),
              const Text(
                'Failed to load deletion history',
                style: TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 15,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                _errorMessage,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.grey.shade500,
                  fontSize: 12,
                ),
              ),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: _loadDeletionHistory,
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
      );
    }

    if (_deletionHistory.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.history_rounded,
              size: 48,
              color: Colors.grey.shade200,
            ),
            const SizedBox(height: 16),
            Text(
              'No deletion history',
              style: TextStyle(
                color: Colors.grey.shade400,
                fontSize: 14,
              ),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadDeletionHistory,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: _deletionHistory.length,
        itemBuilder: (context, index) {
          final item = _deletionHistory[index];
          return _DeletionHistoryTile(
            item: item,
            onRecover: item.canRecover ? () => _recoverExpense(item) : null,
          );
        },
      ),
    );
  }

  Future<void> _recoverExpense(DeletionHistoryItem item) async {
    if (item.expenseId == null) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Recover Expense'),
        content: Text(
          'Are you sure you want to recover "${item.expenseTitle}"? This will restore the expense and notify all roommates.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Recover'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      await _deletionService.recoverExpense(
        item.expenseId!,
        'current_user_id', // Replace with actual user ID
      );

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Expense recovered successfully!'),
          backgroundColor: Colors.green,
        ),
      );

      // Refresh the history
      _loadDeletionHistory();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to recover expense: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }
}

/// Individual deletion history tile
class _DeletionHistoryTile extends StatelessWidget {
  final DeletionHistoryItem item;
  final VoidCallback? onRecover;

  const _DeletionHistoryTile({
    required this.item,
    this.onRecover,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.red.shade100),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.red.shade50,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    Icons.delete_outline_rounded,
                    color: Colors.red.shade600,
                    size: 16,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        item.expenseTitle,
                        style: const TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 14,
                          color: Color(0xFF1A1A2E),
                        ),
                      ),
                      Text(
                        'Rs. ${item.expenseAmount.toStringAsFixed(2)}',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.red.shade600,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
                if (onRecover != null)
                  TextButton.icon(
                    onPressed: onRecover,
                    icon: const Icon(Icons.restore_rounded, size: 16),
                    label: const Text('Recover'),
                    style: TextButton.styleFrom(
                      foregroundColor: Colors.blue.shade600,
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.grey.shade50,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildInfoRow('Deleted by', item.deletedBy),
                  _buildInfoRow('Deleted on', _formatDate(item.deletedAt)),
                  if (item.reason.isNotEmpty)
                    _buildInfoRow('Reason', item.reason),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 80,
            child: Text(
              '$label:',
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey.shade600,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                fontSize: 12,
                color: Color(0xFF1A1A2E),
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _formatDate(DateTime date) {
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
    ];
    
    final now = DateTime.now();
    final difference = now.difference(date);
    
    if (difference.inDays == 0) {
      return 'Today at ${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
    } else if (difference.inDays == 1) {
      return 'Yesterday';
    } else {
      return '${months[date.month - 1]} ${date.day}, ${date.year}';
    }
  }
}