import 'dart:async';
import 'package:flutter/foundation.dart';

/// Advanced state management service for UI state persistence
class StateManagementService extends ChangeNotifier {
  static final StateManagementService _instance = StateManagementService._internal();
  factory StateManagementService() => _instance;
  StateManagementService._internal();

  // Screen states
  final Map<String, Map<String, dynamic>> _screenStates = {};
  final Map<String, DateTime> _lastRefreshTimes = {};
  final Map<String, bool> _loadingStates = {};
  final Map<String, String?> _errorStates = {};
  
  // Refresh intervals for different screen types
  static const Duration _dashboardRefreshInterval = Duration(minutes: 5);
  static const Duration _expenseRefreshInterval = Duration(minutes: 3);
  static const Duration _balanceRefreshInterval = Duration(minutes: 2);
  static const Duration _profileRefreshInterval = Duration(minutes: 30);
  static const Duration _analyticsRefreshInterval = Duration(minutes: 10);

  /// Save screen state
  void saveScreenState(String screenKey, Map<String, dynamic> state) {
    _screenStates[screenKey] = Map.from(state);
    debugPrint('💾 Saved state for $screenKey');
    notifyListeners();
  }

  /// Get screen state
  Map<String, dynamic>? getScreenState(String screenKey) {
    final state = _screenStates[screenKey];
    if (state != null) {
      debugPrint('📦 Retrieved state for $screenKey');
    }
    return state != null ? Map.from(state) : null;
  }

  /// Check if screen needs refresh based on interval
  bool needsRefresh(String screenKey, {Duration? customInterval}) {
    final lastRefresh = _lastRefreshTimes[screenKey];
    if (lastRefresh == null) return true;

    final interval = customInterval ?? _getDefaultInterval(screenKey);
    final shouldRefresh = DateTime.now().difference(lastRefresh) > interval;
    
    if (shouldRefresh) {
      debugPrint('🔄 $screenKey needs refresh (last: ${lastRefresh.toString().substring(11, 19)})');
    } else {
      debugPrint('✅ $screenKey is fresh (last: ${lastRefresh.toString().substring(11, 19)})');
    }
    
    return shouldRefresh;
  }

  /// Mark screen as refreshed
  void markRefreshed(String screenKey) {
    _lastRefreshTimes[screenKey] = DateTime.now();
    debugPrint('✅ Marked $screenKey as refreshed');
    notifyListeners();
  }

  /// Set loading state
  void setLoading(String screenKey, bool loading) {
    _loadingStates[screenKey] = loading;
    debugPrint('⏳ $screenKey loading: $loading');
    notifyListeners();
  }

  /// Get loading state
  bool isLoading(String screenKey) {
    return _loadingStates[screenKey] ?? false;
  }

  /// Set error state
  void setError(String screenKey, String? error) {
    _errorStates[screenKey] = error;
    debugPrint('❌ $screenKey error: $error');
    notifyListeners();
  }

  /// Get error state
  String? getError(String screenKey) {
    return _errorStates[screenKey];
  }

  /// Clear error state
  void clearError(String screenKey) {
    _errorStates.remove(screenKey);
    notifyListeners();
  }

  /// Force refresh for screen
  void forceRefresh(String screenKey) {
    _lastRefreshTimes.remove(screenKey);
    _errorStates.remove(screenKey);
    debugPrint('🔄 Forced refresh for $screenKey');
    notifyListeners();
  }

  /// Clear all states
  void clearAll() {
    _screenStates.clear();
    _lastRefreshTimes.clear();
    _loadingStates.clear();
    _errorStates.clear();
    debugPrint('🗑️ Cleared all states');
    notifyListeners();
  }

  /// Clear states for specific screen
  void clearScreen(String screenKey) {
    _screenStates.remove(screenKey);
    _lastRefreshTimes.remove(screenKey);
    _loadingStates.remove(screenKey);
    _errorStates.remove(screenKey);
    debugPrint('🗑️ Cleared state for $screenKey');
    notifyListeners();
  }

  /// Get default refresh interval for screen type
  Duration _getDefaultInterval(String screenKey) {
    if (screenKey.contains('dashboard')) return _dashboardRefreshInterval;
    if (screenKey.contains('expense')) return _expenseRefreshInterval;
    if (screenKey.contains('balance')) return _balanceRefreshInterval;
    if (screenKey.contains('profile')) return _profileRefreshInterval;
    if (screenKey.contains('analytics')) return _analyticsRefreshInterval;
    return _dashboardRefreshInterval; // Default
  }

  /// Get refresh status for all screens
  Map<String, Map<String, dynamic>> getRefreshStatus() {
    final status = <String, Map<String, dynamic>>{};
    
    for (final screenKey in _screenStates.keys) {
      final lastRefresh = _lastRefreshTimes[screenKey];
      final needsRefresh = this.needsRefresh(screenKey);
      final isLoading = this.isLoading(screenKey);
      final error = getError(screenKey);
      
      status[screenKey] = {
        'last_refresh': lastRefresh?.toIso8601String(),
        'needs_refresh': needsRefresh,
        'is_loading': isLoading,
        'error': error,
        'has_state': _screenStates.containsKey(screenKey),
      };
    }
    
    return status;
  }

  /// Preload states for common screens
  void preloadCommonScreens() {
    final commonScreens = [
      'dashboard',
      'expenses',
      'profile',
    ];
    
    for (final screen in commonScreens) {
      if (!_screenStates.containsKey(screen)) {
        _screenStates[screen] = {};
        debugPrint('🚀 Preloaded state for $screen');
      }
    }
  }

  /// Get memory usage statistics
  Map<String, dynamic> getStats() {
    return {
      'screen_states': _screenStates.length,
      'refresh_times': _lastRefreshTimes.length,
      'loading_states': _loadingStates.length,
      'error_states': _errorStates.length,
      'total_memory_entries': _screenStates.length + _lastRefreshTimes.length + _loadingStates.length + _errorStates.length,
    };
  }
}

/// Screen state keys for consistency
class ScreenKeys {
  static const String dashboard = 'dashboard';
  static const String expenses = 'expenses';
  static const String expenseList = 'expense_list';
  static const String personalExpenses = 'personal_expenses';
  static const String balances = 'balances';
  static const String profile = 'profile';
  static const String settings = 'settings';
  static const String analytics = 'analytics';
  static const String notifications = 'notifications';
  static const String roomspaces = 'roomspaces';
  
  static String roomspaceDetails(String id) => 'roomspace_details_$id';
  static String roomspaceExpenses(String id) => 'roomspace_expenses_$id';
  static String roomspaceBalances(String id) => 'roomspace_balances_$id';
  static String roomspaceAnalytics(String id) => 'roomspace_analytics_$id';
}