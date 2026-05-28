import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/widgets/mobile_scaffold.dart';
import '../../../core/widgets/global_roomspace_selector.dart';
import '../../../services/smart_api_service.dart';
import '../../../services/state_management_service.dart';
import '../../../services/real_time_data_service.dart';
import '../../../models/expense_models.dart';
import '../../../models/recurring_expense_models.dart';
import '../../../providers/roomspace_provider.dart';
import '../../../widgets/enhanced_expense_tile.dart';
import '../../subscription/providers/subscription_provider.dart';
import '../../subscription/utils/subscription_helper.dart';
import '../widgets/month_selector.dart';
import 'expense_list_screen.dart';
import 'personal_expenses_screen.dart';
import 'personal_expense_details_screen.dart';
import 'payment_confirmation_screen.dart';
import 'who_owes_who_screen.dart';
import 'balance_breakdown_screen.dart';
import 'report_options_screen.dart';
import 'settlements_screen.dart';
import 'recurring_payments_screen.dart';
import 'dart:async';
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

/// Main expense screen — acts as a router for different expense-related views.
class ExpenseScreen extends StatefulWidget {
  const ExpenseScreen({super.key});

  @override
  State<ExpenseScreen> createState() => _ExpenseScreenState();
}

class _ExpenseScreenState extends State<ExpenseScreen> 
    with AutomaticKeepAliveClientMixin {
  final SmartApiService _smartApi = SmartApiService();
  final StateManagementService _state = StateManagementService();
  final RealTimeDataService _realTimeService = RealTimeDataService();

  @override
  bool get wantKeepAlive => true; // Keep state alive when switching tabs
  
  // Cache expense data to prevent reloading
  Map<String, dynamic>? _cachedExpenseData;
  DateTime? _lastDataLoad;
  static const Duration _cacheValidDuration = Duration(minutes: 3);
  
  // Initialize with first day of current month
  late DateTime _selectedMonth = DateTime(DateTime.now().year, DateTime.now().month, 1);

  // Stream subscriptions for real-time updates
  StreamSubscription<ExpenseUpdateEvent>? _expenseUpdateSubscription;
  StreamSubscription<BalanceUpdateEvent>? _balanceUpdateSubscription;
  StreamSubscription<NotificationEvent>? _notificationSubscription;
  RoomspaceProvider? _roomspaceProvider;
  static const String _recurringCachePrefix = 'recurring_templates_cache_';

  @override
  void initState() {
    super.initState();
    
    // Listen for roomspace changes
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _roomspaceProvider = Provider.of<RoomspaceProvider>(context, listen: false);
      _roomspaceProvider?.addListener(_onRoomspaceChanged);
      
      // Set up real-time listeners
      _setupRealTimeListeners();
    });
  }

  void _setupRealTimeListeners() {
    // Listen for expense updates
    _expenseUpdateSubscription = _realTimeService.expenseUpdates.listen((event) {
      debugPrint('🔄 Expense update received: ${event.type}');
      
      // Check if this update affects current roomspace
      final currentRoomspaceId = _roomspaceProvider?.getActiveRoomspaceId();
      
      if (event.type == ExpenseUpdateType.clearCache ||
          event.roomspaceId == currentRoomspaceId ||
          event.type == ExpenseUpdateType.personalCreated) {
        // Clear cache and refresh
        _cachedExpenseData = null;
        _lastDataLoad = null;
        _state.forceRefresh(ScreenKeys.expenses);
        _state.forceRefresh(ScreenKeys.personalExpenses);
        if (currentRoomspaceId != null) {
          _state.forceRefresh(ScreenKeys.roomspaceExpenses(currentRoomspaceId));
          _state.forceRefresh(ScreenKeys.roomspaceBalances(currentRoomspaceId));
        }
        
        if (mounted) {
          setState(() {}); // Trigger rebuild with fresh data
        }
      }
    });

    // Listen for balance updates
    _balanceUpdateSubscription = _realTimeService.balanceUpdates.listen((event) {
      debugPrint('🔄 Balance update received: ${event.type}');
      
      final currentRoomspaceId = _roomspaceProvider?.getActiveRoomspaceId();
      
      if (event.type == BalanceUpdateType.clearCache ||
          event.roomspaceId == currentRoomspaceId) {
        // Clear cache and refresh
        _cachedExpenseData = null;
        _lastDataLoad = null;
        _state.forceRefresh(ScreenKeys.expenses);
        if (currentRoomspaceId != null) {
          _state.forceRefresh(ScreenKeys.roomspaceBalances(currentRoomspaceId));
          _state.forceRefresh(ScreenKeys.roomspaceExpenses(currentRoomspaceId));
        }
        
        if (mounted) {
          setState(() {}); // Trigger rebuild
        }
      }
    });

    // Listen for profile updates (QR upload/change) and refresh this screen live
    _notificationSubscription = _realTimeService.notifications.listen((event) {
      if (event.type == NotificationType.profileUpdated) {
        _cachedExpenseData = null;
        _lastDataLoad = null;
        _state.forceRefresh(ScreenKeys.expenses);
        if (mounted) {
          setState(() {});
        }
      }
    });
  }

  @override
  void dispose() {
    _roomspaceProvider?.removeListener(_onRoomspaceChanged);
    
    // Cancel real-time subscriptions
    _expenseUpdateSubscription?.cancel();
    _balanceUpdateSubscription?.cancel();
    _notificationSubscription?.cancel();
    
    super.dispose();
  }

  /// Called automatically when the active roomspace changes
  void _onRoomspaceChanged() {
    // Clear cached data when roomspace changes
    _cachedExpenseData = null;
    _lastDataLoad = null;
    
    // Force refresh expenses when roomspace changes
    _state.forceRefresh(ScreenKeys.expenses);
    setState(() {}); // Trigger rebuild to refresh UI
  }

  /// Smart data loader for expenses with caching
  Future<Map<String, dynamic>> _loadExpenseData({bool forceRefresh = false}) async {
    // Return cached data if valid and not forcing refresh.
    // If recurring count is 0 in roomspace mode, bypass cache to avoid stale empty state.
    if (!forceRefresh && 
        _cachedExpenseData != null && 
        _lastDataLoad != null &&
        DateTime.now().difference(_lastDataLoad!) < _cacheValidDuration) {
      final cachedIsPersonal = _cachedExpenseData!['isPersonalSpace'] as bool? ?? true;
      final cachedRecurring = _cachedExpenseData!['recurringExpenses'];
      final cachedRecurringCount = (cachedRecurring is Map<String, dynamic>)
          ? (cachedRecurring['count'] as int? ?? 0)
          : 0;
      if (!cachedIsPersonal && cachedRecurringCount == 0) {
        debugPrint('🚀 Cached recurring count is 0 in roomspace, fetching fresh data');
      } else {
        debugPrint('🚀 Using cached expense data');
        return _cachedExpenseData!;
      }
    }

    debugPrint('🌐 Loading fresh expense data...');
    final roomspaceProvider = Provider.of<RoomspaceProvider>(context, listen: false);
    String? activeRoomspaceId = roomspaceProvider.getActiveRoomspaceId();
    final isPersonalSpace = roomspaceProvider.isPersonalSpace;

    if (!isPersonalSpace && activeRoomspaceId == null && roomspaceProvider.roomspaces.isNotEmpty) {
      activeRoomspaceId = roomspaceProvider.roomspaces.first.id;
    }

    // Load data in parallel with caching
    final futures = <String, Future<Map<String, dynamic>>>{};
    
    // Always load personal expenses
    futures['personalExpenses'] = _smartApi.getPersonalExpenses(
      limit: 3, 
      offset: 0, 
      month: _selectedMonth,
      forceRefresh: forceRefresh,
    );
    
    // Load roomspace-specific data if in a roomspace
    if (!isPersonalSpace && activeRoomspaceId != null) {
      futures['sharedExpenses'] = _loadSharedExpensesWithFallback(
        activeRoomspaceId,
        forceRefresh: forceRefresh,
      );
      
      // Load recurring expenses separately
      futures['recurringExpenses'] = _loadRecurringExpenses(activeRoomspaceId);
      
      // Load pending payments count
      futures['pendingPayments'] = _loadPendingPaymentsCount(activeRoomspaceId);
      futures['userProfile'] = _smartApi.getUserProfile(forceRefresh: true);
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

    final expenseData = {
      'roomspaceId': activeRoomspaceId,
      'isPersonalSpace': isPersonalSpace,
      'selectedMonth': _selectedMonth,
      ...results,
    };

    // Cache the data
    _cachedExpenseData = expenseData;
    _lastDataLoad = DateTime.now();
    debugPrint('💾 Expense data cached at $_lastDataLoad');

    return expenseData;
  }

  Future<Map<String, dynamic>> _loadPendingPaymentsCount(String roomspaceId) async {
    try {
      final response = await _smartApi.dio.get(
        '/api/roomspaces/$roomspaceId/payments/pending',
      );
      
      if (response.statusCode == 200 && response.data['success'] == true) {
        final List<dynamic> payments = response.data['data'] ?? [];
        return {'data': payments, 'count': payments.length};
      }
      return {'data': [], 'count': 0};
    } catch (e) {
      debugPrint('Error loading pending payments count: $e');
      return {'data': [], 'count': 0, 'error': e.toString()};
    }
  }

  Future<Map<String, dynamic>> _loadSharedExpensesWithFallback(
    String roomspaceId, {
    required bool forceRefresh,
  }) async {
    final recent = await _smartApi.getExpenses(
      roomspaceId: roomspaceId,
      limit: 100,
      offset: 0,
    );

    final raw = recent['data'];
    final list = raw is List ? raw : const <dynamic>[];
    final normalized = list
        .whereType<Map>()
        .map((e) => e.map((k, v) => MapEntry(k.toString(), v)))
        .toList();

    bool isInSelectedMonth(Map<String, dynamic> e) {
      final createdAt = e['created_at']?.toString();
      if (createdAt == null || createdAt.isEmpty) return false;
      final d = DateTime.tryParse(createdAt);
      if (d == null) return false;
      return d.year == _selectedMonth.year && d.month == _selectedMonth.month;
    }

    final monthFiltered = normalized.where(isInSelectedMonth).toList();
    final picked = (monthFiltered.length >= 3 ? monthFiltered : normalized).take(3).toList();

    return {
      ...recent,
      'data': picked,
      'meta': {
        'count': picked.length,
        'limit': 3,
        'offset': 0,
      },
    };
  }

  Future<Map<String, dynamic>> _loadRecurringExpenses(String roomspaceId) async {
    Future<Map<String, dynamic>?> readRecurringCache() async {
      try {
        final prefs = await SharedPreferences.getInstance();
        final raw = prefs.getString('$_recurringCachePrefix$roomspaceId');
        if (raw == null || raw.isEmpty) return null;
        final decoded = Map<String, dynamic>.from(
          (jsonDecode(raw) as Map).map((k, v) => MapEntry(k.toString(), v)),
        );
        final data = decoded['data'];
        if (data is List) {
          return {'data': data, 'count': data.length};
        }
      } catch (e) {
        debugPrint('⚠️ Failed to read recurring cache: $e');
      }
      return null;
    }

    Future<void> writeRecurringCache(List<dynamic> data) async {
      try {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString(
          '$_recurringCachePrefix$roomspaceId',
          jsonEncode({
            'data': data,
            'cached_at': DateTime.now().toIso8601String(),
          }),
        );
      } catch (e) {
        debugPrint('⚠️ Failed to cache recurring templates: $e');
      }
    }

    try {
      debugPrint('🔄 Loading recurring expenses for roomspace: $roomspaceId');
      
      // First try to get recurring expense templates
      final response = await _smartApi.dio.get(
        '/api/roomspaces/$roomspaceId/recurring-expenses',
      );
      
      if (response.statusCode == 200 && response.data['success'] == true) {
        final dynamic rawData = response.data['data'];
        final List<dynamic> recurringData = rawData is List
            ? rawData
            : (rawData is Map<String, dynamic> && rawData['data'] is List ? rawData['data'] as List : <dynamic>[]);
        debugPrint('🔄 Found ${recurringData.length} recurring expense templates');
        if (recurringData.isNotEmpty) {
          await writeRecurringCache(recurringData);
          return {'data': recurringData, 'count': recurringData.length};
        }
        debugPrint('🔄 No templates found, trying fallback from regular expenses');
      }

      // Fallback 1: Upcoming recurring endpoint
      try {
        final upcomingResponse = await _smartApi.dio.get(
          '/api/roomspaces/$roomspaceId/recurring-expenses/upcoming?days=365',
        );
        if (upcomingResponse.statusCode == 200 && upcomingResponse.data['success'] == true) {
          final List<dynamic> upcomingData = upcomingResponse.data['data'] ?? [];
          debugPrint('🔄 Upcoming fallback found ${upcomingData.length} recurring items');
          if (upcomingData.isNotEmpty) {
            await writeRecurringCache(upcomingData);
            return {'data': upcomingData, 'count': upcomingData.length};
          }
        }
      } catch (e) {
        debugPrint('⚠️ Upcoming recurring fallback failed: $e');
      }
      
      // Fallback 2: Filter regular expenses for recurring ones
      debugPrint('🔄 Fallback: Filtering regular expenses for recurring ones');
      final expensesResponse = await _smartApi.getRoomspaceExpenses(
        roomspaceId,
        limit: 50, // Get more to filter
        offset: 0,
      );
      
      if (expensesResponse['success'] == true && expensesResponse['data'] != null) {
        final List<dynamic> allExpenses = expensesResponse['data'];
        final recurringExpenses = allExpenses.where((expense) {
          final recurringConfig = expense['recurring_config'];
          return recurringConfig != null && recurringConfig['is_recurring'] == true;
        }).toList();
        
        debugPrint('🔄 Found ${recurringExpenses.length} recurring expenses from ${allExpenses.length} total');
        if (recurringExpenses.isNotEmpty) {
          await writeRecurringCache(recurringExpenses);
        }
        return {'data': recurringExpenses, 'count': recurringExpenses.length};
      }

      final cached = await readRecurringCache();
      if (cached != null) return cached;
      return {'data': [], 'count': 0};
    } catch (e) {
      debugPrint('❌ Error loading recurring expenses: $e');
      
      // Fallback: Try to filter from regular expenses
      try {
        final expensesResponse = await _smartApi.getRoomspaceExpenses(
          roomspaceId,
          limit: 50,
          offset: 0,
        );
        
        if (expensesResponse['success'] == true && expensesResponse['data'] != null) {
          final List<dynamic> allExpenses = expensesResponse['data'];
          final recurringExpenses = allExpenses.where((expense) {
            final recurringConfig = expense['recurring_config'];
            return recurringConfig != null && recurringConfig['is_recurring'] == true;
          }).toList();
          
          debugPrint('🔄 Fallback successful: Found ${recurringExpenses.length} recurring expenses');
          if (recurringExpenses.isNotEmpty) {
            await writeRecurringCache(recurringExpenses);
          }
          return {'data': recurringExpenses, 'count': recurringExpenses.length};
        }
      } catch (fallbackError) {
        debugPrint('❌ Fallback also failed: $fallbackError');
      }

      final cached = await readRecurringCache();
      if (cached != null) {
        debugPrint('📦 Using cached recurring templates while offline/error');
        return cached;
      }
      return {'data': [], 'count': 0, 'error': e.toString()};
    }
  }

  void _onMonthChanged(DateTime newMonth) {
    setState(() {
      _selectedMonth = newMonth;
    });
    // Clear cache when month changes
    _cachedExpenseData = null;
    _lastDataLoad = null;
    _state.forceRefresh(ScreenKeys.expenses);
  }

  @override
  Widget build(BuildContext context) {
    super.build(context); // Required for AutomaticKeepAliveClientMixin
    
    final primaryColor = Theme.of(context).colorScheme.primary;

    return MobileScaffold(
      currentIndex: 2,
      showAppBar: false,
      showBottomNav: false, // Hide bottom nav since MainNavigation handles it
      body: FutureBuilder<Map<String, dynamic>>(
        future: _loadExpenseData(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return _buildErrorState(primaryColor);
          }
          
          if (snapshot.hasData) {
            return RefreshIndicator(
              onRefresh: () async {
                _cachedExpenseData = null;
                _lastDataLoad = null;
                _state.forceRefresh(ScreenKeys.expenses);
                setState(() {}); // Trigger rebuild with fresh data
              },
              child: _buildExpenseContent(context, snapshot.data!, primaryColor),
            );
          }
          
          return _buildLoadingSkeleton(primaryColor);
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
              'Couldn\'t load expenses',
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
                _cachedExpenseData = null;
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

  Widget _buildExpenseContent(
    BuildContext context,
    Map<String, dynamic> expenseData,
    Color primaryColor,
  ) {
    Map<String, dynamic> asStringKeyedMap(dynamic value) {
      if (value is Map<String, dynamic>) return value;
      if (value is Map) return Map<String, dynamic>.from(value);
      return <String, dynamic>{};
    }

    final isPersonalSpace = expenseData['isPersonalSpace'] as bool? ?? true;
    final personalExpenses = asStringKeyedMap(expenseData['personalExpenses']);
    final sharedExpenses = asStringKeyedMap(expenseData['sharedExpenses']);
    final recurringExpenses = asStringKeyedMap(expenseData['recurringExpenses']);
    final pendingPayments = asStringKeyedMap(expenseData['pendingPayments']);
    final userProfile = asStringKeyedMap(expenseData['userProfile']);
    
    // Extract data safely
    final personalExpensesList = personalExpenses['data'] as List<dynamic>? ?? [];
    final sharedExpensesRaw = sharedExpenses['data'];
    final sharedExpensesList = sharedExpensesRaw is List
        ? sharedExpensesRaw
        : (sharedExpensesRaw is Map<String, dynamic> && sharedExpensesRaw['data'] is List
            ? (sharedExpensesRaw['data'] as List)
            : <dynamic>[]);
    final recurringExpensesList = recurringExpenses['data'] as List<dynamic>? ?? [];
    final pendingPaymentsCount = pendingPayments['count'] as int? ?? 0;
    final profileData = asStringKeyedMap(userProfile['data']);
    final qrImageUrl = profileData['qr_image_url'] as String?;
    
    // Convert to models
    final recentPersonalExpenses = personalExpensesList
        .map((json) => PersonalExpenseData.fromJson(json))
        .toList();
    
    // Filter out recurring expenses from shared expenses to avoid duplication
    final nonRecurringSharedExpenses = sharedExpensesList
        .whereType<Map>()
        .map((e) => e.map((k, v) => MapEntry(k.toString(), v)))
        .where((expense) {
          final recurringConfig = expense['recurring_config'];
          return recurringConfig == null || recurringConfig['is_recurring'] != true;
        })
        .map((json) => ExpenseData.fromJson(json))
        .toList();
    
    final recurringTemplates = recurringExpensesList
        .map((json) => RecurringExpenseTemplate.fromJson(Map<String, dynamic>.from(json)))
        .where((template) => !template.isDeleted)
        .toList();
    
    final totalRecentSpending = nonRecurringSharedExpenses.fold(0.0, (sum, item) => sum + item.amount) +
        recentPersonalExpenses.fold(0.0, (sum, item) => sum + item.amount) +
        recurringTemplates.fold(0.0, (sum, item) => sum + item.amount);

    return SingleChildScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      child: Column(
          children: [
            // ── Header Section ──
            _buildHeader(
              primaryColor,
              totalRecentSpending,
              showQrSetupMessage: !isPersonalSpace && (qrImageUrl == null || qrImageUrl.isEmpty),
            ),

            // ── Month Selector ──
            MonthSelector(
              selectedMonth: _selectedMonth,
              onMonthChanged: _onMonthChanged,
            ),

            // ── Body Content ──
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Recurring Payments Section
                  if (!isPersonalSpace) ...[
                    const SizedBox(height: 12),
                    _buildRecurringPaymentsSection(primaryColor, recurringTemplates),
                    const SizedBox(height: 24),
                  ],
                  
                  // Shared Expenses (Non-recurring)
                  if (!isPersonalSpace) ...[
                    const SizedBox(height: 12),
                    _buildSectionHeader(
                      title: "Shared Expenses", 
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const ExpenseListScreen(
                            isPersonalExpenses: false,
                          ),
                        ),
                      ),
                      primaryColor: primaryColor,
                    ),
                    _buildSharedList(primaryColor, nonRecurringSharedExpenses),
                    const SizedBox(height: 24),
                    
                    // Settle Up Actions (Who Owes Who + Pending Payments)
                    _buildSettleUpSection(primaryColor, pendingPaymentsCount, qrImageUrl),
                    const SizedBox(height: 24),
                  ],

                  if (isPersonalSpace) ...[
                    // Personal Expenses
                    _buildSectionHeader(
                      title: "Personal Expenses",
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const PersonalExpensesScreen(),
                        ),
                      ),
                      primaryColor: Colors.orange.shade700,
                    ),
                    _buildPersonalList(recentPersonalExpenses),
                  ],
                  
                  const SizedBox(height: 100), // Extra space for bottom nav
                ],
              ),
            ),
          ],
        ),
    );
  }

  Widget _buildLoadingSkeleton(Color primaryColor) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          // Header skeleton
          const SizedBox(height: 56),
          Container(
            height: 80,
            decoration: BoxDecoration(
              color: Colors.grey.shade200,
              borderRadius: BorderRadius.circular(12),
            ),
          ),
          const SizedBox(height: 20),
          
          // Month selector skeleton
          Container(
            height: 50,
            decoration: BoxDecoration(
              color: Colors.grey.shade200,
              borderRadius: BorderRadius.circular(12),
            ),
          ),
          const SizedBox(height: 20),
          
          // Expense list skeleton
          ...List.generate(5, (index) => Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Container(
              height: 70,
              decoration: BoxDecoration(
                color: Colors.grey.shade200,
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          )),
        ],
      ),
    );
  }

  Widget _buildHeader(
    Color primaryColor,
    double totalRecentSpending, {
    bool showQrSetupMessage = false,
  }) {
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
          Row(
            children: [
              const Expanded(
                child: Text(
                  'Expenses',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF1A1A2E),
                  ),
                ),
              ),
              GlobalRoomspaceSelector(
                onRoomspaceChanged: () {
                  // Clear cache when roomspace changes
                  _cachedExpenseData = null;
                  _lastDataLoad = null;
                  _state.forceRefresh(ScreenKeys.expenses);
                  setState(() {}); // Trigger rebuild to refresh UI
                },
              ),
            ],
          ),
          if (showQrSetupMessage) ...[
            const SizedBox(height: 12),
            _buildQrSetupMessage(
              color: Colors.teal.shade700,
              onTap: () async {
                await Navigator.pushNamed(context, '/profile');
                _cachedExpenseData = null;
                _lastDataLoad = null;
                _state.forceRefresh(ScreenKeys.expenses);
                if (mounted) setState(() {});
              },
            ),
          ],
          const SizedBox(height: 16),
          _buildSpendingSummaryPanel(primaryColor, totalRecentSpending),
        ],
      ),
    );
  }

  Widget _buildSpendingSummaryPanel(Color primaryColor, double totalRecentSpending) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFF7F7FB),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFEEEEF2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Activity Total',
            style: TextStyle(
              fontSize: 11,
              color: Colors.grey.shade500,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Rs. ${totalRecentSpending.toStringAsFixed(2)}',
            style: const TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w900,
              color: Color(0xFF1A1A2E),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader({
    required String title, 
    required VoidCallback onTap,
    required Color primaryColor
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: Color(0xFF1A1A2E),
            ),
          ),
          TextButton(
            onPressed: onTap,
            style: TextButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              minimumSize: Size.zero,
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
            child: Text(
              'View All',
              style: TextStyle(
                color: primaryColor,
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSharedList(Color primaryColor, List<ExpenseData> recentSharedExpenses) {
    if (recentSharedExpenses.isEmpty) {
      return _buildEmptyState("No shared expenses yet", Icons.people_outline_rounded);
    }

    return Column(
      children: recentSharedExpenses.map((expense) {
        return EnhancedExpenseTile(
          expense: expense,
          themeColor: primaryColor,
          isPersonal: false,
          onUpdated: () {
            // Clear cache and refresh when expense is updated
            _cachedExpenseData = null;
            _lastDataLoad = null;
            _state.forceRefresh(ScreenKeys.expenses);
            _state.forceRefresh(ScreenKeys.dashboard);
            _state.forceRefresh(ScreenKeys.personalExpenses);
            final activeRoomspaceId = Provider.of<RoomspaceProvider>(context, listen: false).getActiveRoomspaceId();
            if (activeRoomspaceId != null) {
              _state.forceRefresh(ScreenKeys.roomspaceExpenses(activeRoomspaceId));
              _state.forceRefresh(ScreenKeys.roomspaceBalances(activeRoomspaceId));
            }
            setState(() {});
          },
        );
      }).toList(),
    );
  }

  Widget _buildRecurringPaymentsSection(Color primaryColor, List<RecurringExpenseTemplate> recurringExpenses) {
    final isEmpty = recurringExpenses.isEmpty;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Section Header with special styling for recurring payments
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: Colors.purple.shade100,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    Icons.repeat_rounded,
                    size: 16,
                    color: Colors.purple.shade700,
                  ),
                ),
                const SizedBox(width: 12),
                const Text(
                  'Recurring Payments',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF1A1A2E),
                  ),
                ),
                const SizedBox(width: 8),
                
              ],
            ),
            TextButton(
              onPressed: _openRecurringManager,
              style: TextButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                minimumSize: Size.zero,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              child: Text(
                'Manage All',
                style: TextStyle(
                  color: Colors.purple.shade700,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          'Automatically scheduled payments',
          style: TextStyle(
            fontSize: 12,
            color: Colors.grey.shade500,
          ),
        ),
        const SizedBox(height: 12),
        
        // Recurring Payments List
        if (isEmpty)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Colors.grey.shade50,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.grey.shade200, width: 1),
            ),
            child: Text(
              'No recurring payments found in this roomspace yet. Tap "Manage All" to open recurring manager.',
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey.shade700,
                fontWeight: FontWeight.w500,
              ),
            ),
          )
        else
          Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.grey.shade200, width: 1),
            ),
            child: Column(
              children: recurringExpenses.take(3).map((expense) {
                final isLast = expense == recurringExpenses.take(3).last;
                return Container(
                  decoration: BoxDecoration(
                    border: isLast ? null : Border(
                      bottom: BorderSide(color: Colors.grey.shade200, width: 0.5),
                    ),
                  ),
                  child: _buildRecurringPaymentTile(expense, Colors.purple.shade700),
                );
              }).toList(),
            ),
          ),
        
        // Show more indicator if there are more than 3
        if (recurringExpenses.length > 3) ...[
          const SizedBox(height: 8),
          Center(
            child: TextButton.icon(
              onPressed: _openRecurringManager,
              icon: Icon(Icons.expand_more_rounded, size: 16, color: Colors.purple.shade600),
              label: Text(
                '+${recurringExpenses.length - 3} more recurring payments',
                style: TextStyle(
                  color: Colors.purple.shade600,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
              style: TextButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                backgroundColor: Colors.purple.shade50,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              ),
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildRecurringPaymentTile(RecurringExpenseTemplate template, Color themeColor) {
    final nextPayment = template.getNextScheduledDateForDisplay();
    
    return InkWell(
      onTap: _openRecurringManager,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            // Icon
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: themeColor.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(
                _getIcon(template.category),
                color: themeColor,
                size: 18,
              ),
            ),
            const SizedBox(width: 12),
            
            // Content
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    template.title,
                    style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 14,
                      color: Color(0xFF1A1A2E),
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Row(
                    children: [
                      Text(
                        template.recurringConfig.interval?.label ?? 'Monthly',
                        style: TextStyle(
                          fontSize: 11,
                          color: themeColor,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      if (nextPayment != null) ...[
                        Text(
                          ' • Next: ${_formatUpcomingDate(nextPayment)}',
                          style: TextStyle(
                            fontSize: 11,
                            color: Colors.grey.shade600,
                          ),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
            
            // Amount
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  'Rs. ${template.amount.toStringAsFixed(0)}',
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 14,
                    color: themeColor,
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: themeColor.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    'AUTO',
                    style: TextStyle(
                      fontSize: 8,
                      fontWeight: FontWeight.w700,
                      color: themeColor,
                      letterSpacing: 0.5,
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

  Future<void> _openRecurringManager() async {
    final roomspaceProvider = Provider.of<RoomspaceProvider>(context, listen: false);
    final activeRoomspaceId = roomspaceProvider.getActiveRoomspaceId();
    if (activeRoomspaceId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No active roomspace selected')),
      );
      return;
    }

    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => RecurringPaymentsScreen(
          roomspaceId: activeRoomspaceId,
          recurringExpenses: const [],
        ),
      ),
    );
    if (!mounted) return;
    _cachedExpenseData = null;
    _lastDataLoad = null;
    _state.forceRefresh(ScreenKeys.expenses);
    _state.forceRefresh(ScreenKeys.dashboard);
    setState(() {});
  }

  IconData _getIcon(String category) {
    switch (category.toLowerCase()) {
      case 'groceries':
        return Icons.shopping_basket_outlined;
      case 'utilities':
        return Icons.bolt_rounded;
      case 'rent':
        return Icons.home_outlined;
      case 'food':
        return Icons.restaurant_rounded;
      case 'transport':
        return Icons.directions_car_rounded;
      case 'entertainment':
        return Icons.movie_creation_rounded;
      default:
        return Icons.receipt_long_outlined;
    }
  }

  Widget _buildPersonalList(List<PersonalExpenseData> recentPersonalExpenses) {
    if (recentPersonalExpenses.isEmpty) {
      return _buildEmptyState("No personal expenses yet", Icons.account_balance_wallet_outlined);
    }

    return Column(
      children: recentPersonalExpenses.map((expense) {
        return _ExpenseTile(
          title: expense.title,
          subtitle: expense.category,
          amount: 'Rs. ${expense.amount.toStringAsFixed(0)}',
          amountColor: Colors.orange.shade700,
          date: _formatDate(expense.createdAt),
          icon: Icons.account_balance_wallet_outlined,
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => PersonalExpenseDetailsScreen(expense: expense),
              ),
            );
          },
        );
      }).toList(),
    );
  }

  Widget _buildSettleUpSection(Color primaryColor, int pendingPaymentsCount, String? qrImageUrl) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.only(bottom: 12),
          child: Text(
            "Management",
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: Color(0xFF1A1A2E),
            ),
          ),
        ),
        _ManagementActionCard(
          title: 'Balance Overview',
          subtitle: 'See who owes who and settle up',
          icon: Icons.people_rounded,
          color: Colors.indigo,
          onTap: () {
            final roomspaceId = Provider.of<RoomspaceProvider>(context, listen: false).getActiveRoomspaceId();
            if (roomspaceId != null) {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => WhoOwesWhoScreen(roomspaceId: roomspaceId),
                ),
              );
            }
          },
        ),
        const SizedBox(height: 12),
        _ManagementActionCard(
          title: 'Confirm Payments',
          subtitle: pendingPaymentsCount > 0 
              ? '$pendingPaymentsCount pending confirmation${pendingPaymentsCount > 1 ? 's' : ''}'
              : 'Review and verify payments',
          icon: Icons.payment_rounded,
          color: Colors.blue.shade600,
          badgeCount: pendingPaymentsCount,
          onTap: () {
            final roomspaceId = Provider.of<RoomspaceProvider>(context, listen: false).getActiveRoomspaceId();
            if (roomspaceId != null) {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => PaymentConfirmationScreen(roomspaceId: roomspaceId),
                ),
              ).then((_) {
                // Refresh pending payments count after returning
                _cachedExpenseData = null;
                _lastDataLoad = null;
                _state.forceRefresh(ScreenKeys.expenses);
                setState(() {});
              });
            }
          },
        ),
        const SizedBox(height: 12),
        _ManagementActionCard(
          title: 'Settlements',
          subtitle: 'View payment history between roommates',
          icon: Icons.payments_rounded,
          color: Colors.green.shade700,
          onTap: () {
            final roomspaceId = Provider.of<RoomspaceProvider>(context, listen: false).getActiveRoomspaceId();
            if (roomspaceId != null) {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => SettlementsScreen(roomspaceId: roomspaceId),
                ),
              );
            }
          },
        ),
        const SizedBox(height: 12),
        _ManagementActionCard(
          title: 'Balance Calculation',
          subtitle: 'See full overall balance math breakdown',
          icon: Icons.calculate_rounded,
          color: Colors.deepPurple.shade600,
          onTap: () {
            final roomspaceId = Provider.of<RoomspaceProvider>(context, listen: false).getActiveRoomspaceId();
            if (roomspaceId != null) {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => BalanceBreakdownScreen(roomspaceId: roomspaceId),
                ),
              );
            }
          },
        ),
        const SizedBox(height: 12),
        Consumer<SubscriptionProvider>(
          builder: (context, subscriptionProvider, child) {
            final canExport = subscriptionProvider.currentLimits.exportFeatures;
            
            return _ManagementActionCard(
              title: 'Generate Report',
              subtitle: canExport 
                  ? 'Export expenses as professional PDF'
                  : '🔒 Pro feature - Upgrade to export',
              icon: Icons.picture_as_pdf_rounded,
              color: canExport ? Colors.red.shade700 : Colors.grey.shade400,
              onTap: () {
                if (canExport) {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => const ReportOptionsScreen()),
                  );
                } else {
                  // Show upgrade dialog
                  SubscriptionHelper.showFeatureBlockedDialog(
                    context,
                    featureName: 'Export Reports',
                    description: 'Export your expenses as professional PDF or Excel reports with detailed analytics.',
                  );
                }
              },
            );
          },
        ),
      ],
    );
  }

  Widget _buildQrSetupMessage({
    required Color color,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withValues(alpha: 0.35)),
        ),
        child: Row(
          children: [
            Icon(Icons.qr_code_rounded, size: 18, color: color),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                'Add your payment QR',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: color,
                ),
              ),
            ),
            Icon(Icons.arrow_forward_ios_rounded, size: 14, color: color),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState(String message, IconData icon) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
      decoration: BoxDecoration(
        color: const Color(0xFFF7F7FB),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFEEEEF2)),
      ),
      child: Column(
        children: [
          Icon(icon, color: Colors.grey.shade400, size: 28),
          const SizedBox(height: 8),
          Text(
            message,
            style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
          ),
        ],
      ),
    );
  }

  String _formatDate(DateTime? date) {
    if (date == null) return '';
    final now = DateTime.now();
    final difference = now.difference(date);
    
    if (difference.inDays == 0) return 'Today';
    if (difference.inDays == 1) return 'Yesterday';
    if (difference.inDays < 7) return '${difference.inDays}d ago';
    
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
    ];
    return '${months[date.month - 1]} ${date.day}';
  }

  String _formatUpcomingDate(DateTime date) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final target = DateTime(date.year, date.month, date.day);
    final dayDiff = target.difference(today).inDays;

    if (dayDiff == 0) return 'Today';
    if (dayDiff == 1) return 'Tomorrow';
    if (dayDiff > 1 && dayDiff < 7) return 'In $dayDiff days';
    if (dayDiff < 0) return 'Overdue';

    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
    ];
    return '${months[date.month - 1]} ${date.day}';
  }
}

