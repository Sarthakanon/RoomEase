import 'package:flutter/material.dart';
import '../../../services/api_service.dart';
import '../../../models/balance_models.dart';
import '../../../models/expense_models.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../expenses/presentation/settlements_screen.dart';
import '../../expenses/presentation/balance_breakdown_screen.dart';

class BalanceDetailsDialog extends StatefulWidget {
  final String roomspaceId;
  final bool isOwed; // true = you'll get back, false = you need to pay
  final ScrollController scrollController;
  final double actualBalance; // The actual balance from backend

  const BalanceDetailsDialog({
    super.key,
    required this.roomspaceId,
    required this.isOwed,
    required this.scrollController,
    required this.actualBalance,
  });

  static Future<void> show(
    BuildContext context, {
    required String roomspaceId,
    required bool isOwed,
    required double actualBalance,
  }) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.75,
        minChildSize: 0.5,
        maxChildSize: 0.9,
        builder: (context, scrollController) => BalanceDetailsDialog(
          roomspaceId: roomspaceId,
          isOwed: isOwed,
          scrollController: scrollController,
          actualBalance: actualBalance,
        ),
      ),
    );
  }

  @override
  State<BalanceDetailsDialog> createState() => _BalanceDetailsDialogState();
}

class _BalanceDetailsDialogState extends State<BalanceDetailsDialog> {
  final ApiService _apiService = ApiService();
  bool _isLoading = true;
  String? _error;
  List<ExpenseData> _expenses = [];
  List<Settlement> _settlements = [];
  String? _currentUserId;

  @override
  void initState() {
    super.initState();
    _currentUserId = FirebaseAuth.instance.currentUser?.uid;
    _loadExpenses(); // This will also load settlements first
  }

