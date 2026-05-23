// ══════════════════════════════════════════════════════════════════
// EXAMPLE: How to integrate offline mode into your app
// ══════════════════════════════════════════════════════════════════

import 'package:flutter/material.dart';
import 'package:room_ease/services/offline_expense_service.dart';
import 'package:room_ease/services/connectivity_service.dart';
import 'package:room_ease/services/sync_service.dart';
import 'package:room_ease/widgets/sync_status_indicator.dart';
import 'package:room_ease/models/expense_models.dart';

// ══════════════════════════════════════════════════════════════════
// 1. UPDATE MAIN.DART - Initialize Services
// ══════════════════════════════════════════════════════════════════

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Initialize Firebase (your existing code)
  // await Firebase.initializeApp(...);
  
  // 🆕 Initialize offline services
  print('🔄 Initializing offline services...');
  await ConnectivityService().initialize();
  await SyncService().initialize();
  await OfflineExpenseService().initialize();
  print('✅ Offline services ready!');
  
  runApp(const MyApp());
}

// ══════════════════════════════════════════════════════════════════
// 2. UPDATE YOUR EXPENSE SCREEN - Add Sync Indicators
// ══════════════════════════════════════════════════════════════════

class ExpenseScreenExample extends StatefulWidget {
  const ExpenseScreenExample({super.key});

  @override
  State<ExpenseScreenExample> createState() => _ExpenseScreenExampleState();
}

