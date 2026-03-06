import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:provider/provider.dart';
import '../../core/widgets/mobile_scaffold.dart';
import '../../core/widgets/roomspace_switcher.dart';
import '../../core/widgets/global_roomspace_selector.dart';
import '../../core/widgets/skeleton_loader.dart';
import '../../services/api_service.dart';
import '../../services/balance_service.dart';
import '../../services/payment_notification_service.dart';
import '../../services/ocr_service.dart';
import '../../models/payment_notification.dart';
import '../../models/expense_models.dart';
import '../../providers/roomspace_provider.dart';
import 'widgets/add_expense_dialog.dart';
import 'widgets/personal_expense_dialog.dart';
import 'widgets/receipt_scanner_dialog.dart';

/// Home dashboard — shows balance summary, quick actions, and recent expenses.
class MobileDashboard extends StatefulWidget {
  const MobileDashboard({super.key});

  @override
  State<MobileDashboard> createState() => _MobileDashboardState();
}

class _MobileDashboardState extends State<MobileDashboard>
    with WidgetsBindingObserver {
  final ApiService _apiService = ApiService();
  final BalanceService _balanceService = BalanceService();

  bool _hasRoomspace = false;
  bool _isLoading = true;
  List<RoommateItem> _roommates = [];
  int _unreadNotificationCount = 0;
  String? _currentRoomspaceId;

  // Recent expense data
  List<ExpenseData> _recentExpenses = [];
  List<PersonalExpenseData> _recentPersonalExpenses = [];
  bool _isLoadingExpenses = true;
  String? _expensesError;

  // Balance data
  double _youAreOwed = 0.0;
  double _youOwe = 0.0;
  bool _isLoadingBalance = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _checkRoomspace();
    _loadUnreadCount();
    _loadBalance();
    _initializePaymentNotifications();

    // Listen for roomspace changes
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final roomspaceProvider =
          Provider.of<RoomspaceProvider>(context, listen: false);
      roomspaceProvider.addListener(_onRoomspaceChanged);
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    final roomspaceProvider =
        Provider.of<RoomspaceProvider>(context, listen: false);
    roomspaceProvider.removeListener(_onRoomspaceChanged);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Refresh when the app comes back from background
    if (state == AppLifecycleState.resumed) {
      _loadBalance();
      _loadRecentExpenses();
      _loadUnreadCount();
    }
  }

  /// Called automatically when the active roomspace changes
  void _onRoomspaceChanged() {
    _loadRecentExpenses();
    _loadBalance();
  }

  Future<void> _initializePaymentNotifications() async {
    try {
      final paymentService = PaymentNotificationService.instance;
      await paymentService.initialize();
      await paymentService.initializeBackgroundService();
      await paymentService.startBackgroundMonitoring();
      paymentService.onExpenseRequested = _showExpenseDialogFromPayment;
    } catch (e) {
      debugPrint('Error initializing payment notifications: $e');
    }
  }

  Future<void> _loadRecentExpenses() async {
    try {
      setState(() {
        _isLoadingExpenses = true;
        _expensesError = null;
      });

      final roomspaceProvider =
          Provider.of<RoomspaceProvider>(context, listen: false);
      final activeRoomspaceId = roomspaceProvider.getActiveRoomspaceId();
      final isPersonalSpace = roomspaceProvider.isPersonalSpace;

      final futures = <Future>[];

      // Only load shared expenses when inside a real roomspace
      if (!isPersonalSpace && activeRoomspaceId != null) {
        futures.add(_apiService.getRecentExpenses(
            roomspaceId: activeRoomspaceId, limit: 3));
      }

      // Always load personal expenses
      futures.add(_apiService.getPersonalExpenses(limit: 3, offset: 0));

      final results = await Future.wait(futures);

      List<ExpenseData> sharedExpenses = [];
      List<PersonalExpenseData> personalExpenses = [];

      int idx = 0;

      if (!isPersonalSpace && activeRoomspaceId != null) {
        final sharedResponse = results[idx++];
        if (sharedResponse.containsKey('data') && sharedResponse['data'] is List) {
          sharedExpenses = (sharedResponse['data'] as List)
              .map((e) => ExpenseData.fromJson(e))
              .toList();
        }
      }

      final personalResponse = results[idx];
      if (personalResponse.containsKey('data') &&
          personalResponse['data'] is List) {
        personalExpenses = (personalResponse['data'] as List)
            .map((e) => PersonalExpenseData.fromJson(e))
            .toList();
      }

      if (mounted) {
        setState(() {
          _recentExpenses = sharedExpenses;
          _recentPersonalExpenses = personalExpenses;
          _isLoadingExpenses = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _expensesError = 'Failed to load recent expenses';
          _isLoadingExpenses = false;
        });
      }
    }
  }

  Future<void> _refreshRecentExpenses() async {
    await _loadRecentExpenses();
    await _loadBalance();
  }

  Future<void> _loadUnreadCount() async {
    try {
      final results = await Future.wait([
        _apiService.getNotifications(),
        _apiService.getJoinRequests(),
      ]);

      final notifications = results[0]['data'] as List<dynamic>? ?? [];
      final joinRequests = results[1]['data'] as List<dynamic>? ?? [];
      final unread = notifications.where((n) => n['is_read'] != true).length;

      if (mounted) {
        setState(() {
          _unreadNotificationCount = unread + joinRequests.length;
        });
      }
    } catch (_) {
      // Notification count is non-critical; silently ignore errors
    }
  }

  Future<void> _checkRoomspace() async {
    try {
      final roomspaceProvider =
          Provider.of<RoomspaceProvider>(context, listen: false);
      await roomspaceProvider.loadRoomspaces();

      final activeRoomspace = roomspaceProvider.activeRoomspace;
      final activeRoomspaceId = roomspaceProvider.getActiveRoomspaceId();

      // Load roommates if in a roomspace
      if (activeRoomspaceId != null && activeRoomspace != null) {
        try {
          final response = await _apiService.getRoomspaceMembers(activeRoomspaceId);
          if (response['success'] == true && response['data'] != null) {
            final members = response['data'] as List;
            _roommates = members
                .map((m) => RoommateItem(
                      id: m['user_id'] ?? '',
                      name: m['user_name'] ?? m['name'] ?? 'Unknown',
                    ))
                .toList();
            _currentRoomspaceId = activeRoomspaceId;
          }
        } catch (e) {
          debugPrint('Error loading roommates: $e');
          _roommates = [];
          _currentRoomspaceId = null;
        }
      } else {
        _roommates = [];
        _currentRoomspaceId = null;
      }

      if (mounted) {
        setState(() {
          _hasRoomspace = activeRoomspace != null;
          _isLoading = false;
        });
      }

      await _loadRecentExpenses();
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _loadBalance() async {
    setState(() => _isLoadingBalance = true);

    try {
      final roomspaceProvider =
          Provider.of<RoomspaceProvider>(context, listen: false);
      final activeRoomspaceId = roomspaceProvider.getActiveRoomspaceId();
      final isPersonalSpace = roomspaceProvider.isPersonalSpace;
      final currentUser = FirebaseAuth.instance.currentUser;

      // No balance to show in personal space
      if (isPersonalSpace || activeRoomspaceId == null || currentUser == null) {
        setState(() {
          _youAreOwed = 0.0;
          _youOwe = 0.0;
          _isLoadingBalance = false;
        });
        return;
      }

      final balance = await _balanceService.getUserBalance(
        activeRoomspaceId,
        currentUser.uid,
      );

      if (balance != null && mounted) {
        setState(() {
          if (balance.balance > 0) {
            _youAreOwed = balance.balance;
            _youOwe = 0.0;
          } else {
            _youAreOwed = 0.0;
            _youOwe = balance.balance.abs();
          }
          _isLoadingBalance = false;
        });
      } else if (mounted) {
        setState(() {
          _youAreOwed = 0.0;
          _youOwe = 0.0;
          _isLoadingBalance = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _youAreOwed = 0.0;
          _youOwe = 0.0;
          _isLoadingBalance = false;
        });
      }
    }
  }

  // ──────────────────────────────────────────
  // ADD EXPENSE HELPERS
  // ──────────────────────────────────────────

  void _showAddExpenseDialog() {
    final primaryColor = Theme.of(context).colorScheme.primary;
    _showExpenseOptions(context, primaryColor);
  }

  void _showExpenseOptions(
    BuildContext context,
    Color primaryColor, {
    PaymentNotification? paymentNotification,
  }) {
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
            // Bottom sheet handle bar
            Container(
              width: 36,
              height: 4,
              margin: const EdgeInsets.symmetric(vertical: 12),
              decoration: BoxDecoration(
                color: Colors.grey.shade300,
                borderRadius: BorderRadius.circular(2),
              ),
            ),

            Padding(
              padding: const EdgeInsets.fromLTRB(20, 4, 20, 4),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Add Expense',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                  ),

                  // Show payment notification info if auto-filled
                  if (paymentNotification != null) ...[
                    const SizedBox(height: 10),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.indigo.shade50,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.indigo.shade100),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.payment_rounded,
                              color: Colors.indigo.shade600, size: 18),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'Rs. ${paymentNotification.amount?.toStringAsFixed(2) ?? '?'} · ${paymentNotification.merchant ?? 'Unknown'}',
                              style: TextStyle(
                                color: Colors.indigo.shade700,
                                fontSize: 13,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),

            const Divider(height: 1),

            // Option 1 — Shared Expense
            ListTile(
              leading: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(Icons.people_outlined,
                    color: Colors.grey.shade700, size: 20),
              ),
              title: const Text('Shared Expense',
                  style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
              subtitle: const Text('Split with roommates',
                  style: TextStyle(fontSize: 12)),
              onTap: () {
                Navigator.pop(context);
                _showSharedExpenseDialog(
                    paymentNotification: paymentNotification);
              },
            ),

            // Option 2 — Personal Expense
            ListTile(
              leading: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(Icons.account_balance_wallet_outlined,
                    color: Colors.grey.shade700, size: 20),
              ),
              title: const Text('Personal Expense',
                  style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
              subtitle: const Text('Track personal spending',
                  style: TextStyle(fontSize: 12)),
              onTap: () {
                Navigator.pop(context);
                _showPersonalExpenseDialog(
                    paymentNotification: paymentNotification);
              },
            ),

            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  void _showSharedExpenseDialog({PaymentNotification? paymentNotification}) {
    if (_roommates.isEmpty || _currentRoomspaceId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Join a roomspace first to add shared expenses'),
        ),
      );
      return;
    }

    AddExpenseDialog.show(
      context,
      roommates: _roommates,
      roomspaceId: _currentRoomspaceId!,
      paymentNotification: paymentNotification,
      onSubmit: _handleExpenseSubmission,
    );
  }

  void _showPersonalExpenseDialog({PaymentNotification? paymentNotification}) {
    PersonalExpenseDialog.show(
      context,
      paymentNotification: paymentNotification,
      onSubmit: (expense) async {
        try {
          final request = PersonalExpenseCreateRequest.fromExpenseData(expense);
          await _apiService.createPersonalExpense(request.toJson());
          await _refreshRecentExpenses();

          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                    'Added: ${expense.title} · Rs. ${expense.amount.toStringAsFixed(2)}'),
              ),
            );
          }
        } catch (e) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Failed to add expense: $e')),
            );
          }
        }
      },
    );
  }

  Future<void> _scanReceiptAndShowOptions() async {
    final result = await ReceiptScannerDialog.show(context);
    if (result != null && mounted) {
      _showScannedExpenseTypeDialog(result);
    }
  }

  void _showScannedExpenseTypeDialog(OcrScanResult scanResult) {
    final primaryColor = Theme.of(context).colorScheme.primary;

    // Build a payment notification from scan data so dialogs can auto-fill
    final notification = PaymentNotification(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      source: 'receipt_scan',
      appName: 'Receipt Scanner',
      rawText: scanResult.rawText,
      amount: scanResult.amount,
      merchant: scanResult.merchant,
      timestamp: DateTime.now(),
      type: PaymentType.debit,
    );

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
              decoration: BoxDecoration(
                color: Colors.grey.shade300,
                borderRadius: BorderRadius.circular(2),
              ),
            ),

            Padding(
              padding: const EdgeInsets.fromLTRB(20, 4, 20, 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.check_circle_outline_rounded,
                          color: Colors.green.shade600, size: 18),
                      const SizedBox(width: 8),
                      Text(
                        'Receipt Scanned',
                        style:
                            Theme.of(context).textTheme.titleMedium?.copyWith(
                                  fontWeight: FontWeight.w700,
                                ),
                      ),
                    ],
                  ),
                  if (scanResult.amount != null) ...[
                    const SizedBox(height: 10),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 10),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF7F7FB),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: const Color(0xFFEEEEF2)),
                      ),
                      child: Row(
                        children: [
                          Text(
                            'Rs. ${scanResult.amount!.toStringAsFixed(2)}',
                            style: const TextStyle(
                                fontSize: 18, fontWeight: FontWeight.w700),
                          ),
                          if (scanResult.merchant != null) ...[
                            const SizedBox(width: 8),
                            Text(
                              '· ${scanResult.merchant}',
                              style: TextStyle(
                                  fontSize: 13,
                                  color: Colors.grey.shade600),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),

            const Divider(height: 1),

            ListTile(
              leading: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(Icons.people_outlined,
                    color: Colors.grey.shade700, size: 20),
              ),
              title: const Text('Add as Shared Expense',
                  style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
              subtitle: const Text('Split with roommates',
                  style: TextStyle(fontSize: 12)),
              onTap: () {
                Navigator.pop(context);
                _showSharedExpenseDialog(paymentNotification: notification);
              },
            ),

            ListTile(
              leading: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(Icons.account_balance_wallet_outlined,
                    color: Colors.grey.shade700, size: 20),
              ),
              title: const Text('Add as Personal Expense',
                  style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
              subtitle: const Text('Track personal spending',
                  style: TextStyle(fontSize: 12)),
              onTap: () {
                Navigator.pop(context);
                _showPersonalExpenseDialog(paymentNotification: notification);
              },
            ),

            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  void _showExpenseDialogFromPayment(PaymentNotification notification) {
    final primaryColor = Theme.of(context).colorScheme.primary;
    _showExpenseOptions(context, primaryColor,
        paymentNotification: notification);
  }

  Future<void> _handleExpenseSubmission(ExpenseData expense) async {
    try {
      final request = ExpenseCreateRequest.fromExpenseData(
          expense, _currentRoomspaceId!);
      await _apiService.createExpense(request.toJson());
      await _refreshRecentExpenses();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text(
                  'Added: ${expense.title} · Rs. ${expense.amount.toStringAsFixed(2)}')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to add expense: $e')),
        );
      }
    }
  }

  // ──────────────────────────────────────────
  // BUILD
  // ──────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    final primaryColor = Theme.of(context).colorScheme.primary;

    return MobileScaffold(
      currentIndex: 0,
      showAppBar: false,
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Header ──
            _buildHeader(user, primaryColor),

            // ── Quick actions ──
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
              child: _buildQuickActions(primaryColor),
            ),

            // ── No roomspace prompt ──
            if (!_hasRoomspace && !_isLoading)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                child: _buildNoRoomspaceCard(primaryColor),
              ),

            // ── Recent Activity ──
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 20, 16, 0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Recent Activity',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF1A1A2E),
                    ),
                  ),
                  TextButton(
                    onPressed: () =>
                        Navigator.pushNamed(context, '/expenses'),
                    child: Text(
                      'View All',
                      style: TextStyle(
                          color: primaryColor,
                          fontSize: 13,
                          fontWeight: FontWeight.w600),
                    ),
                  ),
                ],
              ),
            ),

            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
              child: _buildRecentActivityList(primaryColor),
            ),
          ],
        ),
      ),
    );
  }

  // ──────────────────────────────────────────
  // HEADER
  // ──────────────────────────────────────────
  Widget _buildHeader(User? user, Color primaryColor) {
    final roomspaceProvider = Provider.of<RoomspaceProvider>(context);
    final isPersonalSpace = roomspaceProvider.isPersonalSpace;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(20, 56, 16, 20),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(bottom: BorderSide(color: Colors.grey.shade100)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Top row: greeting + controls
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Hello, ${user?.displayName?.split(' ').first ?? 'there'} 👋',
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF1A1A2E),
                      ),
                    ),
                    Text(
                      _greeting(),
                      style: TextStyle(
                          fontSize: 12, color: Colors.grey.shade500),
                    ),
                  ],
                ),
              ),
              // Roomspace switcher
              GlobalRoomspaceSelector(
                onRoomspaceChanged: () {
                  _checkRoomspace();
                  _loadRecentExpenses();
                },
              ),
              const SizedBox(width: 4),
              // Notification bell
              _buildNotificationButton(primaryColor),
            ],
          ),

          const SizedBox(height: 16),

          // Balance row — only in roomspace mode
          if (!isPersonalSpace) _buildBalanceRow(),
        ],
      ),
    );
  }

  Widget _buildNotificationButton(Color primaryColor) {
    return GestureDetector(
      onTap: () async {
        await Navigator.pushNamed(context, '/notifications');
        _loadUnreadCount();
      },
      child: Stack(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.grey.shade100,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(Icons.notifications_outlined,
                size: 20, color: Colors.grey.shade600),
          ),
          if (_unreadNotificationCount > 0)
            Positioned(
              right: 0,
              top: 0,
              child: Container(
                padding: const EdgeInsets.all(3),
                decoration: const BoxDecoration(
                  color: Color(0xFFD32F2F),
                  shape: BoxShape.circle,
                ),
                constraints:
                    const BoxConstraints(minWidth: 14, minHeight: 14),
                child: Text(
                  _unreadNotificationCount > 9
                      ? '9+'
                      : '$_unreadNotificationCount',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 8,
                    fontWeight: FontWeight.bold,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildBalanceRow() {
    return Row(
      children: [
        Expanded(child: _buildBalanceTile('You are owed', _youAreOwed, true)),
        const SizedBox(width: 10),
        Expanded(child: _buildBalanceTile('You owe', _youOwe, false)),
      ],
    );
  }

  Widget _buildBalanceTile(String label, double amount, bool isPositive) {
    final valueColor = isPositive
        ? const Color(0xFF2E7D32) // dark green
        : const Color(0xFFC62828); // dark red

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xFFF7F7FB),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFEEEEF2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label,
              style:
                  TextStyle(fontSize: 11, color: Colors.grey.shade500)),
          const SizedBox(height: 4),
          _isLoadingBalance
              ? SizedBox(
                  height: 22,
                  width: 22,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: valueColor,
                  ),
                )
              : Text(
                  'Rs. ${amount.round()}',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: valueColor,
                  ),
                ),
        ],
      ),
    );
  }

  // ──────────────────────────────────────────
  // QUICK ACTIONS
  // ──────────────────────────────────────────
  Widget _buildQuickActions(Color primaryColor) {
    return Column(
      children: [
        Row(
          children: [
            // Scan Receipt
            Expanded(
              child: _QuickActionCard(
                icon: Icons.document_scanner_outlined,
                label: 'Scan Receipt',
                onTap: _scanReceiptAndShowOptions,
              ),
            ),
            const SizedBox(width: 12),
            // Add Expense — primary colored
            Expanded(
              child: _QuickActionCard(
                icon: Icons.add_rounded,
                label: 'Add Expense',
                isPrimary: true,
                onTap: _showAddExpenseDialog,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        // View Analytics row
        InkWell(
          onTap: () => Navigator.pushNamed(context, '/analytics'),
          borderRadius: BorderRadius.circular(10),
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 14),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: const Color(0xFFEEEEF2)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.analytics_rounded,
                    color: primaryColor, size: 18),
                const SizedBox(width: 8),
                Text(
                  'View Analytics',
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                    color: primaryColor,
                  ),
                ),
                const SizedBox(width: 4),
                Icon(Icons.arrow_forward_rounded,
                    color: primaryColor, size: 16),
              ],
            ),
          ),
        ),
      ],
    );
  }

  // ──────────────────────────────────────────
  // NO ROOMSPACE CARD
  // ──────────────────────────────────────────
  Widget _buildNoRoomspaceCard(Color primaryColor) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.indigo.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.indigo.shade100),
      ),
      child: Row(
        children: [
          Icon(Icons.home_work_outlined, color: Colors.indigo.shade400),
          const SizedBox(width: 12),
          const Expanded(
            child: Text(
              'Create or join a room to split expenses with roommates.',
              style: TextStyle(fontSize: 13),
            ),
          ),
        ],
      ),
    );
  }

  // ──────────────────────────────────────────
  // RECENT ACTIVITY LIST
  // ──────────────────────────────────────────
  Widget _buildRecentActivityList(Color primaryColor) {
    if (_isLoadingExpenses) {
      return const Column(
        children: [
          SizedBox(height: 8),
          ExpenseListSkeleton(itemCount: 3),
          SizedBox(height: 100),
        ],
      );
    }

    if (_expensesError != null) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 32),
        child: Center(
          child: Column(
            children: [
              Icon(Icons.wifi_off_rounded,
                  size: 36, color: Colors.grey.shade300),
              const SizedBox(height: 10),
              Text(_expensesError!,
                  style: TextStyle(color: Colors.grey.shade500)),
              const SizedBox(height: 8),
              TextButton(
                onPressed: _refreshRecentExpenses,
                child: const Text('Retry'),
              ),
              const SizedBox(height: 100),
            ],
          ),
        ),
      );
    }

    // Merge shared + personal, sort by date
    final combined = <Map<String, dynamic>>[];
    for (final e in _recentExpenses) {
      combined.add({'type': 'shared', 'data': e, 'date': e.createdAt ?? DateTime.now()});
    }
    for (final e in _recentPersonalExpenses) {
      combined.add({'type': 'personal', 'data': e, 'date': e.createdAt ?? DateTime.now()});
    }
    combined.sort((a, b) =>
        (b['date'] as DateTime).compareTo(a['date'] as DateTime));
    final recent = combined.take(5).toList();

    if (recent.isEmpty) {
      return Padding(
        padding: const EdgeInsets.only(bottom: 100),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(28),
          decoration: BoxDecoration(
            color: const Color(0xFFF7F7FB),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xFFEEEEF2)),
          ),
          child: Column(
            children: [
              Icon(Icons.receipt_long_outlined,
                  size: 40, color: Colors.grey.shade300),
              const SizedBox(height: 12),
              const Text(
                'No expenses yet',
                style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF1A1A2E)),
              ),
              const SizedBox(height: 6),
              Text(
                'No expenses yet. Add your first expense to start tracking costs.',
                style: TextStyle(
                    fontSize: 12, color: Colors.grey.shade500),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      );
    }

    return Column(
      children: [
        ...recent.map((map) {
          if (map['type'] == 'shared') {
            return _buildSharedTile(map['data'] as ExpenseData);
          } else {
            return _buildPersonalTile(map['data'] as PersonalExpenseData);
          }
        }),
        const SizedBox(height: 100),
      ],
    );
  }

  // ──────────────────────────────────────────
  // EXPENSE TILES
  // ──────────────────────────────────────────
  Widget _buildSharedTile(ExpenseData expense) {
    final currentUser = FirebaseAuth.instance.currentUser;
    final isPaidByMe = expense.paidBy == currentUser?.uid;

    return _ExpenseTile(
      title: expense.title,
      subtitle: isPaidByMe ? 'You paid' : '${expense.payerName ?? 'Someone'} paid',
      amount: 'Rs. ${expense.amount.toStringAsFixed(0)}',
      amountColor: isPaidByMe ? const Color(0xFF2E7D32) : const Color(0xFFC62828),
      date: _formatDate(expense.createdAt),
      icon: Icons.receipt_long_outlined,
    );
  }

  Widget _buildPersonalTile(PersonalExpenseData expense) {
    return _ExpenseTile(
      title: expense.title,
      subtitle: expense.category,
      amount: 'Rs. ${expense.amount.toStringAsFixed(0)}',
      amountColor: const Color(0xFF1A1A2E),
      date: _formatDate(expense.createdAt),
      icon: Icons.account_balance_wallet_outlined,
    );
  }

  // ──────────────────────────────────────────
  // HELPERS
  // ──────────────────────────────────────────
  String _greeting() {
    final hour = DateTime.now().hour;
    if (hour < 12) return 'Good morning';
    if (hour < 17) return 'Good afternoon';
    return 'Good evening';
  }

  String _formatDate(DateTime? date) {
    if (date == null) return '';
    final diff = DateTime.now().difference(date);
    if (diff.inDays == 0) return 'Today';
    if (diff.inDays == 1) return 'Yesterday';
    if (diff.inDays < 7) return '${diff.inDays}d ago';
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
    ];
    return '${months[date.month - 1]} ${date.day}';
  }
}

