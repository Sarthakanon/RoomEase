import 'dart:io' show Platform;
import 'package:dio/dio.dart';
import 'package:dio_cookie_manager/dio_cookie_manager.dart';
import 'package:cookie_jar/cookie_jar.dart';
import 'package:flutter/foundation.dart' show kIsWeb;

class ApiService {
  static final ApiService _instance = ApiService._internal();

  factory ApiService() {
    return _instance;
  }

  late final Dio _dio;
  late final CookieJar _cookieJar;

  // Using localhost with adb reverse works on any network
  // Just run: adb reverse tcp:8080 tcp:8080
  static String get baseUrl {
    if (kIsWeb) {
      return 'http://localhost:8080';
    }

    // adb reverse makes localhost work on physical Android devices via USB
    // This is network-independent - works on any WiFi/hotspot
    if (Platform.isAndroid) {
      return 'http://localhost:8080';
    } else if (Platform.isIOS) {
      // iOS requires the actual IP address for physical devices
      // For simulator, localhost works
      return 'http://localhost:8080';
    }

    return 'http://localhost:8080';
  }

  ApiService._internal() {
    _cookieJar = CookieJar();

    _dio = Dio(
      BaseOptions(
        baseUrl: baseUrl,
        connectTimeout: const Duration(seconds: 10),
        receiveTimeout: const Duration(seconds: 10),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
      ),
    );

    // Add cookie manager to persist cookies
    _dio.interceptors.add(CookieManager(_cookieJar));

    _dio.interceptors.add(
      LogInterceptor(requestBody: true, responseBody: true, error: true),
    );
  }

  Dio get dio {
    return _dio;
  }

  Future<void> clearCookies() async {
    // Clear all cookies from the cookie jar
    await _cookieJar.deleteAll();
  }

  Future<Map<String, dynamic>> login(String firebaseToken) async {
    try {
      final response = await _dio.post(
        '/api/auth/login',
        data: {'firebase_token': firebaseToken},
      );
      return response.data as Map<String, dynamic>;
    } on DioException catch (e) {
      final errorMessage = _handleError(e);
      throw Exception(errorMessage);
    }
  }

  Future<Map<String, dynamic>> logout() async {
    try {
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
    int? limit,
    int? offset,
  }) async {
    try {
      final queryParams = <String, String>{};
      if (limit != null) queryParams['limit'] = limit.toString();
      if (offset != null) queryParams['offset'] = offset.toString();
      
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
    int? limit,
    int? offset,
  }) async {
    try {
      final queryParams = <String, String>{};
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
  }) async {
    try {
      final queryParams = <String, String>{};
      if (limit != null) queryParams['limit'] = limit.toString();
      if (offset != null) queryParams['offset'] = offset.toString();
      
      final path = '/api/roomspaces/$roomspaceId/expenses${queryParams.isNotEmpty ? '?${Uri(queryParameters: queryParams).query}' : ''}';
      return await get(path);
    } catch (e) {
      throw Exception('Failed to retrieve roomspace expenses: ${e.toString()}');
    }
  }

  Future<Map<String, dynamic>> getRecentExpenses(
    String roomspaceId, {
    int limit = 3,
  }) async {
    try {
      return await get('/api/roomspaces/$roomspaceId/expenses/recent?limit=$limit');
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
      final response = await get('/api/roomspaces/$roomspaceId/members');
      return response;
    } catch (e) {
      throw Exception('Failed to get roomspace members: ${e.toString()}');
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
