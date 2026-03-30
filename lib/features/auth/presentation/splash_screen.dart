import 'dart:async';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:provider/provider.dart';
import '../../../services/auth_state_service.dart';
import '../../../services/ban_monitoring_service.dart';
import '../../../providers/roomspace_provider.dart';
import '../../../widgets/ban_countdown_dialog.dart';
import '../controllers/auth_controller.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  final _authController = AuthController();
  late StreamSubscription<String>? _banSubscription;

  @override
  void initState() {
    super.initState();
    _setupBanListener();
    _checkAuthState();
  }

  @override
  void dispose() {
    _banSubscription?.cancel();
    super.dispose();
  }

  void _setupBanListener() {
    _banSubscription = BanMonitoringService().banNotificationStream.listen((reason) {
      if (mounted) {
        _showBanDialog(reason);
      }
    });
  }

  void _showBanDialog(String reason) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => BanCountdownDialog(reason: reason),
    );
  }

  Future<void> _checkAuthState() async {
    // Add a small delay for splash screen effect
    await Future.delayed(const Duration(seconds: 2));

    if (!mounted) return;

    try {
      final shouldStayLoggedIn = await AuthStateService.shouldStayLoggedIn();
      
      if (shouldStayLoggedIn) {
        // User should stay logged in, authenticate with backend
        final currentUser = FirebaseAuth.instance.currentUser;
        if (currentUser != null) {
          try {
            // Get fresh Firebase token and authenticate with backend
            final idToken = await currentUser.getIdToken(true); // Force refresh
            if (idToken != null) {
              // Authenticate with backend using Firebase token
              await _authController.authenticateWithBackend(idToken);
              
              // Load roomspaces into the provider after authentication
              if (mounted) {
                final roomspaceProvider = Provider.of<RoomspaceProvider>(context, listen: false);
                await roomspaceProvider.loadRoomspaces();
                
                // Check if user has roomspaces
                final hasRoomspaces = roomspaceProvider.roomspaceCount > 0;
                
                if (mounted) {
                  Navigator.pushReplacementNamed(
                    context,
                    hasRoomspaces ? '/home' : '/roomspace-selection',
                  );
                }
              }
              return;
            }
          } catch (e) {
            // If backend authentication fails, clear login state and go to login
            await AuthStateService.clearLoginState();
          }
        }
      }
      
      // User should go to login
      if (mounted) {
        Navigator.pushReplacementNamed(context, '/login');
      }
    } catch (e) {
      // On error, go to login
      if (mounted) {
        Navigator.pushReplacementNamed(context, '/login');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final primaryColor = Theme.of(context).colorScheme.primary;

    return Scaffold(
      backgroundColor: Colors.white,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Logo
            Container(
              height: 120,
              width: 120,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(25),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.1),
                    blurRadius: 15,
                    offset: const Offset(0, 5),
                  ),
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(25),
                child: Image.asset(
                  'png/main_logo.png',
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) {
                    // Fallback to colored container if image fails to load
                    return Container(
                      decoration: BoxDecoration(
                        color: primaryColor,
                        borderRadius: BorderRadius.circular(25),
                      ),
                      child: const Icon(
                        Icons.home_rounded,
                        color: Colors.white,
                        size: 50,
                      ),
                    );
                  },
                ),
              ),
            ),
            const SizedBox(height: 24),
            
            // App Name
            Text(
              'RoomEase',
              style: TextStyle(
                fontSize: 32,
                fontWeight: FontWeight.bold,
                color: primaryColor,
              ),
            ),
            const SizedBox(height: 8),
            
            // Tagline
            Text(
              'Manage expenses with ease',
              style: TextStyle(
                fontSize: 16,
                color: Colors.grey[600],
              ),
            ),
            const SizedBox(height: 48),
            
            // Loading indicator
            CircularProgressIndicator(
              color: primaryColor,
              strokeWidth: 3,
            ),
          ],
        ),
      ),
    );
  }
}