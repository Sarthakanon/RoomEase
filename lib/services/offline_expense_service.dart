import '../models/expense_models.dart';
import 'api_service.dart';
import 'connectivity_service.dart';
import 'local_database_service.dart';
import 'expense_service.dart';
import 'sync_service.dart';

/// Offline-aware expense service
/// Handles expenses with automatic local storage and sync
class OfflineExpenseService {
  static final OfflineExpenseService _instance = OfflineExpenseService._internal();
  factory OfflineExpenseService() => _instance;
  OfflineExpenseService._internal();

  final ConnectivityService _connectivityService = ConnectivityService();
  final LocalDatabaseService _localDb = LocalDatabaseService();
  final ExpenseService _expenseService = ExpenseService();
  final SyncService _syncService = SyncService();
  final ApiService _apiService = ApiService();

  /// Initialize the service
  Future<void> initialize() async {
    await _connectivityService.initialize();
    await _syncService.initialize();
    print('✅ Offline expense service initialized');
  }

  // ══════════════════════════════════════════════════════════════════
  // EXPENSE OPERATIONS
  // ══════════════════════════════════════════════════════════════════

  /// Create expense (works offline)
  Future<ExpenseData> createExpense(ExpenseCreateRequest request) async {
    if (_connectivityService.isConnected) {
      // Online: Create on server and save to local DB
      try {
        final expense = await _expenseService.createExpense(request);
        await _localDb.saveExpense(expense, isSynced: true);
        print('✅ Expense created online and cached locally');
        return expense;
      } catch (e) {
        print('❌ Failed to create expense online: $e');
        // Fall back to offline mode
        return await _createExpenseOffline(request);
      }
    } else {
      // Offline: Save locally and queue for sync
      return await _createExpenseOffline(request);
    }
  }

  /// Create expense offline
  Future<ExpenseData> _createExpenseOffline(ExpenseCreateRequest request) async {
    print('📴 Creating expense offline');
    
    // Create a temporary expense with local ID
    final localId = DateTime.now().millisecondsSinceEpoch.toString();
    final expense = ExpenseData(
      title: request.title,
      amount: request.amount,
      description: request.description,
      category: request.category,
      roomspaceId: request.roomspaceId,
      paidBy: request.paidBy,
      splitType: SplitType.fromString(request.splitType),
      selectedRoommateIds: request.selectedRoommates,
      customSplits: request.customSplits ?? {},
      createdAt: DateTime.now(),
    );

    // Save to local database
    await _localDb.saveExpense(
      expense,
      isSynced: false,
      localId: localId,
    );

    // Add to sync queue
    final requestData = request.toJson();
    requestData['local_id'] = localId;
    
    await _localDb.addToSyncQueue(
      operationType: 'CREATE',
      entityType: 'EXPENSE',
      entityId: localId,
      data: requestData,
    );

    print('✅ Expense saved offline - will sync when online');
    return expense;
  }

  /// Get expenses (from local DB, with optional sync)
  Future<List<ExpenseData>> getExpenses({
    String? roomspaceId,
    int? limit,
    int? offset,
    bool forceSync = false,
  }) async {
    // Sync if online and force sync requested
    if (forceSync && _connectivityService.isConnected) {
      await _syncService.syncAll();
    }

    // Always return from local database
    return await _localDb.getExpenses(
      roomspaceId: roomspaceId,
      limit: limit,
      offset: offset,
    );
  }

  /// Get roomspace expenses
  Future<List<ExpenseData>> getRoomspaceExpenses(
    String roomspaceId, {
    int? limit,
    int? offset,
    bool forceSync = false,
  }) async {
    return await getExpenses(
      roomspaceId: roomspaceId,
      limit: limit,
      offset: offset,
      forceSync: forceSync,
    );
  }

  /// Delete expense (works offline)
  Future<void> deleteExpense(int expenseId) async {
    if (_connectivityService.isConnected) {
      // Online: Delete from server and local DB
      try {
        await _expenseService.deleteExpense(expenseId);
        await _localDb.deleteExpense(expenseId);
        print('✅ Expense deleted online and from cache');
      } catch (e) {
        print('❌ Failed to delete expense online: $e');
        // Fall back to offline mode
        await _deleteExpenseOffline(expenseId);
      }
    } else {
      // Offline: Queue for deletion
      await _deleteExpenseOffline(expenseId);
    }
  }

