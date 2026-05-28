import 'dart:async';
import 'package:flutter/foundation.dart';
import 'advanced_cache_service.dart';
import 'state_management_service.dart';
import 'real_time_data_service.dart';
import 'api_service.dart';
import 'offline_expense_service.dart';
import 'connectivity_service.dart';
import 'local_database_service.dart';
import '../models/expense_models.dart';
import '../models/recurring_expense_models.dart';

/// Smart API service with advanced caching, state management, and offline support
class SmartApiService {
  static final SmartApiService _instance = SmartApiService._internal();
  factory SmartApiService() => _instance;
  SmartApiService._internal();

  final AdvancedCacheService _cache = AdvancedCacheService();
  final StateManagementService _state = StateManagementService();
  final RealTimeDataService _realTimeService = RealTimeDataService();
  final ApiService _api = ApiService();
  final OfflineExpenseService _offlineExpenseService = OfflineExpenseService();
  final ConnectivityService _connectivityService = ConnectivityService();
  final LocalDatabaseService _localDb = LocalDatabaseService();

  // Expose dio for direct API calls when needed
  get dio => _api.dio;

  Map<String, dynamic> _expenseToUiMap(ExpenseData e) {
    final selected = e.selectedRoommateIds;
    final splitType = e.splitType.apiValue;
    final customSplits = e.customSplits;

    final derivedSplits = e.splits ??
        (selected.isNotEmpty
            ? selected.map((uid) {
                final amount = splitType == 'EXACT'
                    ? (customSplits[uid] ?? 0.0)
                    : (selected.isEmpty ? 0.0 : e.amount / selected.length);
                return ExpenseSplit(
                  userUid: uid,
                  userName: uid,
                  amount: amount,
                  percentage: splitType == 'PERCENTAGE'
                      ? customSplits[uid]
                      : null,
                );
              }).toList()
            : <ExpenseSplit>[]);

    return {
      'id': e.id,
      'title': e.title,
      'amount': e.amount,
      'description': e.description,
      'category': e.category,
      'roomspace_id': e.roomspaceId,
      'paid_by': e.paidBy,
      'created_by': e.createdBy,
      'payer_name': e.payerName,
      'split_type': splitType,
      'selected_roommates': selected,
      if (customSplits.isNotEmpty) 'custom_splits': customSplits,
      'created_at': (e.createdAt ?? DateTime.now()).toIso8601String(),
      'splits': derivedSplits
          .map((s) => {
                'user_uid': s.userUid,
                'user_name': s.userName,
                'amount': s.amount,
                'percentage': s.percentage,
              })
          .toList(),
      if (e.recurringConfig != null) 'recurring_config': e.recurringConfig!.toJson(),
    };
  }

  List<ExpenseData> _mergeAndSortExpenses(
    List<ExpenseData> primary,
    List<ExpenseData> secondary,
  ) {
    final byKey = <String, ExpenseData>{};

    String keyFor(ExpenseData e) {
      final created = (e.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0))
          .toIso8601String();
      if (e.id != null) return 'id:$e.id';
      return 'tmp:${e.title}|${e.amount}|$created|${e.roomspaceId ?? ''}';
    }

    for (final e in [...primary, ...secondary]) {
      byKey[keyFor(e)] = e;
    }

