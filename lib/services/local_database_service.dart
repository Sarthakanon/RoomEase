import 'dart:convert';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import '../models/expense_models.dart';

/// Local database service for offline storage
/// Stores expenses, roomspaces, and sync queue
class LocalDatabaseService {
  static final LocalDatabaseService _instance = LocalDatabaseService._internal();
  factory LocalDatabaseService() => _instance;
  LocalDatabaseService._internal();

  Database? _database;

  /// Get database instance
  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDatabase();
    return _database!;
  }

  /// Initialize database
  Future<Database> _initDatabase() async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, 'roomease_offline.db');

    return await openDatabase(
      path,
      version: 1,
      onCreate: _onCreate,
      onUpgrade: _onUpgrade,
    );
  }

  /// Create database tables
  Future<void> _onCreate(Database db, int version) async {
    // Expenses table
    await db.execute('''
      CREATE TABLE expenses (
        id INTEGER PRIMARY KEY,
        title TEXT NOT NULL,
        amount REAL NOT NULL,
        description TEXT,
        category TEXT NOT NULL,
        roomspace_id TEXT,
        paid_by TEXT,
        payer_name TEXT,
        split_type TEXT NOT NULL,
        created_at TEXT NOT NULL,
        splits TEXT,
        recurring_config TEXT,
        is_synced INTEGER DEFAULT 1,
        local_id TEXT UNIQUE
      )
    ''');

    // Personal expenses table
    await db.execute('''
      CREATE TABLE personal_expenses (
        id INTEGER PRIMARY KEY,
        title TEXT NOT NULL,
        amount REAL NOT NULL,
        description TEXT,
        category TEXT NOT NULL,
        created_at TEXT NOT NULL,
        is_synced INTEGER DEFAULT 1,
        local_id TEXT UNIQUE
      )
    ''');

    // Sync queue table - tracks pending operations
    await db.execute('''
      CREATE TABLE sync_queue (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        operation_type TEXT NOT NULL,
        entity_type TEXT NOT NULL,
        entity_id TEXT NOT NULL,
        data TEXT NOT NULL,
        created_at TEXT NOT NULL,
        retry_count INTEGER DEFAULT 0,
        last_error TEXT
      )
    ''');

    // Roomspaces cache table
    await db.execute('''
      CREATE TABLE roomspaces (
        id TEXT PRIMARY KEY,
        name TEXT NOT NULL,
        description TEXT,
        code TEXT,
        created_at TEXT NOT NULL,
        members TEXT,
        last_synced TEXT NOT NULL
      )
    ''');

    // Create indexes for better performance
    await db.execute('CREATE INDEX idx_expenses_roomspace ON expenses(roomspace_id)');
    await db.execute('CREATE INDEX idx_expenses_synced ON expenses(is_synced)');
    await db.execute('CREATE INDEX idx_personal_expenses_synced ON personal_expenses(is_synced)');
    await db.execute('CREATE INDEX idx_sync_queue_type ON sync_queue(operation_type, entity_type)');
  }

  /// Handle database upgrades
  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    // Handle future schema changes
  }

  // ══════════════════════════════════════════════════════════════════
  // EXPENSE OPERATIONS
  // ══════════════════════════════════════════════════════════════════

  /// Save expense to local database
  Future<void> saveExpense(
    ExpenseData expense, {
    bool isSynced = true,
    String? localId,
  }) async {
    final db = await database;
    
    await db.insert(
      'expenses',
      {
        'id': expense.id,
        'title': expense.title,
        'amount': expense.amount,
        'description': expense.description,
        'category': expense.category,
        'roomspace_id': expense.roomspaceId,
        'paid_by': expense.paidBy,
        'payer_name': expense.payerName,
        'split_type': expense.splitType.apiValue,
        'created_at': (expense.createdAt ?? DateTime.now()).toIso8601String(),
        'splits': expense.splits != null ? jsonEncode(expense.splits!.map((s) => {
          'user_uid': s.userUid,
          'user_name': s.userName,
          'amount': s.amount,
          'percentage': s.percentage,
        }).toList()) : null,
        'recurring_config': expense.recurringConfig != null 
            ? jsonEncode(expense.recurringConfig!.toJson()) 
            : null,
        'is_synced': isSynced ? 1 : 0,
        'local_id': localId ?? expense.id?.toString() ?? DateTime.now().millisecondsSinceEpoch.toString(),
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  /// Get all expenses from local database
  Future<List<ExpenseData>> getExpenses({
    String? roomspaceId,
    int? limit,
    int? offset,
  }) async {
    final db = await database;
    
    String query = 'SELECT * FROM expenses';
    List<dynamic> args = [];
    
    if (roomspaceId != null) {
      query += ' WHERE roomspace_id = ?';
      args.add(roomspaceId);
    }
    
    query += ' ORDER BY created_at DESC';
    
    if (limit != null) {
      query += ' LIMIT ?';
      args.add(limit);
      
      if (offset != null) {
        query += ' OFFSET ?';
        args.add(offset);
      }
    }
    
    final results = await db.rawQuery(query, args);
    return results.map((row) => _expenseFromMap(row)).toList();
  }

  /// Get unsynced expenses
  Future<List<ExpenseData>> getUnsyncedExpenses() async {
    final db = await database;
    final results = await db.query(
      'expenses',
      where: 'is_synced = ?',
      whereArgs: [0],
    );
    return results.map((row) => _expenseFromMap(row)).toList();
  }

  /// Mark expense as synced
  Future<void> markExpenseAsSynced(String localId, int? serverId) async {
    final db = await database;
    await db.update(
      'expenses',
      {
        'is_synced': 1,
        if (serverId != null) 'id': serverId,
      },
      where: 'local_id = ?',
      whereArgs: [localId],
    );
  }

  /// Delete expense from local database
  Future<void> deleteExpense(int expenseId) async {
    final db = await database;
    await db.delete(
      'expenses',
      where: 'id = ?',
      whereArgs: [expenseId],
    );
  }

  /// Convert database row to ExpenseData
  ExpenseData _expenseFromMap(Map<String, dynamic> map) {
    return ExpenseData(
      id: map['id'] as int?,
      title: map['title'] as String,
      amount: map['amount'] as double,
      description: map['description'] as String? ?? '',
      category: map['category'] as String,
      roomspaceId: map['roomspace_id'] as String?,
      paidBy: map['paid_by'] as String?,
      payerName: map['payer_name'] as String?,
      splitType: SplitType.fromString(map['split_type'] as String),
      createdAt: DateTime.parse(map['created_at'] as String),
      splits: map['splits'] != null 
          ? (jsonDecode(map['splits'] as String) as List)
              .map((s) => ExpenseSplit.fromJson(s))
              .toList()
          : null,
      selectedRoommateIds: [],
      customSplits: {},
    );
  }

  // ══════════════════════════════════════════════════════════════════
  // PERSONAL EXPENSE OPERATIONS
  // ══════════════════════════════════════════════════════════════════

  /// Save personal expense to local database
  Future<void> savePersonalExpense(
    PersonalExpenseData expense, {
    bool isSynced = true,
    String? localId,
  }) async {
    final db = await database;
    
    await db.insert(
      'personal_expenses',
      {
        'id': expense.id,
        'title': expense.title,
        'amount': expense.amount,
        'description': expense.description,
        'category': expense.category,
        'created_at': (expense.createdAt ?? DateTime.now()).toIso8601String(),
        'is_synced': isSynced ? 1 : 0,
        'local_id': localId ?? expense.id?.toString() ?? DateTime.now().millisecondsSinceEpoch.toString(),
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  /// Get all personal expenses from local database
  Future<List<PersonalExpenseData>> getPersonalExpenses({
    int? limit,
    int? offset,
  }) async {
    final db = await database;
    
    String query = 'SELECT * FROM personal_expenses ORDER BY created_at DESC';
    List<dynamic> args = [];
    
    if (limit != null) {
      query += ' LIMIT ?';
      args.add(limit);
      
      if (offset != null) {
        query += ' OFFSET ?';
        args.add(offset);
      }
    }
    
    final results = await db.rawQuery(query, args);
    return results.map((row) => _personalExpenseFromMap(row)).toList();
  }

  /// Get unsynced personal expenses
  Future<List<PersonalExpenseData>> getUnsyncedPersonalExpenses() async {
    final db = await database;
    final results = await db.query(
      'personal_expenses',
      where: 'is_synced = ?',
      whereArgs: [0],
    );
    return results.map((row) => _personalExpenseFromMap(row)).toList();
  }

  /// Mark personal expense as synced
  Future<void> markPersonalExpenseAsSynced(String localId, int? serverId) async {
    final db = await database;
    await db.update(
      'personal_expenses',
      {
        'is_synced': 1,
        if (serverId != null) 'id': serverId,
      },
      where: 'local_id = ?',
      whereArgs: [localId],
    );
  }

  /// Delete personal expense from local database
  Future<void> deletePersonalExpense(int expenseId) async {
    final db = await database;
    await db.delete(
      'personal_expenses',
      where: 'id = ?',
      whereArgs: [expenseId],
    );
  }

  /// Convert database row to PersonalExpenseData
  PersonalExpenseData _personalExpenseFromMap(Map<String, dynamic> map) {
    return PersonalExpenseData(
      id: map['id'] as int?,
      title: map['title'] as String,
      amount: map['amount'] as double,
      description: map['description'] as String? ?? '',
      category: map['category'] as String,
      createdAt: DateTime.parse(map['created_at'] as String),
    );
  }

  // ══════════════════════════════════════════════════════════════════
  // SYNC QUEUE OPERATIONS
  // ══════════════════════════════════════════════════════════════════

  /// Add operation to sync queue
  Future<void> addToSyncQueue({
    required String operationType, // 'CREATE', 'UPDATE', 'DELETE'
    required String entityType, // 'EXPENSE', 'PERSONAL_EXPENSE'
    required String entityId,
    required Map<String, dynamic> data,
  }) async {
    final db = await database;
    
    await db.insert('sync_queue', {
      'operation_type': operationType,
      'entity_type': entityType,
      'entity_id': entityId,
      'data': jsonEncode(data),
      'created_at': DateTime.now().toIso8601String(),
      'retry_count': 0,
    });
  }

  /// Get all pending sync operations
  Future<List<Map<String, dynamic>>> getPendingSyncOperations() async {
    final db = await database;
    return await db.query(
      'sync_queue',
      orderBy: 'created_at ASC',
    );
  }

  /// Remove operation from sync queue
  Future<void> removeSyncOperation(int id) async {
    final db = await database;
    await db.delete(
      'sync_queue',
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  /// Update sync operation retry count
  Future<void> updateSyncOperationRetry(int id, String error) async {
    final db = await database;
    await db.rawUpdate(
      'UPDATE sync_queue SET retry_count = retry_count + 1, last_error = ? WHERE id = ?',
      [error, id],
    );
  }

  /// Clear all sync operations
  Future<void> clearSyncQueue() async {
    final db = await database;
    await db.delete('sync_queue');
  }

  // ══════════════════════════════════════════════════════════════════
  // ROOMSPACE CACHE OPERATIONS
  // ══════════════════════════════════════════════════════════════════

  /// Save roomspace to cache
  Future<void> saveRoomspace(Map<String, dynamic> roomspace) async {
    final db = await database;
    
    await db.insert(
      'roomspaces',
      {
        'id': roomspace['id'],
        'name': roomspace['name'],
        'description': roomspace['description'],
        'code': roomspace['code'],
        'created_at': roomspace['created_at'],
        'members': jsonEncode(roomspace['members'] ?? []),
        'last_synced': DateTime.now().toIso8601String(),
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  /// Get cached roomspaces
  Future<List<Map<String, dynamic>>> getCachedRoomspaces() async {
    final db = await database;
    final results = await db.query('roomspaces');
    
    return results.map((row) {
      return {
        'id': row['id'],
        'name': row['name'],
        'description': row['description'],
        'code': row['code'],
        'created_at': row['created_at'],
        'members': jsonDecode(row['members'] as String),
        'last_synced': row['last_synced'],
      };
    }).toList();
  }

  /// Clear all cached data
  Future<void> clearAllCache() async {
    final db = await database;
    await db.delete('expenses');
    await db.delete('personal_expenses');
    await db.delete('roomspaces');
    await db.delete('sync_queue');
  }

  /// Get database statistics
  Future<Map<String, int>> getDatabaseStats() async {
    final db = await database;
    
    final expenseCount = Sqflite.firstIntValue(
      await db.rawQuery('SELECT COUNT(*) FROM expenses')
    ) ?? 0;
    
    final personalExpenseCount = Sqflite.firstIntValue(
      await db.rawQuery('SELECT COUNT(*) FROM personal_expenses')
    ) ?? 0;
    
    final unsyncedExpenseCount = Sqflite.firstIntValue(
      await db.rawQuery('SELECT COUNT(*) FROM expenses WHERE is_synced = 0')
    ) ?? 0;
    
    final unsyncedPersonalExpenseCount = Sqflite.firstIntValue(
      await db.rawQuery('SELECT COUNT(*) FROM personal_expenses WHERE is_synced = 0')
    ) ?? 0;
    
    final syncQueueCount = Sqflite.firstIntValue(
      await db.rawQuery('SELECT COUNT(*) FROM sync_queue')
    ) ?? 0;
    
    return {
      'expenses': expenseCount,
      'personal_expenses': personalExpenseCount,
      'unsynced_expenses': unsyncedExpenseCount,
      'unsynced_personal_expenses': unsyncedPersonalExpenseCount,
      'sync_queue': syncQueueCount,
    };
  }
}
