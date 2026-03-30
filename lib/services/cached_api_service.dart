import 'api_service.dart';
import 'cache_service.dart';

class CachedApiService {
  static final CachedApiService _instance = CachedApiService._internal();
  factory CachedApiService() => _instance;
  CachedApiService._internal();

  final ApiService _apiService = ApiService();
  final CacheService _cacheService = CacheService();

  // Cached API methods
  Future<Map<String, dynamic>> getRoomspaces({bool forceRefresh = false}) async {
    if (!forceRefresh) {
      final cached = await _cacheService.getCachedRoomspaces();
      if (cached != null) {
        print('📦 Using cached roomspaces');
        return cached;
      }
    }

    print('🌐 Fetching roomspaces from API');
    final data = await _apiService.getRoomspaces();
    await _cacheService.cacheRoomspaces(data);
    return data;
  }

  Future<Map<String, dynamic>> getUserProfile({bool forceRefresh = false}) async {
    if (!forceRefresh) {
      final cached = await _cacheService.getCachedUserProfile();
      if (cached != null) {
        print('📦 Using cached user profile');
        return cached;
      }
    }

    print('🌐 Fetching user profile from API');
    final data = await _apiService.getUserProfile();
    await _cacheService.cacheUserProfile(data);
    return data;
  }

  Future<Map<String, dynamic>> getRoomspace(int id, {bool forceRefresh = false}) async {
    final roomspaceId = id.toString();
    
    if (!forceRefresh) {
      final cached = await _cacheService.getCachedRoomspace(roomspaceId);
      if (cached != null) {
        print('📦 Using cached roomspace $roomspaceId');
        return cached;
      }
    }

    print('🌐 Fetching roomspace $roomspaceId from API');
    final data = await _apiService.getRoomspace(id);
    await _cacheService.cacheRoomspace(roomspaceId, data);
    return data;
  }

  Future<Map<String, dynamic>> getRoomspaceBalances(String roomspaceId, {bool forceRefresh = false}) async {
    if (!forceRefresh) {
      final cached = await _cacheService.getCachedBalances(roomspaceId);
      if (cached != null) {
        print('📦 Using cached balances for roomspace $roomspaceId');
        return cached;
      }
    }

    print('🌐 Fetching balances for roomspace $roomspaceId from API');
    final data = await _apiService.getRoomspaceBalances(roomspaceId);
    await _cacheService.cacheBalances(roomspaceId, data);
    return data;
  }

  Future<Map<String, dynamic>> getRoomspaceExpenses(
    String roomspaceId, {
    int? limit,
    int? offset,
    DateTime? month,
    bool forceRefresh = false,
  }) async {
    final cacheKey = '${roomspaceId}_${limit ?? 'all'}_${offset ?? 0}_${month?.toString() ?? 'all'}';
    
    if (!forceRefresh) {
      final cached = await _cacheService.getCachedExpenses(cacheKey);
      if (cached != null) {
        print('📦 Using cached expenses for roomspace $roomspaceId');
        return cached;
      }
    }

    print('🌐 Fetching expenses for roomspace $roomspaceId from API');
    final data = await _apiService.getRoomspaceExpenses(
      roomspaceId,
      limit: limit,
      offset: offset,
      month: month,
    );
    await _cacheService.cacheExpenses(cacheKey, data);
    return data;
  }

  Future<Map<String, dynamic>> getPersonalExpenses({
    String? roomspaceId,
    int? limit,
    int? offset,
    DateTime? month,
    bool forceRefresh = false,
  }) async {
    final cacheKey = 'personal_${roomspaceId ?? 'all'}_${limit ?? 'all'}_${offset ?? 0}_${month?.toString() ?? 'all'}';
    
    if (!forceRefresh) {
      final cached = await _cacheService.getCachedExpenses(cacheKey);
      if (cached != null) {
        print('📦 Using cached personal expenses');
        return cached;
      }
    }

    print('🌐 Fetching personal expenses from API');
    final data = await _apiService.getPersonalExpenses(
      roomspaceId: roomspaceId,
      limit: limit,
      offset: offset,
      month: month,
    );
    await _cacheService.cacheExpenses(cacheKey, data);
    return data;
  }

  Future<Map<String, dynamic>> getRoomspaceMembers(String roomspaceId, {bool forceRefresh = false}) async {
    if (!forceRefresh) {
      final cached = await _cacheService.getCachedMembers(roomspaceId);
      if (cached != null) {
        print('📦 Using cached members for roomspace $roomspaceId');
        return cached;
      }
    }

    print('🌐 Fetching members for roomspace $roomspaceId from API');
    final data = await _apiService.getRoomspaceMembers(roomspaceId);
    await _cacheService.cacheMembers(roomspaceId, data);
    return data;
  }

  // Methods that modify data - these should invalidate cache
  Future<Map<String, dynamic>> createExpense(Map<String, dynamic> expenseData) async {
    final result = await _apiService.createExpense(expenseData);
    
    // Invalidate related caches
    final roomspaceId = expenseData['roomspace_id']?.toString();
    if (roomspaceId != null) {
      await _cacheService.invalidateExpenseCache(roomspaceId);
    }
    
    return result;
  }

  Future<Map<String, dynamic>> createPersonalExpense(Map<String, dynamic> expenseData) async {
    final result = await _apiService.createPersonalExpense(expenseData);
    
    // Invalidate personal expense caches
    await _cacheService.clearCache(); // Clear all for simplicity
    
    return result;
  }

