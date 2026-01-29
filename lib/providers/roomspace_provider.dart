import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/roomspace_data.dart';
import '../services/api_service.dart';

/// Error types for roomspace operations
enum RoomspaceErrorType {
  networkFailure,
  invalidRoomspace,
  noRoomspaces,
  authenticationRequired,
  limitReached,
  unknown,
}

/// Custom exception for roomspace operations
class RoomspaceException implements Exception {
  final String message;
  final RoomspaceErrorType type;
  final dynamic originalError;
  
  RoomspaceException(this.message, this.type, [this.originalError]);
  
  @override
  String toString() => message;
}

/// Provider for managing roomspace state across the application
/// Handles multiple roomspace support with active roomspace context
class RoomspaceProvider extends ChangeNotifier {
  final ApiService _apiService = ApiService();
  
  List<RoomspaceData> _roomspaces = [];
  RoomspaceData? _activeRoomspace;
  bool _isLoading = false;
  String? _error;
  RoomspaceErrorType? _errorType;
  
  static const String _activeRoomspaceKey = 'active_roomspace_id';
  static const String _cachedRoomspacesKey = 'cached_roomspaces';
  static const String _cacheTimestampKey = 'cache_timestamp';
  static const int _maxRetries = 3;
  static const Duration _retryDelay = Duration(seconds: 2);
  static const Duration _cacheExpiration = Duration(hours: 24);
  
  // Getters
  List<RoomspaceData> get roomspaces => List.unmodifiable(_roomspaces);
  RoomspaceData? get activeRoomspace => _activeRoomspace;
  bool get isLoading => _isLoading;
  String? get error => _error;
  RoomspaceErrorType? get errorType => _errorType;
  bool get hasMultipleRoomspaces => _roomspaces.length > 1;
  bool get canJoinMore => _roomspaces.length < 5;
  int get roomspaceCount => _roomspaces.length;
  bool get hasNoRoomspaces => _roomspaces.isEmpty;
  bool get isPersonalSpace => _activeRoomspace == null;
  
  /// Load all roomspaces for the authenticated user from the API
  /// Includes retry logic for network failures
  /// Loads cached data first if available, then fetches fresh data
  Future<void> loadRoomspaces({int retryCount = 0, bool forceRefresh = false}) async {
    print('🔄 Loading roomspaces... (forceRefresh: $forceRefresh, retryCount: $retryCount)');
    _isLoading = true;
    _error = null;
    _errorType = null;
    notifyListeners();
    
    // Load cached data first if not forcing refresh
    if (!forceRefresh) {
      await _loadCachedRoomspaces();
    }
    
    try {
      print('📡 Fetching roomspaces from API...');
      final response = await _apiService.getRoomspaces();
      print('✅ API Response: $response');
      
      // Parse roomspaces from response
      final roomspacesData = response['data'] as List<dynamic>?;
      
      if (roomspacesData != null) {
        _roomspaces = roomspacesData
            .map((json) => RoomspaceData.fromJson(json as Map<String, dynamic>))
            .toList();
        
        print('✅ Loaded ${_roomspaces.length} roomspaces');
        for (var rs in _roomspaces) {
          print('   - ${rs.name} (ID: ${rs.id})');
        }
        
        // Cache the fresh data
        await _cacheRoomspaces();
        
        // Restore active roomspace from SharedPreferences
        await _restoreActiveRoomspace();
        print('🎯 Active roomspace: ${_activeRoomspace?.name ?? "Personal Space"}');
        
        // Don't automatically set first roomspace - respect personal space mode
        // User can explicitly switch using the global selector
        
        // Handle no roomspaces scenario
        if (_roomspaces.isEmpty) {
          print('⚠️ No roomspaces found');
          throw RoomspaceException(
            'No roomspaces found. Please create or join a roomspace.',
            RoomspaceErrorType.noRoomspaces,
          );
        }
      } else {
        print('❌ No data in API response');
        _roomspaces = [];
        _activeRoomspace = null;
        throw RoomspaceException(
          'No roomspaces found. Please create or join a roomspace.',
          RoomspaceErrorType.noRoomspaces,
        );
      }
    } on RoomspaceException catch (e) {
      _error = e.message;
      _errorType = e.type;
      print('❌ RoomspaceException: $_error');
    } catch (e) {
      print('❌ Error loading roomspaces: $e');
      // Check if it's a network error
      final isNetworkError = _isNetworkError(e);
      
      if (isNetworkError && retryCount < _maxRetries) {
        // Retry with exponential backoff
        print('🔄 Network error loading roomspaces. Retrying in ${_retryDelay.inSeconds}s... (Attempt ${retryCount + 1}/$_maxRetries)');
        await Future.delayed(_retryDelay * (retryCount + 1));
        return loadRoomspaces(retryCount: retryCount + 1, forceRefresh: forceRefresh);
      }
      
      // If we have cached data and it's a network error, use cached data
      if (isNetworkError && _roomspaces.isNotEmpty) {
        _error = 'Showing cached data. Unable to connect to server.';
        _errorType = RoomspaceErrorType.networkFailure;
        print('📦 Using cached roomspaces due to network error');
      } else {
        _error = isNetworkError
            ? 'Unable to connect to server. Please check your internet connection and try again.'
            : 'Failed to load roomspaces: ${e.toString()}';
        _errorType = isNetworkError 
            ? RoomspaceErrorType.networkFailure 
            : RoomspaceErrorType.unknown;
        print('❌ Error loading roomspaces: $_error');
      }
    } finally {
      _isLoading = false;
      notifyListeners();
      print('✅ loadRoomspaces completed. Count: ${_roomspaces.length}, Active: ${_activeRoomspace?.name ?? "None"}');
    }
  }
  
