import 'package:flutter/material.dart';
import '../../../models/balance_models.dart';
import '../../../services/balance_service.dart';
import '../../../services/payment_confirmation_service.dart';
import '../../../services/api_service.dart';
import '../../../services/auth_services.dart';
import '../../../models/payment_confirmation_models.dart';
import '../dialogs/record_payment_dialog.dart';

class WhoOwesWhoScreen extends StatefulWidget {
  final String roomspaceId;

  const WhoOwesWhoScreen({
    super.key,
    required this.roomspaceId,
  });

  @override
  State<WhoOwesWhoScreen> createState() => _WhoOwesWhoScreenState();
}

class _WhoOwesWhoScreenState extends State<WhoOwesWhoScreen> with WidgetsBindingObserver {
  final BalanceService _balanceService = BalanceService();
  late PaymentConfirmationService _paymentService;
  
  BalanceSummary? _balanceSummary;
  List<Map<String, dynamic>> _settlementSuggestions = [];
  bool _isLoading = true;
  String? _currentUserId;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _paymentService = PaymentConfirmationService(ApiService());
    _loadBalances();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      // Refresh balances when app comes back to foreground
      _loadBalances();
    }
  }

  Future<void> _loadBalances() async {
    setState(() => _isLoading = true);
    try {
      // Get current user ID first
      final user = AuthService().currentUser;
      _currentUserId = user?.uid;
      
      // Load both balance summary and settlement suggestions
      final balanceSummary = await _balanceService.getRoomspaceBalances(widget.roomspaceId);
      final suggestions = await _balanceService.getSettlementSuggestions(widget.roomspaceId);
      
      setState(() {
        _balanceSummary = balanceSummary;
        _settlementSuggestions = suggestions.map((s) => {
          'from_user_id': s.fromUserId,
          'from_user_name': s.fromUserName,
          'to_user_id': s.toUserId,
          'to_user_name': s.toUserName,
          'amount': s.amount,
        }).toList();
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading balances: $e')),
        );
      }
    }
  }

  Future<void> _recordPayment(String toUserId, String toUserName, double suggestedAmount) async {
    // Get all roommates for the dialog
    final roommates = _balanceSummary?.members
        .where((m) => m['user_id'] != _currentUserId)
        .map((m) => {
              'id': m['user_id'] as String,
              'name': m['name'] as String,
            })
        .toList() ?? [];

    final request = await showDialog<PaymentConfirmationRequest>(
      context: context,
      builder: (context) => RecordPaymentDialog(
        roommates: roommates,
        suggestedAmount: suggestedAmount,
      ),
    );

    if (request != null) {
      try {
        await _paymentService.createPaymentConfirmation(
          roomspaceId: widget.roomspaceId,
          request: request,
        );
        
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Payment recorded! Waiting for confirmation.'),
              backgroundColor: Colors.green,
            ),
          );
        }
        
        // Refresh balances
        _loadBalances();
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error: $e')),
          );
        }
      }
    }
  }

  Future<void> _sendReminder(String userId, String userName, double amount) async {
    try {
      // Send reminder notification via API
      final response = await ApiService().post(
        '/api/notifications/send-reminder',
        data: {
          'recipient_uid': userId,
          'roomspace_id': widget.roomspaceId,
          'amount': amount,
        },
      );

      if (mounted) {
        if (response['success'] == true) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Reminder sent to $userName'),
              backgroundColor: Colors.green,
            ),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Failed to send reminder: ${response['error']}'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error sending reminder: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Who Owes Who'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadBalances,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _balanceSummary == null
              ? const Center(child: Text('No balance data available'))
              : RefreshIndicator(
                  onRefresh: _loadBalances,
                  child: SingleChildScrollView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Summary Card
                        _buildSummaryCard(),
                        const SizedBox(height: 24),
                        
                        // People You Owe
                        if (_getPeopleYouOwe().isNotEmpty) ...[
                          _buildSectionHeader(
                            'You Owe',
                            Icons.arrow_upward,
                            Colors.red,
                          ),
                          const SizedBox(height: 12),
                          ..._getPeopleYouOwe().map(_buildOwedCard),
                          const SizedBox(height: 24),
                        ],
                        
                        // People Who Owe You
                        if (_getPeopleWhoOweYou().isNotEmpty) ...[
                          _buildSectionHeader(
                            'Owes You',
                            Icons.arrow_downward,
                            Colors.green,
                          ),
                          const SizedBox(height: 12),
                          ..._getPeopleWhoOweYou().map(_buildOwedCard),
                          const SizedBox(height: 24),
                        ],
                        
                        // Settled Up
                        if (_getSettledPeople().isNotEmpty) ...[
                          _buildSectionHeader(
                            'Settled Up',
                            Icons.check_circle,
                            Colors.grey,
                          ),
                          const SizedBox(height: 12),
                          ..._getSettledPeople().map(_buildSettledCard),
                        ],
                      ],
                    ),
                  ),
                ),
    );
  }

  Widget _buildSummaryCard() {
    final myBalance = _getCurrentUserBalance();
    
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              Theme.of(context).primaryColor,
              Theme.of(context).primaryColor.withOpacity(0.8),
            ],
          ),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          children: [
            const Text(
              'Your Balance',
              style: TextStyle(
                color: Colors.white70,
                fontSize: 14,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              myBalance >= 0
                  ? '+Rs. ${myBalance.abs().toStringAsFixed(2)}'
                  : '-Rs. ${myBalance.abs().toStringAsFixed(2)}',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 32,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              myBalance > 0.01
                  ? 'You are owed'
                  : myBalance < -0.01
                      ? 'You owe'
                      : 'All settled up!',
              style: const TextStyle(
                color: Colors.white70,
                fontSize: 14,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title, IconData icon, Color color) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, color: color, size: 20),
        ),
        const SizedBox(width: 12),
        Text(
          title,
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: Colors.grey[800],
          ),
        ),
      ],
    );
  }

  Widget _buildOwedCard(Map<String, dynamic> person) {
    final userId = person['user_id'] as String;
    final userName = person['name'] as String;
    final balance = (person['balance'] as num).toDouble();
    final isYouOwe = balance < 0;
    final amount = balance.abs();
    
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Row(
              children: [
                CircleAvatar(
                  backgroundColor: isYouOwe
                      ? Colors.red.withOpacity(0.1)
                      : Colors.green.withOpacity(0.1),
                  child: Text(
                    userName[0].toUpperCase(),
                    style: TextStyle(
                      color: isYouOwe ? Colors.red : Colors.green,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        userName,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        isYouOwe
                            ? 'You owe ${userName.split(' ')[0]}'
                            : '${userName.split(' ')[0]} owes you',
                        style: TextStyle(
                          color: Colors.grey[600],
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      'Rs. ${amount.toStringAsFixed(2)}',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: isYouOwe ? Colors.red : Colors.green,
                      ),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () {
                  if (isYouOwe) {
                    _recordPayment(userId, userName, amount);
                  } else {
                    _sendReminder(userId, userName, amount);
                  }
                },
                icon: Icon(isYouOwe ? Icons.payment : Icons.notifications, size: 18),
                label: Text(isYouOwe ? 'Mark as Paid' : 'Remind'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: isYouOwe ? Colors.blue : Colors.orange,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSettledCard(Map<String, dynamic> person) {
    final userName = person['name'] as String;
    
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            CircleAvatar(
              backgroundColor: Colors.grey.withOpacity(0.1),
              child: Text(
                userName[0].toUpperCase(),
                style: TextStyle(
                  color: Colors.grey[600],
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                userName,
                style: const TextStyle(
                  fontWeight: FontWeight.w500,
                  fontSize: 16,
                ),
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.green.withOpacity(0.1),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.check_circle, size: 16, color: Colors.green[700]),
                  const SizedBox(width: 4),
                  Text(
                    'Settled',
                    style: TextStyle(
                      color: Colors.green[700],
                      fontWeight: FontWeight.w600,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  double _getCurrentUserBalance() {
    if (_balanceSummary == null || _currentUserId == null) return 0.0;
    return _balanceSummary!.userBalances[_currentUserId] ?? 0.0;
  }

  List<Map<String, dynamic>> _getPeopleYouOwe() {
    if (_currentUserId == null) return [];
    
    // If we have settlement suggestions, use them
    if (_settlementSuggestions.isNotEmpty) {
      return _settlementSuggestions
          .where((s) => s['from_user_id'] == _currentUserId)
          .map((s) => {
                'user_id': s['to_user_id'] as String,
                'name': s['to_user_name'] as String,
                'balance': -((s['amount'] as num).toDouble()), // Negative because I owe
              })
          .toList();
    }
    
    // Fallback: if no settlement suggestions, show based on raw balances
    // This happens when balance calculation might be off
    if (_balanceSummary == null) return [];
    
    final myBalance = _getCurrentUserBalance();
    if (myBalance >= -0.01) return []; // I don't owe
    
    // Show all other members - this is a simplified view
    return _balanceSummary!.members
        .where((m) => m['user_id'] != _currentUserId)
        .map((m) => {
              'user_id': m['user_id'] as String,
              'name': m['name'] as String,
              'balance': myBalance, // Show my total debt
            })
        .toList();
  }

  List<Map<String, dynamic>> _getPeopleWhoOweYou() {
    if (_currentUserId == null) return [];
    
    // If we have settlement suggestions, use them
    if (_settlementSuggestions.isNotEmpty) {
      return _settlementSuggestions
          .where((s) => s['to_user_id'] == _currentUserId)
          .map((s) => {
                'user_id': s['from_user_id'] as String,
                'name': s['from_user_name'] as String,
                'balance': (s['amount'] as num).toDouble(), // Positive because they owe me
              })
          .toList();
    }
    
    // Fallback: if no settlement suggestions
    if (_balanceSummary == null) return [];
    
    final myBalance = _getCurrentUserBalance();
    if (myBalance <= 0.01) return []; // Nobody owes me
    
    // Show all other members - simplified view
    return _balanceSummary!.members
        .where((m) => m['user_id'] != _currentUserId)
        .map((m) => {
              'user_id': m['user_id'] as String,
              'name': m['name'] as String,
              'balance': myBalance, // Show my total credit
            })
        .toList();
  }

  List<Map<String, dynamic>> _getSettledPeople() {
    if (_balanceSummary == null || _currentUserId == null) return [];
    
    return _balanceSummary!.members
        .where((m) => 
            m['user_id'] != _currentUserId &&
            ((m['balance'] as num).toDouble()).abs() <= 0.01)
        .map((m) => {
              'user_id': m['user_id'],
              'name': m['name'],
              'balance': m['balance'],
            })
        .toList();
  }
}
