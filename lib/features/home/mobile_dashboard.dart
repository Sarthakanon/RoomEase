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

class MobileDashboard extends StatefulWidget {
  const MobileDashboard({super.key});

  @override
  State<MobileDashboard> createState() => _MobileDashboardState();
}

class _MobileDashboardState extends State<MobileDashboard> {
  final ApiService _apiService = ApiService();
  final BalanceService _balanceService = BalanceService();
  bool _hasRoomspace = false;
  bool _isLoading = true;
  List<RoommateItem> _roommates = [];
  int _unreadNotificationCount = 0;
  String? _currentRoomspaceId;
  
  // Recent expenses state
  List<ExpenseData> _recentExpenses = [];
  List<PersonalExpenseData> _recentPersonalExpenses = [];
  bool _isLoadingExpenses = true;
  String? _expensesError;
  
  // Balance state
  double _youAreOwed = 0.0;
  double _youOwe = 0.0;
  bool _isLoadingBalance = false;

  @override
  void initState() {
    super.initState();
    _checkRoomspace();
    _loadUnreadCount();
    _loadBalance();
    _initializePaymentNotifications();
    
    // Listen to roomspace provider changes
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final roomspaceProvider = Provider.of<RoomspaceProvider>(context, listen: false);
      roomspaceProvider.addListener(_onRoomspaceChanged);
    });
  }
  
  @override
  void dispose() {
    // Remove listener when widget is disposed
    final roomspaceProvider = Provider.of<RoomspaceProvider>(context, listen: false);
    roomspaceProvider.removeListener(_onRoomspaceChanged);
    super.dispose();
  }
  
  /// Called when the active roomspace changes
  void _onRoomspaceChanged() {
    // Refresh data when roomspace changes
    _loadRecentExpenses();
    _loadBalance();
  }

  Future<void> _initializePaymentNotifications() async {
    try {
      debugPrint('🚀 Starting payment notification initialization...');
      final paymentService = PaymentNotificationService.instance;
      debugPrint('📱 Got payment service instance');
      
      await paymentService.initialize();
      debugPrint('✅ Payment service initialized');
      
      // Initialize background service
      await paymentService.initializeBackgroundService();
      debugPrint('🔧 Background service initialized');
      
      // Start background monitoring if enabled
      await paymentService.startBackgroundMonitoring();
      debugPrint('👂 Background monitoring started');
      
      // Set callback for when user wants to add expense from payment notification
      paymentService.onExpenseRequested = _showExpenseDialogFromPayment;
      debugPrint('🎯 Expense callback set');
      
      debugPrint('🎉 Payment notification initialization complete!');
    } catch (e) {
      debugPrint('💥 Error initializing payment notifications: $e');
    }
  }

  Future<void> _loadRecentExpenses() async {
    try {
      setState(() {
        _isLoadingExpenses = true;
        _expensesError = null;
      });
      
      // Get active roomspace from provider
      final roomspaceProvider = Provider.of<RoomspaceProvider>(context, listen: false);
      final activeRoomspaceId = roomspaceProvider.getActiveRoomspaceId();
      final isPersonalSpace = roomspaceProvider.isPersonalSpace;
      
      print('📊 Loading recent expenses for roomspace: $activeRoomspaceId (Personal Space: $isPersonalSpace)');
      
      // Load both shared and personal expenses concurrently
      final futures = <Future>[];
      
      // Load shared expenses ONLY if NOT in personal space
      if (!isPersonalSpace && activeRoomspaceId != null) {
        futures.add(_apiService.getRecentExpenses(roomspaceId: activeRoomspaceId, limit: 3));
      }
      
      // Always load personal expenses
      futures.add(_apiService.getPersonalExpenses(limit: 3, offset: 0));
      
      final results = await Future.wait(futures);
      
      List<ExpenseData> sharedExpenses = [];
      List<PersonalExpenseData> personalExpenses = [];
      
      int resultIndex = 0;
      
      // Process shared expenses if we loaded them
      if (!isPersonalSpace && activeRoomspaceId != null) {
        final sharedResponse = results[resultIndex++];
        print('📊 Shared expenses response: $sharedResponse');
        if (sharedResponse.containsKey('data')) {
          final data = sharedResponse['data'];
          if (data != null && data is List) {
            sharedExpenses = data
                .map((expense) => ExpenseData.fromJson(expense))
                .toList();
            print('✅ Loaded ${sharedExpenses.length} shared expenses');
          }
        }
      }
      
      // Process personal expenses
      final personalResponse = results[resultIndex];
      print('📊 Personal expenses response: $personalResponse');
      if (personalResponse.containsKey('data')) {
        final data = personalResponse['data'];
        if (data != null && data is List) {
          personalExpenses = data
              .map((expense) => PersonalExpenseData.fromJson(expense))
              .toList();
          print('✅ Loaded ${personalExpenses.length} personal expenses');
        }
      }
      
      if (mounted) {
        setState(() {
          _recentExpenses = sharedExpenses;
          _recentPersonalExpenses = personalExpenses;
          _isLoadingExpenses = false;
        });
      }
    } catch (e, stackTrace) {
      print('❌ Error loading recent expenses: $e');
      print('Stack trace: $stackTrace');
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
    await _loadBalance(); // Refresh balance when expenses change
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
      // Load roomspaces through the provider
      final roomspaceProvider = Provider.of<RoomspaceProvider>(context, listen: false);
      await roomspaceProvider.loadRoomspaces();
      
      // Get the active roomspace
      final activeRoomspace = roomspaceProvider.activeRoomspace;
      
      if (mounted) {
        setState(() {
          _hasRoomspace = activeRoomspace != null;
          _isLoading = false;
        });
      }
      
      // Load recent expenses after checking roomspace
      await _loadRecentExpenses();
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _loadBalance() async {
    setState(() {
      _isLoadingBalance = true;
    });

    try {
      final roomspaceProvider = Provider.of<RoomspaceProvider>(context, listen: false);
      final activeRoomspaceId = roomspaceProvider.getActiveRoomspaceId();
      final isPersonalSpace = roomspaceProvider.isPersonalSpace;
      final currentUser = FirebaseAuth.instance.currentUser;

      // Hide balance in personal space or if no roomspace
      if (isPersonalSpace || activeRoomspaceId == null || currentUser == null) {
        setState(() {
          _youAreOwed = 0.0;
          _youOwe = 0.0;
          _isLoadingBalance = false;
        });
        return;
      }

      // Fetch balance from API
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
      print('Error loading balance: $e');
      if (mounted) {
        setState(() {
          _youAreOwed = 0.0;
          _youOwe = 0.0;
          _isLoadingBalance = false;
        });
      }
    }
  }

  void _showAddExpenseDialog() {
    final primaryColor = Theme.of(context).colorScheme.primary;
    _showExpenseOptions(context, primaryColor);
  }
  void _showExpenseOptions(BuildContext context, Color primaryColor, {PaymentNotification? paymentNotification}) {
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
                  // Show payment notification info if available
                  if (paymentNotification != null) ...[
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
                              'Payment: Rs. ${paymentNotification.amount?.toStringAsFixed(2) ?? 'Unknown'} to ${paymentNotification.merchant ?? 'Unknown'}',
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
                ],
              ),
            ),
            
            // Options
            ListTile(
              leading: Icon(Icons.people, color: primaryColor),
              title: const Text('Add Shared Expense'),
              subtitle: const Text('Split with roommates'),
              onTap: () {
                Navigator.pop(context);
                _showSharedExpenseDialog(paymentNotification: paymentNotification);
              },
            ),
            ListTile(
              leading: Icon(Icons.account_balance_wallet, color: primaryColor),
              title: const Text('Add Personal Expense'),
              subtitle: const Text('Track personal spending'),
              onTap: () {
                Navigator.pop(context);
                _showPersonalExpenseDialog(paymentNotification: paymentNotification);
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
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    // Debug: Print roommates info
    print('DEBUG: Showing expense dialog with ${_roommates.length} roommates');
    for (var roommate in _roommates) {
      print('DEBUG: Roommate - ID: ${roommate.id}, Name: ${roommate.name}');
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
          // Create personal expense request
          final request = PersonalExpenseCreateRequest.fromExpenseData(expense);

          // Submit to API
          await _apiService.createPersonalExpense(request.toJson());

          // Refresh recent expenses to show the new personal expense
          await _refreshRecentExpenses();

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

  /// Scan receipt and show expense type selection with scanned data
  Future<void> _scanReceiptAndShowOptions() async {
    final result = await ReceiptScannerDialog.show(context);
    
    if (result != null && mounted) {
      // Show dialog to choose expense type with scanned data
      _showScannedExpenseTypeDialog(result);
    }
  }

  /// Show expense type selection dialog with scanned receipt data
  void _showScannedExpenseTypeDialog(OcrScanResult scanResult) {
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
            
            // Header with scanned info
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.check_circle, color: Colors.green, size: 24),
                      const SizedBox(width: 8),
                      Text(
                        'Receipt Scanned',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.grey[800],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.green.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.green.withValues(alpha: 0.3)),
                    ),
                    child: Column(
                      children: [
                        if (scanResult.amount != null)
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                'Rs. ${scanResult.amount!.toStringAsFixed(2)}',
                                style: TextStyle(
                                  fontSize: 24,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.green[800],
                                ),
                              ),
                            ],
                          ),
                        if (scanResult.merchant != null) ...[
                          const SizedBox(height: 4),
                          Text(
                            scanResult.merchant!,
                            style: TextStyle(
                              color: Colors.green[700],
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            ),
            
            // Options
            ListTile(
              leading: Icon(Icons.people, color: primaryColor),
              title: const Text('Add as Shared Expense'),
              subtitle: const Text('Split with roommates'),
              onTap: () {
                Navigator.pop(context);
                _showSharedExpenseDialogWithScan(scanResult);
              },
            ),
            ListTile(
              leading: Icon(Icons.account_balance_wallet, color: primaryColor),
              title: const Text('Add as Personal Expense'),
              subtitle: const Text('Track personal spending'),
              onTap: () {
                Navigator.pop(context);
                _showPersonalExpenseDialogWithScan(scanResult);
              },
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  /// Show shared expense dialog with scanned data pre-filled
  void _showSharedExpenseDialogWithScan(OcrScanResult scanResult) {
    if (_roommates.isEmpty || _currentRoomspaceId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Join a roomspace first to add shared expenses'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    // Create a payment notification from scan result to use auto-fill
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

    AddExpenseDialog.show(
      context,
      roommates: _roommates,
      roomspaceId: _currentRoomspaceId!,
      paymentNotification: notification,
      onSubmit: _handleExpenseSubmission,
    );
  }

  /// Show personal expense dialog with scanned data pre-filled
  void _showPersonalExpenseDialogWithScan(OcrScanResult scanResult) {
    // Create a payment notification from scan result to use auto-fill
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

    PersonalExpenseDialog.show(
      context,
      paymentNotification: notification,
      onSubmit: (expense) async {
        try {
          final request = PersonalExpenseCreateRequest.fromExpenseData(expense);
          await _apiService.createPersonalExpense(request.toJson());
          await _refreshRecentExpenses();

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

  void _showExpenseDialogFromPayment(PaymentNotification notification) {
    final primaryColor = Theme.of(context).colorScheme.primary;
    _showExpenseOptions(context, primaryColor, paymentNotification: notification);
  }

  Future<void> _handleExpenseSubmission(ExpenseData expense) async {
    try {
      // Create expense request
      final request = ExpenseCreateRequest.fromExpenseData(
        expense,
        _currentRoomspaceId!,
      );

      // Submit to API
      await _apiService.createExpense(request.toJson());

      // Refresh recent expenses to show the new expense
      await _refreshRecentExpenses();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Added: ${expense.title} - Rs. ${expense.amount.toStringAsFixed(2)}',
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
  }

  @override
  Widget build(BuildContext context) {
    // 1. Get current user
    final user = FirebaseAuth.instance.currentUser;
    // 2. Use theme colors
    final Color primaryColor = Theme.of(context).colorScheme.primary;

    return MobileScaffold(
      currentIndex: 0,
      showAppBar: false, // Disable AppBar for home screen
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
                      // User greeting - flexible to shrink if needed
                      Flexible(
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              'Hi, ',
                              style: TextStyle(
                                color: Colors.white.withValues(alpha: 0.8),
                                fontSize: 14,
                              ),
                            ),
                            Flexible(
                              child: Text(
                                user?.displayName ?? 'User',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                ),
                                overflow: TextOverflow.ellipsis,
                                maxLines: 1,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      // Right side controls - shrink if needed
                      Flexible(
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            // Global Roomspace Selector
                            Flexible(
                              child: GlobalRoomspaceSelector(
                                onRoomspaceChanged: () {
                                  // Reload dashboard data
                                  _checkRoomspace();
                                  _loadRecentExpenses();
                                },
                              ),
                            ),
                            const SizedBox(width: 12),
                            // Notification Icon
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
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  // Balance section - responsive font sizes
                  LayoutBuilder(
                    builder: (context, constraints) {
                      final screenWidth = constraints.maxWidth;
                      final balanceFontSize = screenWidth < 320 ? 24.0 : 32.0;
                      final labelFontSize = screenWidth < 320 ? 11.0 : 13.0;
                      
                      return Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'You are owed',
                                  style: TextStyle(
                                    color: Colors.white.withValues(alpha: 0.8),
                                    fontSize: labelFontSize,
                                  ),
                                ),
                                const SizedBox(height: 6),
                                _isLoadingBalance
                                  ? SizedBox(
                                      height: balanceFontSize,
                                      child: const CircularProgressIndicator(
                                        color: Colors.greenAccent,
                                        strokeWidth: 2,
                                      ),
                                    )
                                  : Text(
                                      'Rs. ${_youAreOwed.round()}',
                                      style: TextStyle(
                                        color: Colors.greenAccent,
                                        fontSize: balanceFontSize,
                                        fontWeight: FontWeight.w900,
                                      ),
                                      overflow: TextOverflow.ellipsis,
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
                                    fontSize: labelFontSize,
                                  ),
                                ),
                                const SizedBox(height: 6),
                                _isLoadingBalance
                                  ? SizedBox(
                                      height: balanceFontSize,
                                      child: const CircularProgressIndicator(
                                        color: Colors.redAccent,
                                        strokeWidth: 2,
                                      ),
                                    )
                                  : Text(
                                      'Rs. ${_youOwe.round()}',
                                      style: TextStyle(
                                        color: Colors.redAccent,
                                        fontSize: balanceFontSize,
                                        fontWeight: FontWeight.w900,
                                      ),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                              ],
                            ),
                          ),
                        ],
                      );
                    },
                  ),
                ],
              ),
            ),

            // FIXED: Action Buttons - Responsive
            Padding(
              padding: EdgeInsets.all(MediaQuery.of(context).size.width < 360 ? 16 : 20),
              child: Column(
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: InkWell(
                          onTap: _scanReceiptAndShowOptions,
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
                  const SizedBox(height: 15),
                  // View Analytics Button
                  InkWell(
                    onTap: () {
                      Navigator.pushNamed(context, '/analytics');
                    },
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            primaryColor.withValues(alpha: 0.1),
                            primaryColor.withValues(alpha: 0.05),
                          ],
                          begin: Alignment.centerLeft,
                          end: Alignment.centerRight,
                        ),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: primaryColor.withValues(alpha: 0.3),
                          width: 1.5,
                        ),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.analytics_rounded,
                            color: primaryColor,
                            size: 24,
                          ),
                          const SizedBox(width: 12),
                          Text(
                            "View Analytics",
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                              color: primaryColor,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Icon(
                            Icons.arrow_forward_rounded,
                            color: primaryColor,
                            size: 20,
                          ),
                        ],
                      ),
                    ),
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
              padding: EdgeInsets.symmetric(
                horizontal: MediaQuery.of(context).size.width < 360 ? 16 : 20,
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    "Recent Activity",
                    style: TextStyle(
                      fontSize: MediaQuery.of(context).size.width < 360 ? 16 : 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.grey[800],
                    ),
                  ),
                  TextButton(
                    onPressed: () {
                      Navigator.pushNamed(context, '/expenses');
                    },
                    child: Text(
                      'View All',
                      style: TextStyle(
                        color: primaryColor,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 10),

            // ---------------------------------------------
            // RECENT ACTIVITY LIST
            // ---------------------------------------------
            Padding(
              padding: EdgeInsets.symmetric(
                horizontal: MediaQuery.of(context).size.width < 360 ? 16 : 20,
              ),
              child: _buildRecentActivityList(primaryColor),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRecentActivityList(Color primaryColor) {
    if (_isLoadingExpenses) {
      return const Column(
        children: [
          SizedBox(height: 20),
          ExpenseListSkeleton(itemCount: 3),
          SizedBox(height: 20),
        ],
      );
    }

    if (_expensesError != null) {
      return Column(
        children: [
          const SizedBox(height: 20),
          Icon(
            Icons.error_outline,
            color: Colors.red[300],
            size: 48,
          ),
          const SizedBox(height: 10),
          Text(
            _expensesError!,
            style: TextStyle(color: Colors.red[600]),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 10),
          TextButton(
            onPressed: _refreshRecentExpenses,
            child: Text(
              'Retry',
              style: TextStyle(color: primaryColor),
            ),
          ),
          const SizedBox(height: 100),
        ],
      );
    }

    // Combine and sort both shared and personal expenses by date
    final combinedExpenses = <Map<String, dynamic>>[];
    
    // Add shared expenses
    for (final expense in _recentExpenses) {
      combinedExpenses.add({
        'type': 'shared',
        'data': expense,
        'date': expense.createdAt ?? DateTime.now(),
      });
    }
    
    // Add personal expenses
    for (final expense in _recentPersonalExpenses) {
      combinedExpenses.add({
        'type': 'personal',
        'data': expense,
        'date': expense.createdAt ?? DateTime.now(),
      });
    }
    
    // Sort by date (most recent first)
    combinedExpenses.sort((a, b) => (b['date'] as DateTime).compareTo(a['date'] as DateTime));
    
    // Take only the most recent 5 expenses
    final recentExpenses = combinedExpenses.take(5).toList();

    if (recentExpenses.isEmpty) {
      return Column(
        children: [
          const SizedBox(height: 20),
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Colors.grey[50],
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.grey[200]!),
            ),
            child: Column(
              children: [
                Icon(
                  Icons.receipt_long_outlined,
                  color: Colors.grey[400],
                  size: 48,
                ),
                const SizedBox(height: 12),
                Text(
                  'No expenses yet',
                  style: TextStyle(
                    color: Colors.grey[700],
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'Add your first expense to start tracking costs',
                  style: TextStyle(
                    color: Colors.grey[500],
                    fontSize: 14,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),
                ElevatedButton.icon(
                  onPressed: _showAddExpenseDialog,
                  icon: const Icon(Icons.add, size: 18),
                  label: const Text('Add Expense'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: primaryColor,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 10,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    elevation: 1,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 100), // Extra space for bottom nav
        ],
      );
    }

    return Column(
      children: [
        ...recentExpenses.map((expenseMap) {
          final type = expenseMap['type'] as String;
          final data = expenseMap['data'];
          
          if (type == 'shared') {
            return _buildExpenseTile(data as ExpenseData, primaryColor);
          } else {
            return _buildPersonalExpenseTile(data as PersonalExpenseData, primaryColor);
          }
        }),
        const SizedBox(height: 100), // Extra space for bottom nav
      ],
    );
  }

  Widget _buildExpenseTile(ExpenseData expense, Color primaryColor) {
    final currentUser = FirebaseAuth.instance.currentUser;
    final isPaidByCurrentUser = expense.paidBy == currentUser?.uid;
    final formattedDate = _formatExpenseDate(expense.createdAt);

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
                  expense.title,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
                Text(
                  isPaidByCurrentUser 
                      ? "You paid" 
                      : "${expense.payerName ?? 'Someone'} paid",
                  style: TextStyle(color: Colors.grey[500], fontSize: 12),
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                "Rs. ${expense.amount.toStringAsFixed(2)}",
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                  color: isPaidByCurrentUser 
                      ? const Color(0xFF10B981) 
                      : Colors.redAccent,
                ),
              ),
              Text(
                formattedDate,
                style: TextStyle(color: Colors.grey[400], fontSize: 12),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildPersonalExpenseTile(PersonalExpenseData expense, Color primaryColor) {
    final formattedDate = _formatExpenseDate(expense.createdAt);

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
              color: Colors.orange.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(Icons.account_balance_wallet, color: Colors.orange),
          ),
          const SizedBox(width: 15),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  expense.title,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
                Text(
                  "Personal expense",
                  style: TextStyle(color: Colors.grey[500], fontSize: 12),
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                "Rs. ${expense.amount.toStringAsFixed(2)}",
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                  color: Colors.orange,
                ),
              ),
              Text(
                formattedDate,
                style: TextStyle(color: Colors.grey[400], fontSize: 12),
              ),
            ],
          ),
        ],
      ),
    );
  }

  String _formatExpenseDate(DateTime? date) {
    if (date == null) return 'Unknown';
    
    final now = DateTime.now();
    final difference = now.difference(date);
    
    if (difference.inDays == 0) {
      return 'Today';
    } else if (difference.inDays == 1) {
      return 'Yesterday';
    } else if (difference.inDays < 7) {
      return '${difference.inDays} days ago';
    } else {
      // Format as "Oct 24"
      const months = [
        'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
        'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
      ];
      return '${months[date.month - 1]} ${date.day}';
    }
  }

}
