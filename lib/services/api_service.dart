import 'dart:io' show Platform, Directory;
import 'package:dio/dio.dart';
import 'package:dio_cookie_manager/dio_cookie_manager.dart';
import 'package:cookie_jar/cookie_jar.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:firebase_auth/firebase_auth.dart';
import 'package:path_provider/path_provider.dart';
import '../core/constants.dart';
import 'ban_monitoring_service.dart';

class ApiService {
  static final ApiService _instance = ApiService._internal();

  factory ApiService() {
    return _instance;
  }

  late final Dio _dio;
  late CookieJar _cookieJar;
  bool _initialized = false;

  // Backend server IP address - update in lib/core/constants.dart
  static const String _backendIp = AppConstants.backendIp;
  static const int _backendPort = AppConstants.backendPort;

  static String get baseUrl {
    if (kIsWeb) {
      return 'http://localhost:$_backendPort';
    }

    // Use machine IP for physical Android devices
    if (Platform.isAndroid) {
      return 'http://$_backendIp:$_backendPort';
    } else if (Platform.isIOS) {
      // iOS requires the actual IP address for physical devices
      return 'http://$_backendIp:$_backendPort';
    }

    return 'http://$_backendIp:$_backendPort';
  }

  ApiService._internal() {
    _dio = Dio(
      BaseOptions(
        baseUrl: baseUrl,
        connectTimeout: const Duration(seconds: 30), // Increased from 10s
        receiveTimeout: const Duration(seconds: 30), // Increased from 10s
        sendTimeout: const Duration(seconds: 30), // Added send timeout
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
          'Connection': 'keep-alive', // Keep connections alive
        },
      ),
    );

    // Add cookie manager only for non-web platforms
    if (!kIsWeb) {
      _cookieJar = CookieJar();
      _dio.interceptors.add(CookieManager(_cookieJar));
    }

    _dio.interceptors.add(
      LogInterceptor(requestBody: true, responseBody: true, error: true),
    );

