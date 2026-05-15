import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:provider/provider.dart';
import 'screens/login_screen.dart';
import 'screens/enhanced_dashboard_screen.dart';
import 'services/auth_service.dart';
import 'providers/admin_provider.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Initialize Firebase for admin
  await Firebase.initializeApp(
    options: const FirebaseOptions(
      apiKey: "AIzaSyC8epfR3MAWSYMaqk9VXXYVjSQMKG9fEbA",
      authDomain: "roomease-2025.firebaseapp.com",
      projectId: "roomease-2025",
      storageBucket: "roomease-2025.firebasestorage.app",
      messagingSenderId: "949338416443",
      appId: "1:949338416443:web:e958d1632234a75590431e",
    ),
  );
  
  runApp(const AdminApp());
}

class AdminApp extends StatelessWidget {
  const AdminApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AdminProvider()),
        Provider(create: (_) => AuthService()),
      ],
      child: MaterialApp(
        title: 'RoomEase Admin',
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          colorScheme: ColorScheme.fromSeed(
            seedColor: const Color(0xFF6366F1),
            brightness: Brightness.light,
          ),
          useMaterial3: true,
          fontFamily: 'Inter',
        ),
        home: const AuthWrapper(),
        routes: {
          '/login': (context) => const LoginScreen(),
          '/dashboard': (context) => const EnhancedDashboardScreen(),
        },
      ),
    );
  }
}

class AuthWrapper extends StatelessWidget {
  const AuthWrapper({super.key});

  @override
  Widget build(BuildContext context) {
    final authService = Provider.of<AuthService>(context);
    
    return StreamBuilder(
      stream: authService.authStateChanges,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(
              child: CircularProgressIndicator(),
            ),
          );
        }
        
        if (snapshot.hasData) {
          return const EnhancedDashboardScreen();
        }
        
        return const LoginScreen();
      },
    );
  }
}
