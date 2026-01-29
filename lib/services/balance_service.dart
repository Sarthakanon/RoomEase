import 'package:dio/dio.dart';
import '../models/balance_models.dart';
import 'api_service.dart';

class BalanceService {
  final ApiService _apiService = ApiService();

  /// Get user's balance in a specific roomspace
  Future<UserBalance?> getUserBalance(String roomspaceId, String userId) async {
    try {
      final response = await _apiService.get(
        '/api/roomspaces/$roomspaceId/balances/$userId',
      );

      if (response['success'] == true && response['data'] != null) {
        return UserBalance.fromJson(response['data']);
      }
      return null;
    } catch (e) {
      print('Error loading user balance: $e');
      return null;
    }
  }

  /// Get all balances for a roomspace
  Future<BalanceSummary?> getRoomspaceBalances(String roomspaceId) async {
    try {
      final response = await _apiService.get(
        '/api/roomspaces/$roomspaceId/balances',
      );

      if (response['success'] == true && response['data'] != null) {
        return BalanceSummary.fromJson(response['data']);
      }
      return null;
    } catch (e) {
      print('Error loading roomspace balances: $e');
      return null;
    }
  }

  /// Get settlement suggestions for a roomspace
  Future<List<SettlementSuggestion>> getSettlementSuggestions(String roomspaceId) async {
    try {
      final response = await _apiService.get(
        '/api/roomspaces/$roomspaceId/settlements/suggestions',
      );

      if (response['success'] == true && response['data'] != null) {
        final List<dynamic> data = response['data'];
        return data.map((json) => SettlementSuggestion.fromJson(json)).toList();
      }
      return [];
    } catch (e) {
      print('Error loading settlement suggestions: $e');
      return [];
    }
  }

  /// Refresh balance cache for a roomspace
  Future<bool> refreshBalanceCache(String roomspaceId) async {
    try {
      final response = await _apiService.post(
        '/api/roomspaces/$roomspaceId/balances/refresh',
        {},
      );

      return response['success'] == true;
    } catch (e) {
      print('Error refreshing balance cache: $e');
      return false;
    }
  }
}
