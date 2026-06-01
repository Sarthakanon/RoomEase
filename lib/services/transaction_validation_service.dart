import 'dart:developer';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import '../models/payment_notification.dart';

class TransactionValidationService {
  static const String _recentTransactionsKey = 'recent_transactions';
  static const int _maxRecentTransactions = 50;
  static const int _duplicateWindowMinutes = 5;

  /// Validate if transaction should be processed
  static Future<bool> validateTransaction(PaymentNotification notification) async {
    try {
      // Check basic validation rules
      if (!_isValidTransaction(notification)) {
        return false;
      }

      // Demo/VIVA-safe behavior:
      // Allow SMS detections through even if they look duplicated because test
      // messages are often replayed with the exact same content repeatedly.
      if (notification.source.toLowerCase() == 'sms') {
        await _storeTransaction(notification);
        return true;
      }

      // Check for duplicates
      if (await _isDuplicateTransaction(notification)) {
        log('Duplicate transaction detected, skipping');
        return false;
      }

      // Store transaction for future duplicate checking
      await _storeTransaction(notification);
      
      return true;
    } catch (e) {
      log('Error validating transaction: $e');
      return false;
    }
  }

  /// Check basic transaction validity
  static bool _isValidTransaction(PaymentNotification notification) {
    // Amount must be positive
    if (notification.amount == null || notification.amount! <= 0) {
      log('Invalid amount: ${notification.amount}');
      return false;
    }

    // Source must be valid
    if (!['sms', 'notification', 'test'].contains(notification.source)) {
      log('Invalid source: ${notification.source}');
      return false;
    }

    // App name must not be empty
    if (notification.appName.trim().isEmpty) {
      log('Empty app name');
      return false;
    }

    // Raw text must not be empty
    if (notification.rawText.trim().isEmpty) {
      log('Empty raw text');
      return false;
    }

    return true;
  }

  /// Check if transaction is a duplicate
  static Future<bool> _isDuplicateTransaction(PaymentNotification notification) async {
    try {
      final recentTransactions = await _getRecentTransactions();
      final currentTime = DateTime.now();
      
      for (final stored in recentTransactions) {
        // Check if within duplicate window
        final timeDiff = currentTime.difference(stored.timestamp).inMinutes;
        if (timeDiff > _duplicateWindowMinutes) {
          continue;
        }

        // Check for exact match
        if (_isExactMatch(notification, stored)) {
          return true;
        }

        // Check for similar transaction (same amount, similar time, same source)
        if (_isSimilarTransaction(notification, stored)) {
          return true;
        }
      }

      return false;
    } catch (e) {
      log('Error checking duplicate transaction: $e');
      return false;
    }
  }

  /// Check if two transactions are exact matches
  static bool _isExactMatch(PaymentNotification a, PaymentNotification b) {
    return a.amount == b.amount &&
           a.appName == b.appName &&
           a.source == b.source &&
           a.rawText == b.rawText;
  }

  /// Check if two transactions are similar (likely duplicates)
  static bool _isSimilarTransaction(PaymentNotification a, PaymentNotification b) {
    // Same amount and source
    if (a.amount != b.amount || a.source != b.source) {
      return false;
    }

    // Same app or similar app names
    if (a.appName.toLowerCase() != b.appName.toLowerCase()) {
      // Check if app names are similar (e.g., "eSewa" vs "esewa")
      final appA = a.appName.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '');
      final appB = b.appName.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '');
      if (appA != appB) {
        return false;
      }
    }

    // Same merchant if available
    if (a.merchant != null && b.merchant != null) {
      if (a.merchant!.toLowerCase() != b.merchant!.toLowerCase()) {
        return false;
      }
    }

    // Time difference within duplicate window
    final timeDiff = a.timestamp.difference(b.timestamp).inMinutes.abs();
    return timeDiff <= _duplicateWindowMinutes;
  }

  /// Store transaction for duplicate checking
  static Future<void> _storeTransaction(PaymentNotification notification) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final recentTransactions = await _getRecentTransactions();
      
      // Add new transaction
      recentTransactions.add(notification);
      
      // Keep only recent transactions (limit size)
      if (recentTransactions.length > _maxRecentTransactions) {
        recentTransactions.removeRange(0, recentTransactions.length - _maxRecentTransactions);
      }
      
      // Remove old transactions (older than 24 hours)
      final cutoffTime = DateTime.now().subtract(const Duration(hours: 24));
      recentTransactions.removeWhere((t) => t.timestamp.isBefore(cutoffTime));
      
      // Save to preferences
      final jsonList = recentTransactions.map((t) => jsonEncode(t.toJson())).toList();
      await prefs.setStringList(_recentTransactionsKey, jsonList);
      
      log('Stored transaction for duplicate checking: ${notification.amount} from ${notification.appName}');
    } catch (e) {
      log('Error storing transaction: $e');
    }
  }

  /// Get recent transactions from storage
  static Future<List<PaymentNotification>> _getRecentTransactions() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final jsonList = prefs.getStringList(_recentTransactionsKey) ?? [];
      
      final transactions = <PaymentNotification>[];
      for (final jsonStr in jsonList) {
        try {
          final json = jsonDecode(jsonStr) as Map<String, dynamic>;
          transactions.add(PaymentNotification.fromJson(json));
        } catch (e) {
          log('Error parsing stored transaction: $e');
        }
      }
      
      return transactions;
    } catch (e) {
      log('Error getting recent transactions: $e');
      return [];
    }
  }

  /// Clear stored transactions (for testing or reset)
  static Future<void> clearStoredTransactions() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_recentTransactionsKey);
      log('Cleared stored transactions');
    } catch (e) {
      log('Error clearing stored transactions: $e');
    }
  }

  /// Get transaction statistics
  static Future<Map<String, dynamic>> getTransactionStats() async {
    try {
      final recentTransactions = await _getRecentTransactions();
      final now = DateTime.now();
      
      final last24Hours = recentTransactions.where((t) => 
        now.difference(t.timestamp).inHours <= 24
      ).length;
      
      final lastWeek = recentTransactions.where((t) => 
        now.difference(t.timestamp).inDays <= 7
      ).length;
      
      final bySource = <String, int>{};
      for (final transaction in recentTransactions) {
        bySource[transaction.source] = (bySource[transaction.source] ?? 0) + 1;
      }
      
      return {
        'total': recentTransactions.length,
        'last24Hours': last24Hours,
        'lastWeek': lastWeek,
        'bySource': bySource,
      };
    } catch (e) {
      log('Error getting transaction stats: $e');
      return {};
    }
  }
}
