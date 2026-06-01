import 'dart:io' show Platform, Directory;
import 'package:dio/dio.dart';
import 'package:dio_cookie_manager/dio_cookie_manager.dart';
import 'package:cookie_jar/cookie_jar.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:firebase_auth/firebase_auth.dart';
import 'package:path_provider/path_provider.dart';
import '../core/constants.dart';
import 'ban_monitoring_service.dart';
import 'real_time_data_service.dart';

class ApiService {
  static final ApiService _instance = ApiService._internal();

  factory ApiService() {
    return _instance;
  }

  late final Dio _dio;
  late CookieJar _cookieJar;
  bool _initialized = false;

  static String get baseUrl {
    // Use deployed backend by default for all platforms.
    return AppConstants.backendBaseUrl;
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
        // Enable credentials for web (cookies)
        extra: {
          'withCredentials': true,
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
        onRequest: (options, handler) {
          print('📡 API Request: ${options.method} ${options.path}');
          print('📡 Request Data: ${options.data}');
          handler.next(options);
        },
        onResponse: (response, handler) {
          print('📡 API Response: ${response.statusCode} - ${response.requestOptions.path}');
          print('📡 Response Data: ${response.data}');
          
          // Check if response indicates user is banned
          if (response.data is Map<String, dynamic>) {
            final data = response.data as Map<String, dynamic>;
            
            // Check for is_banned field (from ban-status endpoint)
            if (data['is_banned'] == true) {
              final reason = data['ban_reason']?.toString() ?? 'Your account has been suspended';
              print('🚫 BAN DETECTED (is_banned field): $reason');
              _handleBanResponse(reason);
            }
            // Check for banned field or error message
            else if (data['banned'] == true || 
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
        onError: (error, handler) async {
          print('❌ API Error: ${error.response?.statusCode} - ${error.requestOptions.path}');
          print('❌ Error Data: ${error.response?.data}');
          print('❌ Error Type: ${error.type}');
          print('❌ Error Message: ${error.message}');
          
          // Enhanced error logging for connection issues
          if (error.type == DioExceptionType.connectionError) {
            print('🌐 Connection Error Details:');
            print('   - Base URL: ${_dio.options.baseUrl}');
            print('   - Request URL: ${error.requestOptions.uri}');
            print('   - Timeout: ${_dio.options.connectTimeout}');
            if (!kIsWeb) {
              print('   - Platform: ${Platform.operatingSystem}');
            }
          }
          
          // Handle 401 Unauthorized - Session expired or invalid
          if (error.response?.statusCode == 401) {
            print('🔒 401 Unauthorized detected - logging out user');
            await _handleUnauthorizedError();
            handler.next(error);
            return;
          }
          
          // Handle 403 Forbidden - User banned or access denied
          if (error.response?.statusCode == 403) {
            print('🚫 403 Forbidden detected - checking if user is banned');
            final data = error.response?.data;
            if (data is Map<String, dynamic>) {
              final errorMsg = data['error']?.toString() ?? '';
              if (errorMsg.toLowerCase().contains('banned') || 
                  errorMsg.toLowerCase().contains('suspended')) {
                print('🚫 User is banned - logging out');
                await _handleBanResponse(errorMsg);
                handler.next(error);
                return;
              }
            }
          }
          
          // Check if error response indicates user is banned
          if (error.response?.data is Map<String, dynamic>) {
            final data = error.response!.data as Map<String, dynamic>;
            if (data['banned'] == true || 
                (data['error'] != null && 
                 (data['error'].toString().toLowerCase().contains('suspended') ||
                  data['error'].toString().toLowerCase().contains('banned')))) {
              final reason = data['error']?.toString() ?? 'Account suspended';
              print('🚫 BAN DETECTED in error: $reason');
              await _handleBanResponse(reason);
            }
          }
          handler.next(error);
        },
      ),
    );
  }

  /// Handle 401 Unauthorized errors - auto logout
  Future<void> _handleUnauthorizedError() async {
    try {
      print('🔒 Handling unauthorized error - logging out user');
      
      // Stop ban monitoring
      BanMonitoringService().stopMonitoring();
      
      // Clear cookies
      await clearCookies();
      
      // Sign out from Firebase
      await FirebaseAuth.instance.signOut();
      
      print('✅ User logged out due to unauthorized access');
    } catch (e) {
      print('❌ Error handling unauthorized error: $e');
    }
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
        options: Options(
          sendTimeout: const Duration(seconds: 60),
          receiveTimeout: const Duration(seconds: 90),
        ),
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
      
      // Trigger ban notification immediately - this will show the dialog
      BanMonitoringService().notifyBanDetected(errorMessage);
      
      print('🚫 Ban notification sent to UI - dialog should appear');
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
      final response = await _requestWithCloudflareRetry(
        () => _dio.get(path),
        path: path,
      );
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
      final response = await _requestWithCloudflareRetry(
        () => _dio.post(path, data: data),
        path: path,
      );
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
      final response = await _requestWithCloudflareRetry(
        () => _dio.put(path, data: data),
        path: path,
      );
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
      final response = await _requestWithCloudflareRetry(
        () => _dio.delete(path, data: data),
        path: path,
      );
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
    String? qrImageUrl,
  }) async {
    final data = <String, dynamic>{};
    if (name != null) {
      data['name'] = name;
    }
    if (phone != null) {
      data['phone'] = phone;
    }
    if (qrImageUrl != null) {
      data['qr_image_url'] = qrImageUrl;
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
    String roomspaceId,
    String memberFirebaseUid,
  ) async {
    return await delete(
      '/api/roomspaces/$roomspaceId/members',
      data: {'member_firebase_uid': memberFirebaseUid},
    );
  }

  Future<Map<String, dynamic>> leaveRoomspace(String roomspaceId) async {
    return await post('/api/roomspaces/$roomspaceId/leave');
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
      
      // Notify real-time service about the new expense
      final roomspaceId = expenseData['roomspace_id']?.toString();
      if (roomspaceId != null) {
        RealTimeDataService().notifyExpenseCreated(roomspaceId, response);
      }
      
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
      
      // Notify real-time service about the new personal expense
      RealTimeDataService().notifyPersonalExpenseCreated(response);
      
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

      // Trigger immediate UI refresh across all screens that listen for
      // real-time expense/balance updates (home recent activity, shared list, etc.).
      try {
        final data = response['data'];
        final roomspaceId = data is Map<String, dynamic> ? data['roomspace_id']?.toString() : null;
        if (roomspaceId != null && roomspaceId.isNotEmpty) {
          RealTimeDataService().notifyExpenseDeleted(roomspaceId, expenseId.toString(), const []);
        } else {
          // Fallback when backend delete response doesn't include roomspace_id.
          RealTimeDataService().clearAllData();
        }
      } catch (_) {
        RealTimeDataService().clearAllData();
      }

      return response;
    } on DioException catch (e) {
      // Extract error message from response
      if (e.response?.data is Map<String, dynamic>) {
        final errorData = e.response!.data as Map<String, dynamic>;
        final errorMessage = errorData['error'] ?? 'Failed to delete expense';
        throw Exception(errorMessage);
      }
      throw Exception('Failed to delete expense: ${e.message}');
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

  // ══════════════════════════════════════════════════════════════════
  // RECURRING EXPENSES
  // ══════════════════════════════════════════════════════════════════

  /// Get recurring expense templates for a roomspace
  Future<Map<String, dynamic>> getRecurringExpenseTemplates(String roomspaceId) async {
    try {
      final response = await _dio.get('/api/roomspaces/$roomspaceId/recurring-expenses');
      return response.data;
    } catch (e) {
      throw Exception('Failed to get recurring expense templates: ${e.toString()}');
    }
  }

  /// Create a recurring expense template
  Future<Map<String, dynamic>> createRecurringExpenseTemplate(Map<String, dynamic> templateData) async {
    try {
      final response = await _dio.post('/api/recurring-expenses', data: templateData);
      return response.data;
    } catch (e) {
      throw Exception('Failed to create recurring expense template: ${e.toString()}');
    }
  }

  /// Update a recurring expense template
  Future<Map<String, dynamic>> updateRecurringExpenseTemplate(int templateId, Map<String, dynamic> templateData) async {
    try {
      final response = await _dio.put('/api/recurring-expenses/$templateId', data: templateData);
      return response.data;
    } catch (e) {
      throw Exception('Failed to update recurring expense template: ${e.toString()}');
    }
  }

  /// Delete a recurring expense template
  Future<Map<String, dynamic>> deleteRecurringExpenseTemplate(int templateId) async {
    try {
      final response = await _dio.delete('/api/recurring-expenses/$templateId');
      return response.data;
    } catch (e) {
      throw Exception('Failed to delete recurring expense template: ${e.toString()}');
    }
  }

  /// Restore a soft-deleted recurring expense template
  Future<Map<String, dynamic>> restoreRecurringExpenseTemplate(int templateId) async {
    try {
      final response = await _dio.post('/api/recurring-expenses/$templateId/restore');
      return response.data;
    } catch (e) {
      throw Exception('Failed to restore recurring expense template: ${e.toString()}');
    }
  }

  /// Get recurring expense notifications
  Future<Map<String, dynamic>> getRecurringExpenseNotifications() async {
    try {
      final response = await _dio.get('/api/recurring-expenses/notifications');
      return response.data;
    } catch (e) {
      throw Exception('Failed to get recurring expense notifications: ${e.toString()}');
    }
  }

  /// Process a recurring expense notification
  Future<Map<String, dynamic>> processRecurringExpenseNotification(
    int notificationId, 
    Map<String, dynamic> actionData
  ) async {
    try {
      final response = await _dio.post(
        '/api/recurring-expenses/notifications/$notificationId/process',
        data: actionData,
      );
      return response.data;
    } catch (e) {
      throw Exception('Failed to process recurring expense notification: ${e.toString()}');
    }
  }

  /// Get upcoming recurring expenses for a roomspace
  Future<Map<String, dynamic>> getUpcomingRecurringExpenses(String roomspaceId, {int days = 30}) async {
    try {
      final response = await _dio.get('/api/roomspaces/$roomspaceId/recurring-expenses/upcoming?days=$days');
      return response.data;
    } catch (e) {
      throw Exception('Failed to get upcoming recurring expenses: ${e.toString()}');
    }
  }

  /// Get recurring expense statistics for a roomspace
  Future<Map<String, dynamic>> getRecurringExpenseStats(String roomspaceId) async {
    try {
      final response = await _dio.get('/api/roomspaces/$roomspaceId/recurring-expenses/stats');
      return response.data;
    } catch (e) {
      throw Exception('Failed to get recurring expense statistics: ${e.toString()}');
    }
  }

  /// Update backend IP address (for testing purposes)
  Future<void> updateBackendIp(String newIp) async {
    // For now, this is a placeholder method
    // In a real implementation, you might want to update the base URL
    // and reinitialize the Dio instance
    print('Backend IP update requested: $newIp');
    // Note: This would require reinitializing the Dio instance with new baseUrl
  }

  Future<Response<dynamic>> _requestWithCloudflareRetry(
    Future<Response<dynamic>> Function() requestFn, {
    required String path,
  }) async {
    try {
      return await requestFn();
    } on DioException catch (e) {
      final statusCode = e.response?.statusCode;
      if (statusCode == 520) {
        int retryAfterSeconds = 2;
        final data = e.response?.data;
        if (data is Map<String, dynamic>) {
          final retryAfter = data['retry_after'];
          if (retryAfter is int) {
            retryAfterSeconds = retryAfter;
          } else if (retryAfter is String) {
            retryAfterSeconds = int.tryParse(retryAfter) ?? retryAfterSeconds;
          }
        }
        // Keep retry bounded so the UI is not blocked too long.
        final boundedRetry = retryAfterSeconds.clamp(1, 8);
        print('⚠️ Cloudflare 520 on $path. Retrying in ${boundedRetry}s...');
        await Future.delayed(Duration(seconds: boundedRetry));
        return await requestFn();
      }
      rethrow;
    }
  }
}
