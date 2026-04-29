import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'dart:async';
import '../main.dart' show navigatorKey;

/// Listens to Firebase auth state changes and automatically navigates to login
/// when the user is logged out (e.g., due to 401 error or ban)
class AuthStateListener extends StatefulWidget {
  final Widget child;

  const AuthStateListener({
    super.key,
    required this.child,
  });

  @override
  State<AuthStateListener> createState() => _AuthStateListenerState();
}

class _AuthStateListenerState extends State<AuthStateListener> {
  late StreamSubscription<User?> _authSubscription;
  User? _previousUser;
  bool _isInitialized = false;

  @override
  void initState() {
    super.initState();
    _setupAuthListener();
  }

  @override
  void dispose() {
    _authSubscription.cancel();
    super.dispose();
  }

  void _setupAuthListener() {
    // Get initial user state
    _previousUser = FirebaseAuth.instance.currentUser;
    _isInitialized = true;

    // Listen to auth state changes
    _authSubscription = FirebaseAuth.instance.authStateChanges().listen((User? user) {
      if (!mounted) return;

      // Skip the first event (initialization)
      if (!_isInitialized) {
        _isInitialized = true;
        _previousUser = user;
        return;
      }

      // If user was logged in and now is logged out, navigate to login
      if (_previousUser != null && user == null) {
        print('🔒 Auth state changed: User logged out - navigating to login');
        _navigateToLogin();
      }

      _previousUser = user;
    });
  }

  void _navigateToLogin() {
    // Use global navigator key to navigate from anywhere
    final navigator = navigatorKey.currentState;
    if (navigator == null) {
      print('🔒 Navigator not available yet');
      return;
    }

    // Get the current route
    final currentRoute = navigator.overlay?.context != null 
        ? ModalRoute.of(navigator.overlay!.context)?.settings.name 
        : null;

    // Only navigate if not already on login/splash screen
    if (currentRoute != '/login' && currentRoute != '/') {
      print('🔒 Navigating to login from: $currentRoute');
      
      // Use pushNamedAndRemoveUntil to clear the entire stack
      navigator.pushNamedAndRemoveUntil(
        '/login',
        (route) => false,
      );
    } else {
      print('🔒 Already on login/splash screen, skipping navigation');
    }
  }

  @override
  Widget build(BuildContext context) {
    return widget.child;
  }
}
