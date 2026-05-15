import 'dart:convert';
import 'dart:async';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/foundation.dart';

/// Advanced caching service with multi-level caching and offline support
class AdvancedCacheService {
  static final AdvancedCacheService _instance = AdvancedCacheService._internal();
  factory AdvancedCacheService() => _instance;
  AdvancedCacheService._internal();

  // Memory cache for instant access
  final Map<String, _CacheEntry> _memoryCache = {};
  
  // Cache configuration
  static const Duration _shortCache = Duration(minutes: 2);   // Balances, notifications
  static const Duration _mediumCache = Duration(minutes: 10); // Expenses, members
  static const Duration _longCache = Duration(hours: 1);      // Profile, roomspaces
  
  // Cache keys
  static const String _userProfileKey = 'user_profile';
  static const String _roomspacesKey = 'roomspaces';
  static const String _expensesPrefix = 'expenses_';
  static const String _balancesPrefix = 'balances_';
  static const String _membersPrefix = 'members_';
  static const String _notificationsKey = 'notifications';
  static const String _analyticsPrefix = 'analytics_';

  /// Get data with multi-level caching (memory -> disk -> network)
  Future<T?> get<T>(
    String key, {
    Duration? maxAge,
    bool forceRefresh = false,
  }) async {
    if (forceRefresh) {
      await _invalidate(key);
      return null;
    }

    // Check memory cache first
    final memoryEntry = _memoryCache[key];
    if (memoryEntry != null && !memoryEntry.isExpired(maxAge)) {
      debugPrint('📦 Memory cache hit: $key');
      return memoryEntry.data as T?;
    }

    // Check disk cache
    final diskData = await _getDiskCache<T>(key, maxAge);
    if (diskData != null) {
      // Store in memory for faster access
      _memoryCache[key] = _CacheEntry(diskData, DateTime.now());
      debugPrint('💾 Disk cache hit: $key');
      return diskData;
    }

    debugPrint('❌ Cache miss: $key');
    return null;
  }

  /// Store data in both memory and disk cache
  Future<void> set<T>(
    String key,
    T data, {
    Duration? ttl,
  }) async {
    final now = DateTime.now();
    
    // Store in memory
    _memoryCache[key] = _CacheEntry(data, now);
    
    // Store on disk
    await _setDiskCache(key, data, ttl ?? _mediumCache);
    
    debugPrint('💾 Cached: $key (TTL: ${ttl ?? _mediumCache})');
  }

  /// Get data from disk cache
  Future<T?> _getDiskCache<T>(String key, Duration? maxAge) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final cacheString = prefs.getString('cache_$key');
      
      if (cacheString == null) return null;
      
      final cacheData = jsonDecode(cacheString) as Map<String, dynamic>;
      final timestamp = DateTime.fromMillisecondsSinceEpoch(cacheData['timestamp'] as int);
      final ttl = Duration(milliseconds: cacheData['ttl'] as int);
      
      // Check if expired
      final age = DateTime.now().difference(timestamp);
      final effectiveMaxAge = maxAge ?? ttl;
      
      if (age > effectiveMaxAge) {
        await prefs.remove('cache_$key');
        return null;
      }
      
