import 'package:flutter/foundation.dart';
import '../../../services/api_service.dart';
import '../models/subscription_models.dart';

class SubscriptionService {
  static final SubscriptionService _instance = SubscriptionService._internal();
  factory SubscriptionService() => _instance;
  SubscriptionService._internal();

  final ApiService _apiService = ApiService();

  /// Get current user's subscription
  Future<UserSubscription> getCurrentSubscription() async {
    try {
      final response = await _apiService.get('/api/subscription/current');
      
      if (response['success'] == true && response['data'] != null) {
        return UserSubscription.fromJson(response['data']);
      } else {
        // Return default free subscription if none exists
        return _createDefaultFreeSubscription();
      }
    } catch (e) {
      debugPrint('Subscription API not available, using default free subscription: $e');
      // Return default free subscription on error (API not implemented yet)
      return _createDefaultFreeSubscription();
    }
  }

  /// Check if user can create more roomspaces
  Future<bool> canCreateRoomspace() async {
    try {
      final subscription = await getCurrentSubscription();
      final response = await _apiService.getRoomspaces();
      
      if (response['success'] == true && response['data'] != null) {
        final roomspaces = response['data'] as List<dynamic>;
        final currentCount = roomspaces.length;
        final maxAllowed = subscription.limits.maxRoomspaces;
        
        // -1 means unlimited
        if (maxAllowed == -1) return true;
        
        return currentCount < maxAllowed;
      }
      
      return false;
    } catch (e) {
      debugPrint('Error checking roomspace limit: $e');
      return false;
    }
  }

  /// Check if user can join more roomspaces
  Future<bool> canJoinRoomspace() async {
    // Same logic as create for now
    return await canCreateRoomspace();
  }

  /// Get roomspace usage info
  Future<Map<String, dynamic>> getRoomspaceUsage() async {
    try {
      final subscription = await getCurrentSubscription();
      final response = await _apiService.getRoomspaces();
      
      if (response['success'] == true && response['data'] != null) {
        final roomspaces = response['data'] as List<dynamic>;
        final currentCount = roomspaces.length;
        final maxAllowed = subscription.limits.maxRoomspaces;
        
        return {
          'current': currentCount,
          'max': maxAllowed,
          'canCreate': maxAllowed == -1 || currentCount < maxAllowed,
          'percentage': maxAllowed == -1 ? 0.0 : (currentCount / maxAllowed * 100),
        };
      }
      
      return {
        'current': 0,
        'max': 5,
        'canCreate': true,
        'percentage': 0.0,
      };
    } catch (e) {
      debugPrint('Error getting roomspace usage: $e');
      return {
        'current': 0,
        'max': 5,
        'canCreate': true,
        'percentage': 0.0,
      };
    }
  }

  /// Create or upgrade subscription
  Future<Map<String, dynamic>> createSubscription({
    required SubscriptionPlan plan,
    required bool isYearly,
    required String paymentMethod,
  }) async {
    try {
      final planInfo = SubscriptionPlanInfo.getPlanInfo(plan);
      final amount = isYearly ? planInfo.yearlyPrice : planInfo.monthlyPrice;
      
      final response = await _apiService.post('/api/subscription/create', data: {
        'plan': plan.name,
        'is_yearly': isYearly,
        'amount': amount,
        'payment_method': paymentMethod,
      });
      
      return response;
    } catch (e) {
      debugPrint('Error creating subscription: $e');
      return {
        'success': false,
        'error': 'Failed to create subscription: ${e.toString()}',
      };
    }
  }

  /// Cancel subscription
  Future<Map<String, dynamic>> cancelSubscription() async {
    try {
      final response = await _apiService.post('/api/subscription/cancel', data: {});
      return response;
    } catch (e) {
      debugPrint('Error cancelling subscription: $e');
      return {
        'success': false,
        'error': 'Failed to cancel subscription: ${e.toString()}',
      };
    }
  }

  /// Get subscription history
  Future<List<UserSubscription>> getSubscriptionHistory() async {
    try {
      final response = await _apiService.get('/api/subscription/history');
      
      if (response['success'] == true && response['data'] != null) {
        final List<dynamic> data = response['data'];
        return data.map((json) => UserSubscription.fromJson(json)).toList();
      }
      
      return [];
    } catch (e) {
      debugPrint('Error getting subscription history: $e');
      return [];
    }
  }

  /// Process payment (eSewa integration)
  Future<Map<String, dynamic>> processPayment({
    required SubscriptionPlan plan,
    required bool isYearly,
    required Map<String, dynamic> paymentDetails,
  }) async {
    try {
      // In a real app, this would integrate with eSewa payment gateway
      // eSewa API documentation: https://developer.esewa.com.np/
      await Future.delayed(const Duration(seconds: 2)); // Simulate processing
      
      // Mock successful payment - replace with actual eSewa integration
      final response = await createSubscription(
        plan: plan,
        isYearly: isYearly,
        paymentMethod: 'esewa', // Always use eSewa
      );
      
      return response;
    } catch (e) {
      debugPrint('Error processing eSewa payment: $e');
      return {
        'success': false,
        'error': 'eSewa payment processing failed: ${e.toString()}',
      };
    }
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
}