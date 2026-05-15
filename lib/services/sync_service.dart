import 'dart:async';
import 'dart:convert';
import 'connectivity_service.dart';
import 'local_database_service.dart';
import 'api_service.dart';
import '../models/expense_models.dart';

/// Service to handle automatic synchronization between local and remote data
class SyncService {
  static final SyncService _instance = SyncService._internal();
  factory SyncService() => _instance;
  SyncService._internal();

  final ConnectivityService _connectivityService = ConnectivityService();
  final LocalDatabaseService _localDb = LocalDatabaseService();
  final ApiService _apiService = ApiService();

  StreamSubscription<bool>? _connectivitySubscription;
  bool _isSyncing = false;
  bool _isInitialized = false;

  final StreamController<SyncStatus> _syncStatusController = StreamController<SyncStatus>.broadcast();
  
  /// Stream of sync status updates
  Stream<SyncStatus> get syncStatusStream => _syncStatusController.stream;

  /// Current sync status
  SyncStatus _currentStatus = SyncStatus.idle;
  SyncStatus get currentStatus => _currentStatus;

  /// Initialize sync service
  Future<void> initialize() async {
    if (_isInitialized) return;
    
    // Initialize connectivity service
    await _connectivityService.initialize();
    
    // Listen to connectivity changes
    _connectivitySubscription = _connectivityService.connectivityStream.listen(
      (isConnected) {
        if (isConnected) {
          print('🔄 Internet restored - triggering sync');
          syncAll();
        }
      },
    );
    
    _isInitialized = true;
    print('🔄 Sync service initialized');
  }

  /// Sync all data (expenses, personal expenses, roomspaces)
  Future<SyncResult> syncAll() async {
    if (_isSyncing) {
      print('⚠️ Sync already in progress');
      return SyncResult(success: false, message: 'Sync already in progress');
    }

    if (!_connectivityService.isConnected) {
      print('⚠️ No internet connection - sync skipped');
      return SyncResult(success: false, message: 'No internet connection');
    }

    _isSyncing = true;
    _updateStatus(SyncStatus.syncing);

    try {
      print('🔄 Starting full sync...');
      
      // Step 1: Process sync queue (pending operations)
      await _processSyncQueue();
      
      // Step 2: Fetch latest data from server
      await _fetchLatestData();
      
      _updateStatus(SyncStatus.completed);
      print('✅ Sync completed successfully');
      
      return SyncResult(success: true, message: 'Sync completed');
    } catch (e) {
      print('❌ Sync failed: $e');
      _updateStatus(SyncStatus.failed);
      return SyncResult(success: false, message: 'Sync failed: $e');
    } finally {
      _isSyncing = false;
    }
  }

  /// Process pending sync operations
  Future<void> _processSyncQueue() async {
    final operations = await _localDb.getPendingSyncOperations();
    
    if (operations.isEmpty) {
      print('✅ No pending operations to sync');
      return;
    }

    print('🔄 Processing ${operations.length} pending operations...');

    for (final operation in operations) {
      try {
        await _processSyncOperation(operation);
        await _localDb.removeSyncOperation(operation['id'] as int);
        print('✅ Synced operation: ${operation['operation_type']} ${operation['entity_type']}');
      } catch (e) {
        print('❌ Failed to sync operation ${operation['id']}: $e');
        await _localDb.updateSyncOperationRetry(
          operation['id'] as int,
          e.toString(),
        );
      }
    }
  }

  /// Process a single sync operation
  Future<void> _processSyncOperation(Map<String, dynamic> operation) async {
    final operationType = operation['operation_type'] as String;
    final entityType = operation['entity_type'] as String;
    final data = jsonDecode(operation['data'] as String) as Map<String, dynamic>;

    switch (entityType) {
      case 'EXPENSE':
        await _syncExpenseOperation(operationType, data);
        break;
      case 'PERSONAL_EXPENSE':
        await _syncPersonalExpenseOperation(operationType, data);
        break;
      default:
        throw Exception('Unknown entity type: $entityType');
    }
  }

  /// Sync expense operation
  Future<void> _syncExpenseOperation(String operationType, Map<String, dynamic> data) async {
    switch (operationType) {
      case 'CREATE':
        final response = await _apiService.createExpense(data);
        if (response['success'] == true && response['data'] != null) {
          final serverExpense = ExpenseData.fromJson(response['data']);
          await _localDb.markExpenseAsSynced(
            data['local_id'] as String,
            serverExpense.id,
          );
        }
        break;
      case 'UPDATE':
        final expenseId = data['id'] as int;
        await _apiService.updateExpense(expenseId, data);
        break;
      case 'DELETE':
        final expenseId = data['id'] as int;
        await _apiService.deleteExpense(expenseId);
        break;
    }
  }

