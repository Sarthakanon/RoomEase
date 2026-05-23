import 'dart:async';
import 'cached_api_service.dart';

class PerformanceService {
  static final PerformanceService _instance = PerformanceService._internal();
  factory PerformanceService() => _instance;
  PerformanceService._internal();

  final CachedApiService _cachedApiService = CachedApiService();
  Timer? _preloadTimer;
  bool _isPreloading = false;

  /// Initialize performance optimizations
  Future<void> initialize() async {
    try {
      print('🚀 Initializing performance optimizations...');
      
      // Start background preloading
      _startBackgroundPreloading();
      
      print('✅ Performance service initialized');
    } catch (e) {
      print('❌ Performance service initialization failed: $e');
    }
  }

  /// Start background preloading of data
  void _startBackgroundPreloading() {
    // Preload data every 2 minutes to keep cache fresh
    _preloadTimer = Timer.periodic(const Duration(minutes: 2), (timer) {
      if (!_isPreloading) {
        _backgroundPreload();
      }
    });
  }

  /// Background preload without blocking UI
  Future<void> _backgroundPreload() async {
    if (_isPreloading) return;
    
    _isPreloading = true;
    try {
      print('🔄 Background preloading data...');
      
      // Preload in background without waiting
      unawaited(_cachedApiService.preloadData());
      
    } catch (e) {
      print('⚠️ Background preload failed: $e');
    } finally {
      _isPreloading = false;
    }
  }

  /// Preload data for a specific roomspace
  Future<void> preloadRoomspaceData(String roomspaceId) async {
    try {
      print('🚀 Preloading roomspace $roomspaceId data...');
      
      // Load roomspace data in parallel
      await Future.wait([
        _cachedApiService.getRoomspace(int.parse(roomspaceId)),
        _cachedApiService.getRoomspaceBalances(roomspaceId),
        _cachedApiService.getRoomspaceMembers(roomspaceId),
        _cachedApiService.getRoomspaceExpenses(roomspaceId, limit: 10),
      ]);
      
      print('✅ Roomspace $roomspaceId data preloaded');
    } catch (e) {
      print('⚠️ Roomspace preload failed: $e');
    }
  }

  /// Optimize network requests by batching
  Future<Map<String, dynamic>> batchLoadRoomspaceData(String roomspaceId) async {
    try {
      print('📦 Batch loading roomspace $roomspaceId data...');
      
      // Load all roomspace data in parallel
      final results = await Future.wait([
        _cachedApiService.getRoomspace(int.parse(roomspaceId)),
        _cachedApiService.getRoomspaceBalances(roomspaceId),
        _cachedApiService.getRoomspaceMembers(roomspaceId),
        _cachedApiService.getRoomspaceExpenses(roomspaceId, limit: 20),
      ]);
      
      return {
        'roomspace': results[0],
        'balances': results[1],
        'members': results[2],
        'expenses': results[3],
      };
    } catch (e) {
      print('❌ Batch load failed: $e');
      rethrow;
    }
  }

  /// Get optimized recent data for dashboard
  Future<Map<String, dynamic>> getDashboardData() async {
    try {
      print('📊 Loading dashboard data...');
      
      // Load dashboard data in parallel
      final results = await Future.wait([
        _cachedApiService.getRoomspaces(),
        _cachedApiService.getUserProfile(),
        _cachedApiService.getPersonalExpenses(limit: 5),
      ]);
      
      return {
        'roomspaces': results[0],
        'profile': results[1],
        'recent_expenses': results[2],
      };
    } catch (e) {
      print('❌ Dashboard load failed: $e');
      rethrow;
    }
  }

  /// Clear all caches and restart
  Future<void> refreshAllData() async {
    try {
      print('🔄 Refreshing all data...');
      
      await _cachedApiService.clearAllCache();
      await _cachedApiService.preloadData();
      
      print('✅ All data refreshed');
    } catch (e) {
      print('❌ Data refresh failed: $e');
    }
  }

  /// Dispose resources
  void dispose() {
    _preloadTimer?.cancel();
    _preloadTimer = null;
    _isPreloading = false;
  }
}

/// Extension to use unawaited safely
extension UnawaiteExtension on Future {
  void unawaited() {}
}