import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../../services/firebase_auth_service.dart';
import '../../../services/firestore_service.dart';
import '../../../services/api_service.dart';
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
      final userCredential = await _authService.signInWithGoogle();

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
        // Get Firebase ID token
        final idToken = await userCredential.user!.getIdToken();

        if (idToken != null) {
          // Send token to backend to create session and store user in PostgreSQL
          await _apiService.login(idToken);
        }

        // Create user document in Firestore (for backward compatibility)
        final user = UserModel(
          id: userCredential.user!.uid,
          name: name,
          email: email,
          createdAt: DateTime.now(),
        );
        await _firestoreService.createUser(user);
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

      setLoading(false);
    } catch (e) {
      setLoading(false);
      rethrow;
    }
  }

  /// Check if user has roomspaces
  Future<List<dynamic>> getUserRoomspaces(String uid) async {
    return await _firestoreService.getUserRoomspaces(uid);
  }
}
