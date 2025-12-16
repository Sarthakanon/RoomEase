import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../core/widgets/mobile_scaffold.dart';
import '../../services/api_service.dart';
import '../../services/payment_notification_service.dart';
import '../../models/payment_notification.dart';
import 'widgets/add_expense_dialog.dart';

class MobileDashboard extends StatefulWidget {
  const MobileDashboard({super.key});

  @override
  State<MobileDashboard> createState() => _MobileDashboardState();
}

class _MobileDashboardState extends State<MobileDashboard> {
  final ApiService _apiService = ApiService();
  bool _hasRoomspace = false;
  bool _isLoading = true;
  List<RoommateItem> _roommates = [];
  int _unreadNotificationCount = 0;

  @override
  void initState() {
    super.initState();
    _checkRoomspace();
    _loadUnreadCount();
    _initializePaymentNotifications();
  }

  Future<void> _initializePaymentNotifications() async {
    try {
      final paymentService = PaymentNotificationService.instance;
      await paymentService.initialize();
      
      // Set callback for when user wants to add expense from payment notification
      paymentService.onExpenseRequested = _showExpenseDialogFromPayment;
    } catch (e) {
      debugPrint('Error initializing payment notifications: $e');
    }
  }

  Future<void> _loadUnreadCount() async {
    try {
      final results = await Future.wait([
        _apiService.getNotifications(),
        _apiService.getJoinRequests(),
      ]);

      final notifications = results[0]['data'] as List<dynamic>? ?? [];
      final joinRequests = results[1]['data'] as List<dynamic>? ?? [];

      final unreadNotifications = notifications
          .where((n) => n['is_read'] != true)
          .length;

      if (mounted) {
        setState(() {
          _unreadNotificationCount = unreadNotifications + joinRequests.length;
        });
      }
    } catch (e) {
      // Silently fail - notification count is not critical
    }
  }