  /// Set the active roomspace by ID
  /// Persists the selection to SharedPreferences
  /// Includes fallback to first available roomspace if ID is invalid
  Future<void> setActiveRoomspace(String roomspaceId, {int retryCount = 0}) async {
    print('🎯 Setting active roomspace to: $roomspaceId');
    try {
      // Validate roomspace ID
      final roomspace = _roomspaces.firstWhere(
        (r) => r.id == roomspaceId,
        orElse: () {
          // Invalid roomspace ID - fallback to first available
          if (_roomspaces.isNotEmpty) {
            print('⚠️ Invalid roomspace ID: $roomspaceId. Falling back to first available roomspace.');
            throw RoomspaceException(
              'Roomspace not found. Switching to first available roomspace.',
              RoomspaceErrorType.invalidRoomspace,
            );
          } else {
            throw RoomspaceException(
              'No roomspaces available. Please create or join a roomspace.',
              RoomspaceErrorType.noRoomspaces,
            );
          }
        },
      );
      
      _activeRoomspace = roomspace;
      _error = null;
      _errorType = null;
      
      // Persist to SharedPreferences
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_activeRoomspaceKey, roomspaceId);
      
      print('✅ Active roomspace set to: ${roomspace.name} (${roomspace.id})');
      notifyListeners();
    } on RoomspaceException catch (e) {
      // Handle invalid roomspace by falling back to first available
      if (e.type == RoomspaceErrorType.invalidRoomspace && _roomspaces.isNotEmpty) {
        _activeRoomspace = _roomspaces.first;
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString(_activeRoomspaceKey, _roomspaces.first.id);
        _error = e.message;
        _errorType = e.type;
        print('✅ Fallback: Active roomspace set to: ${_roomspaces.first.name} (${_roomspaces.first.id})');
        notifyListeners();
      } else {
        _error = e.message;
        _errorType = e.type;
        print('❌ RoomspaceException: $_error');
        notifyListeners();
      }
    } catch (e) {
      // Check if it's a network error during persistence
      final isNetworkError = _isNetworkError(e);
      
      if (isNetworkError && retryCount < _maxRetries) {
        print('🔄 Network error setting active roomspace. Retrying... (Attempt ${retryCount + 1}/$_maxRetries)');
        await Future.delayed(_retryDelay);
        return setActiveRoomspace(roomspaceId, retryCount: retryCount + 1);
      }
      
      _error = 'Failed to set active roomspace: ${e.toString()}';
      _errorType = isNetworkError 
          ? RoomspaceErrorType.networkFailure 
          : RoomspaceErrorType.unknown;
      print('❌ $_error');
      notifyListeners();
    }
  }
  
  /// Switch to personal space (no active roomspace)
  /// Clears the active roomspace and persists to SharedPreferences
  Future<void> switchToPersonalSpace() async {
    print('🏠 Switching to personal space');
    try {
      _activeRoomspace = null;
      _error = null;
      _errorType = null;
      
      // Clear from SharedPreferences
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_activeRoomspaceKey);
      
      print('✅ Switched to personal space');
      notifyListeners();
    } catch (e) {
      _error = 'Failed to switch to personal space: ${e.toString()}';
      _errorType = RoomspaceErrorType.unknown;
      print('❌ $_error');
      notifyListeners();
    }
  }
  
  /// Refresh the roomspace list from the API
  /// Includes retry logic for network failures
  /// Forces a fresh fetch from the server
  Future<void> refreshRoomspaces() async {
    await loadRoomspaces(forceRefresh: true);
  }
  
  /// Retry the last failed operation
  /// Useful for manual retry after network failure
  Future<void> retryLastOperation() async {
    if (_errorType == RoomspaceErrorType.networkFailure) {
      await loadRoomspaces();
    }
  }
  
  /// Leave a roomspace by ID
  /// If leaving the active roomspace, switches to the first available roomspace
  /// Includes retry logic for network failures
  Future<void> leaveRoomspace(String roomspaceId, {int retryCount = 0}) async {
    _isLoading = true;
    _error = null;
    _errorType = null;
    notifyListeners();
    
    try {
      // Get current user's Firebase UID
      final currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser == null) {
        throw RoomspaceException(
          'You must be logged in to leave a roomspace.',
          RoomspaceErrorType.authenticationRequired,
        );
      }
      
      // Call API to leave roomspace
      await _apiService.removeMemberFromRoomspace(
        int.parse(roomspaceId),
        currentUser.uid,
      );
      
      // Remove from local list
      _roomspaces.removeWhere((r) => r.id == roomspaceId);
      
      // Update cache
      await _cacheRoomspaces();
      
      // If we left the active roomspace, switch to another one
      if (_activeRoomspace?.id == roomspaceId) {
        if (_roomspaces.isNotEmpty) {
          await setActiveRoomspace(_roomspaces.first.id);
        } else {
          _activeRoomspace = null;
          final prefs = await SharedPreferences.getInstance();
          await prefs.remove(_activeRoomspaceKey);
          throw RoomspaceException(
            'No roomspaces available. Please create or join a roomspace.',
            RoomspaceErrorType.noRoomspaces,
          );
        }
      }
    } on RoomspaceException catch (e) {
      _error = e.message;
      _errorType = e.type;
      print('RoomspaceException: $_error');
    } catch (e) {
      // Check if it's a network error
      final isNetworkError = _isNetworkError(e);
      
      if (isNetworkError && retryCount < _maxRetries) {
        print('Network error leaving roomspace. Retrying... (Attempt ${retryCount + 1}/$_maxRetries)');
        await Future.delayed(_retryDelay);
        return leaveRoomspace(roomspaceId, retryCount: retryCount + 1);
      }
      
      _error = isNetworkError
          ? 'Unable to leave roomspace. Please check your internet connection and try again.'
          : 'Failed to leave roomspace: ${e.toString()}';
      _errorType = isNetworkError 
          ? RoomspaceErrorType.networkFailure 
          : RoomspaceErrorType.unknown;
      print('Error leaving roomspace: $_error');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }
  
  /// Get the active roomspace ID
  String? getActiveRoomspaceId() {
    return _activeRoomspace?.id;
  }
  
  /// Get a roomspace by ID
  RoomspaceData? getRoomspaceById(String id) {
    try {
      return _roomspaces.firstWhere((r) => r.id == id);
    } catch (e) {
      return null;
    }
  }
  
  /// Cache roomspaces to SharedPreferences
  /// Stores the list as JSON along with a timestamp
  Future<void> _cacheRoomspaces() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      
      // Convert roomspaces to JSON
      final roomspacesJson = _roomspaces.map((r) => r.toJson()).toList();
      final jsonString = jsonEncode(roomspacesJson);
      
      // Save to SharedPreferences
      await prefs.setString(_cachedRoomspacesKey, jsonString);
      await prefs.setInt(_cacheTimestampKey, DateTime.now().millisecondsSinceEpoch);
      
      print('Cached ${_roomspaces.length} roomspaces');
    } catch (e) {
      print('Failed to cache roomspaces: ${e.toString()}');
    }
  }
  
  /// Load cached roomspaces from SharedPreferences
  /// Returns true if cached data was loaded successfully
  Future<bool> _loadCachedRoomspaces() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      
      // Check if cache exists
      final cachedJson = prefs.getString(_cachedRoomspacesKey);
      final cacheTimestamp = prefs.getInt(_cacheTimestampKey);
      
      if (cachedJson == null || cacheTimestamp == null) {
        print('No cached roomspaces found');
        return false;
      }
      
      // Check if cache is expired
      final cacheAge = DateTime.now().millisecondsSinceEpoch - cacheTimestamp;
      final isExpired = cacheAge > _cacheExpiration.inMilliseconds;
      
      if (isExpired) {
        print('Cached roomspaces expired (age: ${Duration(milliseconds: cacheAge).inHours} hours)');
        // Don't return false - still use expired cache if network fails
      }
      
      // Parse cached data
      final List<dynamic> roomspacesJson = jsonDecode(cachedJson);
      _roomspaces = roomspacesJson
          .map((json) => RoomspaceData.fromJson(json as Map<String, dynamic>))
          .toList();
      
      // Restore active roomspace
      await _restoreActiveRoomspace();
      
      // Don't automatically set first roomspace - respect personal space mode
      // User can explicitly switch using the global selector
      
      print('Loaded ${_roomspaces.length} roomspaces from cache');
      notifyListeners();
      return true;
    } catch (e) {
      print('Failed to load cached roomspaces: ${e.toString()}');
      return false;
    }
  }
  
  /// Clear cached roomspaces from SharedPreferences
  Future<void> _clearCache() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_cachedRoomspacesKey);
      await prefs.remove(_cacheTimestampKey);
      print('Cleared roomspace cache');
    } catch (e) {
      print('Failed to clear cache: ${e.toString()}');
    }
  }
  
  /// Check if cached data is available
  Future<bool> hasCachedData() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.containsKey(_cachedRoomspacesKey);
    } catch (e) {
      return false;
    }
  }
  
  /// Sync with server when connection is restored
  /// This method should be called when network connectivity is detected
  Future<void> syncWhenOnline() async {
    print('Syncing roomspaces with server...');
    await loadRoomspaces(forceRefresh: true);
  }
  
  /// Restore the active roomspace from SharedPreferences
  /// Handles invalid roomspace IDs by falling back to first available
  Future<void> _restoreActiveRoomspace() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final savedRoomspaceId = prefs.getString(_activeRoomspaceKey);
      
      if (savedRoomspaceId != null) {
        // Check if the saved roomspace still exists in the list
        final roomspace = _roomspaces.firstWhere(
          (r) => r.id == savedRoomspaceId,
          orElse: () {
            // If saved roomspace no longer exists, clear it from preferences
            // Stay in personal space mode instead of forcing a roomspace
            print('Saved roomspace $savedRoomspaceId no longer available. Staying in personal space.');
            prefs.remove(_activeRoomspaceKey);
            
            throw RoomspaceException(
              'Previously active roomspace is no longer available.',
              RoomspaceErrorType.invalidRoomspace,
            );
          },
        );
        
        _activeRoomspace = roomspace;
      } else {
        // No saved roomspace - stay in personal space mode
        print('No saved roomspace found. Staying in personal space mode.');
        _activeRoomspace = null;
      }
    } on RoomspaceException catch (e) {
      print('RoomspaceException restoring active roomspace: ${e.message}');
      // Stay in personal space mode instead of forcing a roomspace
      _activeRoomspace = null;
    } catch (e) {
      print('Failed to restore active roomspace: ${e.toString()}');
      // Stay in personal space mode instead of forcing a roomspace
      _activeRoomspace = null;
    }
  }
  
  /// Check if an error is a network-related error
  bool _isNetworkError(dynamic error) {
    final errorString = error.toString().toLowerCase();
    return errorString.contains('network') ||
        errorString.contains('connection') ||
        errorString.contains('timeout') ||
        errorString.contains('socket') ||
        errorString.contains('failed host lookup');
  }
  
  /// Clear error state
  void clearError() {
    _error = null;
    _errorType = null;
    notifyListeners();
  }
  
  /// Get user-friendly error message based on error type
  String getUserFriendlyErrorMessage() {
    if (_error == null) return '';
    
    switch (_errorType) {
      case RoomspaceErrorType.networkFailure:
        return 'Unable to connect. Please check your internet connection and try again.';
      case RoomspaceErrorType.invalidRoomspace:
        return 'The selected roomspace is no longer available. Switched to another roomspace.';
      case RoomspaceErrorType.noRoomspaces:
        return 'No roomspaces found. Please create or join a roomspace to continue.';
      case RoomspaceErrorType.authenticationRequired:
        return 'Please log in to continue.';
      case RoomspaceErrorType.limitReached:
        return 'You have reached the maximum limit of 5 roomspaces.';
      case RoomspaceErrorType.unknown:
      default:
        return _error ?? 'An unexpected error occurred. Please try again.';
    }
  }
  
  /// Clear all roomspace data (useful for logout)
  Future<void> clear() async {
    _roomspaces = [];
    _activeRoomspace = null;
    _error = null;
    
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_activeRoomspaceKey);
    await _clearCache();
    
    notifyListeners();
  }
}
