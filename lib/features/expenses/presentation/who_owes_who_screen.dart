import 'package:flutter/material.dart';
import 'dart:async';
import 'package:firebase_auth/firebase_auth.dart';
import '../../../models/balance_models.dart';
import '../../../services/balance_service.dart';
import '../../../services/smart_api_service.dart';
import '../../../services/real_time_data_service.dart';
import '../../../services/payment_confirmation_service.dart';
import '../../../services/api_service.dart';
import '../../../services/auth_services.dart';
import '../../../models/payment_confirmation_models.dart';
import '../dialogs/record_payment_dialog.dart';
import 'payment_confirmation_screen.dart';

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
  final SmartApiService _smartApi = SmartApiService();
  final RealTimeDataService _realTimeService = RealTimeDataService();
  late PaymentConfirmationService _paymentService;
  
  BalanceSummary? _balanceSummary;
  List<Map<String, dynamic>> _settlementSuggestions = [];
  double _youOwe = 0.0;
  double _youAreOwed = 0.0;
  bool _isLoading = true;
  String? _currentUserId;
  StreamSubscription<ExpenseUpdateEvent>? _expenseUpdateSubscription;
  StreamSubscription<BalanceUpdateEvent>? _balanceUpdateSubscription;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _paymentService = PaymentConfirmationService(ApiService());
    _setupRealTimeListeners();
    _loadBalances();
  }

  @override
  void dispose() {
    _expenseUpdateSubscription?.cancel();
    _balanceUpdateSubscription?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _loadBalances();
  }

  void _setupRealTimeListeners() {
    _expenseUpdateSubscription = _realTimeService.expenseUpdates.listen((event) {
      if (!mounted) return;
      if (event.type == ExpenseUpdateType.clearCache ||
          event.roomspaceId == widget.roomspaceId ||
          event.type == ExpenseUpdateType.personalCreated) {
        _loadBalances();
      }
    });

    _balanceUpdateSubscription = _realTimeService.balanceUpdates.listen((event) {
      if (!mounted) return;
      if (event.type == BalanceUpdateType.clearCache ||
          event.roomspaceId == widget.roomspaceId) {
        _loadBalances();
      }
    });
  }

  Future<void> _loadBalances() async {
    if (!mounted) return;
    setState(() => _isLoading = true);
    try {
      final user = FirebaseAuth.instance.currentUser ?? AuthService().currentUser;
      _currentUserId = user?.uid;
      _currentUserId ??= await AuthService().getStoredUserId();
      
      final rawBalances = await _smartApi.getRoomspaceBalances(widget.roomspaceId);
      final rawData = rawBalances['data'] as Map<String, dynamic>? ?? {};
      _youOwe = (rawData['you_owe'] as num?)?.toDouble() ?? 0.0;
      _youAreOwed = (rawData['you_are_owed'] as num?)?.toDouble() ?? 0.0;

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
    final peopleYouOwe = _getPeopleYouOwe();
    final remainingByUserId = <String, double>{
      for (final p in peopleYouOwe)
        p['user_id'] as String: (p['balance'] as num).toDouble(),
    };

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
        initialRoommateId: toUserId,
        remainingAmountsByUserId: remainingByUserId,
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
          await Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => PaymentConfirmationScreen(roomspaceId: widget.roomspaceId),
            ),
          );
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

            if (_settlementSuggestions.isNotEmpty) ...[
              _buildSectionHeader('Suggested Settlements', const Color(0xFF1A1A2E)),
              ..._settlementSuggestions.map(_buildSettlementSuggestionCard),
              const SizedBox(height: 24),
            ],
            
            if (_getPeopleWhoOweYou().isNotEmpty) ...[
              _buildSectionHeader('Owes You', const Color(0xFF2E7D32)),
              ..._getPeopleWhoOweYou().map((p) => _buildPersonCard(p, isYouOwe: false)),
              const SizedBox(height: 24),
            ],

            if (_getPeopleYouOwe().isNotEmpty) ...[
              _buildSectionHeader('You Owe', const Color(0xFFC62828)),
              ..._getPeopleYouOwe().map((p) => _buildPersonCard(p, isYouOwe: true)),
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
    final youOweTotal = (_youOwe - _youAreOwed).clamp(0.0, double.infinity);
    final owedToYouTotal = (_youAreOwed - _youOwe).clamp(0.0, double.infinity);

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
          Row(
            children: [
              Expanded(
                child: _buildTopSummaryTile(
                  label: 'You Owe',
                  amount: youOweTotal,
                  color: const Color(0xFFC62828),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildTopSummaryTile(
                  label: 'You Are Owed',
                  amount: owedToYouTotal,
                  color: const Color(0xFF2E7D32),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildTopSummaryTile({
    required String label,
    required double amount,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFEEEEF2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              color: Colors.grey.shade600,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Rs. ${amount.toStringAsFixed(0)}',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w900,
              color: color,
            ),
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
    final cardTapHandler = isYouOwe
        ? () => _showQrAndMarkPaidDialog(
              toUserId: person['user_id'] as String,
              toUserName: name,
              amount: amount,
              qrImageUrl: person['qr_image_url'] as String?,
            )
        : () => _sendReminder(person['user_id'], name, amount);

    return InkWell(
      onTap: cardTapHandler,
      borderRadius: BorderRadius.circular(14),
      child: Container(
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
                SizedBox(
                  height: 30,
                  child: TextButton(
                    onPressed: cardTapHandler,
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 0),
                      minimumSize: const Size(0, 30),
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      backgroundColor: isYouOwe ? Colors.blue.shade50 : Colors.orange.shade50,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(6),
                      ),
                    ),
                    child: Text(
                      isYouOwe ? 'Mark Paid' : 'Remind',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: isYouOwe ? Colors.blue.shade700 : Colors.orange.shade700,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _showQrAndMarkPaidDialog({
    required String toUserId,
    required String toUserName,
    required double amount,
    String? qrImageUrl,
  }) async {
    await showDialog<void>(
      context: context,
      builder: (dialogContext) {
        final hasQr = qrImageUrl != null && qrImageUrl.isNotEmpty;
        return AlertDialog(
          title: Text('Pay $toUserName'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Amount left: Rs. ${amount.toStringAsFixed(0)}',
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 12),
              if (hasQr)
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: Image.network(
                    qrImageUrl,
                    height: 220,
                    width: 220,
                    fit: BoxFit.cover,
                  ),
                )
              else
                const Text('This roommate has not uploaded a QR yet.'),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Close'),
            ),
            ElevatedButton(
              onPressed: () async {
                Navigator.pop(dialogContext);
                await _recordPayment(toUserId, toUserName, amount);
              },
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                minimumSize: const Size(132, 44),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              child: const Text('Mark as Paid'),
            ),
          ],
        );
      },
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

  Widget _buildSettlementSuggestionCard(Map<String, dynamic> suggestion) {
    final fromName = suggestion['from_user_name'] as String? ?? 'Unknown';
    final toName = suggestion['to_user_name'] as String? ?? 'Unknown';
    final amount = (suggestion['amount'] as num?)?.toDouble() ?? 0.0;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFEEEEF2)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              '$fromName pays $toName',
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: Color(0xFF1A1A2E),
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          Text(
            'Rs. ${amount.toStringAsFixed(0)}',
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w800,
              color: Color(0xFF1A1A2E),
            ),
          ),
        ],
      ),
    );
  }

  List<Map<String, dynamic>> _getPeopleYouOwe() {
    if (_currentUserId == null) return [];
    if (_settlementSuggestions.isNotEmpty) {
      final grouped = <String, Map<String, dynamic>>{};
      for (final s in _settlementSuggestions.where((s) => s['from_user_id'] == _currentUserId)) {
        final key = s['to_user_id'] as String;
        final amount = (s['amount'] as num?)?.toDouble() ?? 0.0;
        if (!grouped.containsKey(key)) {
          grouped[key] = {
            'user_id': key,
            'name': s['to_user_name'] as String? ?? 'Unknown',
            'balance': 0.0,
            'qr_image_url': _getUserQrImageUrl(key),
          };
        }
        grouped[key]!['balance'] = ((grouped[key]!['balance'] as double) + amount);
      }
      return grouped.values.where((v) => (v['balance'] as double) > 0.01).toList();
    }
    final fallback = _getPeopleYouOweFromSummary();
    if (fallback.isNotEmpty) return fallback;
    return _getSingleRoommateFallback(isYouOwe: true);
  }

  List<Map<String, dynamic>> _getPeopleWhoOweYou() {
    if (_currentUserId == null) return [];
    if (_settlementSuggestions.isNotEmpty) {
      final grouped = <String, Map<String, dynamic>>{};
      for (final s in _settlementSuggestions.where((s) => s['to_user_id'] == _currentUserId)) {
        final key = s['from_user_id'] as String;
        final amount = (s['amount'] as num?)?.toDouble() ?? 0.0;
        if (!grouped.containsKey(key)) {
          grouped[key] = {
            'user_id': key,
            'name': s['from_user_name'] as String? ?? 'Unknown',
            'balance': 0.0,
            'qr_image_url': _getUserQrImageUrl(key),
          };
        }
        grouped[key]!['balance'] = ((grouped[key]!['balance'] as double) + amount);
      }
      return grouped.values.where((v) => (v['balance'] as double) > 0.01).toList();
    }
    final fallback = _getPeopleWhoOweYouFromSummary();
    if (fallback.isNotEmpty) return fallback;
    return _getSingleRoommateFallback(isYouOwe: false);
  }

  List<Map<String, dynamic>> _getSingleRoommateFallback({required bool isYouOwe}) {
    if (_balanceSummary == null || _currentUserId == null) return [];
    final others = _balanceSummary!.members
        .where((m) => m['user_id'] != _currentUserId)
        .toList();
    if (others.length != 1) return [];

    final other = others.first;
    final amount = isYouOwe
        ? (_youOwe - _youAreOwed).clamp(0.0, double.infinity)
        : (_youAreOwed - _youOwe).clamp(0.0, double.infinity);
    if (amount <= 0.01) return [];
    return [
      {
        'user_id': other['user_id'] as String,
        'name': other['name'] as String? ?? 'Unknown',
        'balance': amount,
        'qr_image_url': other['qr_image_url'] as String?,
      }
    ];
  }

  List<Map<String, dynamic>> _getPeopleYouOweFromSummary() {
    if (_balanceSummary == null || _currentUserId == null) return [];

    final myBalance = _balanceSummary!.userBalances[_currentUserId] ?? 0.0;
    if (myBalance >= -0.01) return [];

    double remaining = myBalance.abs();
    final creditors = _balanceSummary!.members
        .where((m) => m['user_id'] != _currentUserId)
        .map((m) => {
              'user_id': m['user_id'] as String,
              'name': m['name'] as String? ?? 'Unknown',
              'balance': ((m['balance'] as num?)?.toDouble() ?? 0.0),
            })
        .where((m) => (m['balance'] as double) > 0.01)
        .toList()
      ..sort((a, b) => ((b['balance'] as double).compareTo(a['balance'] as double)));

    final result = <Map<String, dynamic>>[];
    for (final c in creditors) {
      if (remaining <= 0.01) break;
      final amount = (c['balance'] as double) < remaining ? (c['balance'] as double) : remaining;
      if (amount > 0.01) {
        result.add({
          'user_id': c['user_id'],
          'name': c['name'],
          'balance': amount,
          'qr_image_url': _getUserQrImageUrl(c['user_id'] as String),
        });
        remaining -= amount;
      }
    }
    return result;
  }

  List<Map<String, dynamic>> _getPeopleWhoOweYouFromSummary() {
    if (_balanceSummary == null || _currentUserId == null) return [];

    final myBalance = _balanceSummary!.userBalances[_currentUserId] ?? 0.0;
    if (myBalance <= 0.01) return [];

    double remaining = myBalance;
    final debtors = _balanceSummary!.members
        .where((m) => m['user_id'] != _currentUserId)
        .map((m) => {
              'user_id': m['user_id'] as String,
              'name': m['name'] as String? ?? 'Unknown',
              'balance': ((m['balance'] as num?)?.toDouble() ?? 0.0),
            })
        .where((m) => (m['balance'] as double) < -0.01)
        .toList()
      ..sort((a, b) => (((a['balance'] as double).abs()).compareTo((b['balance'] as double).abs())));

    final result = <Map<String, dynamic>>[];
    for (final d in debtors) {
      if (remaining <= 0.01) break;
      final debtorCapacity = (d['balance'] as double).abs();
      final amount = debtorCapacity < remaining ? debtorCapacity : remaining;
      if (amount > 0.01) {
        result.add({
          'user_id': d['user_id'],
          'name': d['name'],
          'balance': amount,
          'qr_image_url': _getUserQrImageUrl(d['user_id'] as String),
        });
        remaining -= amount;
      }
    }
    return result;
  }

  List<Map<String, dynamic>> _getSettledPeople() {
    if (_balanceSummary == null || _currentUserId == null) return [];
    return _balanceSummary!.members
        .where((m) => m['user_id'] != _currentUserId && ((m['balance'] as num).toDouble()).abs() <= 0.01)
        .map((m) => {'user_id': m['user_id'], 'name': m['name'], 'balance': m['balance']})
        .toList();
  }

  String? _getUserQrImageUrl(String userId) {
    if (_balanceSummary == null) return null;
    for (final member in _balanceSummary!.members) {
      if ((member['user_id'] as String?) == userId) {
        return member['qr_image_url'] as String?;
      }
    }
    return null;
  }
}
