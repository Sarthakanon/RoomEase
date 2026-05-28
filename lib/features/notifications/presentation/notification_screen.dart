import 'package:flutter/material.dart';
import '../../../services/api_service.dart';
import '../../../services/cached_api_service.dart';
import '../../../services/payment_notification_service.dart';
import '../../../services/real_time_data_service.dart';
import '../../../models/payment_notification.dart';
import '../../../models/expense_models.dart';
import '../../home/widgets/add_expense_dialog.dart';
import '../../home/widgets/personal_expense_dialog.dart';
import '../../expenses/presentation/payment_confirmation_screen.dart';
import '../../expenses/presentation/who_owes_who_screen.dart';
import '../../expenses/presentation/expense_history_screen.dart';
import '../../expenses/presentation/deletion_history_screen.dart';
import '../../../providers/roomspace_provider.dart';
import 'package:provider/provider.dart';
import 'dart:async';
import 'dart:convert';

/// Notification screen — unified view for join requests, payment detections, and system alerts.
class NotificationScreen extends StatefulWidget {
  const NotificationScreen({super.key});

  @override
  State<NotificationScreen> createState() => _NotificationScreenState();
}

class _NotificationScreenState extends State<NotificationScreen> {
  final ApiService _apiService = ApiService();
  final CachedApiService _cachedApiService = CachedApiService();
  final RealTimeDataService _realTimeService = RealTimeDataService();
  bool _isLoading = true;
  List<dynamic> _notifications = [];
  List<dynamic> _joinRequests = [];
  List<PaymentNotification> _paymentNotifications = [];
  StreamSubscription<JoinRequestUpdateEvent>? _joinRequestSubscription;

  @override
  void initState() {
    super.initState();
    _loadData();
    _setupRealTimeListeners();
  }

  @override
  void dispose() {
    _joinRequestSubscription?.cancel();
    super.dispose();
  }

