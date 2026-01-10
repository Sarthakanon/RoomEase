import 'package:flutter/material.dart';
import '../../../services/api_service.dart';
import '../../../services/payment_notification_service.dart';
import '../../../models/payment_notification.dart';
import '../../../models/expense_models.dart';
import '../../home/widgets/add_expense_dialog.dart';
import '../../home/widgets/personal_expense_dialog.dart';

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
            backgroundColor: accept ? Colors.green : Colors.orange,
          ),
        );
        _loadData();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<void> _markAsRead(int notificationId) async {
    try {
      await _apiService.markNotificationAsRead(notificationId);
      _loadData();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    }
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
      backgroundColor: const Color(0xFFF8F9FA),
      appBar: AppBar(
        backgroundColor: const Color(0xFFF8F9FA),
        elevation: 0,
        title: const Text(
          'Notifications',
          style: TextStyle(color: Colors.black87, fontWeight: FontWeight.bold),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black87),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          if (_notifications.any((n) => n['is_read'] != true))
            TextButton(
              onPressed: _markAllAsRead,
              child: Text(
                'Mark all read',
                style: TextStyle(color: primaryColor),
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
    if (_joinRequests.isEmpty && _notifications.isEmpty && _paymentNotifications.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Logo
            Container(
              height: 80,
              width: 80,
              margin: const EdgeInsets.only(bottom: 16),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: Image.asset(
                  'png/main_logo.png',
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) {
                    return Icon(Icons.notifications_none, size: 64, color: Colors.grey[400]);
                  },
                ),
              ),
            ),
            Text(
              'No notifications',
              style: TextStyle(fontSize: 18, color: Colors.grey[600]),
            ),
            const SizedBox(height: 8),
            Text(
              'You\'ll see notifications here when they arrive',
              style: TextStyle(fontSize: 14, color: Colors.grey[500]),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );
    }

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        if (_joinRequests.isNotEmpty) ...[
          Text(
            'Join Requests',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Colors.grey[700],
            ),
          ),
          const SizedBox(height: 12),
          ..._joinRequests.map(
            (req) => _buildJoinRequestCard(req, primaryColor),
          ),
          const SizedBox(height: 24),
        ],
        if (_paymentNotifications.isNotEmpty) ...[
          Text(
            'Payment Notifications',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Colors.grey[700],
            ),
          ),
          const SizedBox(height: 12),
          ..._paymentNotifications.where((p) => !p.isProcessed).map(
            (payment) => _buildPaymentNotificationCard(payment, primaryColor),
          ),
          const SizedBox(height: 24),
        ],
        if (_notifications.isNotEmpty) ...[
          Text(
            'Recent',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Colors.grey[700],
            ),
          ),
          const SizedBox(height: 12),
          ..._notifications.map(
            (notif) => _buildNotificationCard(notif, primaryColor),
          ),
        ],
      ],
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
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.orange.withValues(alpha: 0.3)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                backgroundColor: Colors.orange.withValues(alpha: 0.1),
                child: Text(
                  initial,
                  style: const TextStyle(
                    color: Colors.orange,
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
                      name,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                    Text(
                      'wants to join your roomspace',
                      style: TextStyle(color: Colors.grey[600], fontSize: 13),
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
                  onPressed: () =>
                      _processJoinRequest(request['id'].toString(), false, name),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.red,
                    side: const BorderSide(color: Colors.red),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  child: const Text('Reject'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton(
                  onPressed: () =>
                      _processJoinRequest(request['id'].toString(), true, name),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  child: const Text('Accept'),
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
        icon = Icons.check_circle;
        iconColor = Colors.green;
        break;
      case 'JOIN_REJECTED':
        icon = Icons.cancel;
        iconColor = Colors.red;
        break;
      case 'EXPENSE_ADDED':
        icon = Icons.receipt_long;
        iconColor = primaryColor;
        break;
      case 'MEMBER_REMOVED':
        icon = Icons.person_remove;
        iconColor = Colors.red;
        break;
      case 'YOU_REMOVED_USER':
        icon = Icons.person_off;
        iconColor = Colors.orange;
        break;
      default:
        icon = Icons.notifications;
        iconColor = Colors.grey;
    }

    return GestureDetector(
      onTap: isRead ? null : () {
        final notificationId = notification['id'];
        if (notificationId is int) {
          _markAsRead(notificationId);
        } else if (notificationId is String) {
          final parsedId = int.tryParse(notificationId);
          if (parsedId != null) {
            _markAsRead(parsedId);
          }
        }
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: isRead ? Colors.white : primaryColor.withValues(alpha: 0.05),
          borderRadius: BorderRadius.circular(12),
          border: isRead
              ? null
              : Border.all(color: primaryColor.withValues(alpha: 0.2)),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: iconColor.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: iconColor, size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    notification['title'] ?? '',
                    style: TextStyle(
                      fontWeight: isRead ? FontWeight.normal : FontWeight.bold,
                      fontSize: 14,
                    ),
                  ),
                  if (notification['message'] != null)
                    Text(
                      notification['message'],
                      style: TextStyle(color: Colors.grey[600], fontSize: 12),
                    ),
                ],
              ),
            ),
            if (!isRead)
              Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  color: primaryColor,
                  shape: BoxShape.circle,
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildPaymentNotificationCard(PaymentNotification payment, Color primaryColor) {
    final amount = payment.amount?.toStringAsFixed(2) ?? 'Unknown';
    final merchant = payment.merchant ?? 'Unknown merchant';
    final timeAgo = _getTimeAgo(payment.timestamp);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.green.withValues(alpha: 0.3)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.green.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(
                  Icons.payment,
                  color: Colors.green,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Payment Detected - Rs. $amount',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                    Text(
                      'Payment to $merchant via ${payment.appName}',
                      style: TextStyle(color: Colors.grey[600], fontSize: 13),
                    ),
                    Text(
                      timeAgo,
                      style: TextStyle(color: Colors.grey[500], fontSize: 12),
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
                  onPressed: () => _dismissPaymentNotification(payment),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.grey[600],
                    side: BorderSide(color: Colors.grey[400]!),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  child: const Text('Dismiss'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton(
                  onPressed: () => _addPaymentAsExpense(payment),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  child: const Text('Add as Expense'),
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

    if (difference.inMinutes < 1) {
      return 'Just now';
    } else if (difference.inMinutes < 60) {
      return '${difference.inMinutes}m ago';
    } else if (difference.inHours < 24) {
      return '${difference.inHours}h ago';
    } else if (difference.inDays < 7) {
      return '${difference.inDays}d ago';
    } else {
      return '${timestamp.day}/${timestamp.month}/${timestamp.year}';
    }
  }

  void _dismissPaymentNotification(PaymentNotification payment) {
    // Mark as processed to hide from the list
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
      const SnackBar(
        content: Text('Payment notification dismissed'),
        backgroundColor: Colors.grey,
      ),
    );
  }

  void _addPaymentAsExpense(PaymentNotification payment) async {
    try {
      // Get roommates for the expense dialog
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
            id: m['user_id'] ?? '',  // Changed from 'firebase_uid' to 'user_id'
            name: user?['name'] ?? user?['email'] ?? 'Unknown',
            email: user?['email'],
          );
        }).toList();
      }

      // Show expense type selection dialog
      _showExpenseOptionsForPayment(payment, roommates, roomspaceId);
      
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
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
            // Handle bar
            Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.symmetric(vertical: 12),
              decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            
            // Header
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  Text(
                    'Add Expense',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.grey[800],
                    ),
                  ),
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.blue.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.blue.withValues(alpha: 0.3)),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.payment, color: Colors.blue, size: 20),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Payment: Rs. ${payment.amount?.toStringAsFixed(2) ?? 'Unknown'} to ${payment.merchant ?? 'Unknown'}',
                            style: TextStyle(
                              color: Colors.blue[800],
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            
            // Options
            ListTile(
              leading: Icon(Icons.people, color: primaryColor),
              title: const Text('Add Shared Expense'),
              subtitle: const Text('Split with roommates'),
              enabled: roommates.isNotEmpty && roomspaceId != null,
              onTap: roommates.isNotEmpty && roomspaceId != null ? () {
                Navigator.pop(context);
                _showSharedExpenseDialogForPayment(payment, roommates, roomspaceId!);
              } : null,
            ),
            ListTile(
              leading: Icon(Icons.account_balance_wallet, color: primaryColor),
              title: const Text('Add Personal Expense'),
              subtitle: const Text('Track personal spending'),
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
          // Create expense request
          final request = ExpenseCreateRequest.fromExpenseData(
            expense,
            roomspaceId,
          );

          // Submit to API
          await _apiService.createExpense(request.toJson());

          // Mark payment as processed
          _dismissPaymentNotification(payment);
          
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                  'Added payment expense: ${expense.title} - Rs. ${expense.amount.toStringAsFixed(2)}',
                ),
                backgroundColor: Colors.green,
              ),
            );
          }
        } catch (e) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Failed to add expense: ${e.toString()}'),
                backgroundColor: Colors.red,
              ),
            );
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
          // Create personal expense request
          final request = PersonalExpenseCreateRequest.fromExpenseData(expense);

          // Submit to API
          await _apiService.createPersonalExpense(request.toJson());

          // Mark payment as processed
          _dismissPaymentNotification(payment);

          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                  'Added personal expense: ${expense.title} - Rs. ${expense.amount.toStringAsFixed(2)}',
                ),
                backgroundColor: Colors.green,
              ),
            );
          }
        } catch (e) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Failed to add personal expense: ${e.toString()}'),
                backgroundColor: Colors.red,
              ),
            );
          }
        }
      },
    );
  }
}
