import 'package:flutter/material.dart';
import '../../../services/api_service.dart';
import '../../../services/payment_notification_service.dart';
import '../../../models/payment_notification.dart';
import '../../../models/expense_models.dart';
import '../../home/widgets/add_expense_dialog.dart';
import '../../home/widgets/personal_expense_dialog.dart';

/// Notification screen — unified view for join requests, payment detections, and system alerts.
class NotificationScreen extends StatefulWidget {
  const NotificationScreen({super.key});

  @override
  State<NotificationScreen> createState() => _NotificationScreenState();
}

class _NotificationScreenState extends State<NotificationScreen> {
  final ApiService _apiService = ApiService();
  bool _isLoading = true;
  List<dynamic> _notifications = [];
  List<dynamic> _joinRequests = [];
  List<PaymentNotification> _paymentNotifications = [];

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    try {
      final results = await Future.wait([
        _apiService.getNotifications(),
        _apiService.getJoinRequests(),
        PaymentNotificationService.instance.getNotificationHistory(),
      ]);

      final notificationsResult = results[0] as Map<String, dynamic>;
      final joinRequestsResult = results[1] as Map<String, dynamic>;
      final paymentNotificationsResult = results[2] as List<PaymentNotification>;

      setState(() {
        _notifications = notificationsResult['data'] ?? [];
        _joinRequests = joinRequestsResult['data'] ?? [];
        _paymentNotifications = paymentNotificationsResult;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _processJoinRequest(
    String requestId,
    bool accept,
    String name,
  ) async {
    try {
      await _apiService.processJoinRequest(requestId, accept);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              accept ? '$name has been added!' : 'Request rejected',
            ),
          ),
        );
        _loadData();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    }
  }

  Future<void> _markAsRead(int notificationId) async {
    try {
      await _apiService.markNotificationAsRead(notificationId);
      _loadData();
    } catch (_) {}
  }

  Future<void> _markAllAsRead() async {
    final unreadNotifications = _notifications
        .where((n) => n['is_read'] != true)
        .toList();
    for (final notification in unreadNotifications) {
      final notificationId = notification['id'];
      if (notificationId is int) {
        await _apiService.markNotificationAsRead(notificationId);
      } else if (notificationId is String) {
        final parsedId = int.tryParse(notificationId);
        if (parsedId != null) {
          await _apiService.markNotificationAsRead(parsedId);
        }
      }
    }
    _loadData();
  }