  Future<void> _checkRoomspace() async {
    try {
      final response = await _apiService.getRoomspaces();
      if (response.containsKey('data')) {
        final roomspaces = response['data'] as List<dynamic>;
        if (mounted) {
          setState(() {
            _hasRoomspace = roomspaces.isNotEmpty;
            _isLoading = false;
          });

          // Load roommates from first roomspace
          if (roomspaces.isNotEmpty) {
            final members = roomspaces[0]['members'] as List<dynamic>? ?? [];
            _roommates = members.map((m) {
              final user = m['user'];
              return RoommateItem(
                id: m['firebase_uid'] ?? '',
                name: user?['name'] ?? user?['email'] ?? 'Unknown',
                email: user?['email'],
              );
            }).toList();
          }
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _hasRoomspace = false;
          _isLoading = false;
        });
      }
    }
  }

  void _showAddExpenseDialog() {
    if (_roommates.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Join a roomspace first to add expenses'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    AddExpenseDialog.show(
      context,
      roommates: _roommates,
      onSubmit: (expense) {
        // TODO: Save expense to API and notify selected roommates
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Added: ${expense.title} - Rs. ${expense.amount.toStringAsFixed(2)}',
            ),
            backgroundColor: Colors.green,
          ),
        );
      },
    );
  }

  void _showExpenseDialogFromPayment(PaymentNotification notification) {
    if (_roommates.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Join a roomspace first to add expenses'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    AddExpenseDialog.show(
      context,
      roommates: _roommates,
      paymentNotification: notification,
      onSubmit: (expense) {
        // TODO: Save expense to API and notify selected roommates
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Added payment expense: ${expense.title} - Rs. ${expense.amount.toStringAsFixed(2)}',
            ),
            backgroundColor: Colors.green,
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    // 1. Get current user
    final user = FirebaseAuth.instance.currentUser;
    // 2. Use theme colors
    final Color primaryColor = Theme.of(context).colorScheme.primary;

    return MobileScaffold(
      currentIndex: 0,
      body: SingleChildScrollView(
        child: Column(
          children: [
            // ---------------------------------------------
            // HEADER SECTION
            // ---------------------------------------------
            Container(
              width: double.infinity,
              padding: const EdgeInsets.only(
                left: 20,
                right: 20,
                top: 60,
                bottom: 25,
              ),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [primaryColor, primaryColor.withValues(alpha: 0.7)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: const BorderRadius.only(
                  bottomLeft: Radius.circular(30),
                  bottomRight: Radius.circular(30),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          Text(
                            'Hi, ',
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.8),
                              fontSize: 14,
                            ),
                          ),
                          Text(
                            user?.displayName ?? 'User',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                      GestureDetector(
                        onTap: () async {
                          await Navigator.pushNamed(context, '/notifications');
                          _loadUnreadCount();
                        },
                        child: Stack(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.2),
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(
                                Icons.notifications_outlined,
                                color: Colors.white,
                                size: 22,
                              ),
                            ),
                            if (_unreadNotificationCount > 0)
                              Positioned(
                                right: 0,
                                top: 0,
                                child: Container(
                                  padding: const EdgeInsets.all(4),
                                  decoration: const BoxDecoration(
                                    color: Colors.red,
                                    shape: BoxShape.circle,
                                  ),
                                  constraints: const BoxConstraints(
                                    minWidth: 16,
                                    minHeight: 16,
                                  ),
                                  child: Text(
                                    _unreadNotificationCount > 9
                                        ? '9+'
                                        : '$_unreadNotificationCount',
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 9,
                                      fontWeight: FontWeight.bold,
                                    ),
                                    textAlign: TextAlign.center,
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'You are owed',
                              style: TextStyle(
                                color: Colors.white.withValues(alpha: 0.8),
                                fontSize: 13,
                              ),
                            ),
                            const SizedBox(height: 6),
                            const Text(
                              'Rs. 450.00',
                              style: TextStyle(
                                color: Colors.greenAccent,
                                fontSize: 32,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Container(
                        width: 1,
                        height: 60,
                        color: Colors.white.withValues(alpha: 0.3),
                      ),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text(
                              'You owe',
                              style: TextStyle(
                                color: Colors.white.withValues(alpha: 0.8),
                                fontSize: 13,
                              ),
                            ),
                            const SizedBox(height: 6),
                            const Text(
                              'Rs. 120.00',
                              style: TextStyle(
                                color: Colors.redAccent,
                                fontSize: 32,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            // FIXED: Action Buttons
            Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: InkWell(
                          onTap: () {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Opening Scanner...'),
                              ),
                            );
                          },
                          child: Container(
                            height: 100,
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(20),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.grey.withValues(alpha: 0.1),
                                  blurRadius: 10,
                                  offset: const Offset(0, 4),
                                ),
                              ],
                            ),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons.document_scanner_rounded,
                                  color: primaryColor,
                                  size: 30,
                                ),
                                const SizedBox(height: 8),
                                const Text(
                                  "Scan Receipt",
                                  style: TextStyle(fontWeight: FontWeight.bold),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 15),
                      Expanded(
                        child: InkWell(
                          onTap: () => _showAddExpenseDialog(),
                          child: Container(
                            height: 100,
                            decoration: BoxDecoration(
                              color: primaryColor,
                              borderRadius: BorderRadius.circular(20),
                              boxShadow: [
                                BoxShadow(
                                  color: primaryColor.withValues(alpha: 0.4),
                                  blurRadius: 10,
                                  offset: const Offset(0, 4),
                                ),
                              ],
                            ),
                            child: const Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.add, color: Colors.white, size: 30),
                                SizedBox(height: 8),
                                Text(
                                  "Add Expense",
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: Colors.white,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  if (!_hasRoomspace && !_isLoading) ...[
                    const SizedBox(height: 20),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: () {
                              Navigator.pushNamed(context, '/create-roomspace');
                            },
                            icon: Icon(
                              Icons.add_home_rounded,
                              color: primaryColor,
                            ),
                            label: Text(
                              "Create Room",
                              style: TextStyle(color: primaryColor),
                            ),
                            style: OutlinedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              side: BorderSide(color: primaryColor),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 15),
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: () {
                              Navigator.pushNamed(context, '/join-roomspace');
                            },
                            icon: Icon(
                              Icons.login_rounded,
                              color: primaryColor,
                            ),
                            label: Text(
                              "Join Room",
                              style: TextStyle(color: primaryColor),
                            ),
                            style: OutlinedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              side: BorderSide(color: primaryColor),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),

            // Recent Activity Header
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  "Recent Activity",
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.grey[800],
                  ),
                ),
              ),
            ),
            const SizedBox(height: 10),

            // ---------------------------------------------
            // RECENT ACTIVITY LIST
            // ---------------------------------------------
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Column(
                children: [
                  _expenseTile(
                    "Grocery Run",
                    "Yesterday",
                    45.50,
                    true,
                    primaryColor,
                  ),
                  _expenseTile(
                    "Internet Bill",
                    "Oct 24",
                    30.00,
                    false,
                    primaryColor,
                  ),
                  _expenseTile(
                    "House Party",
                    "Oct 22",
                    120.00,
                    true,
                    primaryColor,
                  ),
                  const SizedBox(height: 100), // Extra space for bottom nav
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Helper widget to build a single expense row
  Widget _expenseTile(
    String title,
    String date,
    double amount,
    bool youPaid,
    Color primaryColor,
  ) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withValues(alpha: 0.05),
            blurRadius: 5,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: primaryColor.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(Icons.receipt_long, color: primaryColor),
          ),
          const SizedBox(width: 15),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
                Text(
                  youPaid ? "You paid" : "Someone else paid",
                  style: TextStyle(color: Colors.grey[500], fontSize: 12),
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                "Rs. ${amount.toStringAsFixed(2)}",
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                  color: youPaid ? const Color(0xFF10B981) : Colors.redAccent,
                ),
              ),
              Text(
                date,
                style: TextStyle(color: Colors.grey[400], fontSize: 12),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
