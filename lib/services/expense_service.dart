import '../models/expense_models.dart';
import 'api_service.dart';

class ExpenseService {
  static final ExpenseService _instance = ExpenseService._internal();
  factory ExpenseService() => _instance;
  ExpenseService._internal();

  final ApiService _apiService = ApiService();

  /// Creates a new expense
  /// 
  /// Throws [Exception] if the creation fails
  Future<ExpenseData> createExpense(
    ExpenseCreateRequest request,
  ) async {
    try {
      final response = await _apiService.createExpense(request.toJson());
      
      if (response['success'] == true && response['data'] != null) {
        return ExpenseData.fromJson(response['data']);
      } else {
        throw Exception(response['error'] ?? 'Failed to create expense');
      }
    } catch (e) {
      if (e is Exception) {
        rethrow;
      }
      throw Exception('Failed to create expense: ${e.toString()}');
    }
  }

  /// Retrieves expenses for the current user across all roomspaces or filtered by roomspace
  /// 
  /// [roomspaceId] - Optional roomspace ID to filter expenses
  /// [limit] - Maximum number of expenses to retrieve (default: 20)
  /// [offset] - Number of expenses to skip for pagination (default: 0)
  /// 
  /// Returns a list of [ExpenseData] and metadata
  Future<ExpenseListResponse> getExpenses({
    String? roomspaceId,
    int? limit,
    int? offset,
  }) async {
    try {
      final response = await _apiService.getExpenses(
        roomspaceId: roomspaceId,
        limit: limit,
        offset: offset,
      );
      
      if (response['success'] == true) {
        // Handle null or empty data gracefully
        final data = response['data'];
        final expenses = <ExpenseData>[];
        
        if (data != null && data is List) {
          expenses.addAll(
            data.map((expense) => ExpenseData.fromJson(expense)).toList()
          );
        }
        
        final meta = response['meta'] as Map<String, dynamic>? ?? {};
        
        return ExpenseListResponse(
          expenses: expenses,
          limit: meta['limit'] ?? limit ?? 20,
          offset: meta['offset'] ?? offset ?? 0,
          count: meta['count'] ?? expenses.length,
        );
      } else {
        throw Exception(response['error'] ?? 'Failed to retrieve expenses');
      }
    } catch (e) {
      if (e is Exception) {
        rethrow;
      }
      throw Exception('Failed to retrieve expenses: ${e.toString()}');
    }
  }

  /// Retrieves a specific expense by ID
  /// 
  /// Throws [Exception] if the expense is not found or access is denied
  Future<ExpenseData> getExpenseById(int expenseId) async {
    try {
      final response = await _apiService.getExpenseById(expenseId);
      
      if (response['success'] == true && response['data'] != null) {
        return ExpenseData.fromJson(response['data']);
      } else {
        throw Exception(response['error'] ?? 'Failed to retrieve expense');
      }
    } catch (e) {
      if (e is Exception) {
        rethrow;
      }
      throw Exception('Failed to retrieve expense: ${e.toString()}');
    }
  }

  /// Retrieves expenses for a specific roomspace
  /// 
  /// [roomspaceId] - ID of the roomspace
  /// [limit] - Maximum number of expenses to retrieve (default: 20)
  /// [offset] - Number of expenses to skip for pagination (default: 0)
  /// 
  /// Returns a list of [ExpenseData] and metadata
  Future<ExpenseListResponse> getRoomspaceExpenses(
    String roomspaceId, {
    int? limit,
    int? offset,
  }) async {
    try {
      final response = await _apiService.getRoomspaceExpenses(
        roomspaceId,
        limit: limit,
        offset: offset,
      );
      
      if (response['success'] == true) {
        // Handle null or empty data gracefully
        final data = response['data'];
        final expenses = <ExpenseData>[];
        
        if (data != null && data is List) {
          expenses.addAll(
            data.map((expense) => ExpenseData.fromJson(expense)).toList()
          );
        }
        
        final meta = response['meta'] as Map<String, dynamic>? ?? {};
        
        return ExpenseListResponse(
          expenses: expenses,
          limit: meta['limit'] ?? limit ?? 20,
          offset: meta['offset'] ?? offset ?? 0,
          count: meta['count'] ?? expenses.length,
        );
      } else {
        throw Exception(response['error'] ?? 'Failed to retrieve roomspace expenses');
      }
    } catch (e) {
      if (e is Exception) {
        rethrow;
      }
      throw Exception('Failed to retrieve roomspace expenses: ${e.toString()}');
    }
  }

