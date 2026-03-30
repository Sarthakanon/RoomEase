import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:provider/provider.dart';
import 'firebase_options.dart';
import 'package:google_fonts/google_fonts.dart';
import 'features/auth/presentation/splash_screen.dart';
import 'features/auth/presentation/login_screen.dart';
import 'features/auth/presentation/signup_screen.dart';
import 'features/auth/presentation/forgot_password_screen.dart';
import 'features/roomspace/presentation/roomspace_selection_screen.dart';
import 'features/roomspace/presentation/create_roomspace_screen.dart';
import 'features/roomspace/presentation/join_roomspace_screen.dart';
import 'features/roomspace/presentation/roomspace_details_screen.dart';
import 'features/settings/presentation/settings_screen.dart';
import 'features/notifications/presentation/notification_screen.dart';
import 'features/expenses/presentation/expense_list_screen.dart';
import 'features/expenses/presentation/personal_expenses_screen.dart';
import 'core/widgets/main_navigation.dart';
import 'services/api_service.dart';
import 'services/performance_service.dart';
import 'services/loading_service.dart';
import 'providers/roomspace_provider.dart';
import 'widgets/ban_listener_widget.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize Firebase
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  // Initialize persistent cookie storage for API service
  await ApiService().initializePersistentCookies();

  // Initialize performance optimizations
  await PerformanceService().initialize();

  // Configure system UI overlay style for status bar
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.dark,
      statusBarBrightness: Brightness.light,
      systemNavigationBarColor: Colors.white,
      systemNavigationBarIconBrightness: Brightness.dark,
    ),
  );

  runApp(const RoomEaseApp());
}

class RoomEaseApp extends StatelessWidget {
  const RoomEaseApp({super.key});

  @override
  Widget build(BuildContext context) {
    // Wrap MaterialApp with multiple providers for state management
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => RoomspaceProvider()),
        ChangeNotifierProvider(create: (_) => LoadingService()),
      ],
      child: BanListenerWidget(
        child: MaterialApp(
          debugShowCheckedModeBanner: false,
          title: 'RoomEase',
          theme: ThemeData(
            primarySwatch: Colors.indigo,
            colorScheme: ColorScheme.fromSeed(
              seedColor: Colors.indigo,
              secondary: Colors.amber,
              tertiary: Colors.teal,
            ),
            textTheme: GoogleFonts.poppinsTextTheme(
              Theme.of(context).textTheme.copyWith(
                displayLarge: GoogleFonts.poppins(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  color: Colors.indigo,
                ),
                displayMedium: GoogleFonts.poppins(
                  fontSize: 24,
                  fontWeight: FontWeight.w600,
                ),
                bodyLarge: GoogleFonts.poppins(
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                ),
                bodyMedium: GoogleFonts.poppins(fontSize: 14),
              ),
            ),
            elevatedButtonTheme: ElevatedButtonThemeData(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.indigo,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
            inputDecorationTheme: InputDecorationTheme(
              filled: true,
              fillColor: Colors.grey[100],
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: Colors.indigo, width: 2),
              ),
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 16,
              ),
            ),
            tooltipTheme: const TooltipThemeData(
              waitDuration: Duration(milliseconds: 800),
              showDuration: Duration(milliseconds: 1500),
              triggerMode: TooltipTriggerMode.longPress,
              enableFeedback: false,
            ),
          ),
          initialRoute: '/',
          routes: {
            '/': (context) => const SplashScreen(),
            '/login': (context) => const LoginScreen(),
            '/signup': (context) => const SignupScreen(),
            '/forgot-password': (context) => const ForgotPasswordScreen(),
            '/roomspace-selection': (context) => const RoomspaceSelectionScreen(),
            '/create-roomspace': (context) => const CreateRoomspaceScreen(),
            '/join-roomspace': (context) => const JoinRoomspaceScreen(),
            '/roomspace-details': (context) => const RoomspaceDetailsScreen(),
            '/settings': (context) => const SettingsScreen(),
            '/notifications': (context) => const NotificationScreen(),
            '/home': (context) => const MainNavigation(initialIndex: 0),
            '/roomspace': (context) => const MainNavigation(initialIndex: 1),
            '/expenses': (context) => const MainNavigation(initialIndex: 2),
            '/analytics': (context) => const MainNavigation(initialIndex: 3),
            '/profile': (context) => const MainNavigation(initialIndex: 4),
            '/expense-list': (context) => const ExpenseListScreen(),
            '/personal-expenses': (context) => const PersonalExpensesScreen(),
          },
        ),
      ),
    );
  }
}
