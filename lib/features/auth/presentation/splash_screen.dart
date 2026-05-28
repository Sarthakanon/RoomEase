import 'dart:async';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:provider/provider.dart';
import '../../../services/auth_state_service.dart';
import '../../../services/ban_monitoring_service.dart';
import '../../../services/connectivity_service.dart';
import '../../../providers/roomspace_provider.dart';
import '../../../widgets/ban_countdown_dialog.dart';
import '../../../widgets/first_time_permissions_dialog.dart';
import '../controllers/auth_controller.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  final _authController = AuthController();
  final _connectivityService = ConnectivityService();
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
    await Future.delayed(const Duration(milliseconds: 600));

    if (!mounted) return;

    try {
      final shouldStayLoggedIn = await AuthStateService.shouldStayLoggedIn();
      
      if (shouldStayLoggedIn) {
        // User should stay logged in, authenticate with backend
        final currentUser = FirebaseAuth.instance.currentUser;
        if (currentUser != null) {
          try {
            await _connectivityService.initialize();
            final isOnline = _connectivityService.isConnected;

            if (isOnline) {
              // Get fresh Firebase token and authenticate with backend when online.
              final idToken = await currentUser.getIdToken();
              if (idToken != null) {
                await _authController.authenticateWithBackend(idToken);
              }
            } else {
              debugPrint('📴 Offline at startup: skipping backend auth refresh');
            }

            // Load roomspaces (provider can fallback to cached data on network error).
            if (mounted) {
              final roomspaceProvider = Provider.of<RoomspaceProvider>(context, listen: false);
              await roomspaceProvider.loadRoomspaces().timeout(const Duration(seconds: 6), onTimeout: () {});

              final hasRoomspaces = roomspaceProvider.roomspaceCount > 0;

              if (mounted) {
                await FirstTimePermissionsDialog.show(context);

                if (mounted) {
                  Navigator.pushReplacementNamed(
                    context,
                    hasRoomspaces ? '/home' : '/roomspace-selection',
                  );
                }
              }
            }
            return;
          } catch (e) {
            // Keep user logged in on transient/network failures.
            final error = e.toString().toLowerCase();
            final isNetworkLike = error.contains('network') ||
                error.contains('connection') ||
                error.contains('timeout') ||
                error.contains('socket') ||
                error.contains('failed host lookup');

            if (isNetworkLike && mounted) {
              debugPrint('📴 Startup auth refresh failed due to network. Preserving session.');
              final roomspaceProvider = Provider.of<RoomspaceProvider>(context, listen: false);
              await roomspaceProvider.loadRoomspaces().timeout(const Duration(seconds: 6), onTimeout: () {});
              final hasRoomspaces = roomspaceProvider.roomspaceCount > 0;
              if (mounted) {
                await FirstTimePermissionsDialog.show(context);
              }
              if (mounted) {
                Navigator.pushReplacementNamed(
                  context,
                  hasRoomspaces ? '/home' : '/roomspace-selection',
                );
                return;
              }
            }

            // Only clear persisted login state for non-network auth/session failures.
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