  /// Sync personal expense operation
  Future<void> _syncPersonalExpenseOperation(String operationType, Map<String, dynamic> data) async {
    switch (operationType) {
      case 'CREATE':
        final response = await _apiService.createPersonalExpense(data);
        if (response['success'] == true && response['data'] != null) {
          final serverExpense = PersonalExpenseData.fromJson(response['data']);
          await _localDb.markPersonalExpenseAsSynced(
            data['local_id'] as String,
            serverExpense.id,
          );
        }
        break;
      case 'DELETE':
        final expenseId = data['id'] as int;
        await _apiService.deletePersonalExpense(expenseId);
        break;
    }
  }

  /// Fetch latest data from server
  Future<void> _fetchLatestData() async {
    print('🔄 Fetching latest data from server...');
    
    try {
      // Fetch roomspaces
      final roomspacesResponse = await _apiService.getRoomspaces();
      if (roomspacesResponse['success'] == true && roomspacesResponse['data'] != null) {
        final roomspaces = roomspacesResponse['data'] as List;
        for (final roomspace in roomspaces) {
          await _localDb.saveRoomspace(roomspace);
          
          // Fetch expenses for each roomspace
          final roomspaceId = roomspace['id'] as String;
          await _fetchRoomspaceExpenses(roomspaceId);
        }
      }
      
      // Fetch personal expenses
      await _fetchPersonalExpenses();
      
      print('✅ Latest data fetched successfully');
    } catch (e) {
      print('❌ Error fetching latest data: $e');
      rethrow;
    }
  }

  /// Fetch expenses for a specific roomspace
  Future<void> _fetchRoomspaceExpenses(String roomspaceId) async {
    try {
      final response = await _apiService.getRoomspaceExpenses(roomspaceId);
      if (response['success'] == true && response['data'] != null) {
        final expenses = (response['data'] as List)
            .map((e) => ExpenseData.fromJson(e))
            .toList();
        
        for (final expense in expenses) {
          await _localDb.saveExpense(expense, isSynced: true);
        }
      }
    } catch (e) {
      print('❌ Error fetching expenses for roomspace $roomspaceId: $e');
    }
  }

  /// Fetch personal expenses
  Future<void> _fetchPersonalExpenses() async {
    try {
      final response = await _apiService.getPersonalExpenses();
      if (response['success'] == true && response['data'] != null) {
        final expenses = (response['data'] as List)
            .map((e) => PersonalExpenseData.fromJson(e))
            .toList();
        
        for (final expense in expenses) {
          await _localDb.savePersonalExpense(expense, isSynced: true);
        }
      }
    } catch (e) {
      print('❌ Error fetching personal expenses: $e');
    }
  }

  /// Update sync status
  void _updateStatus(SyncStatus status) {
    _currentStatus = status;
    _syncStatusController.add(status);
  }

  /// Get sync statistics
  Future<Map<String, dynamic>> getSyncStats() async {
    final dbStats = await _localDb.getDatabaseStats();
    final pendingOps = await _localDb.getPendingSyncOperations();
    
    return {
      'total_expenses': dbStats['expenses'],
      'total_personal_expenses': dbStats['personal_expenses'],
      'unsynced_expenses': dbStats['unsynced_expenses'],
      'unsynced_personal_expenses': dbStats['unsynced_personal_expenses'],
      'pending_operations': pendingOps.length,
      'is_connected': _connectivityService.isConnected,
      'last_sync_status': _currentStatus.toString(),
    };
  }

  /// Force sync (useful for pull-to-refresh)
  Future<SyncResult> forceSync() async {
    print('🔄 Force sync triggered');
    return await syncAll();
  }

  /// Dispose resources
  void dispose() {
    _connectivitySubscription?.cancel();
    _syncStatusController.close();
    _isInitialized = false;
  }
}

/// Sync status enum
enum SyncStatus {
  idle,
  syncing,
  completed,
  failed,
}

/// Sync result
class SyncResult {
  final bool success;
  final String message;
  
  SyncResult({required this.success, required this.message});
}
