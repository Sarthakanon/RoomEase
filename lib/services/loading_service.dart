import 'package:flutter/material.dart';

class LoadingService extends ChangeNotifier {
  static final LoadingService _instance = LoadingService._internal();
  factory LoadingService() => _instance;
  LoadingService._internal();

  final Map<String, bool> _loadingStates = {};
  final Map<String, String> _loadingMessages = {};

  bool isLoading(String key) => _loadingStates[key] ?? false;
  String getLoadingMessage(String key) => _loadingMessages[key] ?? 'Loading...';

  void setLoading(String key, bool loading, [String? message]) {
    _loadingStates[key] = loading;
    if (message != null) {
      _loadingMessages[key] = message;
    }
    notifyListeners();
  }

  void clearLoading(String key) {
    _loadingStates.remove(key);
    _loadingMessages.remove(key);
    notifyListeners();
  }

  void clearAllLoading() {
    _loadingStates.clear();
    _loadingMessages.clear();
    notifyListeners();
  }

  // Specific loading states
  bool get isLoadingRoomspaces => isLoading('roomspaces');
  bool get isLoadingProfile => isLoading('profile');
  bool get isLoadingExpenses => isLoading('expenses');
  bool get isLoadingBalances => isLoading('balances');

  void setRoomspacesLoading(bool loading) => setLoading('roomspaces', loading, 'Loading roomspaces...');
  void setProfileLoading(bool loading) => setLoading('profile', loading, 'Loading profile...');
  void setExpensesLoading(bool loading) => setLoading('expenses', loading, 'Loading expenses...');
  void setBalancesLoading(bool loading) => setLoading('balances', loading, 'Loading balances...');
}