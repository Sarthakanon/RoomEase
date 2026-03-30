import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'firebase_auth_service.dart';
import 'api_service.dart';

/// AuthService ties together Firebase Auth and backend session management.
/// It handles the full authentication flow and persists session state locally.
class AuthService {
  static final AuthService _instance = AuthService._internal();
  factory AuthService() => _instance;

  final FirebaseAuthService _firebaseAuth = FirebaseAuthService();
  final ApiService _apiService = ApiService();

  static const String _sessionIdKey = 'session_id';
  static const String _userIdKey = 'user_id';
  static const String _emailKey = 'user_email';

  AuthService._internal();

  /// Get current Firebase user
  User? get currentUser => _firebaseAuth.currentUser;

  /// Stream of auth state changes
  Stream<User?> get authStateChanges => _firebaseAuth.authStateChanges;

  /// Check if user is authenticated (has valid session)
  Future<bool> isAuthenticated() async {
    final prefs = await SharedPreferences.getInstance();
    final sessionId = prefs.getString(_sessionIdKey);

    if (sessionId == null) return false;

    try {
      final response = await _apiService.verifySession();
      return response['valid'] == true;
    } catch (e) {
      // Session invalid, clear local storage
      await clearLocalSession();
      return false;
    }
  }

  /// Login with email and password
  Future<User?> loginWithEmail(String email, String password) async {
    final userCredential = await _firebaseAuth.signInWithEmailAndPassword(
      email: email,
      password: password,
    );

    if (userCredential?.user != null) {
      await _syncWithBackend(userCredential!.user!);
    }

    return userCredential?.user;
  }

  /// Login with Google
  Future<User?> loginWithGoogle() async {
    final userCredential = await _firebaseAuth.signInWithGoogle();

    if (userCredential?.user != null) {
      await _syncWithBackend(userCredential!.user!);
    }

    return userCredential?.user;
  }

  /// Sign up with email and password
  Future<User?> signUpWithEmail({
    required String email,
    required String password,
    required String name,
  }) async {
    final userCredential = await _firebaseAuth.signUpWithEmailAndPassword(
      email: email,
      password: password,
      name: name,
    );

    // Note: User needs to verify email before they can fully login
    // Don't sync with backend until email is verified
    return userCredential?.user;
  }

  /// Sync Firebase user with backend (creates session)
  Future<void> _syncWithBackend(User user) async {
    final idToken = await user.getIdToken();

    if (idToken != null) {
      final response = await _apiService.login(idToken);

      // Store session info locally for persistence
      await _saveLocalSession(
        sessionId: response['session_id'] as String,
        userId: response['user_id'] as String,
        email: response['email'] as String,
      );
    }
  }

  /// Save session to local storage
  Future<void> _saveLocalSession({
    required String sessionId,
    required String userId,
    required String email,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_sessionIdKey, sessionId);
    await prefs.setString(_userIdKey, userId);
    await prefs.setString(_emailKey, email);
  }

  /// Clear local session data
  Future<void> clearLocalSession() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_sessionIdKey);
    await prefs.remove(_userIdKey);
    await prefs.remove(_emailKey);
  }

  /// Get stored user ID
  Future<String?> getStoredUserId() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_userIdKey);
  }

  /// Logout from both Firebase and backend
  Future<void> logout() async {
    try {
      await _apiService.logout();
    } catch (e) {
      // Continue with logout even if backend call fails
    }

    await clearLocalSession();
    await _firebaseAuth.signOut();
  }

  /// Refresh the backend session
  Future<bool> refreshSession() async {
    try {
      await _apiService.refreshSession();
      return true;
    } catch (e) {
      return false;
    }
  }

  /// Send password reset email
  Future<void> sendPasswordResetEmail(String email) async {
    await _firebaseAuth.sendPasswordResetEmail(email: email);
  }

  /// Resend email verification
  Future<void> resendEmailVerification() async {
    await _firebaseAuth.resendEmailVerification();
  }
}