// ══════════════════════════════════════════════════════════════════
// SHARED PRIVATE WIDGETS
// ══════════════════════════════════════════════════════════════════

/// A card button for Scan Receipt / Add Expense
class _QuickActionCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool isPrimary;

  const _QuickActionCard({
    required this.icon,
    required this.label,
    required this.onTap,
    this.isPrimary = false,
  });

  @override
  Widget build(BuildContext context) {
    final primaryColor = Theme.of(context).colorScheme.primary;
    final bg = isPrimary ? primaryColor : Colors.white;
    final fg = isPrimary ? Colors.white : const Color(0xFF1A1A2E);

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        height: 88,
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(12),
          border: isPrimary
              ? null
              : Border.all(color: const Color(0xFFEEEEF2)),
          boxShadow: isPrimary
              ? [
                  BoxShadow(
                    color: primaryColor.withValues(alpha: 0.3),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  )
                ]
              : null,
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: fg, size: 26),
            const SizedBox(height: 6),
            Text(
              label,
              style: TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: 13,
                color: fg,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// A single expense list tile
class _ExpenseTile extends StatelessWidget {
  final String title;
  final String subtitle;
  final String amount;
  final Color amountColor;
  final String date;
  final IconData icon;

  const _ExpenseTile({
    required this.title,
    required this.subtitle,
    required this.amount,
    required this.amountColor,
    required this.date,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFEEEEF2)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(9),
            decoration: BoxDecoration(
              color: const Color(0xFFF7F7FB),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, size: 18, color: Colors.grey.shade600),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                      fontWeight: FontWeight.w600, fontSize: 13),
                ),
                Text(
                  subtitle,
                  style: TextStyle(
                      fontSize: 11, color: Colors.grey.shade500),
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                amount,
                style: TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 13,
                  color: amountColor,
                ),
              ),
              Text(
                date,
                style: TextStyle(
                    fontSize: 10, color: Colors.grey.shade400),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
