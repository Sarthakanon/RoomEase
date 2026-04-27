import 'package:flutter/foundation.dart';
import '../models/subscription_models.dart';
import '../services/subscription_service.dart';

class SubscriptionProvider with ChangeNotifier {
  static final SubscriptionProvider _instance = SubscriptionProvider._internal();
  factory SubscriptionProvider() => _instance;
  SubscriptionProvider._internal();

  final SubscriptionService _subscriptionService = SubscriptionService();

  UserSubscription? _currentSubscription;
  Map<String, dynamic>? _roomspaceUsage;
  bool _isLoading = false;
  String? _error;

  // Getters
  UserSubscription? get currentSubscription => _currentSubscription;
  Map<String, dynamic>? get roomspaceUsage => _roomspaceUsage;
  bool get isLoading => _isLoading;
  String? get error => _error;

  bool get isPremiumUser => _currentSubscription?.plan != SubscriptionPlan.free;
  bool get isProUser => _currentSubscription?.plan == SubscriptionPlan.pro;
  bool get isFreeUser => _currentSubscription?.plan == SubscriptionPlan.free;

  SubscriptionLimits get currentLimits => 
      _currentSubscription?.limits ?? SubscriptionLimits.free;

  /// Initialize subscription data
  Future<void> initialize() async {
    // Initialize with default values first to avoid null states
    _currentSubscription = _createDefaultFreeSubscription();
    _roomspaceUsage = {
      'current': 0,
      'max': 5,
      'canCreate': true,
      'percentage': 0.0,
    };
    notifyListeners();
    
    // Then load actual data
    await loadCurrentSubscription();
    await loadRoomspaceUsage();
  }

  /// Create default free subscription
  UserSubscription _createDefaultFreeSubscription() {
    return UserSubscription(
      id: 'free_default',
      userId: 'current_user',
      plan: SubscriptionPlan.free,
      status: SubscriptionStatus.active,
      startDate: DateTime.now(),
      endDate: null, // Free plan doesn't expire
      isYearly: false,
      amount: 0.0,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );
  }

  /// Load current subscription
  Future<void> loadCurrentSubscription() async {
    try {
      _setLoading(true);
      _currentSubscription = await _subscriptionService.getCurrentSubscription();
      _error = null; // Clear any previous errors
    } catch (e) {
      // Don't show error for subscription loading since API might not be implemented yet
      debugPrint('Subscription loading failed (expected if API not implemented): $e');
      // Ensure we have a default subscription
      _currentSubscription ??= _createDefaultFreeSubscription();
      _error = null; // Don't show error to user
    } finally {
      _setLoading(false);
    }
  }

  /// Load roomspace usage
  Future<void> loadRoomspaceUsage() async {
    try {
      _roomspaceUsage = await _subscriptionService.getRoomspaceUsage();
      notifyListeners();
    } catch (e) {
      debugPrint('Error loading roomspace usage: $e');
      // Provide fallback usage data
      _roomspaceUsage ??= {
        'current': 0,
        'max': 5,
        'canCreate': true,
        'percentage': 0.0,
      };
      notifyListeners();
    }
  }

  /// Check if user can create roomspace
  Future<bool> canCreateRoomspace() async {
    try {
      final canCreate = await _subscriptionService.canCreateRoomspace();
      await loadRoomspaceUsage(); // Refresh usage data
      return canCreate;
    } catch (e) {
      debugPrint('Error checking create permission: $e');
      return false;
    }
  }

  /// Check if user can join roomspace
  Future<bool> canJoinRoomspace() async {
    try {
      final canJoin = await _subscriptionService.canJoinRoomspace();
      await loadRoomspaceUsage(); // Refresh usage data
      return canJoin;
    } catch (e) {
      debugPrint('Error checking join permission: $e');
      return false;
    }
  }

  /// Upgrade subscription
  Future<bool> upgradeSubscription({
    required SubscriptionPlan plan,
    required bool isYearly,
    required Map<String, dynamic> paymentDetails,
  }) async {
    try {
      _setLoading(true);
      
      final result = await _subscriptionService.processPayment(
        plan: plan,
        isYearly: isYearly,
        paymentDetails: paymentDetails,
      );

      if (result['success'] == true) {
        await loadCurrentSubscription(); // Refresh subscription data
        await loadRoomspaceUsage(); // Refresh usage data
        return true;
      } else {
        _error = result['error'] ?? 'Upgrade failed';
        return false;
      }
    } catch (e) {
      _error = 'Upgrade failed: ${e.toString()}';
      debugPrint(_error);
      return false;
    } finally {
      _setLoading(false);
    }
  }

  /// Cancel subscription
  Future<bool> cancelSubscription() async {
    try {
      _setLoading(true);
      
      final result = await _subscriptionService.cancelSubscription();

      if (result['success'] == true) {
        await loadCurrentSubscription(); // Refresh subscription data
        return true;
      } else {
        _error = result['error'] ?? 'Cancellation failed';
        return false;
      }
    } catch (e) {
      _error = 'Cancellation failed: ${e.toString()}';
      debugPrint(_error);
      return false;
    } finally {
      _setLoading(false);
    }
  }

  /// Get formatted usage text
  String get roomspaceUsageText {
    if (_roomspaceUsage == null) return 'Loading...';
    
    final current = _roomspaceUsage!['current'] as int;
    final max = _roomspaceUsage!['max'] as int;
    
    if (max == -1) return '$current roomspaces (Unlimited)';
    return '$current / $max roomspaces';
  }

  /// Get usage percentage
  double get roomspaceUsagePercentage {
    if (_roomspaceUsage == null) return 0.0;
    return (_roomspaceUsage!['percentage'] as num).toDouble();
  }

  /// Check if near limit
  bool get isNearRoomspaceLimit {
    if (_roomspaceUsage == null) return false;
    final percentage = roomspaceUsagePercentage;
    return percentage >= 80.0; // 80% or more
  }

  /// Clear error
  void clearError() {
    _error = null;
    notifyListeners();
  }

  /// Set loading state
  void _setLoading(bool loading) {
    _isLoading = loading;
    notifyListeners();
  }

  /// Refresh all data
  Future<void> refresh() async {
    await initialize();
  }
}