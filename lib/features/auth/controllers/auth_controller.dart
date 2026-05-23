import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../../services/firebase_auth_service.dart';
import '../../../services/firestore_service.dart';
import '../../../services/api_service.dart';
import '../../../services/auth_state_service.dart';
import '../../../models/user_model.dart';

class AuthController extends ChangeNotifier {
  final FirebaseAuthService _authService = FirebaseAuthService();
  final FirestoreService _firestoreService = FirestoreService();
  final ApiService _apiService = ApiService();

  bool _isLoading = false;
  bool get isLoading => _isLoading;

  void setLoading(bool value) {
    _isLoading = value;
    notifyListeners();
  }

  /// Login with email and password
  Future<UserCredential?> loginWithEmail(String email, String password) async {
    setLoading(true);
    try {
      // Sign in with Firebase
      final userCredential = await _authService.signInWithEmailAndPassword(
        email: email,
        password: password,
      );

      if (userCredential != null) {
        // Get Firebase ID token
        final idToken = await userCredential.user!.getIdToken();

        if (idToken != null) {
          // Send token to backend to create session and store user in PostgreSQL
          await _apiService.login(idToken);
        }
      }

      setLoading(false);
      return userCredential;
    } catch (e) {
      setLoading(false);
      rethrow;
    }
  }

  /// Login with Google
  Future<UserCredential?> loginWithGoogle() async {
    setLoading(true);
    try {
      debugPrint('🔵 AuthController: Starting Google login...');
      
      final userCredential = await _authService.signInWithGoogle();

      if (userCredential == null) {
        debugPrint('⚪ AuthController: User canceled Google Sign-In');
        setLoading(false);
        return null;
      }

      debugPrint('🔵 AuthController: Google Sign-In successful, getting ID token...');

      // Get Firebase ID token
      final idToken = await userCredential.user!.getIdToken();

      if (idToken != null) {
        debugPrint('🔵 AuthController: ID token obtained, sending to backend...');
        
        // Send token to backend to create session and store user in PostgreSQL
        try {
          await _apiService.login(idToken);
          debugPrint('✅ AuthController: Backend login successful');
        } catch (e) {
          debugPrint('❌ AuthController: Backend login failed: $e');
          // Sign out from Firebase if backend login fails
          await _authService.signOut();
          setLoading(false);
          throw 'Failed to authenticate with server. Please try again.';
        }
      } else {
        debugPrint('❌ AuthController: Failed to get ID token');
        await _authService.signOut();
        setLoading(false);
        throw 'Failed to get authentication token. Please try again.';
      }

      setLoading(false);
      return userCredential;
    } catch (e, stackTrace) {
      debugPrint('❌ AuthController: Login with Google failed: $e');
      debugPrint('Stack trace: $stackTrace');
      setLoading(false);
      rethrow;
    }
  }

  /// Sign up with email and password
  Future<UserCredential?> signUpWithEmail({
    required String email,
    required String password,
    required String name,
  }) async {
    setLoading(true);
    try {
      // Create user with Firebase Auth
      final userCredential = await _authService.signUpWithEmailAndPassword(
        email: email,
        password: password,
        name: name,
      );

      if (userCredential != null && userCredential.user != null) {
        debugPrint('✅ AuthController: User created successfully');
        debugPrint('📧 AuthController: Email verification sent to ${userCredential.user!.email}');
        
        // DO NOT login to backend yet - user needs to verify email first
        // DO NOT sign out here - let the UI handle it after showing the dialog
        
        // Create user document in Firestore (for backward compatibility)
        final user = UserModel(
          id: userCredential.user!.uid,
          name: name,
          email: email,
          createdAt: DateTime.now(),
        );
        
        try {
          await _firestoreService.createUser(user);
          debugPrint('✅ AuthController: Firestore user document created');
        } catch (e) {
          debugPrint('⚠️ AuthController: Firestore creation failed (non-critical): $e');
          // Don't fail signup if Firestore fails - it's optional
        }
      }

      setLoading(false);
      return userCredential;
    } catch (e) {
      setLoading(false);
      rethrow;
    }
  }

  /// Logout
  Future<void> logout() async {
    setLoading(true);
    try {
      // Logout from backend first
      await _apiService.logout();

      // Then sign out from Firebase
      await _authService.signOut();

      // Clear login state
      await AuthStateService.clearLoginState();

      setLoading(false);
    } catch (e) {
      setLoading(false);
      rethrow;
    }
  }

  /// Authenticate with backend using Firebase token
  Future<void> authenticateWithBackend(String firebaseToken) async {
    try {
      await _apiService.login(firebaseToken);
    } catch (e) {
      // Re-throw to let caller handle the error
      rethrow;
    }
  }

  /// Check if user has roomspaces from PostgreSQL backend
  Future<List<dynamic>> getUserRoomspaces(String uid) async {
    try {
      final response = await _apiService.getRoomspaces();
      // The API returns {data: [...]}
      if (response.containsKey('data')) {
        return response['data'] as List<dynamic>;
      }
      return [];
    } catch (e) {
      // If error, return empty list (user has no roomspaces)
      return [];
    }
  }

  /// Resend email verification
  Future<void> resendEmailVerification() async {
    try {
      await _authService.resendEmailVerification();
    } catch (e) {
      rethrow;
    }
  }

  /// Resend email verification with credentials
  Future<void> resendEmailVerificationWithCredentials({
    required String email,
    required String password,
  }) async {
    try {
      await _authService.resendEmailVerificationWithCredentials(
        email: email,
        password: password,
      );
    } catch (e) {
      rethrow;
    }
  }
}