class _ExpenseScreenExampleState extends State<ExpenseScreenExample> {
  final OfflineExpenseService _offlineService = OfflineExpenseService();
  List<ExpenseData> _expenses = [];
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _loadExpenses();
  }

  // 🆕 Load expenses from local cache (works offline!)
  Future<void> _loadExpenses() async {
    setState(() => _isLoading = true);
    
    try {
      // Get expenses from local database
      // If online, it will sync first
      final expenses = await _offlineService.getExpenses(
        roomspaceId: 'your-roomspace-id',
        forceSync: true, // Sync with server if online
      );
      
      setState(() {
        _expenses = expenses;
        _isLoading = false;
      });
    } catch (e) {
      print('Error loading expenses: $e');
      setState(() => _isLoading = false);
    }
  }

  // 🆕 Create expense (works offline!)
  Future<void> _createExpense() async {
    try {
      final request = ExpenseCreateRequest(
        roomspaceId: 'your-roomspace-id',
        title: 'Groceries',
        amount: 50.0,
        category: 'Food',
        description: 'Weekly groceries',
        splitType: 'EQUAL',
        selectedRoommates: ['user1', 'user2'],
      );

      // This works offline! Will sync when online
      final expense = await _offlineService.createExpense(request);
      
      // Show success message
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              _offlineService.isOnline 
                ? 'Expense created!' 
                : 'Expense saved offline - will sync when online'
            ),
            backgroundColor: _offlineService.isOnline ? Colors.green : Colors.orange,
          ),
        );
      }
      
      // Reload expenses
      _loadExpenses();
    } catch (e) {
      print('Error creating expense: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  // 🆕 Delete expense (works offline!)
  Future<void> _deleteExpense(int expenseId) async {
    try {
      await _offlineService.deleteExpense(expenseId);
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              _offlineService.isOnline 
                ? 'Expense deleted!' 
                : 'Expense deleted offline - will sync when online'
            ),
            backgroundColor: _offlineService.isOnline ? Colors.green : Colors.orange,
          ),
        );
      }
      
      _loadExpenses();
    } catch (e) {
      print('Error deleting expense: $e');
    }
  }

  // 🆕 Manual sync
  Future<void> _syncNow() async {
    if (!_offlineService.isOnline) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No internet connection'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    // Show syncing message
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Row(
          children: [
            SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
              ),
            ),
            SizedBox(width: 12),
            Text('Syncing...'),
          ],
        ),
        duration: Duration(seconds: 2),
      ),
    );

    final result = await _offlineService.syncAll();
    
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(result.message),
          backgroundColor: result.success ? Colors.green : Colors.red,
        ),
      );
      
      if (result.success) {
        _loadExpenses();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Expenses'),
        actions: [
          // 🆕 Add sync status indicator
          const SyncStatusIndicator(),
          const SizedBox(width: 8),
          // 🆕 Add manual sync button
          IconButton(
            icon: const Icon(Icons.sync),
            onPressed: _syncNow,
            tooltip: 'Sync now',
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: Column(
        children: [
          // 🆕 Add sync banner at top
          const SyncStatusBanner(),
          
          // Your expense list
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : RefreshIndicator(
                    onRefresh: _loadExpenses,
                    child: ListView.builder(
                      itemCount: _expenses.length,
                      itemBuilder: (context, index) {
                        final expense = _expenses[index];
                        return ListTile(
                          title: Text(expense.title),
                          subtitle: Text('\$${expense.amount.toStringAsFixed(2)}'),
                          trailing: IconButton(
                            icon: const Icon(Icons.delete),
                            onPressed: () => _deleteExpense(expense.id!),
                          ),
                        );
                      },
                    ),
                  ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _createExpense,
        child: const Icon(Icons.add),
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════════
// 3. EXAMPLE: Dashboard with Sync Status
// ══════════════════════════════════════════════════════════════════

class DashboardExample extends StatefulWidget {
  const DashboardExample({super.key});

  @override
  State<DashboardExample> createState() => _DashboardExampleState();
}

class _DashboardExampleState extends State<DashboardExample> {
  final OfflineExpenseService _offlineService = OfflineExpenseService();
  Map<String, dynamic>? _syncStats;

  @override
  void initState() {
    super.initState();
    _loadSyncStats();
  }

  Future<void> _loadSyncStats() async {
    final stats = await _offlineService.getSyncStatus();
    setState(() {
      _syncStats = stats;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Dashboard'),
        actions: const [
          SyncStatusIndicator(),
          SizedBox(width: 16),
        ],
      ),
      body: Column(
        children: [
          // Sync status banner
          const SyncStatusBanner(),
          
          // Sync statistics card
          if (_syncStats != null)
            Card(
              margin: const EdgeInsets.all(16),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Sync Status',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 12),
                    _buildStatRow(
                      'Connection',
                      _syncStats!['is_connected'] ? 'Online' : 'Offline',
                      _syncStats!['is_connected'] ? Colors.green : Colors.red,
                    ),
                    _buildStatRow(
                      'Total Expenses',
                      '${_syncStats!['total_expenses']}',
                      Colors.blue,
                    ),
                    _buildStatRow(
                      'Unsynced Expenses',
                      '${_syncStats!['unsynced_expenses']}',
                      Colors.orange,
                    ),
                    _buildStatRow(
                      'Pending Operations',
                      '${_syncStats!['pending_operations']}',
                      Colors.purple,
                    ),
                  ],
                ),
              ),
            ),
          
          // Your dashboard content
          Expanded(
            child: Center(
              child: Text('Your dashboard content here'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatRow(String label, String value, Color color) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: color),
            ),
            child: Text(
              value,
              style: TextStyle(
                color: color,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════════
// 4. EXAMPLE: Settings Screen with Sync Controls
// ══════════════════════════════════════════════════════════════════

class SettingsExample extends StatefulWidget {
  const SettingsExample({super.key});

  @override
  State<SettingsExample> createState() => _SettingsExampleState();
}

class _SettingsExampleState extends State<SettingsExample> {
  final OfflineExpenseService _offlineService = OfflineExpenseService();

  Future<void> _clearCache() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Clear Cache'),
        content: const Text(
          'This will clear all locally cached data. '
          'Unsynced changes will be lost. Continue?'
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Clear'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      // Clear cache
      final db = LocalDatabaseService();
      await db.clearAllCache();
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Cache cleared'),
            backgroundColor: Colors.green,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings'),
      ),
      body: ListView(
        children: [
          ListTile(
            leading: const Icon(Icons.sync),
            title: const Text('Sync Now'),
            subtitle: Text(
              _offlineService.isOnline 
                ? 'Sync all data with server' 
                : 'No internet connection'
            ),
            enabled: _offlineService.isOnline,
            onTap: () async {
              final result = await _offlineService.syncAll();
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(result.message),
                    backgroundColor: result.success ? Colors.green : Colors.red,
                  ),
                );
              }
            },
          ),
          ListTile(
            leading: const Icon(Icons.delete_sweep),
            title: const Text('Clear Cache'),
            subtitle: const Text('Remove all locally stored data'),
            onTap: _clearCache,
          ),
          ListTile(
            leading: const Icon(Icons.info),
            title: const Text('Sync Status'),
            subtitle: FutureBuilder<Map<String, dynamic>>(
              future: _offlineService.getSyncStatus(),
              builder: (context, snapshot) {
                if (!snapshot.hasData) {
                  return const Text('Loading...');
                }
                final stats = snapshot.data!;
                return Text(
                  '${stats['unsynced_expenses']} unsynced expenses, '
                  '${stats['pending_operations']} pending operations'
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
