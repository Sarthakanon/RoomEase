import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'dart:developer';
import '../../features/home/mobile_dashboard.dart';
import '../../features/roomspace/presentation/roomspace_router.dart';
import '../../features/expenses/presentation/expense_screen.dart';
import '../../features/analytics/presentation/analytics_page.dart';
import '../../features/profile/presentation/profile_screen.dart';
import '../../providers/roomspace_provider.dart';
import '../../services/payment_dialog_service.dart';

/// Main navigation widget that maintains state across tab switches
/// Uses IndexedStack to keep all screens alive and prevent reloading
class MainNavigation extends StatefulWidget {
  final int initialIndex;

  const MainNavigation({
    super.key,
    this.initialIndex = 0,
  });

  @override
  State<MainNavigation> createState() => _MainNavigationState();
}

class _MainNavigationState extends State<MainNavigation> with WidgetsBindingObserver {
  late int _currentIndex;

  // Keep all screens alive to prevent reloading
  late final List<Widget> _screens;

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex;
    
    // Initialize screens once and keep them alive
    _screens = [
      const MobileDashboard(), // Home
      const RoomspaceRouter(),  // Rooms
      const ExpenseScreen(),    // Expenses
      const AnalyticsPage(),    // Analytics
      const ProfileScreen(),    // Profile
    ];
    
    // Add lifecycle observer for app state changes
    WidgetsBinding.instance.addObserver(this);
    
    // Set context for payment dialog service
    WidgetsBinding.instance.addPostFrameCallback((_) {
      PaymentDialogService.setContext(context);
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    
    // Update payment dialog service about app state
    switch (state) {
      case AppLifecycleState.resumed:
        PaymentDialogService.setAppForegroundState(true);
        PaymentDialogService.setContext(context);
        log('App resumed - foreground state: true');
        break;
      case AppLifecycleState.paused:
        PaymentDialogService.setAppForegroundState(false);
        log('App paused - foreground state: false');
        break;
      case AppLifecycleState.inactive:
        PaymentDialogService.setAppForegroundState(false);
        log('App inactive - foreground state: false');
        break;
      case AppLifecycleState.detached:
        PaymentDialogService.setAppForegroundState(false);
        log('App detached - foreground state: false');
        break;
      case AppLifecycleState.hidden:
        PaymentDialogService.setAppForegroundState(false);
        log('App hidden - foreground state: false');
        break;
    }
  }

  void _onTabTapped(int index) {
    if (_currentIndex != index) {
      setState(() {
        _currentIndex = index;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<RoomspaceProvider>(
      builder: (context, roomspaceProvider, child) {
        final isPersonalSpace = roomspaceProvider.isPersonalSpace;

        // If user switches to Personal Space while currently on Rooms tab,
        // move to Expenses tab to avoid showing roomspace-only context.
        if (isPersonalSpace && _currentIndex == 1) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted && _currentIndex == 1) {
              setState(() => _currentIndex = 2);
            }
          });
        }
        
        return Scaffold(
          backgroundColor: Colors.white,
          body: IndexedStack(
            index: _currentIndex,
            children: _screens,
          ),
          bottomNavigationBar: _buildBottomNavigationBar(isPersonalSpace),
        );
      },
    );
  }

  Widget _buildBottomNavigationBar(bool isPersonalSpace) {
    final screenWidth = MediaQuery.of(context).size.width;
    
    // Responsive sizing
    final horizontalMargin = screenWidth < 360 ? 12.0 : 24.0;
    final iconSize = screenWidth < 360 ? 22.0 : 24.0;
    final fontSize = screenWidth < 360 ? 12.0 : 14.0;
    final navBarHeight = screenWidth < 360 ? 55.0 : 63.0;
    
    return SafeArea(
      child: Container(
        height: navBarHeight,
        padding: const EdgeInsets.all(10),
        margin: EdgeInsets.symmetric(
          horizontal: horizontalMargin,
          vertical: 10,
        ),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.1),
              blurRadius: 20,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            Expanded(
              child: _NavBarItem(
                icon: Icons.dashboard_rounded,
                label: 'Home',
                isActive: _currentIndex == 0,
                iconSize: iconSize,
                fontSize: fontSize,
                onTap: () => _onTabTapped(0),
              ),
            ),
            // Hide Rooms tab in personal space
            if (!isPersonalSpace)
              Expanded(
                child: _NavBarItem(
                  icon: Icons.meeting_room_rounded,
                  label: 'Rooms',
                  isActive: _currentIndex == 1,
                  iconSize: iconSize,
                  fontSize: fontSize,
                  onTap: () => _onTabTapped(1),
                ),
              ),
            Expanded(
              child: _NavBarItem(
                icon: Icons.receipt_long_rounded,
                label: 'Expenses',
                isActive: _currentIndex == 2,
                iconSize: iconSize,
                fontSize: fontSize,
                onTap: () => _onTabTapped(2),
              ),
            ),
            Expanded(
              child: _NavBarItem(
                icon: Icons.analytics_rounded,
                label: 'Analytics',
                isActive: _currentIndex == 3,
                iconSize: iconSize,
                fontSize: fontSize,
                onTap: () => _onTabTapped(3),
              ),
            ),
            Expanded(
              child: _NavBarItem(
                icon: Icons.person_rounded,
                label: 'Profile',
                isActive: _currentIndex == 4,
                iconSize: iconSize,
                fontSize: fontSize,
                onTap: () => _onTabTapped(4),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _NavBarItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool isActive;
  final VoidCallback onTap;
  final double iconSize;
  final double fontSize;

  const _NavBarItem({
    required this.icon,
    required this.label,
    required this.isActive,
    required this.onTap,
    this.iconSize = 24.0,
    this.fontSize = 14.0,
  });

  @override
  Widget build(BuildContext context) {
    final Color primaryColor = Theme.of(context).colorScheme.primary;
    final screenWidth = MediaQuery.of(context).size.width;
    
    final horizontalPadding = screenWidth < 360 ? 8.0 : 12.0;
    final verticalPadding = screenWidth < 360 ? 5.0 : 6.5;

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOut,
        padding: EdgeInsets.symmetric(
          horizontal: horizontalPadding,
          vertical: verticalPadding,
        ),
        decoration: BoxDecoration(
          color: isActive
              ? primaryColor.withValues(alpha: 0.1)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              color: isActive ? primaryColor : Colors.grey[400],
              size: iconSize,
            ),
          ],
        ),
      ),
    );
  }
}