  @override
  Widget build(BuildContext context) {
    final primaryColor = Theme.of(context).colorScheme.primary;

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: const Text(
          'Notifications',
          style: TextStyle(
            color: Color(0xFF1A1A2E),
            fontWeight: FontWeight.w700,
            fontSize: 17,
          ),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Color(0xFF1A1A2E), size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(color: const Color(0xFFF0F0F0), height: 1),
        ),
        actions: [
          if (_notifications.any((n) => n['is_read'] != true))
            TextButton(
              onPressed: _markAllAsRead,
              child: Text(
                'Mark all read',
                style: TextStyle(color: primaryColor, fontWeight: FontWeight.w600, fontSize: 13),
              ),
            ),
        ],
      ),
      body: _isLoading
          ? Center(child: CircularProgressIndicator(color: primaryColor))
          : RefreshIndicator(
              onRefresh: _loadData,
              child: _buildContent(primaryColor),
            ),
    );
  }

  Widget _buildContent(Color primaryColor) {
    final activePaymentNotifs = _paymentNotifications.where((p) => !p.isProcessed).toList();
    
    if (_joinRequests.isEmpty && _notifications.isEmpty && activePaymentNotifs.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.notifications_none_rounded, size: 48, color: Colors.grey.shade300),
            const SizedBox(height: 16),
            const Text(
              'All caught up',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: Color(0xFF1A1A2E),
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'No new notifications to show.',
              style: TextStyle(fontSize: 13, color: Colors.grey.shade500),
            ),
          ],
        ),
      );
    }

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        if (_joinRequests.isNotEmpty) ...[
          _buildSectionHeader('Join Requests'),
          ..._joinRequests.map(
            (req) => _buildJoinRequestCard(req, primaryColor),
          ),
          const SizedBox(height: 16),
        ],
        if (activePaymentNotifs.isNotEmpty) ...[
          _buildSectionHeader('Payment Detections'),
          ...activePaymentNotifs.map(
            (payment) => _buildPaymentNotificationCard(payment, primaryColor),
          ),
          const SizedBox(height: 16),
        ],
        if (_notifications.isNotEmpty) ...[
          _buildSectionHeader('Recent'),
          ..._notifications.map(
            (notif) => _buildNotificationCard(notif, primaryColor),
          ),
        ],
        const SizedBox(height: 100),
      ],
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 0, 0, 12),
      child: Text(
        title,
        style: const TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w700,
          color: Color(0xFF1A1A2E),
        ),
      ),
    );
  }

  Widget _buildJoinRequestCard(dynamic request, Color primaryColor) {
    final requester = request['requester'];
    final name = requester?['name'] ?? requester?['email'] ?? 'Unknown';
    final initial = name.isNotEmpty ? name[0].toUpperCase() : '?';

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.orange.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 18,
                backgroundColor: Colors.orange.shade50,
                child: Text(
                  initial,
                  style: TextStyle(
                    color: Colors.orange.shade800,
                    fontWeight: FontWeight.w700,
                    fontSize: 13,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name,
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 14,
                        color: Color(0xFF1A1A2E),
                      ),
                    ),
                    Text(
                      'Request to join roomspace',
                      style: TextStyle(color: Colors.grey.shade500, fontSize: 12),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () => _processJoinRequest(request['id'].toString(), false, name),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(0xFFC62828),
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  child: const Text('Reject', style: TextStyle(fontSize: 13)),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton(
                  onPressed: () => _processJoinRequest(request['id'].toString(), true, name),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF2E7D32),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  child: const Text('Accept', style: TextStyle(fontSize: 13)),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildNotificationCard(dynamic notification, Color primaryColor) {
    final isRead = notification['is_read'] ?? false;
    IconData icon;
    Color iconColor;

    switch (notification['type']) {
      case 'JOIN_ACCEPTED':
      case 'PAYMENT_CONFIRMED':
        icon = Icons.check_circle_outline_rounded;
        iconColor = const Color(0xFF2E7D32);
        break;
      case 'JOIN_REJECTED':
      case 'MEMBER_REMOVED':
      case 'PAYMENT_REJECTED':
        icon = Icons.error_outline_rounded;
        iconColor = const Color(0xFFC62828);
        break;
      case 'EXPENSE_ADDED':
        icon = Icons.receipt_long_outlined;
        iconColor = primaryColor;
        break;
      case 'PAYMENT_REMINDER':
      case 'YOU_REMOVED_USER':
        icon = Icons.notifications_active_outlined;
        iconColor = Colors.orange.shade700;
        break;
      case 'PAYMENT_CLAIM':
        icon = Icons.payment_outlined;
        iconColor = Colors.blue.shade700;
        break;
      default:
        icon = Icons.notifications_none_rounded;
        iconColor = Colors.grey.shade600;
    }

    return GestureDetector(
      onTap: isRead ? null : () => _markAsRead(notification['id'] is int ? notification['id'] : int.tryParse(notification['id'].toString()) ?? 0),
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: isRead ? Colors.white : primaryColor.withValues(alpha: 0.05),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: isRead ? const Color(0xFFEEEEF2) : primaryColor.withValues(alpha: 0.1)),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: iconColor.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(icon, color: iconColor, size: 18),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    notification['title'] ?? '',
                    style: TextStyle(
                      fontWeight: isRead ? FontWeight.w500 : FontWeight.w700,
                      fontSize: 13,
                      color: const Color(0xFF1A1A2E),
                    ),
                  ),
                  if (notification['message'] != null)
                    Text(
                      notification['message'],
                      style: TextStyle(color: Colors.grey.shade500, fontSize: 11),
                    ),
                ],
              ),
            ),
            if (!isRead)
              Container(
                width: 6,
                height: 6,
                decoration: BoxDecoration(color: primaryColor, shape: BoxShape.circle),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildPaymentNotificationCard(PaymentNotification payment, Color primaryColor) {
    final amount = payment.amount?.toStringAsFixed(0) ?? '?';
    final merchant = payment.merchant ?? 'Unknown merchant';
    final timeAgo = _getTimeAgo(payment.timestamp);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.blue.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.blue.shade50,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(Icons.payment_rounded, color: Colors.blue.shade700, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Rs. $amount detected',
                      style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14, color: Color(0xFF1A1A2E)),
                    ),
                    Text(
                      'to $merchant',
                      style: TextStyle(color: Colors.grey.shade500, fontSize: 12),
                    ),
                  ],
                ),
              ),
              Text(timeAgo, style: TextStyle(color: Colors.grey.shade400, fontSize: 10)),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () => _dismissPaymentNotification(payment),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  child: const Text('Dismiss', style: TextStyle(fontSize: 13)),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton(
                  onPressed: () => _addPaymentAsExpense(payment),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue.shade700,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  child: const Text('Add Expense', style: TextStyle(fontSize: 13)),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  String _getTimeAgo(DateTime timestamp) {
    final now = DateTime.now();
    final difference = now.difference(timestamp);

    if (difference.inMinutes < 1) return 'now';
    if (difference.inMinutes < 60) return '${difference.inMinutes}m';
    if (difference.inHours < 24) return '${difference.inHours}h';
    if (difference.inDays < 7) return '${difference.inDays}d';
    return '${timestamp.day}/${timestamp.month}';
  }

  void _dismissPaymentNotification(PaymentNotification payment) {
    setState(() {
      _paymentNotifications = _paymentNotifications.map((p) {
        if (p.id == payment.id) {
          return PaymentNotification(
            id: p.id,
            source: p.source,
            appName: p.appName,
            rawText: p.rawText,
            amount: p.amount,
            merchant: p.merchant,
            timestamp: p.timestamp,
            type: p.type,
            isProcessed: true,
          );
        }
        return p;
      }).toList();
    });
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Notification dismissed')),
    );
  }

  void _addPaymentAsExpense(PaymentNotification payment) async {
    try {
      final roomspacesResponse = await _apiService.getRoomspaces();
      final roomspaces = roomspacesResponse['data'] as List<dynamic>? ?? [];
      
      List<RoommateItem> roommates = [];
      String? roomspaceId;
      
      if (roomspaces.isNotEmpty) {
        roomspaceId = roomspaces[0]['id']?.toString();
        final members = roomspaces[0]['members'] as List<dynamic>? ?? [];
        roommates = members.map((m) {
          final user = m['user'];
          return RoommateItem(
            id: m['user_id'] ?? '',
            name: user?['name'] ?? user?['email'] ?? 'Unknown',
            email: user?['email'],
          );
        }).toList();
      }

      _showExpenseOptionsForPayment(payment, roommates, roomspaceId);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    }
  }

  void _showExpenseOptionsForPayment(PaymentNotification payment, List<RoommateItem> roommates, String? roomspaceId) {
    final primaryColor = Theme.of(context).colorScheme.primary;
    
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 36,
              height: 4,
              margin: const EdgeInsets.symmetric(vertical: 12),
              decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(2)),
            ),
            Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                children: [
                  const Text('Select Expense Type', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: Color(0xFF1A1A2E))),
                  const SizedBox(height: 16),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF7F7FB),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: const Color(0xFFEEEEF2)),
                    ),
                    child: Text(
                      'Payment: Rs. ${payment.amount?.toStringAsFixed(0)} to ${payment.merchant}',
                      style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ],
              ),
            ),
            ListTile(
              leading: Icon(Icons.people_outlined, color: primaryColor),
              title: const Text('Add Shared Expense', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
              enabled: roommates.isNotEmpty && roomspaceId != null,
              onTap: () {
                Navigator.pop(context);
                _showSharedExpenseDialogForPayment(payment, roommates, roomspaceId!);
              },
            ),
            ListTile(
              leading: Icon(Icons.account_balance_wallet_outlined, color: primaryColor),
              title: const Text('Add Personal Expense', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
              onTap: () {
                Navigator.pop(context);
                _showPersonalExpenseDialogForPayment(payment);
              },
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  void _showSharedExpenseDialogForPayment(PaymentNotification payment, List<RoommateItem> roommates, String roomspaceId) {
    AddExpenseDialog.show(
      context,
      roommates: roommates,
      roomspaceId: roomspaceId,
      paymentNotification: payment,
      onSubmit: (expense) async {
        try {
          final request = ExpenseCreateRequest.fromExpenseData(expense, roomspaceId);
          await _apiService.createExpense(request.toJson());
          _dismissPaymentNotification(payment);
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Shared expense added')));
          }
        } catch (e) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed: $e')));
          }
        }
      },
    );
  }

  void _showPersonalExpenseDialogForPayment(PaymentNotification payment) {
    PersonalExpenseDialog.show(
      context,
      paymentNotification: payment,
      onSubmit: (expense) async {
        try {
          final request = PersonalExpenseCreateRequest.fromExpenseData(expense);
          await _apiService.createPersonalExpense(request.toJson());
          _dismissPaymentNotification(payment);
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Personal expense added')));
          }
        } catch (e) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed: $e')));
          }
        }
      },
    );
  }
}
