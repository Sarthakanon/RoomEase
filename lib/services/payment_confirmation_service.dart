import 'dart:developer';
import '../models/payment_confirmation_models.dart';
import 'api_service.dart';

class PaymentConfirmationService {
  final ApiService _apiService;

  PaymentConfirmationService(this._apiService);

  /// Create a new payment confirmation claim
  Future<PaymentConfirmation> createPaymentConfirmation({
    required String roomspaceId,
    required PaymentConfirmationRequest request,
  }) async {
    try {
      final response = await _apiService.post(
        '/api/roomspaces/$roomspaceId/payments/confirm',
        data: request.toJson(),
      );

      if (response['success'] == true && response['data'] != null) {
        return PaymentConfirmation.fromJson(response['data']);
      } else {
        throw Exception(response['error'] ?? 'Failed to create payment confirmation');
      }
    } catch (e) {
      log('Error creating payment confirmation: $e');
      rethrow;
    }
  }

  /// Confirm a payment (recipient confirms they received payment)
  Future<PaymentConfirmation> confirmPayment({
    required String roomspaceId,
    required int paymentId,
  }) async {
    try {
      final response = await _apiService.put(
        '/api/roomspaces/$roomspaceId/payments/$paymentId/confirm',
        data: {},
      );

      if (response['success'] == true && response['data'] != null) {
        return PaymentConfirmation.fromJson(response['data']);
      } else {
        throw Exception(response['error'] ?? 'Failed to confirm payment');
      }
    } catch (e) {
      log('Error confirming payment: $e');
      rethrow;
    }
  }

  /// Reject a payment claim
  Future<PaymentConfirmation> rejectPayment({
    required String roomspaceId,
    required int paymentId,
    String? reason,
  }) async {
    try {
      final response = await _apiService.put(
        '/api/roomspaces/$roomspaceId/payments/$paymentId/reject',
        data: reason != null ? {'reason': reason} : {},
      );

      if (response['success'] == true && response['data'] != null) {
        return PaymentConfirmation.fromJson(response['data']);
      } else {
        throw Exception(response['error'] ?? 'Failed to reject payment');
      }
    } catch (e) {
      log('Error rejecting payment: $e');
      rethrow;
    }
  }

  /// Get pending payment confirmations for current user
  Future<List<PaymentConfirmation>> getPendingConfirmations({
    required String roomspaceId,
  }) async {
    try {
      final response = await _apiService.get(
        '/api/roomspaces/$roomspaceId/payments/pending',
      );

      if (response['success'] == true && response['data'] != null) {
        final List<dynamic> paymentsJson = response['data'];
        return paymentsJson
            .map((json) => PaymentConfirmation.fromJson(json))
            .toList();
      } else {
        throw Exception(response['error'] ?? 'Failed to get pending confirmations');
      }
    } catch (e) {
      log('Error getting pending confirmations: $e');
      rethrow;
    }
  }

  /// Get payment history with filters
  Future<List<PaymentConfirmation>> getPaymentHistory({
    required String roomspaceId,
    String? userId,
    PaymentStatus? status,
    int limit = 20,
    int offset = 0,
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    try {
      // Build query string
      final queryParams = <String, String>{
        'limit': limit.toString(),
        'offset': offset.toString(),
      };

      if (userId != null) queryParams['user_id'] = userId;
      if (status != null) queryParams['status'] = status.value;
      if (startDate != null) {
        queryParams['start_date'] = startDate.toIso8601String();
      }
      if (endDate != null) {
        queryParams['end_date'] = endDate.toIso8601String();
      }

      final queryString = queryParams.entries
          .map((e) => '${e.key}=${Uri.encodeComponent(e.value)}')
          .join('&');

      final response = await _apiService.get(
        '/api/roomspaces/$roomspaceId/payments/history?$queryString',
      );

      if (response['success'] == true && response['data'] != null) {
        final List<dynamic> paymentsJson = response['data'];
        return paymentsJson
            .map((json) => PaymentConfirmation.fromJson(json))
            .toList();
      } else {
        throw Exception(response['error'] ?? 'Failed to get payment history');
      }
    } catch (e) {
      log('Error getting payment history: $e');
      rethrow;
    }
  }

  /// Get payment statistics for a roomspace
  Future<PaymentStats> getPaymentStats({
    required String roomspaceId,
  }) async {
    try {
      final response = await _apiService.get(
        '/api/roomspaces/$roomspaceId/payments/stats',
      );

      if (response['success'] == true && response['data'] != null) {
        return PaymentStats.fromJson(response['data']);
      } else {
        throw Exception(response['error'] ?? 'Failed to get payment stats');
      }
    } catch (e) {
      log('Error getting payment stats: $e');
      rethrow;
    }
  }

  /// Get payments where current user needs to confirm (received payments)
  Future<List<PaymentConfirmation>> getPaymentsToConfirm({
    required String roomspaceId,
    required String currentUserId,
  }) async {
    try {
      final allPending = await getPendingConfirmations(roomspaceId: roomspaceId);
      return allPending.where((p) => p.toUserId == currentUserId).toList();
    } catch (e) {
      log('Error getting payments to confirm: $e');
      rethrow;
    }
  }

  /// Get payments where current user is waiting for confirmation (sent payments)
  Future<List<PaymentConfirmation>> getPaymentsWaitingConfirmation({
    required String roomspaceId,
    required String currentUserId,
  }) async {
    try {
      final allPending = await getPendingConfirmations(roomspaceId: roomspaceId);
      return allPending.where((p) => p.fromUserId == currentUserId).toList();
    } catch (e) {
      log('Error getting payments waiting confirmation: $e');
      rethrow;
    }
  }
}
