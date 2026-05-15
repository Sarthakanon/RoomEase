import 'package:dio/dio.dart';

class AdminApiService {
  static final AdminApiService _instance = AdminApiService._internal();
  factory AdminApiService() => _instance;

  late final Dio _dio;
  
  // Backend API URL
  static const String baseUrl = 'http://192.168.1.89:8080';

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

  // Get system statistics
  Future<Map<String, dynamic>> getSystemStats() async {
    try {
      final response = await _dio.get('/api/admin/stats');
      return response.data as Map<String, dynamic>;
    } on DioException catch (e) {
      throw Exception(_handleError(e));
    }
  }

  // Get all users
  Future<Map<String, dynamic>> getAllUsers() async {
    try {
      final response = await _dio.get('/api/admin/users');
      return response.data as Map<String, dynamic>;
    } on DioException catch (e) {
      throw Exception(_handleError(e));
    }
  }

  // Ban a user
  Future<Map<String, dynamic>> banUser(String userId, String reason) async {
    try {
      final response = await _dio.post('/api/admin/users/$userId/ban', data: {
        'reason': reason,
      });
      return response.data as Map<String, dynamic>;
    } on DioException catch (e) {
      throw Exception(_handleError(e));
    }
  }

  // Unban a user
  Future<Map<String, dynamic>> unbanUser(String userId) async {
    try {
      final response = await _dio.post('/api/admin/users/$userId/unban');
      return response.data as Map<String, dynamic>;
    } on DioException catch (e) {
      throw Exception(_handleError(e));
    }
  }

  // Check if user is banned (for mobile app)
  Future<Map<String, dynamic>> checkUserBanStatus(String userId) async {
    try {
      final response = await _dio.get('/api/admin/users/$userId/ban-status');
      return response.data as Map<String, dynamic>;
    } on DioException catch (e) {
      throw Exception(_handleError(e));
    }
  }

  // Get user details
  Future<Map<String, dynamic>> getUserDetails(String userId) async {
    try {
      final response = await _dio.get('/api/admin/users/$userId');
      return response.data as Map<String, dynamic>;
    } on DioException catch (e) {
      throw Exception(_handleError(e));
    }
  }

  // Get all roomspaces
  Future<Map<String, dynamic>> getAllRoomspaces() async {
    try {
      final response = await _dio.get('/api/admin/roomspaces');
      return response.data as Map<String, dynamic>;
    } on DioException catch (e) {
      throw Exception(_handleError(e));
    }
  }

  // Get roomspace details
  Future<Map<String, dynamic>> getRoomspaceDetails(String roomspaceId) async {
    try {
      final response = await _dio.get('/api/admin/roomspaces/$roomspaceId');
      return response.data as Map<String, dynamic>;
    } on DioException catch (e) {
      throw Exception(_handleError(e));
    }
  }

  // Get all expenses
  Future<Map<String, dynamic>> getAllExpenses({int? limit, int? offset}) async {
    try {
      final queryParams = <String, dynamic>{};
      if (limit != null) queryParams['limit'] = limit;
      if (offset != null) queryParams['offset'] = offset;
      
      final response = await _dio.get(
        '/api/admin/expenses',
        queryParameters: queryParams,
      );
      return response.data as Map<String, dynamic>;
    } on DioException catch (e) {
      throw Exception(_handleError(e));
    }
  }

  // Get expense details
  Future<Map<String, dynamic>> getExpenseDetails(int expenseId) async {
    try {
      final response = await _dio.get('/api/admin/expenses/$expenseId');
      return response.data as Map<String, dynamic>;
    } on DioException catch (e) {
      throw Exception(_handleError(e));
    }
  }

  // Get all personal expenses
  Future<Map<String, dynamic>> getAllPersonalExpenses({int? limit, int? offset}) async {
    try {
      final queryParams = <String, dynamic>{};
      if (limit != null) queryParams['limit'] = limit;
      if (offset != null) queryParams['offset'] = offset;
      
      final response = await _dio.get(
        '/api/admin/personal-expenses',
        queryParameters: queryParams,
      );
      return response.data as Map<String, dynamic>;
    } on DioException catch (e) {
      throw Exception(_handleError(e));
    }
  }

  // Get analytics data
  Future<Map<String, dynamic>> getAnalyticsData() async {
    try {
      final response = await _dio.get('/api/admin/analytics');
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