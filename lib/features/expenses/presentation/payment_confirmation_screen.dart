import 'package:flutter/material.dart';
import '../../../models/payment_confirmation_models.dart';
import '../../../services/payment_confirmation_service.dart';
import '../../../services/api_service.dart';
import '../../../services/auth_services.dart';
import '../../../services/balance_service.dart';
import '../widgets/payment_confirmation_card.dart';
import '../dialogs/record_payment_dialog.dart';

/// Professional, minimalist screen for managing payment confirmations.
class PaymentConfirmationScreen extends StatefulWidget {
  final String roomspaceId;
  const PaymentConfirmationScreen({super.key, required this.roomspaceId});

  @override
  State<PaymentConfirmationScreen> createState() => _PaymentConfirmationScreenState();
}

class _PaymentConfirmationScreenState extends State<PaymentConfirmationScreen> with SingleTickerProviderStateMixin {
  late PaymentConfirmationService _service;
  late BalanceService _balanceService;
  late TabController _tabController;
  
  List<PaymentConfirmation> _pending = [];
  List<PaymentConfirmation> _confirmed = [];
  List<PaymentConfirmation> _rejected = [];
  bool _isLoading = true;
  String? _userId;

  @override
  void initState() {
    super.initState();
    _service = PaymentConfirmationService(ApiService());
    _balanceService = BalanceService();
    _tabController = TabController(length: 3, vsync: this);
    _load();
  }

  Future<void> _load() async {
    setState(() => _isLoading = true);
    try {
      _userId = (await AuthService().currentUser)?.uid;
      final all = await _service.getPaymentHistory(roomspaceId: widget.roomspaceId, limit: 100);
      setState(() {
        _pending = all.where((p) => p.isPending).toList();
        _confirmed = all.where((p) => p.isConfirmed).toList();
        _rejected = all.where((p) => p.isRejected).toList();
        _isLoading = false;
      });
    } catch (_) {
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
        title: const Text('Confirmations', style: TextStyle(color: Color(0xFF1A1A2E), fontSize: 18, fontWeight: FontWeight.w700)),
        centerTitle: false,
        actions: [
          IconButton(onPressed: _load, icon: Icon(Icons.refresh_rounded, color: Colors.grey.shade600, size: 20)),
          const SizedBox(width: 8),
        ],
        bottom: TabBar(
          controller: _tabController,
          labelColor: primary, unselectedLabelColor: Colors.grey.shade400,
          indicatorColor: primary, indicatorWeight: 2,
          indicatorSize: TabBarIndicatorSize.label,
          labelStyle: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13, letterSpacing: 0.2),
          tabs: [Tab(text: 'Pending (${_pending.length})'), const Tab(text: 'Confirmed'), const Tab(text: 'Rejected')],
        ),
      ),
      body: _isLoading ? const Center(child: CircularProgressIndicator()) : TabBarView(
        controller: _tabController,
        children: [
          _buildList(_pending, width, true),
          _buildList(_confirmed, width, false),
          _buildList(_rejected, width, false),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        key: const ValueKey('record_payment_fab'),
        onPressed: _showRecordDialog,
        backgroundColor: primary, 
        foregroundColor: Colors.white, 
        elevation: 2,
        tooltip: 'Record Payment',
        icon: const Icon(Icons.add_rounded), 
        label: const Text('Record Payment', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
      ),
    );
  }

  Widget _buildList(List<PaymentConfirmation> list, double width, bool canAct) {
    if (list.isEmpty) return _buildEmpty();
    return RefreshIndicator(
      onRefresh: _load, color: Theme.of(context).primaryColor,
      child: ListView.builder(
        padding: EdgeInsets.symmetric(horizontal: width > 600 ? width * 0.15 : 20, vertical: 24),
        itemCount: list.length,
        itemBuilder: (context, i) {
          final p = list[i];
          return PaymentConfirmationCard(
            payment: p, currentUserId: _userId ?? '',
            onConfirm: canAct && p.toUserId == _userId ? () => _confirm(p.id) : null,
            onReject: canAct && p.toUserId == _userId ? () => _reject(p.id) : null,
          );
        },
      ),
    );
  }

  Widget _buildEmpty() {
    return Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [Icon(Icons.inbox_outlined, size: 48, color: Colors.grey.shade100), const SizedBox(height: 16), Text('Nothing here yet', style: TextStyle(color: Colors.grey.shade300, fontSize: 14, fontWeight: FontWeight.w500))]));
  }

  Future<void> _confirm(int id) async {
    final ok = await _showConfirm('Verify Receipt', 'Confirm you received this payment?');
    if (ok) { await _service.confirmPayment(roomspaceId: widget.roomspaceId, paymentId: id); _load(); }
  }

  Future<void> _reject(int id) async {
    final reason = await showDialog<String>(context: context, builder: (context) => _RejectDialog());
    if (reason != null) { await _service.rejectPayment(roomspaceId: widget.roomspaceId, paymentId: id, reason: reason); _load(); }
  }

  Future<void> _showRecordDialog() async {
    final summary = await _balanceService.getRoomspaceBalances(widget.roomspaceId);
    if (summary == null || !mounted) return;
    final roommates = summary.members.where((m) => m['user_id'] != _userId).map((m) => {'id': m['user_id'] as String, 'name': m['name'] as String}).toList();
    final req = await showDialog<PaymentConfirmationRequest>(context: context, builder: (context) => RecordPaymentDialog(roommates: roommates));
    if (req != null) { await _service.createPaymentConfirmation(roomspaceId: widget.roomspaceId, request: req); _load(); }
  }

  Future<bool> _showConfirm(String title, String body) async {
    return await showDialog<bool>(context: context, builder: (context) => AlertDialog(shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)), title: Text(title, style: const TextStyle(fontWeight: FontWeight.w800)), content: Text(body, style: const TextStyle(fontSize: 14)), actions: [TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel', style: TextStyle(color: Colors.grey))), TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('Confirm', style: TextStyle(fontWeight: FontWeight.bold)))])) ?? false;
  }
}

class _RejectDialog extends StatefulWidget {
  @override
  State<_RejectDialog> createState() => _RejectDialogState();
}

class _RejectDialogState extends State<_RejectDialog> {
  final _c = TextEditingController();
  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: const Text('Reject Payment', style: TextStyle(fontWeight: FontWeight.w800)),
      content: TextField(controller: _c, autofocus: true, style: const TextStyle(fontSize: 14), decoration: InputDecoration(hintText: 'Reason (e.g. Wrong amount)', filled: true, fillColor: const Color(0xFFF7F7FB), border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none))),
      actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel', style: TextStyle(color: Colors.grey))), TextButton(onPressed: () => Navigator.pop(context, _c.text), child: const Text('Reject', style: TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold)))],
    );
  }
}