  void _setupRealTimeListeners() {
    // Listen for join request updates
    _joinRequestSubscription = _realTimeService.joinRequestUpdates.listen((event) {
      debugPrint('🔄 NotificationScreen: Join request update received');
      // Reload data when join request is processed
      _loadData();
    });
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = _notifications.isEmpty && _joinRequests.isEmpty && _paymentNotifications.isEmpty);
    try {
      Map<String, dynamic> notificationsResult = {'data': _notifications};
      Map<String, dynamic> joinRequestsResult = {'data': _joinRequests};
      List<PaymentNotification> paymentNotificationsResult = _paymentNotifications;

      try {
        notificationsResult = await _cachedApiService.getNotifications();
      } catch (_) {}
      try {
        joinRequestsResult = await _cachedApiService.getJoinRequests();
      } catch (_) {}
      try {
        paymentNotificationsResult =
            await PaymentNotificationService.instance.getNotificationHistory();
      } catch (_) {}

      setState(() {
        _notifications = notificationsResult['data'] ?? [];
        _joinRequests = joinRequestsResult['data'] ?? [];
        _paymentNotifications = paymentNotificationsResult;
        _isLoading = false;
      });

      // Silent background refresh
      Future.wait([
        _cachedApiService.getNotifications(forceRefresh: true),
        _cachedApiService.getJoinRequests(forceRefresh: true),
      ]).then((fresh) {
        if (!mounted) return;
        setState(() {
          _notifications = (fresh[0]['data'] ?? []) as List<dynamic>;
          _joinRequests = (fresh[1]['data'] ?? []) as List<dynamic>;
        });
      }).catchError((_) {});
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
      // Mark as processing
      setState(() {
        final index = _joinRequests.indexWhere((r) => r['id'].toString() == requestId);
        if (index != -1) {
          _joinRequests[index]['_isProcessing'] = true;
        }
      });

      await _apiService.processJoinRequest(requestId, accept);
      
      // Notify real-time service
      _realTimeService.notifyJoinRequestProcessed(requestId, accept);
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              accept ? '$name has been added!' : 'Request rejected',
            ),
          ),
        );
        // Reload data to remove the processed request
        await _loadData();
      }
    } catch (e) {
      // Remove processing state on error
      setState(() {
        final index = _joinRequests.indexWhere((r) => r['id'].toString() == requestId);
        if (index != -1) {
          _joinRequests[index]['_isProcessing'] = false;
        }
      });
      
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
      _realTimeService.notifyNotificationsUpdated();
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
    _realTimeService.notifyNotificationsUpdated();
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
    final roomspace = request['roomspace'];
    final roomspaceName =
        roomspace?['name'] ??
        request['roomspace_name'] ??
        request['room_name'] ??
        'this roomspace';
    final initial = name.isNotEmpty ? name[0].toUpperCase() : '?';
    final requestId = request['id'].toString();
    final isProcessing = request['_isProcessing'] == true;

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
                      'Request to join $roomspaceName',
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
                  onPressed: isProcessing ? null : () => _processJoinRequest(requestId, false, name),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(0xFFC62828),
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  child: isProcessing 
                      ? const SizedBox(
                          height: 16,
                          width: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('Reject', style: TextStyle(fontSize: 13)),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton(
                  onPressed: isProcessing ? null : () => _processJoinRequest(requestId, true, name),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF2E7D32),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  child: isProcessing
                      ? const SizedBox(
                          height: 16,
                          width: 16,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                        )
                      : const Text('Accept', style: TextStyle(fontSize: 13)),
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
      onTap: () => _handleNotificationTap(notification),
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

  Future<void> _handleNotificationTap(dynamic notification) async {
    final notificationId = notification['id'] is int
        ? notification['id'] as int
        : int.tryParse(notification['id'].toString());
    if (notificationId != null && notification['is_read'] != true) {
      await _markAsRead(notificationId);
    }

    final type = (notification['type'] ?? '').toString();
    final data = _parseNotificationData(notification['data']);
    final roomspaceId = (data['roomspace_id'] ?? '').toString();
    if (roomspaceId.isNotEmpty) {
      await _setActiveRoomspaceIfAvailable(roomspaceId);
    }

    if (!mounted) return;

    switch (type) {
      case 'PAYMENT_CLAIM':
      case 'PAYMENT_CONFIRMED':
      case 'PAYMENT_REJECTED':
      case 'PAYMENT_REMINDER':
      case 'PAYMENT_RECEIVED':
        if (roomspaceId.isNotEmpty) {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => PaymentConfirmationScreen(roomspaceId: roomspaceId),
            ),
          );
        }
        return;
      case 'EXPENSE_ADDED':
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => ExpenseHistoryScreen(
              roomspaceId: roomspaceId.isNotEmpty ? roomspaceId : null,
            ),
          ),
        );
        return;
      case 'EXPENSE_DELETION_REQUEST':
      case 'EXPENSE_DELETION_APPROVED':
      case 'EXPENSE_DELETION_REJECTED':
        if (roomspaceId.isNotEmpty) {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => DeletionHistoryScreen(roomspaceId: roomspaceId),
            ),
          );
        }
        return;
      case 'JOIN_ACCEPTED':
      case 'JOIN_REJECTED':
      case 'MEMBER_REMOVED':
      case 'YOU_REMOVED_USER':
      case 'OWNERSHIP_TRANSFERRED':
        if (roomspaceId.isNotEmpty) {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => WhoOwesWhoScreen(roomspaceId: roomspaceId),
            ),
          );
        }
        return;
      default:
        return;
    }
  }

  Map<String, dynamic> _parseNotificationData(dynamic rawData) {
    if (rawData is Map<String, dynamic>) return rawData;
    if (rawData is String && rawData.isNotEmpty) {
      try {
        final parsed = jsonDecode(rawData);
        if (parsed is Map<String, dynamic>) return parsed;
      } catch (_) {}
    }
    return {};
  }

  Future<void> _setActiveRoomspaceIfAvailable(String roomspaceId) async {
    try {
      final provider = Provider.of<RoomspaceProvider>(context, listen: false);
      await provider.setActiveRoomspace(roomspaceId);
    } catch (_) {}
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
          final requests = ExpenseCreateRequest.fromExpenseDataBatch(expense, roomspaceId);
          for (final request in requests) {
            await _apiService.createExpense(request.toJson());
          }
          final isRecurring = expense.recurringConfig?.isRecurring == true;
          if (isRecurring && requests.length > 1) {
            final payerAmounts = Map<String, double>.from(expense.payerAmounts)
              ..removeWhere((_, v) => v <= 0);
            final fallbackPayer = expense.paidBy ??
                (expense.selectedRoommateIds.isNotEmpty ? expense.selectedRoommateIds.first : '');
            if (fallbackPayer.isNotEmpty && payerAmounts.isEmpty) {
              payerAmounts[fallbackPayer] = expense.amount;
            }
            await _apiService.createRecurringExpenseTemplate({
              'roomspace_id': roomspaceId,
              'title': expense.title,
              'description': expense.description,
              'amount': expense.amount,
              'category': expense.category,
              'paid_by': fallbackPayer,
              'payer_amounts': payerAmounts,
              'split_type': expense.splitType.apiValue,
              'selected_roommates': expense.selectedRoommateIds,
              'custom_splits': expense.customSplits,
              'recurring_config': expense.recurringConfig!.toJson(),
            });
          }
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