    // Add ban detection interceptor
    _dio.interceptors.add(
      InterceptorsWrapper(
        onResponse: (response, handler) {
          print('📡 API Response: ${response.statusCode} - ${response.requestOptions.path}');
          print('📡 Response Data: ${response.data}');
          
          // Check if response indicates user is banned
          if (response.data is Map<String, dynamic>) {
            final data = response.data as Map<String, dynamic>;
            if (data['banned'] == true || 
                (data['error'] != null && 
                 (data['error'].toString().toLowerCase().contains('suspended') ||
                  data['error'].toString().toLowerCase().contains('banned')))) {
              final reason = data['error']?.toString() ?? 'Account suspended';
              print('🚫 BAN DETECTED in response: $reason');
              _handleBanResponse(reason);
            }
          }
          handler.next(response);
        },
        onError: (error, handler) {
          print('❌ API Error: ${error.response?.statusCode} - ${error.requestOptions.path}');
          print('❌ Error Data: ${error.response?.data}');
          
          // Check if error response indicates user is banned
          if (error.response?.data is Map<String, dynamic>) {
            final data = error.response!.data as Map<String, dynamic>;
            if (data['banned'] == true || 
                (data['error'] != null && 
                 (data['error'].toString().toLowerCase().contains('suspended') ||
                  data['error'].toString().toLowerCase().contains('banned')))) {
              final reason = data['error']?.toString() ?? 'Account suspended';
              print('🚫 BAN DETECTED in error: $reason');
              _handleBanResponse(reason);
            }
          }
          handler.next(error);
        },
      ),
    );
  }

  /// Initialize persistent cookie storage
  Future<void> initializePersistentCookies() async {
    if (_initialized || kIsWeb) return;
    
    try {
      final Directory appDocDir = await getApplicationDocumentsDirectory();
      final String appDocPath = appDocDir.path;
      _cookieJar = PersistCookieJar(
        ignoreExpires: true,
        storage: FileStorage('$appDocPath/.cookies/'),
      );
      
      // Remove old interceptor and add new one with persistent cookie jar
      _dio.interceptors.removeWhere((i) => i is CookieManager);
      _dio.interceptors.insert(0, CookieManager(_cookieJar));
      _initialized = true;
      print('Persistent cookie storage initialized at: $appDocPath/.cookies/');
    } catch (e) {
      print('Failed to initialize persistent cookies: $e');
    }
  }

  Dio get dio {
    return _dio;
  }

  Future<void> clearCookies() async {
    // Clear all cookies from the cookie jar (only on non-web platforms)
    if (!kIsWeb) {
      await _cookieJar.deleteAll();
    }
  }

  Future<Map<String, dynamic>> login(String firebaseToken) async {
    try {
      final response = await _dio.post(
        '/api/auth/login',
        data: {'firebase_token': firebaseToken},
      );
      
      // After successful login, check if user is banned
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        await _checkUserBanStatus(user.uid);
        // Start ban monitoring after successful login
        BanMonitoringService().startMonitoring();
      }
      
      return response.data as Map<String, dynamic>;
    } on DioException catch (e) {
      final errorMessage = _handleError(e);
      throw Exception(errorMessage);
    }
  }

  Future<void> _checkUserBanStatus(String userId) async {
    try {
      final response = await _dio.get('/api/admin/users/$userId/ban-status');
      final data = response.data as Map<String, dynamic>;
      
      if (data['is_banned'] == true) {
        final reason = data['ban_reason'] ?? 'Unusual activity';
        await FirebaseAuth.instance.signOut();
        throw Exception('Your account has been suspended due to: $reason. Please contact support for assistance.');
      }
    } catch (e) {
      if (e.toString().contains('suspended') || e.toString().contains('banned')) {
        rethrow;
      }
      // If ban check fails, continue with login (don't block user)
      print('Ban check failed: $e');
    }
  }

  /// Handle ban response from any API call
  Future<void> _handleBanResponse(String errorMessage) async {
    try {
      print('🚫 _handleBanResponse called with: $errorMessage');
      
      // Stop ban monitoring
      BanMonitoringService().stopMonitoring();
      
      // Trigger ban notification immediately
      BanMonitoringService().notifyBanDetected(errorMessage);
      
      print('🚫 Ban notification sent to UI');
    } catch (e) {
      print('❌ Error handling ban response: $e');
    }
  }

  Future<Map<String, dynamic>> logout() async {
    try {
      // Stop ban monitoring when logging out
      BanMonitoringService().stopMonitoring();
      
      final response = await _dio.post('/api/auth/logout');
      await clearCookies();
      return response.data as Map<String, dynamic>;
    } on DioException catch (e) {
      final errorMessage = _handleError(e);
      throw Exception(errorMessage);
    }
  }

  Future<Map<String, dynamic>> verifySession() async {
    try {
      final response = await _dio.get('/api/auth/verify');
      return response.data as Map<String, dynamic>;
    } on DioException catch (e) {
      final errorMessage = _handleError(e);
      throw Exception(errorMessage);
    }
  }

  Future<Map<String, dynamic>> refreshSession() async {
    try {
      final response = await _dio.post('/api/auth/refresh');
      return response.data as Map<String, dynamic>;
    } on DioException catch (e) {
      final errorMessage = _handleError(e);
      throw Exception(errorMessage);
    }
  }

  Future<Map<String, dynamic>> get(String path) async {
    try {
      final response = await _dio.get(path);
      return response.data as Map<String, dynamic>;
    } on DioException catch (e) {
      if (e.response?.statusCode == 401) {
        await clearCookies();
        throw Exception('Session expired. Please login again.');
      }
      final errorMessage = _handleError(e);
      throw Exception(errorMessage);
    }
  }

  Future<Map<String, dynamic>> post(
    String path, {
    Map<String, dynamic>? data,
  }) async {
    try {
      final response = await _dio.post(path, data: data);
      return response.data as Map<String, dynamic>;
    } on DioException catch (e) {
      if (e.response?.statusCode == 401) {
        await clearCookies();
        throw Exception('Session expired. Please login again.');
      }
      final errorMessage = _handleError(e);
      throw Exception(errorMessage);
    }
  }

  Future<Map<String, dynamic>> put(
    String path, {
    Map<String, dynamic>? data,
  }) async {
    try {
      final response = await _dio.put(path, data: data);
      return response.data as Map<String, dynamic>;
    } on DioException catch (e) {
      if (e.response?.statusCode == 401) {
        await clearCookies();
        throw Exception('Session expired. Please login again.');
      }
      final errorMessage = _handleError(e);
      throw Exception(errorMessage);
    }
  }

  Future<Map<String, dynamic>> delete(
    String path, {
    Map<String, dynamic>? data,
  }) async {
    try {
      final response = await _dio.delete(path, data: data);
      return response.data as Map<String, dynamic>;
    } on DioException catch (e) {
      if (e.response?.statusCode == 401) {
        await clearCookies();
        throw Exception('Session expired. Please login again.');
      }
      final errorMessage = _handleError(e);
      throw Exception(errorMessage);
    }
  }

  Future<Map<String, dynamic>> getUserProfile() async {
    return await get('/api/user/profile');
  }

  Future<Map<String, dynamic>> updateUserProfile({
    String? name,
    String? phone,
  }) async {
    final data = <String, dynamic>{};
    if (name != null) {
      data['name'] = name;
    }
    if (phone != null) {
      data['phone'] = phone;
    }
    return await put('/api/user/profile', data: data);
  }

  Future<Map<String, dynamic>> getRoomspaces() async {
    return await get('/api/roomspaces');
  }

  Future<Map<String, dynamic>> createRoomspace({
    required String name,
    String? description,
  }) async {
    final data = <String, dynamic>{'name': name};
    if (description != null) {
      data['description'] = description;
    }
    return await post('/api/roomspaces', data: data);
  }

  Future<Map<String, dynamic>> getRoomspace(int id) async {
    return await get('/api/roomspaces/$id');
  }

  Future<Map<String, dynamic>> joinRoomspace(int id) async {
    return await post('/api/roomspaces/$id/join');
  }

  Future<Map<String, dynamic>> searchRoomspaceByCode(String code) async {
    return await get('/api/roomspaces/code/$code');
  }

  Future<Map<String, dynamic>> joinRoomspaceByCode(String code) async {
    return await post('/api/roomspaces/code/$code/join');
  }

  Future<Map<String, dynamic>> getRoomspaceBalances(String roomspaceId) async {
    try {
      final response = await get('/api/roomspaces/$roomspaceId/balances');
      return response;
    } catch (e) {
      throw Exception('Failed to get roomspace balances: ${e.toString()}');
    }
  }

  Future<Map<String, dynamic>> getSettlements({
    required String roomspaceId,
    int? limit,
    int? offset,
  }) async {
    try {
      final queryParams = <String, String>{};
      if (limit != null) queryParams['limit'] = limit.toString();
      if (offset != null) queryParams['offset'] = offset.toString();
      
      final path = '/api/roomspaces/$roomspaceId/settlements${queryParams.isNotEmpty ? '?${Uri(queryParameters: queryParams).query}' : ''}';
      return await get(path);
    } catch (e) {
      throw Exception('Failed to get settlements: ${e.toString()}');
    }
  }

  Future<Map<String, dynamic>> removeMemberFromRoomspace(
    int roomspaceId,
    String memberFirebaseUid,
  ) async {
    return await delete(
      '/api/roomspaces/$roomspaceId/members',
      data: {'member_firebase_uid': memberFirebaseUid},
    );
  }

  // Notification APIs
  Future<Map<String, dynamic>> getNotifications() async {
    return await get('/api/notifications');
  }

  Future<Map<String, dynamic>> markNotificationAsRead(int id) async {
    return await put('/api/notifications/$id/read');
  }

  Future<Map<String, dynamic>> getJoinRequests() async {
    return await get('/api/join-requests');
  }

  Future<Map<String, dynamic>> getPendingJoinRequest() async {
    return await get('/api/join-requests/pending');
  }

  Future<Map<String, dynamic>> processJoinRequest(
    String requestId,
    bool accept,
  ) async {
    return await post(
      '/api/join-requests/$requestId/process',
      data: {'accept': accept},
    );
  }

  // Expense APIs
  Future<Map<String, dynamic>> createExpense(
    Map<String, dynamic> expenseData,
  ) async {
    try {
      // Debug: Print the expense data being sent
      print('Creating expense with data: $expenseData');
      final response = await post('/api/expenses', data: expenseData);
      return response;
    } catch (e) {
      print('Error creating expense: $e');
      throw Exception('Failed to create expense: ${e.toString()}');
    }
  }

  Future<Map<String, dynamic>> createPersonalExpense(
    Map<String, dynamic> expenseData,
  ) async {
    try {
      // Debug: Print the personal expense data being sent
      print('Creating personal expense with data: $expenseData');
      final response = await post('/api/personal-expenses', data: expenseData);
      return response;
    } catch (e) {
      print('Error creating personal expense: $e');
      throw Exception('Failed to create personal expense: ${e.toString()}');
    }
  }

  Future<Map<String, dynamic>> getPersonalExpenses({
    String? roomspaceId,
    int? limit,
    int? offset,
    DateTime? month,
  }) async {
    try {
      final queryParams = <String, String>{};
      if (roomspaceId != null) queryParams['roomspace_id'] = roomspaceId;
      if (limit != null) queryParams['limit'] = limit.toString();
      if (offset != null) queryParams['offset'] = offset.toString();
      
      // Add month/year filtering
      if (month != null) {
        queryParams['year'] = month.year.toString();
        queryParams['month'] = month.month.toString();
      }
      
      final path = '/api/personal-expenses${queryParams.isNotEmpty ? '?${Uri(queryParameters: queryParams).query}' : ''}';
      return await get(path);
    } catch (e) {
      print('Error getting personal expenses: $e');
      throw Exception('Failed to get personal expenses: ${e.toString()}');
    }
  }

  Future<Map<String, dynamic>> deletePersonalExpense(int expenseId) async {
    try {
      final response = await delete('/api/personal-expenses/$expenseId');
      return response;
    } catch (e) {
      print('Error deleting personal expense: $e');
      throw Exception('Failed to delete personal expense: ${e.toString()}');
    }
  }

  Future<Map<String, dynamic>> getExpenses({
    String? roomspaceId,
    int? limit,
    int? offset,
  }) async {
    try {
      final queryParams = <String, String>{};
      if (roomspaceId != null) queryParams['roomspace_id'] = roomspaceId;
      if (limit != null) queryParams['limit'] = limit.toString();
      if (offset != null) queryParams['offset'] = offset.toString();
      
      final path = '/api/expenses${queryParams.isNotEmpty ? '?${Uri(queryParameters: queryParams).query}' : ''}';
      return await get(path);
    } catch (e) {
      throw Exception('Failed to retrieve expenses: ${e.toString()}');
    }
  }

  Future<Map<String, dynamic>> getExpenseById(int expenseId) async {
    try {
      return await get('/api/expenses/$expenseId');
    } catch (e) {
      throw Exception('Failed to retrieve expense details: ${e.toString()}');
    }
  }

  Future<Map<String, dynamic>> getRoomspaceExpenses(
    String roomspaceId, {
    int? limit,
    int? offset,
    DateTime? month,
  }) async {
    try {
      final queryParams = <String, String>{};
      if (limit != null) queryParams['limit'] = limit.toString();
      if (offset != null) queryParams['offset'] = offset.toString();
      
      // Add month/year filtering
      if (month != null) {
        queryParams['year'] = month.year.toString();
        queryParams['month'] = month.month.toString();
      }
      
      final path = '/api/roomspaces/$roomspaceId/expenses${queryParams.isNotEmpty ? '?${Uri(queryParameters: queryParams).query}' : ''}';
      return await get(path);
    } catch (e) {
      throw Exception('Failed to retrieve roomspace expenses: ${e.toString()}');
    }
  }

  Future<Map<String, dynamic>> getRecentExpenses({
    String? roomspaceId,
    int limit = 3,
    DateTime? month,
  }) async {
    try {
      if (roomspaceId != null) {
        // Use roomspace-specific endpoint
        final queryParams = <String, String>{
          'limit': limit.toString(),
          'offset': '0',
        };
        
        // Add month/year filtering
        if (month != null) {
          queryParams['year'] = month.year.toString();
          queryParams['month'] = month.month.toString();
        }
        
        final path = '/api/roomspaces/$roomspaceId/expenses?${Uri(queryParameters: queryParams).query}';
        return await get(path);
      } else {
        // Use personal expenses endpoint
        return await getPersonalExpenses(limit: limit, offset: 0, month: month);
      }
    } catch (e) {
      throw Exception('Failed to retrieve recent expenses: ${e.toString()}');
    }
  }

  Future<Map<String, dynamic>> updateExpense(
    int expenseId,
    Map<String, dynamic> expenseData,
  ) async {
    try {
      final response = await put('/api/expenses/$expenseId', data: expenseData);
      return response;
    } catch (e) {
      throw Exception('Failed to update expense: ${e.toString()}');
    }
  }

  Future<Map<String, dynamic>> deleteExpense(int expenseId) async {
    try {
      final response = await delete('/api/expenses/$expenseId');
      return response;
    } catch (e) {
      throw Exception('Failed to delete expense: ${e.toString()}');
    }
  }

  Future<Map<String, dynamic>> getRoomspaceMembers(String roomspaceId) async {
    try {
      // Get the roomspace data which includes members
      final response = await get('/api/roomspaces/$roomspaceId');
      
      // Extract members from the roomspace data
      if (response['success'] == true && response['data'] != null) {
        final roomspaceData = response['data'] as Map<String, dynamic>;
        final members = roomspaceData['members'] as List<dynamic>? ?? [];
        
        return {
          'success': true,
          'data': members,
        };
      }
      
      return response;
    } catch (e) {
      throw Exception('Failed to get roomspace members: ${e.toString()}');
    }
  }

  // Payment Notification API methods
  Future<Map<String, dynamic>> createPaymentNotification(Map<String, dynamic> notificationData) async {
    try {
      final response = await post('/api/payment-notifications', data: notificationData);
      return response;
    } catch (e) {
      throw Exception('Failed to create payment notification: ${e.toString()}');
    }
  }

  Future<Map<String, dynamic>> getPaymentNotifications({
    String? roomspaceId,
    int? limit,
    int? offset,
  }) async {
    try {
      final queryParams = <String, String>{};
      if (roomspaceId != null) queryParams['roomspace_id'] = roomspaceId;
      if (limit != null) queryParams['limit'] = limit.toString();
      if (offset != null) queryParams['offset'] = offset.toString();
      
      final path = '/api/payment-notifications${queryParams.isNotEmpty ? '?${Uri(queryParameters: queryParams).query}' : ''}';
      return await get(path);
    } catch (e) {
      throw Exception('Failed to retrieve payment notifications: ${e.toString()}');
    }
  }

  Future<Map<String, dynamic>> getPaymentNotification(int notificationId) async {
    try {
      return await get('/api/payment-notifications/$notificationId');
    } catch (e) {
      throw Exception('Failed to retrieve payment notification: ${e.toString()}');
    }
  }

  Future<Map<String, dynamic>> markPaymentNotificationAsProcessed(
    int notificationId, {
    int? expenseId,
  }) async {
    try {
      final data = <String, dynamic>{};
      if (expenseId != null) {
        data['expense_id'] = expenseId;
      }
      
      final response = await put('/api/payment-notifications/$notificationId/processed', data: data);
      return response;
    } catch (e) {
      throw Exception('Failed to mark payment notification as processed: ${e.toString()}');
    }
  }

  Future<Map<String, dynamic>> deletePaymentNotification(int notificationId) async {
    try {
      final response = await delete('/api/payment-notifications/$notificationId');
      return response;
    } catch (e) {
      throw Exception('Failed to delete payment notification: ${e.toString()}');
    }
  }

  String _handleError(DioException error) {
    if (error.response != null) {
      final data = error.response!.data;
      if (data is Map && data.containsKey('error')) {
        return data['error'].toString();
      }
      return 'Server error: ${error.response!.statusCode}';
    } else if (error.type == DioExceptionType.connectionTimeout) {
      return 'Connection timeout';
    } else if (error.type == DioExceptionType.receiveTimeout) {
      return 'Receive timeout';
    } else {
      return 'Network error: ${error.message}';
    }
  }
}
