import 'package:dio/dio.dart';

class AdminApiService {
  static final AdminApiService _instance = AdminApiService._internal();
  factory AdminApiService() => _instance;

  late final Dio _dio;
  
  // Backend API URL
  static const String baseUrl = 'https://roomease-backend-80x8.onrender.com';

  AdminApiService._internal() {
    _dio = Dio(
      BaseOptions(
        baseUrl: baseUrl,
        connectTimeout: const Duration(seconds: 30),
        receiveTimeout: const Duration(seconds: 30),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
      ),
    );

    _dio.interceptors.add(
      LogInterceptor(
        requestBody: true,
        responseBody: true,
        error: true,
      ),
    );
  }

  Dio get dio => _dio;

  // Generic GET request
  Future<Map<String, dynamic>> get(String path) async {
    try {
      final response = await _dio.get(path);
      return response.data as Map<String, dynamic>;
    } on DioException catch (e) {
      throw Exception(_handleError(e));
    }
  }

  // Generic POST request
  Future<Map<String, dynamic>> post(
    String path, {
    Map<String, dynamic>? data,
  }) async {
    try {
      final response = await _dio.post(path, data: data);
      return response.data as Map<String, dynamic>;
    } on DioException catch (e) {
      throw Exception(_handleError(e));
    }
  }

  // Generic PUT request
  Future<Map<String, dynamic>> put(
    String path, {
    Map<String, dynamic>? data,
  }) async {
    try {
      final response = await _dio.put(path, data: data);
      return response.data as Map<String, dynamic>;
    } on DioException catch (e) {
      throw Exception(_handleError(e));
    }
  }

  // Generic DELETE request
  Future<Map<String, dynamic>> delete(String path) async {
    try {
      final response = await _dio.delete(path);
      return response.data as Map<String, dynamic>;
    } on DioException catch (e) {
      throw Exception(_handleError(e));
    }
  }

  String _handleError(DioException error) {
    if (error.response != null) {
      final data = error.response!.data;
      if (data is Map && data.containsKey('error')) {
        return data['error'].toString();
      }
      return 'Server error: ${error.response!.statusCode}';
    }
    return 'Network error: ${error.message}';
  }
}
