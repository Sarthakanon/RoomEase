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

  // Platform-specific base URL
  static String get baseUrl {
    if (kIsWeb) {
      return 'http://localhost:8080'; // Web uses localhost
    } else {
      // Use your computer's actual IP address
      // Change this if your IP changes when switching networks
      return 'http://172.20.10.5:8080'; // Android emulator
    }
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

  Future<Map<String, dynamic>> delete(String path) async {
    try {
      final response = await _dio.delete(path);
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
