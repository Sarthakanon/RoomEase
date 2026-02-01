import 'package:flutter/material.dart';
import '../../../models/payment_confirmation_models.dart';
import '../../../services/payment_confirmation_service.dart';
import '../../../services/api_service.dart';
import '../../../services/auth_services.dart';
import '../../../services/balance_service.dart';
import '../widgets/payment_confirmation_card.dart';
import '../dialogs/record_payment_dialog.dart';

class PaymentConfirmationScreen extends StatefulWidget {
  final String roomspaceId;

  const PaymentConfirmationScreen({
    super.key,
    required this.roomspaceId,
  });

  @override
  State<PaymentConfirmationScreen> createState() => _PaymentConfirmationScreenState();
}

class _PaymentConfirmationScreenState extends State<PaymentConfirmationScreen> with SingleTickerProviderStateMixin {
  late PaymentConfirmationService _service;
  late BalanceService _balanceService;
  late TabController _tabController;
  
  List<PaymentConfirmation> _pendingPayments = [];
  List<PaymentConfirmation> _confirmedPayments = [];
  List<PaymentConfirmation> _rejectedPayments = [];
  
  bool _isLoading = true;
  String? _currentUserId;

  @override
  void initState() {
    super.initState();
    _service = PaymentConfirmationService(ApiService());
    _balanceService = BalanceService();
    _tabController = TabController(length: 3, vsync: this);
    _loadCurrentUser();
    _loadPayments();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadCurrentUser() async {
    try {
      final user = AuthService().currentUser;
      setState(() {
        _currentUserId = user?.uid;
      });
    } catch (e) {
      debugPrint('Error loading current user: $e');
    }
  }

  Future<void> _loadPayments() async {
    setState(() => _isLoading = true);
    try {
      // Load all payment history
      final allPayments = await _service.getPaymentHistory(
        roomspaceId: widget.roomspaceId,
        limit: 100,
      );
      
      setState(() {
        _pendingPayments = allPayments.where((p) => p.isPending).toList();
        _confirmedPayments = allPayments.where((p) => p.isConfirmed).toList();
        _rejectedPayments = allPayments.where((p) => p.isRejected).toList();
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading payments: $e')),
        );
      }
    }
  }

  Future<void> _confirmPayment(int paymentId) async {
    // Show confirmation dialog
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Confirm Payment'),
        content: const Text('Are you sure you received this payment? This will update balances.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green,
              foregroundColor: Colors.white,
            ),
            child: const Text('Confirm'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        await _service.confirmPayment(
          roomspaceId: widget.roomspaceId,
          paymentId: paymentId,
        );
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Payment confirmed! Balances updated.'),
              backgroundColor: Colors.green,
            ),
          );
        }
        _loadPayments();
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error: $e')),
          );
        }
      }
    }
  }

  Future<void> _rejectPayment(int paymentId) async {
    // Show dialog to get rejection reason
    final reason = await showDialog<String>(
      context: context,
      builder: (context) => _RejectPaymentDialog(),
    );

    if (reason != null) {
      try {
        await _service.rejectPayment(
          roomspaceId: widget.roomspaceId,
          paymentId: paymentId,
          reason: reason.isEmpty ? null : reason,
        );
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Payment rejected'),
              backgroundColor: Colors.orange,
            ),
          );
        }
        _loadPayments();
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error: $e')),
          );
        }
      }
    }
  }

  Future<void> _showRecordPaymentDialog() async {
    try {
      // Get balance summary to show roommates
      final balanceSummary = await _balanceService.getRoomspaceBalances(widget.roomspaceId);
      
      if (balanceSummary == null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Unable to load roommates')),
          );
        }
        return;
      }
      
      // Get all roommates except current user
      final roommates = balanceSummary.members
          .where((m) => m['user_id'] != _currentUserId)
          .map((m) => {
                'id': m['user_id'] as String,
                'name': m['name'] as String,
              })
          .toList();

      if (roommates.isEmpty) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('No roommates found')),
          );
        }
        return;
      }

      final request = await showDialog<PaymentConfirmationRequest>(
        context: context,
        builder: (context) => RecordPaymentDialog(
          roommates: roommates,
        ),
      );

      if (request != null) {
        try {
          await _service.createPaymentConfirmation(
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
          
          _loadPayments();
        } catch (e) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Error: $e')),
            );
          }
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading roommates: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Payment Confirmations'),
        bottom: TabBar(
          controller: _tabController,
          tabs: [
            Tab(
              text: 'Pending',
              icon: Badge(
                label: Text(_pendingPayments.length.toString()),
                child: const Icon(Icons.schedule),
              ),
            ),
            Tab(
              text: 'Confirmed',
              icon: Badge(
                label: Text(_confirmedPayments.length.toString()),
                child: const Icon(Icons.check_circle),
              ),
            ),
            Tab(
              text: 'Rejected',
              icon: Badge(
                label: Text(_rejectedPayments.length.toString()),
                child: const Icon(Icons.cancel),
              ),
            ),
          ],
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : TabBarView(
              controller: _tabController,
              children: [
                _buildPaymentList(_pendingPayments, showActions: true),
                _buildPaymentList(_confirmedPayments),
                _buildPaymentList(_rejectedPayments),
              ],
            ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showRecordPaymentDialog,
        icon: const Icon(Icons.payment),
        label: const Text('Record Payment'),
      ),
    );
  }

  Widget _buildPaymentList(List<PaymentConfirmation> payments, {bool showActions = false}) {
    if (payments.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.inbox_outlined, size: 64, color: Colors.grey[400]),
            const SizedBox(height: 16),
            Text(
              'No payments here',
              style: TextStyle(
                fontSize: 16,
                color: Colors.grey[600],
              ),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadPayments,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: payments.length,
        itemBuilder: (context, index) {
          final payment = payments[index];
          return PaymentConfirmationCard(
            payment: payment,
            currentUserId: _currentUserId ?? '',
            onConfirm: showActions && payment.toUserId == _currentUserId
                ? () => _confirmPayment(payment.id)
                : null,
            onReject: showActions && payment.toUserId == _currentUserId
                ? () => _rejectPayment(payment.id)
                : null,
          );
        },
      ),
    );
  }
}

class _RejectPaymentDialog extends StatefulWidget {
  @override
  State<_RejectPaymentDialog> createState() => _RejectPaymentDialogState();
}

class _RejectPaymentDialogState extends State<_RejectPaymentDialog> {
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Reject Payment'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text('Why are you rejecting this payment?'),
          const SizedBox(height: 16),
          TextField(
            controller: _controller,
            decoration: const InputDecoration(
              labelText: 'Reason (optional)',
              hintText: 'e.g., Amount is incorrect',
              border: OutlineInputBorder(),
            ),
            maxLines: 3,
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: () => Navigator.pop(context, _controller.text),
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.red,
            foregroundColor: Colors.white,
          ),
          child: const Text('Reject'),
        ),
      ],
    );
  }
}
