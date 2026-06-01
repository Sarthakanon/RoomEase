import 'dart:developer';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:firebase_auth/firebase_auth.dart';

class AuthStateService {
  static const String _rememberMeKey = 'remember_me';
  static const String _userEmailKey = 'user_email';
  static const String _isLoggedInKey = 'is_logged_in';

  /// Check if user wants to be remembered
  static Future<bool> getRememberMe() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getBool(_rememberMeKey) ?? false;
    } catch (e) {
      log('Error getting remember me preference: $e');
      return false;
    }
  }

  /// Set remember me preference
  static Future<void> setRememberMe(bool remember) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_rememberMeKey, remember);
    } catch (e) {
      log('Error setting remember me preference: $e');
    }
  }

  /// Save login state
  static Future<void> saveLoginState(String email, bool rememberMe) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_isLoggedInKey, true);
      await prefs.setString(_userEmailKey, email);
      await prefs.setBool(_rememberMeKey, rememberMe);
      log('Login state saved for: $email (remember: $rememberMe)');
    } catch (e) {
      log('Error saving login state: $e');
    }
  }

  /// Get saved email
  static Future<String?> getSavedEmail() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getString(_userEmailKey);
    } catch (e) {
      log('Error getting saved email: $e');
      return null;
    }
  }

  /// Check if user should stay logged in
  static Future<bool> shouldStayLoggedIn() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final isLoggedIn = prefs.getBool(_isLoggedInKey) ?? false;
      final rememberMe = prefs.getBool(_rememberMeKey) ?? false;
      final currentUser = FirebaseAuth.instance.currentUser;
      
      // Keep session if user was previously logged in and Firebase still has
      // a valid local session. Remember-me only controls UI conveniences
      // (like pre-filling email), not auth session persistence.
      final shouldStay = isLoggedIn && currentUser != null;
      
      log('Should stay logged in: $shouldStay (logged: $isLoggedIn, remember: $rememberMe, firebase: ${currentUser != null})');
      return shouldStay;
    } catch (e) {
      log('Error checking login state: $e');
      return false;
    }
  }

  /// Clear login state (logout)
  static Future<void> clearLoginState() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_isLoggedInKey);
      await prefs.remove(_userEmailKey);
      // Keep remember me preference for next login
      log('Login state cleared');
    } catch (e) {
      log('Error clearing login state: $e');
    }
  }

  /// Get the appropriate initial route based on login state
  static Future<String> getInitialRoute() async {
    try {
      final shouldStay = await shouldStayLoggedIn();
      if (shouldStay) {
        // Check if user has roomspaces to determine route
        // For now, default to home - can be enhanced later
        return '/home';
      }
      return '/login';
    } catch (e) {
      log('Error determining initial route: $e');
      return '/login';
    }
  }
}
