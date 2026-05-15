import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:provider/provider.dart';
import '../../core/widgets/mobile_scaffold.dart';
import '../../core/widgets/global_roomspace_selector.dart';
import '../../core/widgets/skeleton_loader.dart';
import '../../core/mixins/auto_refresh_mixin.dart';
import '../../services/smart_api_service.dart';
import '../../services/state_management_service.dart';
import '../../services/payment_notification_service.dart';
import '../../services/ocr_service.dart';
import '../../services/real_time_data_service.dart';
import 'dart:async';
import '../../models/payment_notification.dart';
import '../../models/expense_models.dart';
import '../../providers/roomspace_provider.dart';
import 'widgets/add_expense_dialog.dart';
import 'widgets/personal_expense_dialog.dart';
import 'widgets/receipt_scanner_dialog.dart';
import 'widgets/balance_details_dialog.dart';
import '../expenses/presentation/expense_history_screen.dart';

/// Home dashboard — shows balance summary, quick actions, and recent expenses.
class MobileDashboard extends StatefulWidget {
  const MobileDashboard({super.key});

  @override
  State<MobileDashboard> createState() => _MobileDashboardState();
}

class _MobileDashboardState extends State<MobileDashboard>
    with WidgetsBindingObserver, AutomaticKeepAliveClientMixin, AutoRefreshMixin {
  final SmartApiService _smartApi = SmartApiService();
  final StateManagementService _state = StateManagementService();
  final RealTimeDataService _realTimeService = RealTimeDataService();

  @override
  bool get wantKeepAlive => true; // Keep state alive when switching tabs

  List<RoommateItem> _roommates = [];
  String? _currentRoomspaceId;
  
  // Cache dashboard data to prevent reloading
  Map<String, dynamic>? _cachedDashboardData;
  DateTime? _lastDataLoad;
  static const Duration _cacheValidDuration = Duration(minutes: 5);
  
  // Add a flag to track if we're currently loading
  bool _isLoading = false;
  Future<Map<String, dynamic>>? _currentFuture;
  
  // Stream subscriptions for real-time updates
  StreamSubscription<ExpenseUpdateEvent>? _expenseUpdateSubscription;
  StreamSubscription<BalanceUpdateEvent>? _balanceUpdateSubscription;
  StreamSubscription<NotificationEvent>? _notificationUpdateSubscription;
  RoomspaceProvider? _roomspaceProvider;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _initializePaymentNotifications();
    
    // Preload common data with extended cache
    _smartApi.preloadCommonData();

    // Listen for roomspace changes
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _roomspaceProvider = Provider.of<RoomspaceProvider>(context, listen: false);
      _roomspaceProvider?.addListener(_onRoomspaceChanged);
      
      // Set up real-time listeners for auto-refresh
      _setupRealTimeListeners();
    });
  }
  
  void _setupRealTimeListeners() {
    debugPrint('🔄 Dashboard: Setting up real-time listeners');
    
    // Listen for expense updates (both shared and personal)
    _expenseUpdateSubscription = _realTimeService.expenseUpdates.listen((event) {
      debugPrint('🔄 Dashboard: Expense update received: ${event.type}');
      
      // Check if this update affects current roomspace
      final currentRoomspaceId = _roomspaceProvider?.getActiveRoomspaceId();
      
      if (event.type == ExpenseUpdateType.clearCache ||
          event.roomspaceId == currentRoomspaceId ||
          event.type == ExpenseUpdateType.personalCreated) {
        // Clear cache and refresh dashboard
        debugPrint('🔄 Dashboard: Clearing cache and refreshing');
        _cachedDashboardData = null;
        _lastDataLoad = null;
        
        if (mounted) {
          setState(() {}); // Trigger rebuild with fresh data
        }
      }
    });

    // Listen for balance updates
    _balanceUpdateSubscription = _realTimeService.balanceUpdates.listen((event) {
      debugPrint('🔄 Dashboard: Balance update received: ${event.type}');
      
      final currentRoomspaceId = _roomspaceProvider?.getActiveRoomspaceId();
      
      if (event.type == BalanceUpdateType.clearCache ||
          event.roomspaceId == currentRoomspaceId) {
        // Clear cache and refresh dashboard
        debugPrint('🔄 Dashboard: Clearing cache and refreshing balances');
        _cachedDashboardData = null;
        _lastDataLoad = null;
        
        if (mounted) {
          setState(() {}); // Trigger rebuild
        }
      }
    });

    // Listen for notification updates (mark read / mark all read)
    _notificationUpdateSubscription = _realTimeService.notifications.listen((event) async {
      if (!mounted) return;
      if (event.type == NotificationType.notificationsUpdated ||
          event.type == NotificationType.profileUpdated) {
        _cachedDashboardData = null;
        _lastDataLoad = null;
        _state.forceRefresh(ScreenKeys.dashboard);
        await _loadDashboardData(forceRefresh: true);
        if (mounted) setState(() {});
      }
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _roomspaceProvider?.removeListener(_onRoomspaceChanged);
    
    // Cancel real-time subscriptions
    _expenseUpdateSubscription?.cancel();
    _balanceUpdateSubscription?.cancel();
    _notificationUpdateSubscription?.cancel();
    
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Smart refresh when app comes back from background
    if (state == AppLifecycleState.resumed) {
      // Only refresh if cache is old
      if (_lastDataLoad == null || 
          DateTime.now().difference(_lastDataLoad!) > _cacheValidDuration) {
        _smartApi.preloadCommonData();
      }
    }
  }

  /// Called automatically when the active roomspace changes
  void _onRoomspaceChanged() {
    // Clear cached data when roomspace changes
    _cachedDashboardData = null;
    _lastDataLoad = null;
    
    // Force refresh dashboard when roomspace changes
    _state.forceRefresh(ScreenKeys.dashboard);
    setState(() {}); // Trigger rebuild to refresh UI
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

  /// Smart data loader for dashboard with aggressive caching
  Future<Map<String, dynamic>> _loadDashboardData({bool forceRefresh = false}) async {
    final shouldForceByState = _state.needsRefresh(ScreenKeys.dashboard);
    final effectiveForceRefresh = forceRefresh || shouldForceByState;

    // Return cached data if valid and not forcing refresh
    if (!effectiveForceRefresh && 
        _cachedDashboardData != null && 
        _lastDataLoad != null &&
        DateTime.now().difference(_lastDataLoad!) < _cacheValidDuration) {
      debugPrint('🚀 Using cached dashboard data');
      return _cachedDashboardData!;
    }

    // If we're already loading, return the current future
    if (_isLoading && _currentFuture != null) {
      debugPrint('⏳ Dashboard already loading, returning existing future');
      return _currentFuture!;
    }

    debugPrint('🌐 Loading fresh dashboard data...');
    _isLoading = true;
    
    _currentFuture = _performDataLoad(effectiveForceRefresh);
    
    try {
      final result = await _currentFuture!;
      _isLoading = false;
      return result;
    } catch (e) {
      _isLoading = false;
      rethrow;
    }
  }

  Future<Map<String, dynamic>> _performDataLoad(bool forceRefresh) async {
    final roomspaceProvider = Provider.of<RoomspaceProvider>(context, listen: false);
    final activeRoomspaceId = roomspaceProvider.getActiveRoomspaceId();
    final isPersonalSpace = roomspaceProvider.isPersonalSpace;
    final hasAnyRoomspaces = roomspaceProvider.roomspaces.isNotEmpty; // Check if user has any roomspaces

    // Load data in parallel with extended cache times
    final futures = <String, Future<Map<String, dynamic>>>{};
    
    // Always load notifications, profile, and personal expenses
    futures['notifications'] = _smartApi.getNotifications(forceRefresh: forceRefresh);
    futures['userProfile'] = _smartApi.getUserProfile(forceRefresh: forceRefresh);
    futures['personalExpenses'] = _smartApi.getPersonalExpenses(limit: 3, offset: 0, forceRefresh: forceRefresh);
    futures['personalExpensesMonthly'] = _smartApi.getPersonalExpenses(
      limit: 500,
      offset: 0,
      month: DateTime(DateTime.now().year, DateTime.now().month, 1),
      forceRefresh: forceRefresh,
    );
    
    // Load roomspace-specific data if in a roomspace
    if (!isPersonalSpace && activeRoomspaceId != null) {
      futures['roomspaceExpenses'] = _smartApi.getRoomspaceExpenses(activeRoomspaceId, limit: 3, forceRefresh: forceRefresh);
      futures['balances'] = _smartApi.getRoomspaceBalances(activeRoomspaceId, forceRefresh: forceRefresh);
      futures['members'] = _smartApi.getRoomspaceMembers(activeRoomspaceId, forceRefresh: forceRefresh);
    }

    // Wait for all data to load
    final results = <String, Map<String, dynamic>>{};
    for (final entry in futures.entries) {
      try {
        results[entry.key] = await entry.value;
      } catch (e) {
        debugPrint('Error loading ${entry.key}: $e');
        results[entry.key] = {'data': [], 'error': e.toString()};
      }
    }

    final dashboardData = {
      'roomspaceId': activeRoomspaceId,
      'isPersonalSpace': isPersonalSpace,
      'hasRoomspace': hasAnyRoomspaces, // Use hasAnyRoomspaces instead of activeRoomspaceId != null
      ...results,
    };

    // Cache the data
    _cachedDashboardData = dashboardData;
    _lastDataLoad = DateTime.now();
    _state.markRefreshed(ScreenKeys.dashboard);
    debugPrint('💾 Dashboard data cached at $_lastDataLoad');

    return dashboardData;
  }

  // ──────────────────────────────────────────
  // ADD EXPENSE HELPERS
  // ──────────────────────────────────────────

  void _showAddExpenseDialog() {
    final primaryColor = Theme.of(context).colorScheme.primary;
    final roomspaceProvider = Provider.of<RoomspaceProvider>(context, listen: false);
    
    // If in personal space, directly show personal expense dialog
    if (roomspaceProvider.isPersonalSpace) {
      _showPersonalExpenseDialog();
      return;
    }
    
    // Otherwise, show the expense type selection dialog
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

  Future<void> _showSharedExpenseDialog({PaymentNotification? paymentNotification}) async {
    final roomspaceProvider =
        Provider.of<RoomspaceProvider>(context, listen: false);
    final activeRoomspaceId = roomspaceProvider.getActiveRoomspaceId();
    final isPersonalSpace = roomspaceProvider.isPersonalSpace;

    // Check if user is in a real roomspace (not personal space)
    if (isPersonalSpace || activeRoomspaceId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Join a roomspace first to add shared expenses'),
        ),
      );
      return;
    }

    // If roommates haven't loaded yet or roomspace changed, load them
    if (_roommates.isEmpty || _currentRoomspaceId != activeRoomspaceId) {
      try {
        // Show loading indicator
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Loading roomspace members...'),
              duration: Duration(seconds: 1),
            ),
          );
        }

        final response = await _smartApi.getRoomspaceMembers(activeRoomspaceId);
        
        if (response['success'] == true && response['data'] != null) {
          final members = response['data'] as List;
          _roommates = members
              .map((m) {
                // Extract user name from nested user object or fallback to direct fields
                String userName = 'Unknown';
                if (m['user'] != null && m['user']['name'] != null) {
                  userName = m['user']['name'];
                } else if (m['user_name'] != null) {
                  userName = m['user_name'];
                } else if (m['name'] != null) {
                  userName = m['name'];
                }
                
                return RoommateItem(
                  id: m['user_id'] ?? '',
                  name: userName,
                );
              })
              .toList();
          _currentRoomspaceId = activeRoomspaceId;
          
          // Allow adding expense even with just one member (yourself)
          // This is useful for tracking expenses before others join
        } else {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Failed to load members: ${response['message'] ?? 'Unknown error'}'),
              ),
            );
          }
          return;
        }
      } catch (e) {
        debugPrint('Error loading roommates: $e');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error loading members: ${e.toString()}'),
            ),
          );
        }
        return;
      }
    }

    // Show the dialog with loaded roommates (even if it's just you)
    if (mounted) {
      AddExpenseDialog.show(
        context,
        roommates: _roommates,
        roomspaceId: _currentRoomspaceId!,
        paymentNotification: paymentNotification,
        onSubmit: _handleExpenseSubmission,
      );
    }
  }

  void _showPersonalExpenseDialog({PaymentNotification? paymentNotification}) {
    PersonalExpenseDialog.show(
      context,
      paymentNotification: paymentNotification,
      onSubmit: (expense) async {
        try {
          final request = PersonalExpenseCreateRequest.fromExpenseData(expense);
          await _smartApi.createPersonalExpense(request.toJson());

          // Clear cache and trigger immediate refresh
          _cachedDashboardData = null;
          _lastDataLoad = null;
          
          // Notify real-time service to update all listeners
          _realTimeService.notifyPersonalExpenseCreated(expense.toJson());
          
          if (mounted) {
            setState(() {}); // Trigger rebuild
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
    await performOperationWithRefresh(
      () async {
        final request = ExpenseCreateRequest.fromExpenseData(
            expense, _currentRoomspaceId!);
        
        // Debug: Log the request data
        debugPrint('Creating expense with paid_by: ${request.paidBy}');
        debugPrint('Request JSON: ${request.toJson()}');
        
        await _smartApi.createExpense(request.toJson());
        
        // Clear cache and trigger immediate refresh
        _cachedDashboardData = null;
        _lastDataLoad = null;
        
        // Notify real-time service to update all listeners
        _realTimeService.notifyExpenseCreated(
          _currentRoomspaceId!,
          expense.toJson(),
        );
      },
      successMessage: 'Added: ${expense.title} · Rs. ${expense.amount.toStringAsFixed(2)}',
      errorMessage: 'Failed to add expense',
    );
  }

  @override
  Future<void> refreshData() async {
    // Clear cached data to force refresh
    _cachedDashboardData = null;
    _lastDataLoad = null;
    if (mounted) {
      setState(() {}); // Trigger rebuild with fresh data
    }
  }

  // ──────────────────────────────────────────
  // BUILD
  // ──────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    super.build(context); // Required for AutomaticKeepAliveClientMixin
    
    final user = FirebaseAuth.instance.currentUser;
    final primaryColor = Theme.of(context).colorScheme.primary;

    return MobileScaffold(
      currentIndex: 0,
      showAppBar: false,
      showBottomNav: false, // Hide bottom nav since MainNavigation handles it
      body: FutureBuilder<Map<String, dynamic>>(
        future: _loadDashboardData(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return _buildErrorState(primaryColor);
          }
          
          if (snapshot.hasData) {
            return RefreshIndicator(
              onRefresh: () async {
                _cachedDashboardData = null;
                _lastDataLoad = null;
                setState(() {}); // Trigger rebuild with fresh data
              },
              child: _buildDashboardContent(context, snapshot.data!, user, primaryColor),
            );
          }
          
          return _buildLoadingSkeleton();
        },
      ),
    );
  }

  Widget _buildErrorState(Color primaryColor) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.wifi_off_rounded, size: 48, color: Colors.grey.shade300),
            const SizedBox(height: 16),
            const Text(
              'Couldn\'t load dashboard',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: Color(0xFF1A1A2E),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Please try again',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey.shade500, fontSize: 13),
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: () {
                _cachedDashboardData = null;
                _lastDataLoad = null;
                setState(() {}); // Trigger rebuild
              },
              child: const Text('Try Again'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDashboardContent(
    BuildContext context,
    Map<String, dynamic> dashboardData,
    User? user,
    Color primaryColor,
  ) {
    Map<String, dynamic> asStringKeyedMap(dynamic value) {
      if (value is Map<String, dynamic>) return value;
      if (value is Map) return Map<String, dynamic>.from(value);
      return <String, dynamic>{};
    }

    final isPersonalSpace = dashboardData['isPersonalSpace'] as bool? ?? true;
    final hasRoomspace = dashboardData['hasRoomspace'] as bool? ?? false;
    final roomspaceId = dashboardData['roomspaceId'] as String?;
    
    // Extract data with better null safety
    final notifications = asStringKeyedMap(dashboardData['notifications']);
    final personalExpenses = asStringKeyedMap(dashboardData['personalExpenses']);
    final roomspaceExpenses = asStringKeyedMap(dashboardData['roomspaceExpenses']);
    final balances = asStringKeyedMap(dashboardData['balances']);
    final members = asStringKeyedMap(dashboardData['members']);
    final personalExpensesMonthly = asStringKeyedMap(dashboardData['personalExpensesMonthly']);
    final userProfile = asStringKeyedMap(dashboardData['userProfile']);
    final userProfileData = asStringKeyedMap(userProfile['data']);
    final backendUserName = userProfileData['name'] as String?;

    final monthlyPersonalList = personalExpensesMonthly['data'] as List<dynamic>? ?? [];
    final personalMonthlyTotal = monthlyPersonalList.fold<double>(0.0, (sum, item) {
      if (item is Map && item['amount'] is num) {
        return sum + (item['amount'] as num).toDouble();
      }
      return sum;
    });

    // Calculate unread notifications
    final notificationsList = notifications['data'] as List<dynamic>? ?? [];
    final unreadCount = notificationsList.where((n) => n['is_read'] != true).length;

    // Update local state for dialogs
    _currentRoomspaceId = roomspaceId;
    
    // Safely process members data
    _roommates = [];
    if (members.containsKey('data') && members['data'] is List) {
      final membersList = members['data'] as List<dynamic>;
      _roommates = membersList
          .map((m) {
            if (m is! Map<String, dynamic>) return null;
            
            String userName = 'Unknown';
            if (m['user'] != null && m['user']['name'] != null) {
              userName = m['user']['name'];
            } else if (m['user_name'] != null) {
              userName = m['user_name'];
            } else if (m['name'] != null) {
              userName = m['name'];
            }
            
            return RoommateItem(
              id: m['user_id']?.toString() ?? '',
              name: userName,
            );
          })
          .where((item) => item != null)
          .cast<RoommateItem>()
          .toList();
    }

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Header ──
          _buildHeader(
            user,
            backendUserName,
            primaryColor,
            isPersonalSpace,
            balances,
            unreadCount,
            personalMonthlyTotal,
          ),

          // ── Quick actions ──
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
            child: _buildQuickActions(primaryColor),
          ),

          // ── No roomspace prompt ──
          if (!hasRoomspace) ...[
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
              child: _buildNoRoomspaceCard(primaryColor),
            ),
          ],

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
                Row(
                  children: [
                    TextButton.icon(
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => const ExpenseHistoryScreen(),
                          ),
                        );
                      },
                      icon: Icon(
                        Icons.history_rounded,
                        size: 18,
                        color: primaryColor,
                      ),
                      label: Text(
                        'History',
                        style: TextStyle(
                          color: primaryColor,
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      style: TextButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 8),
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
              ],
            ),
          ),

          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
            child: _buildRecentActivityList(primaryColor, personalExpenses, roomspaceExpenses),
          ),
        ],
      ),
    );
  }

  Widget _buildLoadingSkeleton() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          // Header skeleton
          const SizedBox(height: 56),
          const SkeletonLoader(height: 80, borderRadius: BorderRadius.all(Radius.circular(12))),
          const SizedBox(height: 20),
          
          // Balance cards skeleton
          Row(
            children: [
              Expanded(child: const SkeletonLoader(height: 100, borderRadius: BorderRadius.all(Radius.circular(12)))),
              const SizedBox(width: 12),
              Expanded(child: const SkeletonLoader(height: 100, borderRadius: BorderRadius.all(Radius.circular(12)))),
            ],
          ),
          const SizedBox(height: 20),
          
          // Quick actions skeleton
          const SkeletonLoader(height: 120, borderRadius: BorderRadius.all(Radius.circular(12))),
          const SizedBox(height: 20),
          
          // Recent expenses skeleton
          ...List.generate(3, (index) => Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: const SkeletonLoader(height: 70, borderRadius: BorderRadius.all(Radius.circular(12))),
          )),
        ],
      ),
    );
  }

  // ──────────────────────────────────────────
  // HEADER
  // ──────────────────────────────────────────
  Widget _buildHeader(
    User? user,
    String? backendUserName,
    Color primaryColor,
    bool isPersonalSpace,
    Map<String, dynamic> balances,
    int unreadCount,
    double personalMonthlyTotal,
  ) {
    // Debug logging for balance data
    debugPrint('🏠 Header - isPersonalSpace: $isPersonalSpace');
    debugPrint('💰 Balance data received: $balances');

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
                      'Hello, ${(backendUserName ?? user?.displayName)?.split(' ').first ?? 'there'} 👋',
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
                  // Force refresh dashboard when roomspace changes
                  _state.forceRefresh(ScreenKeys.dashboard);
                  setState(() {});
                },
              ),
              const SizedBox(width: 4),
              // Notification bell
              _buildNotificationButton(primaryColor, unreadCount),
            ],
          ),

          const SizedBox(height: 16),

          // Balance row — only in roomspace mode
          if (!isPersonalSpace)
            _buildBalanceRow(balances)
          else
            _buildPersonalMonthTotalCard(primaryColor, personalMonthlyTotal),
        ],
      ),
    );
  }

  Widget _buildNotificationButton(Color primaryColor, int unreadCount) {
    return GestureDetector(
      onTap: () async {
        await Navigator.pushNamed(context, '/notifications');
        // Hard refresh dashboard to update notification badge immediately
        _cachedDashboardData = null;
        _lastDataLoad = null;
        _state.forceRefresh(ScreenKeys.dashboard);
        await _loadDashboardData(forceRefresh: true);
        if (mounted) {
          setState(() {});
        }
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
          if (unreadCount > 0)
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
                  unreadCount > 9 ? '9+' : '$unreadCount',
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

  Widget _buildBalanceRow(Map<String, dynamic> balances) {
    // Debug logging for balance data
    debugPrint('🔍 Raw balance response: $balances');
    
    // Extract balance data - handle the new response structure
    dynamic balanceData = balances['data'];
    debugPrint('🔍 Balance data extracted: $balanceData');
    
    // Initialize default values
    double youOwe = 0.0;
    double youAreOwed = 0.0;
    
    // Handle the response structure with you_owe and you_are_owed fields
    if (balanceData is Map<String, dynamic>) {
      // Extract the breakdown values (not your_balance which is the net)
      youOwe = (balanceData['you_owe'] as num?)?.toDouble() ?? 0.0;
      youAreOwed = (balanceData['you_are_owed'] as num?)?.toDouble() ?? 0.0;
      
      // Debug logging
      debugPrint('💰 Balance breakdown: you_owe=$youOwe, you_are_owed=$youAreOwed');
      debugPrint('💰 Net balance: ${balanceData['your_balance']}');
    }
    final netYouOwe = (youOwe - youAreOwed).clamp(0.0, double.infinity);
    final netYouAreOwed = (youAreOwed - youOwe).clamp(0.0, double.infinity);
    
    return Row(
      children: [
        Expanded(child: _buildBalanceTile('You\'ll get back', netYouAreOwed, true)),
        const SizedBox(width: 10),
        Expanded(child: _buildBalanceTile('You need to pay', netYouOwe, false)),
      ],
    );
  }

  Widget _buildPersonalMonthTotalCard(Color primaryColor, double total) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFEEEEF2)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: primaryColor.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(
              Icons.account_balance_wallet_outlined,
              color: primaryColor,
              size: 20,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Total Expense This Month',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey.shade600,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Rs. ${total.toStringAsFixed(2)}',
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF1A1A2E),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBalanceTile(String label, double amount, bool isPositive) {
    final valueColor = isPositive
        ? const Color(0xFF2E7D32) // dark green
        : const Color(0xFFC62828); // dark red

    return GestureDetector(
      onTap: amount > 0 ? () => _showBalanceDetails(isPositive, amount) : null,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: const Color(0xFFF7F7FB),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: const Color(0xFFEEEEF2)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    label,
                    style: TextStyle(fontSize: 11, color: Colors.grey.shade500),
                  ),
                ),
                if (amount > 0)
                  Icon(
                    Icons.arrow_forward_ios,
                    size: 10,
                    color: Colors.grey.shade400,
                  ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              'Rs. ${amount.round()}',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: valueColor,
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showBalanceDetails(bool isOwed, double actualBalance) {
    final roomspaceProvider =
        Provider.of<RoomspaceProvider>(context, listen: false);
    final activeRoomspaceId = roomspaceProvider.getActiveRoomspaceId();

    if (activeRoomspaceId == null) return;

    BalanceDetailsDialog.show(
      context,
      roomspaceId: activeRoomspaceId,
      isOwed: isOwed,
      actualBalance: actualBalance,
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
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            primaryColor.withValues(alpha: 0.1),
            primaryColor.withValues(alpha: 0.05),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: primaryColor.withValues(alpha: 0.2)),
      ),
      child: Column(
        children: [
          // Icon and message
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: primaryColor.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  Icons.home_work_outlined,
                  color: primaryColor,
                  size: 28,
                ),
              ),
              const SizedBox(width: 16),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'No Roomspace Yet',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF1A1A2E),
                      ),
                    ),
                    SizedBox(height: 4),
                    Text(
                      'Create or join a room to split expenses with roommates',
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.grey,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          
          const SizedBox(height: 20),
          
          // Action buttons
          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: () {
                    Navigator.pushNamed(context, '/create-roomspace');
                  },
                  icon: const Icon(Icons.add_rounded, size: 18),
                  label: const Text(
                    'Create Room',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: primaryColor,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                    elevation: 0,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () {
                    Navigator.pushNamed(context, '/join-roomspace');
                  },
                  icon: Icon(Icons.group_add_rounded, size: 18, color: primaryColor),
                  label: Text(
                    'Join Room',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: primaryColor,
                    ),
                  ),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    side: BorderSide(color: primaryColor, width: 1.5),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ──────────────────────────────────────────
  // RECENT ACTIVITY LIST
  // ──────────────────────────────────────────
  Widget _buildRecentActivityList(
    Color primaryColor, 
    Map<String, dynamic> personalExpenses, 
    Map<String, dynamic> roomspaceExpenses,
  ) {
    // Extract expense data
    final personalExpensesList = personalExpenses['data'] as List<dynamic>? ?? [];
    final roomspaceExpensesList = roomspaceExpenses['data'] as List<dynamic>? ?? [];
    
    // Check for loading states
    final isLoadingPersonal = personalExpenses['loading'] == true;
    final isLoadingRoomspace = roomspaceExpenses['loading'] == true;
    final isLoading = isLoadingPersonal || isLoadingRoomspace;
    
    // Check for errors
    final personalError = personalExpenses['error'] as String?;
    final roomspaceError = roomspaceExpenses['error'] as String?;
    final hasError = personalError != null || roomspaceError != null;
    
    if (isLoading) {
      return const Column(
        children: [
          SizedBox(height: 8),
          ExpenseListSkeleton(itemCount: 3),
          SizedBox(height: 100),
        ],
      );
    }

    if (hasError) {
      final errorMessage = personalError ?? roomspaceError ?? 'Unknown error';
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 32),
        child: Center(
          child: Column(
            children: [
              Icon(Icons.wifi_off_rounded,
                  size: 36, color: Colors.grey.shade300),
              const SizedBox(height: 10),
              Text(errorMessage,
                  style: TextStyle(color: Colors.grey.shade500)),
              const SizedBox(height: 8),
              TextButton(
                onPressed: () {
                  // Force refresh dashboard
                  _state.forceRefresh(ScreenKeys.dashboard);
                  setState(() {});
                },
                child: const Text('Retry'),
              ),
              const SizedBox(height: 100),
            ],
          ),
        ),
      );
    }

    // Combine and sort expenses by date
    final combined = <Map<String, dynamic>>[];
    
    // Add personal expenses with safety checks
    for (final expense in personalExpensesList) {
      if (expense is! Map<String, dynamic>) continue;
      
      final createdAt = expense['created_at'] as String?;
      DateTime date = DateTime.now();
      if (createdAt != null) {
        try {
          date = DateTime.parse(createdAt);
        } catch (e) {
          // Use current time if parsing fails
        }
      }
      
      combined.add({
        'type': 'personal',
        'data': expense,
        'date': date,
      });
    }
    
    // Add roomspace expenses with safety checks
    for (final expense in roomspaceExpensesList) {
      if (expense is! Map<String, dynamic>) continue;
      
      final createdAt = expense['created_at'] as String?;
      DateTime date = DateTime.now();
      if (createdAt != null) {
        try {
          date = DateTime.parse(createdAt);
        } catch (e) {
          // Use current time if parsing fails
        }
      }
      
      combined.add({
        'type': 'shared',
        'data': expense,
        'date': date,
      });
    }
    
    // Sort by date (newest first)
    combined.sort((a, b) => (b['date'] as DateTime).compareTo(a['date'] as DateTime));
    
    // Take only the most recent 5
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
        ...recent.map((expenseMap) {
          try {
            final expenseData = expenseMap['data'] as Map<String, dynamic>;
            final type = expenseMap['type'] as String;
            
            if (type == 'shared') {
              return _buildSharedTileFromData(expenseData);
            } else {
              return _buildPersonalTileFromData(expenseData);
            }
          } catch (e) {
            debugPrint('Error rendering expense tile: $e');
            // Return empty container for invalid expense data
            return const SizedBox.shrink();
          }
        }).where((widget) => widget is! SizedBox || (widget).height != 0),
        const SizedBox(height: 100),
      ],
    );
  }

  // ──────────────────────────────────────────
  // EXPENSE TILES
  // ──────────────────────────────────────────
  Widget _buildSharedTileFromData(Map<String, dynamic> expense) {
    final currentUser = FirebaseAuth.instance.currentUser;
    final paidBy = expense['paid_by'] as String?;
    final isPaidByMe = paidBy == currentUser?.uid;
    final title = expense['title'] as String? ?? 'Unknown Expense';
    final amount = (expense['amount'] as num?)?.toDouble() ?? 0.0;
    final payerName = expense['payer_name'] as String?;
    final createdAt = expense['created_at'] as String?;
    
    DateTime? date;
    if (createdAt != null) {
      try {
        date = DateTime.parse(createdAt);
      } catch (e) {
        date = DateTime.now();
      }
    }

    return _ExpenseTile(
      title: title,
      subtitle: isPaidByMe ? 'You paid' : '${payerName ?? 'Someone'} paid',
      amount: 'Rs. ${amount.toStringAsFixed(0)}',
      amountColor: isPaidByMe ? const Color(0xFF2E7D32) : const Color(0xFFC62828),
      date: _formatDate(date),
      icon: Icons.receipt_long_outlined,
    );
  }

  Widget _buildPersonalTileFromData(Map<String, dynamic> expense) {
    final title = expense['title'] as String? ?? 'Unknown Expense';
    final amount = (expense['amount'] as num?)?.toDouble() ?? 0.0;
    final category = expense['category'] as String? ?? 'Personal';
    final createdAt = expense['created_at'] as String?;
    
    DateTime? date;
    if (createdAt != null) {
      try {
        date = DateTime.parse(createdAt);
      } catch (e) {
        date = DateTime.now();
      }
    }

    return _ExpenseTile(
      title: title,
      subtitle: category,
      amount: 'Rs. ${amount.toStringAsFixed(0)}',
      amountColor: const Color(0xFF1A1A2E),
      date: _formatDate(date),
      icon: Icons.account_balance_wallet_outlined,
    );
  }

  // ──────────────────────────────────────────
  // HELPERS
  // ──────────────────────────────────────────
  String _greeting() {
    // Nepal time is UTC+05:45
    final nepalNow = DateTime.now().toUtc().add(const Duration(hours: 5, minutes: 45));
    final hour = nepalNow.hour;
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