      return cacheData['data'] as T?;
    } catch (e) {
      debugPrint('❌ Disk cache error for $key: $e');
      return null;
    }
  }

  /// Store data on disk
  Future<void> _setDiskCache<T>(String key, T data, Duration ttl) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final cacheData = {
        'data': data,
        'timestamp': DateTime.now().millisecondsSinceEpoch,
        'ttl': ttl.inMilliseconds,
      };
      await prefs.setString('cache_$key', jsonEncode(cacheData));
    } catch (e) {
      debugPrint('❌ Disk cache write error for $key: $e');
    }
  }

  /// Invalidate specific cache entry
  Future<void> _invalidate(String key) async {
    _memoryCache.remove(key);
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('cache_$key');
  }

  /// Clear all cache
  Future<void> clearAll() async {
    _memoryCache.clear();
    final prefs = await SharedPreferences.getInstance();
    final keys = prefs.getKeys().where((k) => k.startsWith('cache_')).toList();
    for (final key in keys) {
      await prefs.remove(key);
    }
    debugPrint('🗑️ All cache cleared');
  }

  /// Clear expired entries
  Future<void> clearExpired() async {
    // Clear expired memory cache
    final now = DateTime.now();
    _memoryCache.removeWhere((key, entry) => entry.isExpired());
    
    // Clear expired disk cache
    final prefs = await SharedPreferences.getInstance();
    final keys = prefs.getKeys().where((k) => k.startsWith('cache_')).toList();
    
    for (final key in keys) {
      try {
        final cacheString = prefs.getString(key);
        if (cacheString != null) {
          final cacheData = jsonDecode(cacheString) as Map<String, dynamic>;
          final timestamp = DateTime.fromMillisecondsSinceEpoch(cacheData['timestamp'] as int);
          final ttl = Duration(milliseconds: cacheData['ttl'] as int);
          
          if (now.difference(timestamp) > ttl) {
            await prefs.remove(key);
          }
        }
      } catch (e) {
        await prefs.remove(key); // Remove corrupted cache
      }
    }
    
    debugPrint('🧹 Expired cache cleared');
  }

  /// Get cache statistics
  Map<String, dynamic> getStats() {
    return {
      'memory_entries': _memoryCache.length,
      'memory_size_kb': _memoryCache.length * 0.5, // Rough estimate
    };
  }

  // Specific cache methods with appropriate TTLs
  
  Future<Map<String, dynamic>?> getUserProfile({bool forceRefresh = false}) async {
    return await get<Map<String, dynamic>>(
      _userProfileKey,
      maxAge: _longCache,
      forceRefresh: forceRefresh,
    );
  }

  Future<void> setUserProfile(Map<String, dynamic> data) async {
    await set(_userProfileKey, data, ttl: _longCache);
  }

  Future<Map<String, dynamic>?> getRoomspaces({bool forceRefresh = false}) async {
    return await get<Map<String, dynamic>>(
      _roomspacesKey,
      maxAge: _longCache,
      forceRefresh: forceRefresh,
    );
  }

  Future<void> setRoomspaces(Map<String, dynamic> data) async {
    await set(_roomspacesKey, data, ttl: _longCache);
  }

  Future<Map<String, dynamic>?> getExpenses(String key, {bool forceRefresh = false}) async {
    return await get<Map<String, dynamic>>(
      '$_expensesPrefix$key',
      maxAge: _mediumCache,
      forceRefresh: forceRefresh,
    );
  }

  Future<void> setExpenses(String key, Map<String, dynamic> data) async {
    await set('$_expensesPrefix$key', data, ttl: _mediumCache);
  }

  Future<Map<String, dynamic>?> getBalances(String roomspaceId, {bool forceRefresh = false}) async {
    return await get<Map<String, dynamic>>(
      '$_balancesPrefix$roomspaceId',
      maxAge: _shortCache,
      forceRefresh: forceRefresh,
    );
  }

  Future<void> setBalances(String roomspaceId, Map<String, dynamic> data) async {
    await set('$_balancesPrefix$roomspaceId', data, ttl: _shortCache);
  }

  Future<Map<String, dynamic>?> getMembers(String roomspaceId, {bool forceRefresh = false}) async {
    return await get<Map<String, dynamic>>(
      '$_membersPrefix$roomspaceId',
      maxAge: _longCache,
      forceRefresh: forceRefresh,
    );
  }

  Future<void> setMembers(String roomspaceId, Map<String, dynamic> data) async {
    await set('$_membersPrefix$roomspaceId', data, ttl: _longCache);
  }

  Future<Map<String, dynamic>?> getNotifications({bool forceRefresh = false}) async {
    return await get<Map<String, dynamic>>(
      _notificationsKey,
      maxAge: _shortCache,
      forceRefresh: forceRefresh,
    );
  }

  Future<void> setNotifications(Map<String, dynamic> data) async {
    await set(_notificationsKey, data, ttl: _shortCache);
  }

  Future<Map<String, dynamic>?> getAnalytics(String key, {bool forceRefresh = false}) async {
    return await get<Map<String, dynamic>>(
      '$_analyticsPrefix$key',
      maxAge: _mediumCache,
      forceRefresh: forceRefresh,
    );
  }

  Future<void> setAnalytics(String key, Map<String, dynamic> data) async {
    await set('$_analyticsPrefix$key', data, ttl: _mediumCache);
  }

  /// Invalidate related caches when data changes
  Future<void> invalidateExpenseRelated(String roomspaceId) async {
    final keys = _memoryCache.keys.where((k) => 
      k.startsWith(_expensesPrefix) || 
      k == '$_balancesPrefix$roomspaceId'
    ).toList();
    
    for (final key in keys) {
      await _invalidate(key);
    }
    
    debugPrint('🗑️ Invalidated expense-related cache for roomspace $roomspaceId');
  }

  Future<void> invalidateRoomspaceRelated(String roomspaceId) async {
    final keys = _memoryCache.keys.where((k) => 
      k.contains(roomspaceId) || k == _roomspacesKey
    ).toList();
    
    for (final key in keys) {
      await _invalidate(key);
    }
    
    debugPrint('🗑️ Invalidated roomspace-related cache for $roomspaceId');
  }

  Future<void> invalidateUserRelated() async {
    await _invalidate(_userProfileKey);
    await _invalidate(_notificationsKey);
    debugPrint('🗑️ Invalidated user-related cache');
  }
}

/// Cache entry with timestamp
class _CacheEntry {
  final dynamic data;
  final DateTime timestamp;

  _CacheEntry(this.data, this.timestamp);

  bool isExpired([Duration? maxAge]) {
    if (maxAge == null) return false;
    return DateTime.now().difference(timestamp) > maxAge;
  }
}
