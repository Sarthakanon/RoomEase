import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:provider/provider.dart';
import 'global_roomspace_selector.dart';
import '../../providers/roomspace_provider.dart';

class MobileScaffold extends StatefulWidget {
  final Widget body;
  final String? title;
  final List<Widget>? actions;
  final bool showBottomNav;
  final int currentIndex;
  final bool showAppBar; // New parameter to control AppBar visibility

  const MobileScaffold({
    super.key,
    required this.body,
    this.title,
    this.actions,
    this.showBottomNav = true,
    this.currentIndex = 0,
    this.showAppBar = true, // Default to true
  });

  @override
  State<MobileScaffold> createState() => _MobileScaffoldState();
}

class _MobileScaffoldState extends State<MobileScaffold> {
  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

    return Scaffold(
      backgroundColor: Colors.white, // Changed from grey to white
      appBar: widget.showAppBar ? AppBar(
        backgroundColor: Colors.white, // Changed from grey to white
        elevation: 0,
        automaticallyImplyLeading: false,
        title: Text(
          widget.title ?? 'RoomEase',
          style: const TextStyle(
            color: Colors.black87,
            fontWeight: FontWeight.bold,
            fontSize: 20,
          ),
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: Center(
              child: GlobalRoomspaceSelector(
                onRoomspaceChanged: () {
                  // Trigger refresh if needed
                },
              ),
            ),
          ),
        ],
      ) : null,
      body: widget.body,
      // Keep false to prevent overlap
      extendBody: false,
      bottomNavigationBar: widget.showBottomNav && user != null
          ? Consumer<RoomspaceProvider>(
              builder: (context, roomspaceProvider, child) {
                final isPersonalSpace = roomspaceProvider.isPersonalSpace;
                final screenWidth = MediaQuery.of(context).size.width;
                
                // Responsive sizing based on screen width
                final horizontalMargin = screenWidth < 360 ? 12.0 : 24.0;
                final iconSize = screenWidth < 360 ? 22.0 : 24.0;
                final fontSize = screenWidth < 360 ? 12.0 : 14.0;
                final navBarHeight = screenWidth < 360 ? 55.0 : 63.0;
                
                return SafeArea(
                  child: Container(
                    // Responsive height - adjusted 5% bigger
                    height: navBarHeight,
                    padding: const EdgeInsets.all(10), // Slightly increased from 9
                    margin: EdgeInsets.symmetric(
                      horizontal: horizontalMargin,
                      vertical: 10, // Slightly increased from 9
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
                            isActive: widget.currentIndex == 0,
                            iconSize: iconSize,
                            fontSize: fontSize,
                            onTap: () {
                              if (widget.currentIndex != 0) {
                                Navigator.pushReplacementNamed(context, '/home');
                              }
                            },
                          ),
                        ),
                        // Hide Rooms tab in personal space
                        if (!isPersonalSpace)
                          Expanded(
                            child: _NavBarItem(
                              icon: Icons.meeting_room_rounded,
                              label: 'Rooms',
                              isActive: widget.currentIndex == 1,
                              iconSize: iconSize,
                              fontSize: fontSize,
                              onTap: () {
                                if (widget.currentIndex != 1) {
                                  Navigator.pushNamed(context, '/roomspace');
                                }
                              },
                            ),
                          ),
                        Expanded(
                          child: _NavBarItem(
                            icon: Icons.receipt_long_rounded,
                            label: 'Expenses',
                            isActive: widget.currentIndex == 2,
                            iconSize: iconSize,
                            fontSize: fontSize,
                            onTap: () {
                              if (widget.currentIndex != 2) {
                                Navigator.pushNamed(context, '/expenses');
                              }
                            },
                          ),
                        ),
                        Expanded(
                          child: _NavBarItem(
                            icon: Icons.analytics_rounded,
                            label: 'Analytics',
                            isActive: widget.currentIndex == 3,
                            iconSize: iconSize,
                            fontSize: fontSize,
                            onTap: () {
                              if (widget.currentIndex != 3) {
                                Navigator.pushNamed(context, '/analytics');
                              }
                            },
                          ),
                        ),
                        Expanded(
                          child: _NavBarItem(
                            icon: Icons.person_rounded,
                            label: 'Profile',
                            isActive: widget.currentIndex == 4,
                            iconSize: iconSize,
                            fontSize: fontSize,
                            onTap: () {
                              if (widget.currentIndex != 4) {
                                Navigator.pushNamed(context, '/profile');
                              }
                            },
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            )
          : null,
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
    // Use theme primary color
    final Color primaryColor = Theme.of(context).colorScheme.primary;
    final screenWidth = MediaQuery.of(context).size.width;
    
    // Responsive padding - adjusted 5% bigger
    final horizontalPadding = screenWidth < 360 ? 8.0 : 12.0;
    final verticalPadding = screenWidth < 360 ? 5.0 : 6.5; // Slightly increased

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
          // CRITICAL FIX: Minimize main axis size to prevent stretching
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              color: isActive ? primaryColor : Colors.grey[400],
              size: iconSize,
            ),
            AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              width: isActive ? (screenWidth < 360 ? 4 : 8) : 0,
            ),
            if (isActive)
              Flexible(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: fontSize,
                    fontWeight: FontWeight.bold,
                    color: primaryColor,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