    final merged = byKey.values.toList()
      ..sort((a, b) {
        final ad = a.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0);
        final bd = b.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0);
        return bd.compareTo(ad);
      });
    return merged;
  }

  List<Map<String, dynamic>> _extractMapList(dynamic raw) {
    dynamic source = raw;
    if (source is Map) {
      if (source['data'] is List) {
        source = source['data'];
      } else if (source['expenses'] is List) {
        source = source['expenses'];
      }
    }
    if (source is! List) return const [];
    return source
        .whereType<Map>()
        .map((e) => e.map((k, v) => MapEntry(k.toString(), v)))
        .toList();
  }

  /// Smart data fetching with multi-level caching and state management
  Future<Map<String, dynamic>> smartFetch({
    required String screenKey,
    required String cacheKey,
    required Future<Map<String, dynamic>> Function() apiCall,
    Duration? customRefreshInterval,
    bool forceRefresh = false,
  }) async {
    try {
      // Set loading state
      _state.setLoading(screenKey, true);
      _state.clearError(screenKey);

      // Check if we need to refresh
      final needsRefresh = forceRefresh || _state.needsRefresh(screenKey, customInterval: customRefreshInterval);
      
      // Try cache first if we don't need refresh
      if (!needsRefresh) {
        final cachedData = await _cache.get<Map<String, dynamic>>(cacheKey);
        if (cachedData != null) {
          _state.setLoading(screenKey, false);
          debugPrint('⚡ Smart fetch cache hit: $screenKey');
          return cachedData;
        }
      }

      // Fetch from API
      debugPrint('🌐 Smart fetch API call: $screenKey');
      final data = await apiCall();
      
      // Cache the data
      await _cache.set(cacheKey, data);
      
      // Update state
      _state.markRefreshed(screenKey);
      _state.setLoading(screenKey, false);
      
      debugPrint('✅ Smart fetch completed: $screenKey');
      return data;
      
    } catch (e) {
      _state.setLoading(screenKey, false);
      _state.setError(screenKey, e.toString());
      
      // Try to return cached data as fallback
      final cachedData = await _cache.get<Map<String, dynamic>>(cacheKey);
      if (cachedData != null) {
        debugPrint('📦 Smart fetch fallback to cache: $screenKey');
        return cachedData;
      }
      
      debugPrint('❌ Smart fetch failed: $screenKey - $e');
      rethrow;
    }
  }

  /// Get user profile with smart caching
  Future<Map<String, dynamic>> getUserProfile({bool forceRefresh = false}) async {
    await _connectivityService.initialize();
    if (!_connectivityService.isConnected && !forceRefresh) {
      final cached = await _cache.get<Map<String, dynamic>>(
        'user_profile',
        allowExpired: true,
      );
      if (cached != null) return cached;
    }
    return await smartFetch(
      screenKey: ScreenKeys.profile,
      cacheKey: 'user_profile',
      apiCall: () => _api.getUserProfile(),
      customRefreshInterval: const Duration(minutes: 30),
      forceRefresh: forceRefresh,
    );
  }

  /// Get roomspaces with smart caching
  Future<Map<String, dynamic>> getRoomspaces({bool forceRefresh = false}) async {
    await _connectivityService.initialize();
    if (!_connectivityService.isConnected && !forceRefresh) {
      final cached = await _cache.get<Map<String, dynamic>>(
        'roomspaces',
        allowExpired: true,
      );
      if (cached != null) return cached;
    }
    return await smartFetch(
      screenKey: ScreenKeys.roomspaces,
      cacheKey: 'roomspaces',
      apiCall: () => _api.getRoomspaces(),
      customRefreshInterval: const Duration(minutes: 15),
      forceRefresh: forceRefresh,
    );
  }

  /// Get roomspace expenses with smart caching
  Future<Map<String, dynamic>> getRoomspaceExpenses(
    String roomspaceId, {
    int? limit,
    int? offset,
    DateTime? month,
    bool forceRefresh = false,
  }) async {
    final cacheKey = 'expenses_${roomspaceId}_${limit ?? 'all'}_${offset ?? 0}_${month?.toString() ?? 'all'}';
    
    await _connectivityService.initialize();
    final isOnline = _connectivityService.isConnected;
    if (isOnline) {
      try {
        final remote = await smartFetch(
          screenKey: ScreenKeys.roomspaceExpenses(roomspaceId),
          cacheKey: cacheKey,
          apiCall: () => _api.getRoomspaceExpenses(roomspaceId, limit: limit, offset: offset, month: month),
          customRefreshInterval: const Duration(minutes: 3),
          forceRefresh: forceRefresh,
        );

        final remoteList = _extractMapList(remote['data'])
            .map(ExpenseData.fromJson)
            .toList();
        for (final expense in remoteList) {
          await _localDb.saveExpense(expense, isSynced: true);
        }
        final unsyncedLocal = await _offlineExpenseService.getUnsyncedExpenses(
          roomspaceId: roomspaceId,
        );

        final merged = _mergeAndSortExpenses(unsyncedLocal, remoteList);
        return {
          'success': true,
          'data': merged.map(_expenseToUiMap).toList(),
          'meta': remote['meta'] ?? {'count': merged.length, 'offset': offset ?? 0, 'limit': limit ?? merged.length},
        };
      } catch (_) {
        // Fall back to local data quickly if API fails.
      }
    }

    final localExpenses = await _offlineExpenseService.getRoomspaceExpenses(
      roomspaceId,
      limit: limit,
      offset: offset,
      forceSync: false,
    );
    List<ExpenseData> cachedExpenses = [];
    final cached = await _cache.get<Map<String, dynamic>>(
      cacheKey,
      allowExpired: true,
    );
    if (cached != null) {
      cachedExpenses = _extractMapList(cached['data'])
          .map(ExpenseData.fromJson)
          .toList();
    }
    final mergedOffline = _mergeAndSortExpenses(localExpenses, cachedExpenses);
    return {
      'success': true,
      'data': mergedOffline.map(_expenseToUiMap).toList(),
      'meta': {
        'limit': limit ?? mergedOffline.length,
        'offset': offset ?? 0,
        'count': mergedOffline.length,
      },
    };
  }

  /// Get personal expenses with smart caching
  Future<Map<String, dynamic>> getPersonalExpenses({
    String? roomspaceId,
    int? limit,
    int? offset,
    DateTime? month,
    bool forceRefresh = false,
  }) async {
    final cacheKey = 'personal_expenses_${roomspaceId ?? 'all'}_${limit ?? 'all'}_${offset ?? 0}_${month?.toString() ?? 'all'}';
    
    await _connectivityService.initialize();
    final isOnline = _connectivityService.isConnected;
    if (isOnline) {
      try {
        final remote = await smartFetch(
          screenKey: ScreenKeys.personalExpenses,
          cacheKey: cacheKey,
          apiCall: () => _api.getPersonalExpenses(roomspaceId: roomspaceId, limit: limit, offset: offset, month: month),
          customRefreshInterval: const Duration(minutes: 3),
          forceRefresh: forceRefresh,
        );

        final remoteList = (remote['data'] as List<dynamic>? ?? const [])
            .map((e) => PersonalExpenseData.fromJson(e as Map<String, dynamic>))
            .toList();
        for (final expense in remoteList) {
          await _localDb.savePersonalExpense(expense, isSynced: true);
        }
        final unsyncedLocal = await _offlineExpenseService.getUnsyncedPersonalExpenses();
        final merged = <PersonalExpenseData>[
          ...unsyncedLocal,
          ...remoteList,
        ];
        return {
          'success': true,
          'data': merged.map((e) => e.toJson()).toList(),
          'meta': remote['meta'] ?? {'count': merged.length, 'offset': offset ?? 0, 'limit': limit ?? merged.length},
        };
      } catch (_) {
        // Fall back to local data quickly if API fails.
      }
    }

    final expenses = await _offlineExpenseService.getPersonalExpenses(
      limit: limit,
      offset: offset,
      forceSync: false,
    );
    if (expenses.isEmpty) {
      final cached = await _cache.get<Map<String, dynamic>>(
        cacheKey,
        allowExpired: true,
      );
      if (cached != null) return cached;
    }
    return {
      'success': true,
      'data': expenses.map((e) => e.toJson()).toList(),
      'meta': {
        'limit': limit ?? expenses.length,
        'offset': offset ?? 0,
        'count': expenses.length,
      },
    };
  }

  /// Get roomspace balances with smart caching
  Future<Map<String, dynamic>> getRoomspaceBalances(String roomspaceId, {bool forceRefresh = false}) async {
    await _connectivityService.initialize();
    if (!_connectivityService.isConnected) {
      final cached = await _cache.get<Map<String, dynamic>>(
        'balances_$roomspaceId',
        allowExpired: true,
      );
      if (cached != null) return cached;
    }
    return await smartFetch(
      screenKey: ScreenKeys.roomspaceBalances(roomspaceId),
      cacheKey: 'balances_$roomspaceId',
      apiCall: () => _api.getRoomspaceBalances(roomspaceId),
      customRefreshInterval: const Duration(minutes: 2),
      forceRefresh: forceRefresh,
    );
  }

  /// Get roomspace members with smart caching
  Future<Map<String, dynamic>> getRoomspaceMembers(String roomspaceId, {bool forceRefresh = false}) async {
    await _connectivityService.initialize();
    if (!_connectivityService.isConnected) {
      final cached = await _cache.get<Map<String, dynamic>>(
        'members_$roomspaceId',
        allowExpired: true,
      );
      if (cached != null) return cached;
    }
    return await smartFetch(
      screenKey: 'members_$roomspaceId',
      cacheKey: 'members_$roomspaceId',
      apiCall: () => _api.getRoomspaceMembers(roomspaceId),
      customRefreshInterval: const Duration(minutes: 15),
      forceRefresh: forceRefresh,
    );
  }

  /// Get notifications with smart caching
  Future<Map<String, dynamic>> getNotifications({bool forceRefresh = false}) async {
    await _connectivityService.initialize();
    if (!_connectivityService.isConnected) {
      final cached = await _cache.get<Map<String, dynamic>>(
        'notifications',
        allowExpired: true,
      );
      if (cached != null) return cached;
    }
    return await smartFetch(
      screenKey: ScreenKeys.notifications,
      cacheKey: 'notifications',
      apiCall: () => _api.getNotifications(),
      customRefreshInterval: const Duration(minutes: 1),
      forceRefresh: forceRefresh,
    );
  }

  /// Create expense with cache invalidation
  Future<Map<String, dynamic>> createExpense(Map<String, dynamic> expenseData) async {
    await _connectivityService.initialize();
    final isOnline = _connectivityService.isConnected;
    final request = ExpenseCreateRequest(
      roomspaceId: expenseData['roomspace_id']?.toString() ?? '',
      title: (expenseData['title'] ?? '').toString(),
      description: (expenseData['description'] ?? '').toString(),
      amount: (expenseData['amount'] as num).toDouble(),
      category: (expenseData['category'] ?? 'General').toString(),
      paidBy: expenseData['paid_by']?.toString(),
      splitType: (expenseData['split_type'] ?? 'EQUAL').toString(),
      selectedRoommates: ((expenseData['selected_roommates'] as List?) ?? const [])
          .map((e) => e.toString())
          .toList(),
      customSplits: (expenseData['custom_splits'] as Map?)
          ?.map((key, value) => MapEntry(key.toString(), (value as num).toDouble())),
      payerAmounts: (expenseData['payer_amounts'] as Map?)
          ?.map((key, value) => MapEntry(key.toString(), (value as num).toDouble())),
      recurringConfig: expenseData['recurring_config'] is Map<String, dynamic>
          ? RecurringExpenseConfig.fromJson(
              expenseData['recurring_config'] as Map<String, dynamic>,
            )
          : null,
    );
    final created = await _offlineExpenseService.createExpense(request);
    final result = {
      'success': true,
      'data': _expenseToUiMap(created),
    };
    
    // Invalidate related caches
    final roomspaceId = expenseData['roomspace_id']?.toString();
    if (roomspaceId != null) {
      if (isOnline) {
        await _cache.invalidateExpenseRelated(roomspaceId);
      }
      _state.forceRefresh(ScreenKeys.roomspaceExpenses(roomspaceId));
      if (isOnline) {
        _state.forceRefresh(ScreenKeys.roomspaceBalances(roomspaceId));
      }
      _state.forceRefresh(ScreenKeys.dashboard);
      
      // Trigger real-time update
      _realTimeService.notifyExpenseCreated(
        roomspaceId,
        (result['data'] as Map<String, dynamic>?) ?? expenseData,
      );
    }
    
    return result;
  }

  /// Create personal expense with cache invalidation
  Future<Map<String, dynamic>> createPersonalExpense(Map<String, dynamic> expenseData) async {
    final request = PersonalExpenseCreateRequest(
      title: (expenseData['title'] ?? '').toString(),
      amount: (expenseData['amount'] as num).toDouble(),
      description: (expenseData['description'] ?? '').toString(),
      category: (expenseData['category'] ?? 'General').toString(),
    );
    final created = await _offlineExpenseService.createPersonalExpense(request);
    final result = {
      'success': true,
      'data': created.toJson(),
    };
    
    // Invalidate related caches
    await _cache.invalidateExpenseRelated('personal');
    _state.forceRefresh(ScreenKeys.personalExpenses);
    _state.forceRefresh(ScreenKeys.dashboard);
    
    // Trigger real-time update
    _realTimeService.notifyPersonalExpenseCreated(
      (result['data'] as Map<String, dynamic>?) ?? expenseData,
    );
    
    return result;
  }

  /// Update expense with cache invalidation
  Future<Map<String, dynamic>> updateExpense(int expenseId, Map<String, dynamic> expenseData) async {
    final result = await _api.updateExpense(expenseId, expenseData);
    
    // Invalidate related caches
    final roomspaceId = expenseData['roomspace_id']?.toString();
    if (roomspaceId != null) {
      await _cache.invalidateExpenseRelated(roomspaceId);
      _state.forceRefresh(ScreenKeys.roomspaceExpenses(roomspaceId));
      _state.forceRefresh(ScreenKeys.roomspaceBalances(roomspaceId));
      
      // Trigger real-time update
      final affectedUsers = (expenseData['splits'] as List?)
          ?.map((split) => split['user_id']?.toString())
          .where((id) => id != null)
          .cast<String>()
          .toList() ?? [];
      _realTimeService.notifyExpenseUpdated(roomspaceId, result['data'] ?? expenseData, affectedUsers);
    }
    _state.forceRefresh(ScreenKeys.dashboard);
    
    return result;
  }

  /// Delete expense with cache invalidation
  Future<Map<String, dynamic>> deleteExpense(int expenseId) async {
    final result = await _api.deleteExpense(expenseId);
    
    // Invalidate all expense-related caches
    await _cache.clearAll(); // Safe approach for delete operations
    _state.forceRefresh(ScreenKeys.dashboard);
    _state.forceRefresh(ScreenKeys.expenses);
    _state.forceRefresh(ScreenKeys.personalExpenses);
    
    // Trigger real-time update (roomspace ID would need to be passed or extracted)
    _realTimeService.clearAllData(); // Clear all caches to ensure consistency
    
    return result;
  }

  /// Join roomspace with cache invalidation
  Future<Map<String, dynamic>> joinRoomspace(int id) async {
    final result = await _api.joinRoomspace(id);
    
    // Invalidate roomspace-related caches
    await _cache.invalidateRoomspaceRelated(id.toString());
    _state.forceRefresh(ScreenKeys.roomspaces);
    _state.forceRefresh(ScreenKeys.dashboard);
    
    return result;
  }

  /// Create roomspace with cache invalidation
  Future<Map<String, dynamic>> createRoomspace({required String name, String? description}) async {
    final result = await _api.createRoomspace(name: name, description: description);
    
    // Invalidate roomspace list
    _state.forceRefresh(ScreenKeys.roomspaces);
    _state.forceRefresh(ScreenKeys.dashboard);
    
    return result;
  }

  /// Update user profile with cache invalidation
  Future<Map<String, dynamic>> updateUserProfile({
    String? name,
    String? phone,
    String? qrImageUrl,
  }) async {
    final result = await _api.updateUserProfile(
      name: name,
      phone: phone,
      qrImageUrl: qrImageUrl,
    );
    
    // Invalidate user-related caches
    await _cache.invalidateUserRelated();
    _state.forceRefresh(ScreenKeys.profile);
    
    return result;
  }

  /// Login with cache clearing
  Future<Map<String, dynamic>> login(String firebaseToken) async {
    final result = await _api.login(firebaseToken);
    
    // Clear all cache on login
    await _cache.clearAll();
    _state.clearAll();
    
    return result;
  }

  /// Logout with cache clearing
  Future<Map<String, dynamic>> logout() async {
    final result = await _api.logout();
    
    // Clear all cache on logout
    await _cache.clearAll();
    _state.clearAll();
    
    return result;
  }

  /// Check if screen needs refresh
  bool needsRefresh(String screenKey) {
    return _state.needsRefresh(screenKey);
  }

  /// Force refresh for screen
  void forceRefresh(String screenKey) {
    _state.forceRefresh(screenKey);
  }

  /// Get loading state
  bool isLoading(String screenKey) {
    return _state.isLoading(screenKey);
  }

  /// Get error state
  String? getError(String screenKey) {
    return _state.getError(screenKey);
  }

  /// Clear error state
  void clearError(String screenKey) {
    _state.clearError(screenKey);
  }

  /// Get cache and state statistics
  Map<String, dynamic> getStats() {
    return {
      'cache': _cache.getStats(),
      'state': _state.getStats(),
    };
  }

  /// Preload common data
  Future<void> preloadCommonData() async {
    try {
      debugPrint('🚀 Preloading common data...');
      
      // Preload in parallel without waiting
      unawaited(getUserProfile());
      unawaited(getRoomspaces());
      unawaited(getNotifications());
      
      _state.preloadCommonScreens();
      
      debugPrint('✅ Common data preload initiated');
    } catch (e) {
      debugPrint('⚠️ Preload failed: $e');
    }
  }

  /// Clear all cache and state
  Future<void> clearAll() async {
    await _cache.clearAll();
    _state.clearAll();
  }

  // Pass-through methods that don't need caching
  Future<Map<String, dynamic>> verifySession() => _api.verifySession();
  Future<Map<String, dynamic>> refreshSession() => _api.refreshSession();
  Future<Map<String, dynamic>> searchRoomspaceByCode(String code) => _api.searchRoomspaceByCode(code);
  Future<Map<String, dynamic>> joinRoomspaceByCode(String code) => _api.joinRoomspaceByCode(code);
  Future<Map<String, dynamic>> getExpenses({String? roomspaceId, int? limit, int? offset}) => _api.getExpenses(roomspaceId: roomspaceId, limit: limit, offset: offset);
  Future<Map<String, dynamic>> getExpenseById(int expenseId) => _api.getExpenseById(expenseId);
  Future<Map<String, dynamic>> removeMemberFromRoomspace(String roomspaceId, String memberFirebaseUid) => _api.removeMemberFromRoomspace(roomspaceId, memberFirebaseUid);
  Future<Map<String, dynamic>> leaveRoomspace(String roomspaceId) => _api.leaveRoomspace(roomspaceId);
  Future<Map<String, dynamic>> getSettlements({required String roomspaceId, int? limit, int? offset}) => _api.getSettlements(roomspaceId: roomspaceId, limit: limit, offset: offset);
  Future<Map<String, dynamic>> createPaymentNotification(Map<String, dynamic> notificationData) => _api.createPaymentNotification(notificationData);
  Future<Map<String, dynamic>> getPaymentNotifications({String? roomspaceId, int? limit, int? offset}) => _api.getPaymentNotifications(roomspaceId: roomspaceId, limit: limit, offset: offset);
  Future<Map<String, dynamic>> getPaymentNotification(int notificationId) => _api.getPaymentNotification(notificationId);
  Future<Map<String, dynamic>> markPaymentNotificationAsProcessed(int notificationId, {int? expenseId}) => _api.markPaymentNotificationAsProcessed(notificationId, expenseId: expenseId);
  Future<Map<String, dynamic>> deletePaymentNotification(int notificationId) => _api.deletePaymentNotification(notificationId);
  Future<void> clearCookies() => _api.clearCookies();
}

/// Extension to use unawaited safely
extension UnawaiteExtension on Future {
  void unawaited() {}
}