/// Simplified expense tile reused across the screen
class _ExpenseTile extends StatelessWidget {
  final String title;
  final String subtitle;
  final String amount;
  final Color amountColor;
  final String date;
  final IconData icon;
  final VoidCallback onTap;

  const _ExpenseTile({
    required this.title,
    required this.subtitle,
    required this.amount,
    required this.amountColor,
    required this.date,
    required this.icon,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFEEEEF2)),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: const Color(0xFFF7F7FB),
                  borderRadius: BorderRadius.circular(10),
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
                      style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                      overflow: TextOverflow.ellipsis,
                    ),
                    Text(
                      subtitle,
                      style: TextStyle(fontSize: 11, color: Colors.grey.shade500),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
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
                    style: TextStyle(fontSize: 10, color: Colors.grey.shade400),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Action card for Management section (Who Owes Who / Confirm Payments)
class _ManagementActionCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final Color color;
  final int? badgeCount;
  final VoidCallback onTap;

  const _ManagementActionCard({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.color,
    this.badgeCount,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFEEEEF2)),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    Icon(icon, size: 24, color: color),
                    if (badgeCount != null && badgeCount! > 0)
                      Positioned(
                        right: -4,
                        top: -4,
                        child: Container(
                          padding: const EdgeInsets.all(4),
                          decoration: const BoxDecoration(
                            color: Colors.red,
                            shape: BoxShape.circle,
                          ),
                          constraints: const BoxConstraints(minWidth: 16, minHeight: 16),
                          child: Text(
                            '$badgeCount',
                            style: const TextStyle(color: Colors.white, fontSize: 8, fontWeight: FontWeight.bold),
                            textAlign: TextAlign.center,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
                    ),
                    Text(
                      subtitle,
                      style: TextStyle(fontSize: 12, color: Colors.grey.shade500),
                    ),
                  ],
                ),
              ),
              Icon(Icons.arrow_forward_ios_rounded, size: 14, color: Colors.grey.shade400),
            ],
          ),
        ),
      ),
    );
  }
}