  /// Retrieves recent expenses for a roomspace (typically for dashboard)
  /// 
  /// [roomspaceId] - Optional ID of the roomspace (if not provided, gets recent expenses across all roomspaces)
  /// [limit] - Maximum number of recent expenses to retrieve (default: 3)
  /// 
  /// Returns a list of recent [ExpenseData]
  Future<List<ExpenseData>> getRecentExpenses({
    String? roomspaceId,
    int limit = 3,
  }) async {
    try {
      final response = await _apiService.getRecentExpenses(
        roomspaceId: roomspaceId,
        limit: limit,
      );
      
      if (response['success'] == true) {
        // Handle null or empty data gracefully
        final data = response['data'];
        if (data == null) {
          return [];
        }
        
        if (data is List) {
          return data
              .map((expense) => ExpenseData.fromJson(expense))
              .toList();
        }
        
        return [];
      } else {
        throw Exception(response['error'] ?? 'Failed to retrieve recent expenses');
      }
    } catch (e) {
      if (e is Exception) {
        rethrow;
      }
      throw Exception('Failed to retrieve recent expenses: ${e.toString()}');
    }
  }

  /// Retrieves expenses for the current user across all roomspaces
  /// 
  /// [limit] - Maximum number of expenses to retrieve (default: 20)
  /// [offset] - Number of expenses to skip for pagination (default: 0)
  /// 
  /// Returns a list of [ExpenseData]
  Future<List<ExpenseData>> getUserExpenses({
    int? limit,
    int? offset,
  }) async {
    try {
      final response = await getExpenses(limit: limit, offset: offset);
      return response.expenses;
    } catch (e) {
      if (e is Exception) {
        rethrow;
      }
      throw Exception('Failed to retrieve user expenses: ${e.toString()}');
    }
  }

  /// Retrieves only personal expenses for the current user.
  Future<List<PersonalExpenseData>> getPersonalExpenses({
    int? limit,
    int? offset,
  }) async {
    try {
      final response = await _apiService.getPersonalExpenses(
        limit: limit,
        offset: offset,
      );
      if (response['success'] == true) {
        final data = response['data'];
        if (data is List) {
          return data.map((e) => PersonalExpenseData.fromJson(e)).toList();
        }
        return [];
      }
      throw Exception(response['error'] ?? 'Failed to retrieve personal expenses');
    } catch (e) {
      if (e is Exception) rethrow;
      throw Exception('Failed to retrieve personal expenses: ${e.toString()}');
    }
  }

  /// Updates an existing expense
  /// 
  /// Throws [Exception] if the update fails
  Future<ExpenseData> updateExpense(
    int expenseId,
    ExpenseCreateRequest request,
  ) async {
    try {
      final response = await _apiService.updateExpense(expenseId, request.toJson());
      
      if (response['success'] == true && response['data'] != null) {
        return ExpenseData.fromJson(response['data']);
      } else {
        throw Exception(response['error'] ?? 'Failed to update expense');
      }
    } catch (e) {
      if (e is Exception) {
        rethrow;
      }
      throw Exception('Failed to update expense: ${e.toString()}');
    }
  }

  /// Deletes an expense
  /// 
  /// Throws [Exception] if the deletion fails
  Future<void> deleteExpense(int expenseId) async {
    try {
      final response = await _apiService.deleteExpense(expenseId);
      
      if (response['success'] != true) {
        throw Exception(response['error'] ?? 'Failed to delete expense');
      }
    } catch (e) {
      if (e is Exception) {
        rethrow;
      }
      throw Exception('Failed to delete expense: ${e.toString()}');
    }
  }

  /// Creates an expense from ExpenseData and roomspace ID
  /// 
  /// This is a convenience method that converts ExpenseData to the proper request format
  Future<ExpenseData> createExpenseFromData(
    ExpenseData expenseData,
    String roomspaceId,
  ) async {
    final request = ExpenseCreateRequest.fromExpenseData(expenseData, roomspaceId);
    return await createExpense(request);
  }
}

/// Response wrapper for expense list operations
class ExpenseListResponse {
  final List<ExpenseData> expenses;
  final int limit;
  final int offset;
  final int count;

  ExpenseListResponse({
    required this.expenses,
    required this.limit,
    required this.offset,
    required this.count,
  });

  /// Whether there might be more expenses available
  bool get hasMore => count == limit;

  /// Next offset for pagination
  int get nextOffset => offset + count;
}