  Future<Map<String, dynamic>> updateExpense(int expenseId, Map<String, dynamic> expenseData) async {
    final result = await _apiService.updateExpense(expenseId, expenseData);
    
    // Invalidate related caches
    final roomspaceId = expenseData['roomspace_id']?.toString();
    if (roomspaceId != null) {
      await _cacheService.invalidateExpenseCache(roomspaceId);
    }
    
    return result;
  }

  Future<Map<String, dynamic>> deleteExpense(int expenseId) async {
    final result = await _apiService.deleteExpense(expenseId);
    
    // Clear all expense-related caches since we don't know which roomspace
    await _cacheService.clearCache();
    
    return result;
  }

  Future<Map<String, dynamic>> deletePersonalExpense(int expenseId) async {
    final result = await _apiService.deletePersonalExpense(expenseId);
    
    // Clear personal expense caches
    await _cacheService.clearCache();
    
    return result;
  }

  Future<Map<String, dynamic>> createRoomspace({required String name, String? description}) async {
    final result = await _apiService.createRoomspace(name: name, description: description);
    
    // Invalidate roomspaces list
    await _cacheService.clearCache(CacheService.roomspacesKey);
    
    return result;
  }

  Future<Map<String, dynamic>> joinRoomspace(int id) async {
    final result = await _apiService.joinRoomspace(id);
    
    // Invalidate roomspaces list and specific roomspace
    await _cacheService.clearCache(CacheService.roomspacesKey);
    await _cacheService.invalidateRoomspaceCache(id.toString());
    
    return result;
  }

  Future<Map<String, dynamic>> joinRoomspaceByCode(String code) async {
    final result = await _apiService.joinRoomspaceByCode(code);
    
    // Invalidate roomspaces list
    await _cacheService.clearCache(CacheService.roomspacesKey);
    
    return result;
  }

  // Pass-through methods that don't need caching
  Future<Map<String, dynamic>> login(String firebaseToken) async {
    final result = await _apiService.login(firebaseToken);
    // Clear all cache on login
    await _cacheService.clearCache();
    return result;
  }

  Future<Map<String, dynamic>> logout() async {
    final result = await _apiService.logout();
    // Clear all cache on logout
    await _cacheService.clearCache();
    return result;
  }

  Future<Map<String, dynamic>> updateUserProfile({String? name, String? phone}) async {
    final result = await _apiService.updateUserProfile(name: name, phone: phone);
    // Invalidate user profile cache
    await _cacheService.clearCache(CacheService.userProfileKey);
    return result;
  }

  // Direct pass-through for methods that don't benefit from caching
  Future<Map<String, dynamic>> verifySession() => _apiService.verifySession();
  Future<Map<String, dynamic>> refreshSession() => _apiService.refreshSession();
  Future<Map<String, dynamic>> searchRoomspaceByCode(String code) => _apiService.searchRoomspaceByCode(code);
  Future<Map<String, dynamic>> getNotifications() => _apiService.getNotifications();
  Future<Map<String, dynamic>> markNotificationAsRead(int id) => _apiService.markNotificationAsRead(id);
  Future<Map<String, dynamic>> getJoinRequests() => _apiService.getJoinRequests();
  Future<Map<String, dynamic>> getPendingJoinRequest() => _apiService.getPendingJoinRequest();
  Future<Map<String, dynamic>> processJoinRequest(String requestId, bool accept) => _apiService.processJoinRequest(requestId, accept);
  Future<Map<String, dynamic>> getExpenses({String? roomspaceId, int? limit, int? offset}) => _apiService.getExpenses(roomspaceId: roomspaceId, limit: limit, offset: offset);
  Future<Map<String, dynamic>> getExpenseById(int expenseId) => _apiService.getExpenseById(expenseId);
  Future<Map<String, dynamic>> getRecentExpenses({String? roomspaceId, int limit = 3, DateTime? month}) => _apiService.getRecentExpenses(roomspaceId: roomspaceId, limit: limit, month: month);
  Future<Map<String, dynamic>> removeMemberFromRoomspace(int roomspaceId, String memberFirebaseUid) => _apiService.removeMemberFromRoomspace(roomspaceId, memberFirebaseUid);
  Future<Map<String, dynamic>> getSettlements({required String roomspaceId, int? limit, int? offset}) => _apiService.getSettlements(roomspaceId: roomspaceId, limit: limit, offset: offset);
  Future<Map<String, dynamic>> createPaymentNotification(Map<String, dynamic> notificationData) => _apiService.createPaymentNotification(notificationData);
  Future<Map<String, dynamic>> getPaymentNotifications({String? roomspaceId, int? limit, int? offset}) => _apiService.getPaymentNotifications(roomspaceId: roomspaceId, limit: limit, offset: offset);
  Future<Map<String, dynamic>> getPaymentNotification(int notificationId) => _apiService.getPaymentNotification(notificationId);
  Future<Map<String, dynamic>> markPaymentNotificationAsProcessed(int notificationId, {int? expenseId}) => _apiService.markPaymentNotificationAsProcessed(notificationId, expenseId: expenseId);
  Future<Map<String, dynamic>> deletePaymentNotification(int notificationId) => _apiService.deletePaymentNotification(notificationId);

  // Utility methods
  Future<void> clearAllCache() async {
    await _cacheService.clearCache();
  }

  Future<void> preloadData() async {
    try {
      // Preload commonly used data
      print('🚀 Preloading data...');
      
      // Load user profile and roomspaces in parallel
      await Future.wait([
        getUserProfile(),
        getRoomspaces(),
      ]);
      
      print('✅ Data preloaded successfully');
    } catch (e) {
      print('⚠️ Preload failed: $e');
    }
  }
}