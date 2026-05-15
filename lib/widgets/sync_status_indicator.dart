import 'package:flutter/material.dart';
import '../services/connectivity_service.dart';
import '../services/sync_service.dart';
import '../services/offline_expense_service.dart';

/// Widget to display sync status and connectivity
class SyncStatusIndicator extends StatefulWidget {
  const SyncStatusIndicator({super.key});

  @override
  State<SyncStatusIndicator> createState() => _SyncStatusIndicatorState();
}

class _SyncStatusIndicatorState extends State<SyncStatusIndicator> {
  final ConnectivityService _connectivityService = ConnectivityService();
  final SyncService _syncService = SyncService();
  final OfflineExpenseService _offlineService = OfflineExpenseService();

  bool _isConnected = false;
  SyncStatus _syncStatus = SyncStatus.idle;
  int _unsyncedCount = 0;

  @override
  void initState() {
    super.initState();
    _initialize();
  }

  Future<void> _initialize() async {
    // Listen to connectivity changes
    _connectivityService.connectivityStream.listen((isConnected) {
      if (mounted) {
        setState(() {
          _isConnected = isConnected;
        });
      }
    });

    // Listen to sync status changes
    _syncService.syncStatusStream.listen((status) {
      if (mounted) {
        setState(() {
          _syncStatus = status;
        });
      }
    });

    // Initial state
    setState(() {
      _isConnected = _connectivityService.isConnected;
      _syncStatus = _syncService.currentStatus;
    });

    // Get unsynced count
    _updateUnsyncedCount();
  }

  Future<void> _updateUnsyncedCount() async {
    final count = await _offlineService.getUnsyncedCount();
    if (mounted) {
      setState(() {
        _unsyncedCount = count;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    // Don't show anything if online and synced
    if (_isConnected && _syncStatus == SyncStatus.idle && _unsyncedCount == 0) {
      return const SizedBox.shrink();
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: _getBackgroundColor(),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            _getIcon(),
            size: 16,
            color: Colors.white,
          ),
          const SizedBox(width: 6),
          Text(
            _getMessage(),
            style: const TextStyle(
              color: Colors.white,
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
          ),
          if (_syncStatus == SyncStatus.syncing) ...[
            const SizedBox(width: 8),
            const SizedBox(
              width: 12,
              height: 12,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Color _getBackgroundColor() {
    if (!_isConnected) {
      return Colors.orange;
    }
    
    switch (_syncStatus) {
      case SyncStatus.syncing:
        return Colors.blue;
      case SyncStatus.failed:
        return Colors.red;
      case SyncStatus.completed:
        return Colors.green;
      default:
        if (_unsyncedCount > 0) {
          return Colors.orange;
        }
        return Colors.grey;
    }
  }

  IconData _getIcon() {
    if (!_isConnected) {
      return Icons.cloud_off;
    }
    
    switch (_syncStatus) {
      case SyncStatus.syncing:
        return Icons.sync;
      case SyncStatus.failed:
        return Icons.error_outline;
      case SyncStatus.completed:
        return Icons.cloud_done;
      default:
        if (_unsyncedCount > 0) {
          return Icons.cloud_upload;
        }
        return Icons.cloud_queue;
    }
  }

  String _getMessage() {
    if (!_isConnected) {
      if (_unsyncedCount > 0) {
        return 'Offline • $_unsyncedCount pending';
      }
      return 'Offline';
    }
    
    switch (_syncStatus) {
      case SyncStatus.syncing:
        return 'Syncing...';
      case SyncStatus.failed:
        return 'Sync failed';
      case SyncStatus.completed:
        return 'Synced';
      default:
        if (_unsyncedCount > 0) {
          return '$_unsyncedCount pending';
        }
        return 'Online';
    }
  }
}

/// Floating sync status banner (for bottom of screen)
class SyncStatusBanner extends StatefulWidget {
  const SyncStatusBanner({super.key});

  @override
  State<SyncStatusBanner> createState() => _SyncStatusBannerState();
}

class _SyncStatusBannerState extends State<SyncStatusBanner> {
  final ConnectivityService _connectivityService = ConnectivityService();
  final OfflineExpenseService _offlineService = OfflineExpenseService();

  bool _isConnected = false;
  int _unsyncedCount = 0;
  bool _showBanner = false;

  @override
  void initState() {
    super.initState();
    _initialize();
  }

  Future<void> _initialize() async {
    // Listen to connectivity changes
    _connectivityService.connectivityStream.listen((isConnected) async {
      if (mounted) {
        setState(() {
          _isConnected = isConnected;
        });
        await _updateUnsyncedCount();
        _updateBannerVisibility();
      }
    });

    // Initial state
    setState(() {
      _isConnected = _connectivityService.isConnected;
    });

    await _updateUnsyncedCount();
    _updateBannerVisibility();
  }

  Future<void> _updateUnsyncedCount() async {
    final count = await _offlineService.getUnsyncedCount();
    if (mounted) {
      setState(() {
        _unsyncedCount = count;
      });
    }
  }

  void _updateBannerVisibility() {
    setState(() {
      _showBanner = !_isConnected || _unsyncedCount > 0;
    });
  }

  Future<void> _handleSync() async {
    if (!_isConnected) {
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
        await _updateUnsyncedCount();
        _updateBannerVisibility();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!_showBanner) {
      return const SizedBox.shrink();
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: _isConnected ? Colors.orange.shade100 : Colors.red.shade100,
        border: Border(
          top: BorderSide(
            color: _isConnected ? Colors.orange : Colors.red,
            width: 2,
          ),
        ),
      ),
      child: Row(
        children: [
          Icon(
            _isConnected ? Icons.cloud_upload : Icons.cloud_off,
            color: _isConnected ? Colors.orange : Colors.red,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  _isConnected ? 'Pending Sync' : 'Offline Mode',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: _isConnected ? Colors.orange.shade900 : Colors.red.shade900,
                  ),
                ),
                if (_unsyncedCount > 0)
                  Text(
                    '$_unsyncedCount expense${_unsyncedCount > 1 ? 's' : ''} waiting to sync',
                    style: TextStyle(
                      fontSize: 12,
                      color: _isConnected ? Colors.orange.shade700 : Colors.red.shade700,
                    ),
                  ),
              ],
            ),
          ),
          if (_isConnected && _unsyncedCount > 0)
            ElevatedButton(
              onPressed: _handleSync,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.orange,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              ),
              child: const Text('Sync Now'),
            ),
        ],
      ),
    );
  }
}