  Future<void> _loadExpenses() async {
    setState(() => _isLoading = true);
    try {
      // First load settlements to get the last settlement date
      await _loadSettlements();
      
      // Find the most recent settlement date
      DateTime? lastSettlementDate;
      if (_settlements.isNotEmpty) {
        for (final settlement in _settlements) {
          if (settlement.createdAt != null) {
            if (lastSettlementDate == null || settlement.createdAt!.isAfter(lastSettlementDate)) {
              lastSettlementDate = settlement.createdAt;
            }
          }
        }
      }
      
      final response = await _apiService.getRecentExpenses(
        roomspaceId: widget.roomspaceId,
        limit: 100, // Get more expenses to show full breakdown
      );
      
      if (response['success'] == true && response['data'] != null) {
        final expensesData = response['data'] as List;
        final allExpenses = expensesData
            .map((e) => ExpenseData.fromJson(e))
            .toList();
        
        print('=== BALANCE DETAILS DEBUG ===');
        print('Total expenses fetched: ${allExpenses.length}');
        print('Current user ID: $_currentUserId');
        print('Last settlement date: $lastSettlementDate');
        print('Dialog type: ${widget.isOwed ? "You'll get back" : "You need to pay"}');
        
        // Filter expenses based on what we're showing
        _expenses = allExpenses.where((expense) {
          if (_currentUserId == null) return false;
          
          // Only show expenses AFTER the last settlement
          if (lastSettlementDate != null && expense.createdAt != null) {
            if (expense.createdAt!.isBefore(lastSettlementDate)) {
              print('Skipping expense "${expense.title}" - created before last settlement');
              return false;
            }
          }
          
          final isPaidByMe = expense.paidBy == _currentUserId;
          final amIInSplit = expense.splits?.any((s) => s.userUid == _currentUserId) ?? false;
          
          // Only show expenses where user is involved
          if (!amIInSplit) return false;
          
          if (widget.isOwed) {
            // Show expenses I paid where my share < what I paid (others owe me)
            if (!isPaidByMe) return false;
            
            // Calculate my share
            final mySplit = expense.splits!.firstWhere(
              (s) => s.userUid == _currentUserId,
              orElse: () => ExpenseSplit(userUid: '', amount: 0, userName: ''),
            );
            
            // Only include if I paid more than my share (others owe me)
            final iOwed = expense.amount - mySplit.amount;
            if (iOwed > 0.01) {
              print('Expense "${expense.title}": I paid Rs. ${expense.amount}, my share Rs. ${mySplit.amount}, others owe Rs. ${iOwed.toStringAsFixed(2)}');
            }
            return iOwed > 0.01;
          } else {
            // Show expenses others paid where I owe my share
            if (isPaidByMe) return false;
            
            final mySplit = expense.splits!.firstWhere(
              (s) => s.userUid == _currentUserId,
              orElse: () => ExpenseSplit(userUid: '', amount: 0, userName: ''),
            );
            
            if (mySplit.amount > 0.01) {
              print('Expense "${expense.title}": ${expense.payerName} paid Rs. ${expense.amount}, I owe Rs. ${mySplit.amount.toStringAsFixed(2)}');
            }
            return mySplit.amount > 0.01;
          }
        }).toList();
        
        print('Filtered expenses count: ${_expenses.length}');
        
        // Calculate total for debug
        double debugTotal = 0.0;
        for (final expense in _expenses) {
          if (expense.splits != null && _currentUserId != null) {
            if (widget.isOwed) {
              final mySplit = expense.splits!.firstWhere(
                (s) => s.userUid == _currentUserId,
                orElse: () => ExpenseSplit(userUid: '', amount: 0, userName: ''),
              );
              debugTotal += (expense.amount - mySplit.amount);
            } else {
              final mySplit = expense.splits!.firstWhere(
                (s) => s.userUid == _currentUserId,
                orElse: () => ExpenseSplit(userUid: '', amount: 0, userName: ''),
              );
              debugTotal += mySplit.amount;
            }
          }
        }
        print('Total calculated: Rs. ${debugTotal.toStringAsFixed(2)}');
        print('=== END DEBUG ===');
      }
      
      setState(() => _isLoading = false);
    } catch (e) {
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  Future<void> _loadSettlements() async {
    try {
      final response = await _apiService.getSettlements(
        roomspaceId: widget.roomspaceId,
        limit: 50,
      );
      
      if (response['success'] == true && response['data'] != null) {
        final settlementsData = response['data'] as List;
        final allSettlements = settlementsData
            .map((s) => Settlement.fromJson(s))
            .toList();
        
        // Filter settlements relevant to current user
        if (mounted) {
          setState(() {
            _settlements = allSettlements.where((s) {
              return s.fromUserId == _currentUserId || s.toUserId == _currentUserId;
            }).toList();
          });
        }
      }
    } catch (e) {
      print('Error loading settlements: $e');
      // Don't show error for settlements, just log it
    }
  }

  @override
  Widget build(BuildContext context) {
    final primaryColor = Theme.of(context).colorScheme.primary;

    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildHandle(),
          _buildHeader(primaryColor),
          Expanded(
            child: SingleChildScrollView(
              controller: widget.scrollController,
              padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
              child: _buildContent(primaryColor),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHandle() {
    return Container(
      margin: const EdgeInsets.only(top: 12),
      width: 40,
      height: 4,
      decoration: BoxDecoration(
        color: const Color(0xFFEEEEF2),
        borderRadius: BorderRadius.circular(2),
      ),
    );
  }

  Widget _buildHeader(Color primaryColor) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 16, 16, 16),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: widget.isOwed
                      ? const Color(0xFF2E7D32).withValues(alpha: 0.1)
                      : const Color(0xFFC62828).withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  widget.isOwed ? Icons.arrow_downward : Icons.arrow_upward,
                  color: widget.isOwed ? const Color(0xFF2E7D32) : const Color(0xFFC62828),
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.isOwed ? 'You\'ll Get Back' : 'You Need to Pay',
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF1A1A2E),
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                    Text(
                      widget.isOwed
                          ? 'Your share from expenses you paid'
                          : 'Your share of expenses others paid',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey.shade500,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              IconButton(
                onPressed: () => Navigator.pop(context),
                icon: const Icon(Icons.close_rounded, size: 22),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
              ),
            ],
          ),
          const SizedBox(height: 12),
          // View Detailed Breakdown Button
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: () {
                Navigator.pop(context); // Close dialog
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => BalanceBreakdownScreen(roomspaceId: widget.roomspaceId),
                  ),
                );
              },
              icon: const Icon(Icons.analytics_outlined, size: 16),
              label: const Text(
                'View Detailed Breakdown',
                style: TextStyle(fontSize: 13),
              ),
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
                side: BorderSide(color: primaryColor.withValues(alpha: 0.3)),
                foregroundColor: primaryColor,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildContent(Color primaryColor) {
    if (_isLoading) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(32),
          child: CircularProgressIndicator(),
        ),
      );
    }

    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            children: [
              Icon(Icons.error_outline, size: 48, color: Colors.grey.shade300),
              const SizedBox(height: 16),
              Text('Failed to load expenses', style: TextStyle(color: Colors.grey.shade600)),
              const SizedBox(height: 8),
              TextButton(
                onPressed: _loadExpenses,
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
      );
    }

    if (_expenses.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            children: [
              Icon(
                widget.isOwed ? Icons.check_circle_outline : Icons.celebration_outlined,
                size: 48,
                color: Colors.grey.shade300,
              ),
              const SizedBox(height: 16),
              Text(
                widget.isOwed ? 'No pending payments' : 'You\'re all settled!',
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF1A1A2E),
                ),
              ),
              const SizedBox(height: 4),
              Text(
                widget.isOwed
                    ? 'All expenses are settled'
                    : 'You don\'t owe anyone money',
                style: TextStyle(fontSize: 13, color: Colors.grey.shade500),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      );
    }

    return Column(
      children: [
        ..._expenses.map((expense) => _buildExpenseItem(expense, primaryColor)),
        if (_settlements.isNotEmpty) ...[
          const SizedBox(height: 24),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Settlements',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: Colors.grey.shade700,
                ),
              ),
              TextButton(
                onPressed: () {
                  Navigator.pop(context); // Close dialog
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => SettlementsScreen(roomspaceId: widget.roomspaceId),
                    ),
                  );
                },
                style: TextButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                child: Text(
                  'View All',
                  style: TextStyle(
                    color: Colors.blue.shade700,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ..._settlements.map((settlement) => buildSettlementItem(settlement)),
        ],
        const SizedBox(height: 16),
        _buildTotalCard(primaryColor),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.amber.shade50,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.amber.shade200),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.info_outline, color: Colors.amber.shade900, size: 20),
                  const SizedBox(width: 8),
                  Text(
                    'About These Amounts',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: Colors.amber.shade900,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                widget.isOwed
                    ? 'These are expenses you paid. The amounts shown are what others owe you (total expense minus your share).'
                    : 'These are expenses others paid. The amounts shown are your share of each expense.',
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.amber.shade900,
                  height: 1.4,
                ),
              ),
              if (_settlements.isNotEmpty) ...[
                const SizedBox(height: 8),
                Text(
                  'Note: Settlements (payments made) will reduce these amounts.',
                  style: TextStyle(
                    fontSize: 11,
                    color: Colors.amber.shade800,
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildExpenseItem(ExpenseData expense, Color primaryColor) {
    final color = widget.isOwed ? const Color(0xFF2E7D32) : const Color(0xFFC62828);
    
    // Calculate amounts
    double displayAmount = 0.0;
    if (expense.splits != null && _currentUserId != null) {
      final mySplit = expense.splits!.firstWhere(
        (s) => s.userUid == _currentUserId,
        orElse: () => ExpenseSplit(userUid: '', amount: 0, userName: ''),
      );
      
      if (widget.isOwed) {
        // For "You'll get back": show (what I paid - my share) = what others owe me
        displayAmount = expense.amount - mySplit.amount;
      } else {
        // For "You need to pay": show my share
        displayAmount = mySplit.amount;
      }
    }

    // Get who paid
    final payerName = expense.payerName ?? 'Someone';
    final isPaidByMe = expense.paidBy == _currentUserId;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFEEEEF2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  Icons.receipt_long_outlined,
                  color: color,
                  size: 18,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      expense.title,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF1A1A2E),
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      isPaidByMe 
                          ? 'You paid this expense'
                          : 'Paid by $payerName',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey.shade500,
                      ),
                    ),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    'Rs. ${displayAmount.toStringAsFixed(0)}',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      color: color,
                    ),
                  ),
                  Text(
                    widget.isOwed ? 'they owe' : 'you owe',
                    style: TextStyle(
                      fontSize: 10,
                      color: Colors.grey.shade400,
                    ),
                  ),
                ],
              ),
            ],
          ),
          if (expense.description.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              expense.description,
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey.shade600,
              ),
            ),
          ],
          const SizedBox(height: 8),
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFFF7F7FB),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  expense.category,
                  style: TextStyle(
                    fontSize: 10,
                    color: Colors.grey.shade600,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                _formatDate(expense.createdAt),
                style: TextStyle(
                  fontSize: 10,
                  color: Colors.grey.shade400,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  String _formatDate(DateTime? date) {
    if (date == null) return '';
    final diff = DateTime.now().difference(date);
    if (diff.inDays == 0) return 'Today';
    if (diff.inDays == 1) return 'Yesterday';
    if (diff.inDays < 7) return '${diff.inDays}d ago';
    const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    return '${months[date.month - 1]} ${date.day}';
  }

  Widget _buildTotalCard(Color primaryColor) {
    double total = 0.0;
    for (final expense in _expenses) {
      if (expense.splits != null && _currentUserId != null) {
        final mySplit = expense.splits!.firstWhere(
          (s) => s.userUid == _currentUserId,
          orElse: () => ExpenseSplit(userUid: '', amount: 0, userName: ''),
        );
        if (widget.isOwed) {
          total += (expense.amount - mySplit.amount);
        } else {
          total += mySplit.amount;
        }
      }
    }
    
    final color = widget.isOwed ? const Color(0xFF2E7D32) : const Color(0xFFC62828);

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Icon(widget.isOwed ? Icons.trending_up : Icons.trending_down, color: color, size: 24),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('From These Expenses', style: TextStyle(fontSize: 12, color: Colors.grey.shade600, fontWeight: FontWeight.w600)),
                    const SizedBox(height: 2),
                    Text('${_expenses.length} expense${_expenses.length != 1 ? 's' : ''}', style: TextStyle(fontSize: 11, color: Colors.grey.shade500)),
                  ],
                ),
              ),
              Text('Rs. ${total.toStringAsFixed(0)}', style: TextStyle(fontSize: 24, fontWeight: FontWeight.w900, color: color)),
            ],
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: Colors.grey.shade200),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Actual Balance:', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Colors.grey.shade700)),
                Text('Rs. ${widget.actualBalance.toStringAsFixed(0)}', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: color)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget buildSettlementItem(Settlement settlement) {
    final isPaidByMe = settlement.fromUserId == _currentUserId;
    final otherPersonName = isPaidByMe ? settlement.toUserName : settlement.fromUserName;
    
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.blue.shade50,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.blue.shade100),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.blue.shade100,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(
              Icons.payments_outlined,
              color: Colors.blue.shade700,
              size: 18,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '💰 Settlement',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: Colors.blue.shade900,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  isPaidByMe 
                      ? 'You paid $otherPersonName'
                      : '$otherPersonName paid you',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.blue.shade700,
                  ),
                ),
                if (settlement.createdAt != null) ...[
                  const SizedBox(height: 2),
                  Text(
                    _formatDate(settlement.createdAt),
                    style: TextStyle(
                      fontSize: 10,
                      color: Colors.blue.shade600,
                    ),
                  ),
                ],
              ],
            ),
          ),
          Text(
            'Rs. ${settlement.amount.toStringAsFixed(0)}',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w800,
              color: Colors.blue.shade900,
            ),
          ),
        ],
      ),
    );
  }
}
