import 'dart:async';
import 'dart:developer';
import 'package:firebase_auth/firebase_auth.dart';
import 'api_service.dart';
import 'auth_state_service.dart';

class BanMonitoringService {
  static final BanMonitoringService _instance = BanMonitoringService._internal();
  factory BanMonitoringService() => _instance;
  BanMonitoringService._internal();

  Timer? _banCheckTimer;
  bool _isMonitoring = false;
  final ApiService _apiService = ApiService();

  /// Start monitoring user ban status
  /// Checks every 30 seconds if the user is banned
  void startMonitoring() {
    if (_isMonitoring) return;
    
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    _isMonitoring = true;
    log('Started ban monitoring for user: ${user.uid}');

    // Check immediately
    _checkBanStatus(user.uid);

    // Then check every 30 seconds
    _banCheckTimer = Timer.periodic(const Duration(seconds: 30), (timer) {
      final currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser == null) {
        stopMonitoring();
        return;
      }
      _checkBanStatus(currentUser.uid);
    });
  }

  /// Stop monitoring user ban status
  void stopMonitoring() {
    if (!_isMonitoring) return;
    
    _banCheckTimer?.cancel();
    _banCheckTimer = null;
    _isMonitoring = false;
    log('Stopped ban monitoring');
  }

  /// Check if the current user is banned
  Future<void> _checkBanStatus(String userId) async {
    try {
      final response = await _apiService.get('/api/admin/users/$userId/ban-status');
      
      if (response['success'] == true) {
        final isBanned = response['is_banned'] == true;
        
        if (isBanned) {
          final reason = response['ban_reason'] ?? 'Unusual activity detected';
          log('User is banned: $reason');
          await _handleUserBanned(reason);
        }
      } else {
        // API returned success: false, but don't treat as ban
        log('Ban status check returned error: ${response['error'] ?? 'Unknown error'}');
      }
    } catch (e) {
      // Don't log out user if ban check fails due to network/server issues
      // Only log the error for debugging
      final errorMessage = e.toString();
      
      // Check if it's a specific error type
      if (errorMessage.contains('500') || errorMessage.contains('timeout') || errorMessage.contains('connection')) {
        log('Ban status check failed due to server/network issue: $e');
      } else if (errorMessage.contains('404')) {
        log('Ban status check failed - user not found: $e');
      } else {
        log('Ban status check failed with unknown error: $e');
      }
      
      // Don't take any action on API failures to prevent false logouts
    }
  }

  /// Handle when user is detected as banned
  Future<void> _handleUserBanned(String reason) async {
    try {
      // Stop monitoring
      stopMonitoring();
      
      // Clear authentication state
      await AuthStateService.clearLoginState();
      await _apiService.clearCookies();
      await FirebaseAuth.instance.signOut();
      
      // Show ban notification (this will be handled by the UI layer)
      notifyBanDetected(reason);
      
      log('User logged out due to ban: $reason');
    } catch (e) {
      log('Error handling user ban: $e');
    }
  }

  /// Notify the UI layer that a ban was detected
  /// This uses a stream controller to notify listeners
  final StreamController<String> _banNotificationController = StreamController<String>.broadcast();
  
  Stream<String> get banNotificationStream => _banNotificationController.stream;
  
  void notifyBanDetected(String reason) {
    _banNotificationController.add(reason);
  }

  /// Dispose resources
  void dispose() {
    stopMonitoring();
    _banNotificationController.close();
  }
}