  /// Delete expense offline
  Future<void> _deleteExpenseOffline(int expenseId) async {
    print('📴 Deleting expense offline');
    
    // Mark as deleted locally (or remove from DB)
    await _localDb.deleteExpense(expenseId);

    // Add to sync queue
    await _localDb.addToSyncQueue(
      operationType: 'DELETE',
      entityType: 'EXPENSE',
      entityId: expenseId.toString(),
      data: {'id': expenseId},
    );

    print('✅ Expense deleted offline - will sync when online');
  }

  // ══════════════════════════════════════════════════════════════════
  // PERSONAL EXPENSE OPERATIONS
  // ══════════════════════════════════════════════════════════════════

  /// Create personal expense (works offline)
  Future<PersonalExpenseData> createPersonalExpense(PersonalExpenseCreateRequest request) async {
    if (_connectivityService.isConnected) {
      // Online: Create on server and save to local DB
      try {
        final response = await _apiService.createPersonalExpense(request.toJson());
        final expense = PersonalExpenseData.fromJson(response['data']);
        await _localDb.savePersonalExpense(expense, isSynced: true);
        print('✅ Personal expense created online and cached locally');
        return expense;
      } catch (e) {
        print('❌ Failed to create personal expense online: $e');
        // Fall back to offline mode
        return await _createPersonalExpenseOffline(request);
      }
    } else {
      // Offline: Save locally and queue for sync
      return await _createPersonalExpenseOffline(request);
    }
  }

  /// Create personal expense offline
  Future<PersonalExpenseData> _createPersonalExpenseOffline(PersonalExpenseCreateRequest request) async {
    print('📴 Creating personal expense offline');
    
    // Create a temporary expense with local ID
    final localId = DateTime.now().millisecondsSinceEpoch.toString();
    final expense = PersonalExpenseData(
      title: request.title,
      amount: request.amount,
      description: request.description,
      category: request.category,
      createdAt: DateTime.now(),
    );

    // Save to local database
    await _localDb.savePersonalExpense(
      expense,
      isSynced: false,
      localId: localId,
    );

    // Add to sync queue
    final requestData = request.toJson();
    requestData['local_id'] = localId;
    
    await _localDb.addToSyncQueue(
      operationType: 'CREATE',
      entityType: 'PERSONAL_EXPENSE',
      entityId: localId,
      data: requestData,
    );

    print('✅ Personal expense saved offline - will sync when online');
    return expense;
  }

  /// Get personal expenses (from local DB, with optional sync)
  Future<List<PersonalExpenseData>> getPersonalExpenses({
    int? limit,
    int? offset,
    bool forceSync = false,
  }) async {
    // Sync if online and force sync requested
    if (forceSync && _connectivityService.isConnected) {
      await _syncService.syncAll();
    }

    // Always return from local database
    return await _localDb.getPersonalExpenses(
      limit: limit,
      offset: offset,
    );
  }

  /// Delete personal expense (works offline)
  Future<void> deletePersonalExpense(int expenseId) async {
    if (_connectivityService.isConnected) {
      // Online: Delete from server and local DB
      try {
        await _apiService.deletePersonalExpense(expenseId);
        await _localDb.deletePersonalExpense(expenseId);
        print('✅ Personal expense deleted online and from cache');
      } catch (e) {
        print('❌ Failed to delete personal expense online: $e');
        // Fall back to offline mode
        await _deletePersonalExpenseOffline(expenseId);
      }
    } else {
      // Offline: Queue for deletion
      await _deletePersonalExpenseOffline(expenseId);
    }
  }

  /// Delete personal expense offline
  Future<void> _deletePersonalExpenseOffline(int expenseId) async {
    print('📴 Deleting personal expense offline');
    
    // Mark as deleted locally (or remove from DB)
    await _localDb.deletePersonalExpense(expenseId);

    // Add to sync queue
    await _localDb.addToSyncQueue(
      operationType: 'DELETE',
      entityType: 'PERSONAL_EXPENSE',
      entityId: expenseId.toString(),
      data: {'id': expenseId},
    );

    print('✅ Personal expense deleted offline - will sync when online');
  }

  // ══════════════════════════════════════════════════════════════════
  // UTILITY METHODS
  // ══════════════════════════════════════════════════════════════════

  /// Check if device is online
  bool get isOnline => _connectivityService.isConnected;

  /// Get sync status
  Future<Map<String, dynamic>> getSyncStatus() async {
    return await _syncService.getSyncStats();
  }

  /// Force sync all data
  Future<SyncResult> syncAll() async {
    return await _syncService.syncAll();
  }

  /// Get unsynced expenses count
  Future<int> getUnsyncedCount() async {
    final stats = await _localDb.getDatabaseStats();
    return (stats['unsynced_expenses'] ?? 0) + (stats['unsynced_personal_expenses'] ?? 0);
  }
}
