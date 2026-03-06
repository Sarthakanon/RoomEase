import 'package:flutter/material.dart';
import '../../../models/balance_models.dart';
import '../../../services/balance_service.dart';
import '../../../services/payment_confirmation_service.dart';
import '../../../services/api_service.dart';
import '../../../services/auth_services.dart';
import '../../../models/payment_confirmation_models.dart';
import '../dialogs/record_payment_dialog.dart';

/// Screen showing who owes whom within a roomspace and facilitating settlements.
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
    if (state == AppLifecycleState.resumed) _loadBalances();
  }

  Future<void> _loadBalances() async {
    setState(() => _isLoading = true);
    try {
      final user = AuthService().currentUser;
      _currentUserId = user?.uid;
      
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
    }
  }

  Future<void> _recordPayment(String toUserId, String toUserName, double suggestedAmount) async {
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
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Payment recorded!')));
        }
        _loadBalances();
      } catch (_) {}
    }
  }

  Future<void> _sendReminder(String userId, String userName, double amount) async {
    try {
      final response = await ApiService().post(
        '/api/notifications/send-reminder',
        data: {
          'recipient_uid': userId,
          'roomspace_id': widget.roomspaceId,
          'amount': amount,
        },
      );
      if (mounted && response['success'] == true) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Reminder sent to $userName')));
      }
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    final isTablet = width > 600;
    final horizontalPadding = isTablet ? width * 0.15 : 20.0;
    
    final primaryColor = Theme.of(context).colorScheme.primary;

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        title: const Text('Who Owes Who', 
          style: TextStyle(color: Color(0xFF1A1A2E), fontWeight: FontWeight.w700, fontSize: 17)),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Color(0xFF1A1A2E), size: 18),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          IconButton(
            icon: Icon(Icons.refresh_rounded, color: Colors.grey.shade600, size: 20),
            onPressed: _loadBalances,
          ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(color: const Color(0xFFF0F0F0), height: 1),
        ),
      ),
      body: _isLoading
          ? Center(child: CircularProgressIndicator(color: primaryColor))
          : _balanceSummary == null
              ? _buildEmptyState()
              : _buildContent(primaryColor, horizontalPadding),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.people_outline_rounded, size: 48, color: Colors.grey.shade200),
          const SizedBox(height: 16),
          Text('No balance data available', style: TextStyle(color: Colors.grey.shade400, fontSize: 14)),
        ],
      ),
    );
  }

  Widget _buildContent(Color primaryColor, double horizontalPadding) {
    return RefreshIndicator(
      onRefresh: _loadBalances,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: EdgeInsets.symmetric(horizontal: horizontalPadding, vertical: 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildBalanceSummaryCard(primaryColor),
            const SizedBox(height: 32),
            
            if (_getPeopleYouOwe().isNotEmpty) ...[
              _buildSectionHeader('You Owe', const Color(0xFFC62828)),
              ..._getPeopleYouOwe().map((p) => _buildPersonCard(p, isYouOwe: true)),
              const SizedBox(height: 24),
            ],
            
            if (_getPeopleWhoOweYou().isNotEmpty) ...[
              _buildSectionHeader('Owes You', const Color(0xFF2E7D32)),
              ..._getPeopleWhoOweYou().map((p) => _buildPersonCard(p, isYouOwe: false)),
              const SizedBox(height: 24),
            ],
            
            if (_getSettledPeople().isNotEmpty) ...[
              _buildSectionHeader('Settled Up', Colors.grey.shade600),
              ..._getSettledPeople().map(_buildSettledCard),
            ],
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  Widget _buildBalanceSummaryCard(Color primaryColor) {
    final balance = _getCurrentUserBalance();
    final isPositive = balance >= 0;
    final valueColor = isPositive ? const Color(0xFF2E7D32) : const Color(0xFFC62828);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFFF7F7FB),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFEEEEF2)),
      ),
      child: Column(
        children: [
          Text(
            'Your Net Balance',
            style: TextStyle(fontSize: 12, color: Colors.grey.shade500, fontWeight: FontWeight.w500),
          ),
          const SizedBox(height: 8),
          Text(
            'Rs. ${balance.abs().toStringAsFixed(0)}',
            style: TextStyle(fontSize: 32, fontWeight: FontWeight.w900, color: valueColor),
          ),
          const SizedBox(height: 4),
          Text(
            balance > 0.01 ? 'You are owed in total' : balance < -0.01 ? 'You owe in total' : 'All clear!',
            style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title, Color color) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 12),
      child: Text(
        title.toUpperCase(),
        style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: color, letterSpacing: 1),
      ),
    );
  }

  Widget _buildPersonCard(Map<String, dynamic> person, {required bool isYouOwe}) {
    final name = person['name'] as String;
    final amount = (person['balance'] as num).toDouble().abs();
    final color = isYouOwe ? const Color(0xFFC62828) : const Color(0xFF2E7D32);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFEEEEF2)),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 20,
            backgroundColor: color.withValues(alpha: 0.1),
            child: Text(name[0].toUpperCase(), style: TextStyle(color: color, fontWeight: FontWeight.w700, fontSize: 13)),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(name, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14, color: Color(0xFF1A1A2E))),
                Text(isYouOwe ? 'You owe them' : 'They owe you', style: TextStyle(fontSize: 11, color: Colors.grey.shade500)),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text('Rs. ${amount.toStringAsFixed(0)}', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15, color: color)),
              const SizedBox(height: 8),
              InkWell(
                onTap: () => isYouOwe 
                  ? _recordPayment(person['user_id'], name, amount) 
                  : _sendReminder(person['user_id'], name, amount),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: isYouOwe ? Colors.blue.shade50 : Colors.orange.shade50,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    isYouOwe ? 'Mark Paid' : 'Remind',
                    style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: isYouOwe ? Colors.blue.shade700 : Colors.orange.shade700),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSettledCard(Map<String, dynamic> person) {
    final name = person['name'] as String;
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFF0F0F3)),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 16,
            backgroundColor: Colors.grey.shade100,
            child: Text(name[0].toUpperCase(), style: TextStyle(color: Colors.grey.shade400, fontSize: 11, fontWeight: FontWeight.w600)),
          ),
          const SizedBox(width: 12),
          Expanded(child: Text(name, style: TextStyle(fontSize: 13, color: Colors.grey.shade600, fontWeight: FontWeight.w500))),
          Icon(Icons.check_circle_rounded, size: 16, color: Colors.green.shade200),
        ],
      ),
    );
  }

  double _getCurrentUserBalance() {
    if (_balanceSummary == null || _currentUserId == null) return 0.0;
    return _balanceSummary!.userBalances[_currentUserId] ?? 0.0;
  }

  List<Map<String, dynamic>> _getPeopleYouOwe() {
    if (_currentUserId == null) return [];
    if (_settlementSuggestions.isNotEmpty) {
      return _settlementSuggestions
          .where((s) => s['from_user_id'] == _currentUserId)
          .map((s) => {'user_id': s['to_user_id'] as String, 'name': s['to_user_name'] as String, 'balance': -((s['amount'] as num).toDouble())})
          .toList();
    }
    return [];
  }

  List<Map<String, dynamic>> _getPeopleWhoOweYou() {
    if (_currentUserId == null) return [];
    if (_settlementSuggestions.isNotEmpty) {
      return _settlementSuggestions
          .where((s) => s['to_user_id'] == _currentUserId)
          .map((s) => {'user_id': s['from_user_id'] as String, 'name': s['from_user_name'] as String, 'balance': (s['amount'] as num).toDouble()})
          .toList();
    }
    return [];
  }

  List<Map<String, dynamic>> _getSettledPeople() {
    if (_balanceSummary == null || _currentUserId == null) return [];
    return _balanceSummary!.members
        .where((m) => m['user_id'] != _currentUserId && ((m['balance'] as num).toDouble()).abs() <= 0.01)
        .map((m) => {'user_id': m['user_id'], 'name': m['name'], 'balance': m['balance']})
        .toList();
  }
}
