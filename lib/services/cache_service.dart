import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

class CacheService {
  static final CacheService _instance = CacheService._internal();
  factory CacheService() => _instance;
  CacheService._internal();

  static const Duration _defaultCacheDuration = Duration(minutes: 5);
  static const Duration _longCacheDuration = Duration(minutes: 30);

  // Cache keys
  // Keep this distinct from RoomspaceProvider's raw-list cache key
  // to avoid format collisions.
  static const String roomspacesKey = 'cached_roomspaces_api_v1';
  static const String userProfileKey = 'cached_user_profile';
  static const String roomspacePrefix = 'cached_roomspace_';
  static const String balancesPrefix = 'cached_balances_';
  static const String expensesPrefix = 'cached_expenses_';
  static const String membersPrefix = 'cached_members_';
  static const String notificationsKey = 'cached_notifications';
  static const String joinRequestsKey = 'cached_join_requests';

  Future<void> cacheData(String key, Map<String, dynamic> data, {Duration? duration}) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final cacheData = {
        'data': data,
        'timestamp': DateTime.now().millisecondsSinceEpoch,
        'duration': (duration ?? _defaultCacheDuration).inMilliseconds,
      };
      await prefs.setString(key, jsonEncode(cacheData));
    } catch (e) {
      print('Cache write error: $e');
    }
  }

  Future<Map<String, dynamic>?> getCachedData(String key, {bool allowExpired = false}) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final cachedString = prefs.getString(key);
      
      if (cachedString == null) return null;

      final decoded = jsonDecode(cachedString);

      // Legacy/plain payload support: if cached value is not the wrapped cache
      // envelope, normalize it into a response map directly.
      if (decoded is! Map<String, dynamic> ||
          !decoded.containsKey('timestamp') ||
          !decoded.containsKey('duration') ||
          !decoded.containsKey('data')) {
        if (decoded is Map<String, dynamic>) return decoded;
        if (decoded is List) return {'data': decoded, 'success': true};
        return null;
      }

      final cacheData = decoded;
      final timestamp = cacheData['timestamp'] as int;
      final duration = cacheData['duration'] as int;
      
      // Check if cache is still valid
      final now = DateTime.now().millisecondsSinceEpoch;
      if (now - timestamp > duration) {
        if (!allowExpired) {
          // Cache expired, remove it
          await prefs.remove(key);
          return null;
        }
      }
      
      final payload = cacheData['data'];
      if (payload is Map<String, dynamic>) return payload;
      if (payload is List) return {'data': payload, 'success': true};
      return null;
    } catch (e) {
      print('Cache read error: $e');
      return null;
    }
  }

  Future<void> clearCache([String? key]) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      if (key != null) {
        await prefs.remove(key);
      } else {
        // Clear all cache
        final keys = prefs.getKeys().where((k) => k.startsWith('cached_')).toList();
        for (final k in keys) {
          await prefs.remove(k);
        }
      }
    } catch (e) {
      print('Cache clear error: $e');
    }
  }

  // Specific cache methods
  Future<void> cacheRoomspaces(Map<String, dynamic> data) async {
    await cacheData(roomspacesKey, data, duration: _longCacheDuration);
  }

  Future<Map<String, dynamic>?> getCachedRoomspaces({bool allowExpired = false}) async {
    return await getCachedData(roomspacesKey, allowExpired: allowExpired);
  }

  Future<void> cacheUserProfile(Map<String, dynamic> data) async {
    await cacheData(userProfileKey, data, duration: _longCacheDuration);
  }

  Future<Map<String, dynamic>?> getCachedUserProfile({bool allowExpired = false}) async {
    return await getCachedData(userProfileKey, allowExpired: allowExpired);
  }

  Future<void> cacheRoomspace(String roomspaceId, Map<String, dynamic> data) async {
    await cacheData('$roomspacePrefix$roomspaceId', data, duration: _longCacheDuration);
  }

  Future<Map<String, dynamic>?> getCachedRoomspace(String roomspaceId, {bool allowExpired = false}) async {
    return await getCachedData('$roomspacePrefix$roomspaceId', allowExpired: allowExpired);
  }

  Future<void> cacheBalances(String roomspaceId, Map<String, dynamic> data) async {
    await cacheData('$balancesPrefix$roomspaceId', data, duration: const Duration(minutes: 2));
  }

  Future<Map<String, dynamic>?> getCachedBalances(String roomspaceId, {bool allowExpired = false}) async {
    return await getCachedData('$balancesPrefix$roomspaceId', allowExpired: allowExpired);
  }

  Future<void> cacheExpenses(String key, Map<String, dynamic> data) async {
    await cacheData('$expensesPrefix$key', data, duration: const Duration(minutes: 3));
  }

  Future<Map<String, dynamic>?> getCachedExpenses(String key, {bool allowExpired = false}) async {
    return await getCachedData('$expensesPrefix$key', allowExpired: allowExpired);
  }

  Future<void> cacheMembers(String roomspaceId, Map<String, dynamic> data) async {
    await cacheData('$membersPrefix$roomspaceId', data, duration: _longCacheDuration);
  }

  Future<Map<String, dynamic>?> getCachedMembers(String roomspaceId, {bool allowExpired = false}) async {
    return await getCachedData('$membersPrefix$roomspaceId', allowExpired: allowExpired);
  }

  Future<void> cacheNotifications(Map<String, dynamic> data) async {
    await cacheData(notificationsKey, data, duration: const Duration(minutes: 2));
  }

  Future<Map<String, dynamic>?> getCachedNotifications({bool allowExpired = false}) async {
    return await getCachedData(notificationsKey, allowExpired: allowExpired);
  }

  Future<void> cacheJoinRequests(Map<String, dynamic> data) async {
    await cacheData(joinRequestsKey, data, duration: const Duration(minutes: 2));
  }

  Future<Map<String, dynamic>?> getCachedJoinRequests({bool allowExpired = false}) async {
    return await getCachedData(joinRequestsKey, allowExpired: allowExpired);
  }

  // Invalidate related caches when data changes
  Future<void> invalidateRoomspaceCache(String roomspaceId) async {
    await clearCache('$roomspacePrefix$roomspaceId');
    await clearCache('$balancesPrefix$roomspaceId');
    await clearCache('$membersPrefix$roomspaceId');
    await clearCache(roomspacesKey); // Also clear roomspaces list
  }

  Future<void> invalidateExpenseCache(String roomspaceId) async {
    final prefs = await SharedPreferences.getInstance();
    final keys = prefs.getKeys().where((k) => 
      k.startsWith(expensesPrefix) && k.contains(roomspaceId)).toList();
    for (final key in keys) {
      await prefs.remove(key);
    }
    await clearCache('$balancesPrefix$roomspaceId'); // Balances depend on expenses
  }
}
