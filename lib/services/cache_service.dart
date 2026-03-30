import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

class CacheService {
  static final CacheService _instance = CacheService._internal();
  factory CacheService() => _instance;
  CacheService._internal();

  static const Duration _defaultCacheDuration = Duration(minutes: 5);
  static const Duration _longCacheDuration = Duration(minutes: 30);

  // Cache keys
  static const String roomspacesKey = 'cached_roomspaces';
  static const String userProfileKey = 'cached_user_profile';
  static const String roomspacePrefix = 'cached_roomspace_';
  static const String balancesPrefix = 'cached_balances_';
  static const String expensesPrefix = 'cached_expenses_';
  static const String membersPrefix = 'cached_members_';

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

  Future<Map<String, dynamic>?> getCachedData(String key) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final cachedString = prefs.getString(key);
      
      if (cachedString == null) return null;
      
      final cacheData = jsonDecode(cachedString) as Map<String, dynamic>;
      final timestamp = cacheData['timestamp'] as int;
      final duration = cacheData['duration'] as int;
      
      // Check if cache is still valid
      final now = DateTime.now().millisecondsSinceEpoch;
      if (now - timestamp > duration) {
        // Cache expired, remove it
        await prefs.remove(key);
        return null;
      }
      
      return cacheData['data'] as Map<String, dynamic>;
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

  Future<Map<String, dynamic>?> getCachedRoomspaces() async {
    return await getCachedData(roomspacesKey);
  }

  Future<void> cacheUserProfile(Map<String, dynamic> data) async {
    await cacheData(userProfileKey, data, duration: _longCacheDuration);
  }

  Future<Map<String, dynamic>?> getCachedUserProfile() async {
    return await getCachedData(userProfileKey);
  }

  Future<void> cacheRoomspace(String roomspaceId, Map<String, dynamic> data) async {
    await cacheData('$roomspacePrefix$roomspaceId', data, duration: _longCacheDuration);
  }

  Future<Map<String, dynamic>?> getCachedRoomspace(String roomspaceId) async {
    return await getCachedData('$roomspacePrefix$roomspaceId');
  }

  Future<void> cacheBalances(String roomspaceId, Map<String, dynamic> data) async {
    await cacheData('$balancesPrefix$roomspaceId', data, duration: const Duration(minutes: 2));
  }

  Future<Map<String, dynamic>?> getCachedBalances(String roomspaceId) async {
    return await getCachedData('$balancesPrefix$roomspaceId');
  }

  Future<void> cacheExpenses(String key, Map<String, dynamic> data) async {
    await cacheData('$expensesPrefix$key', data, duration: const Duration(minutes: 3));
  }

  Future<Map<String, dynamic>?> getCachedExpenses(String key) async {
    return await getCachedData('$expensesPrefix$key');
  }

  Future<void> cacheMembers(String roomspaceId, Map<String, dynamic> data) async {
    await cacheData('$membersPrefix$roomspaceId', data, duration: _longCacheDuration);
  }

  Future<Map<String, dynamic>?> getCachedMembers(String roomspaceId) async {
    return await getCachedData('$membersPrefix$roomspaceId');
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