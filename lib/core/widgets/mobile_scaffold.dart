import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';

class MobileScaffold extends StatefulWidget {
  final Widget body;
  final String? title;
  final List<Widget>? actions;
  final bool showBottomNav;
  final int currentIndex;

  const MobileScaffold({
    super.key,
    required this.body,
    this.title,
    this.actions,
    this.showBottomNav = true,
    this.currentIndex = 0,
  });

  @override
  State<MobileScaffold> createState() => _MobileScaffoldState();
}

class _MobileScaffoldState extends State<MobileScaffold> {
  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF6366F1), Color(0xFF8B5CF6)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(
                Icons.home_rounded,
                color: Colors.white,
                size: 20,
              ),
            ),
            const SizedBox(width: 8),
            Text(
              widget.title ?? 'RoomEase',
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Color(0xFF2C3E50),
              ),
            ),
          ],
        ),
        actions:
            widget.actions ??
            [
              if (user != null)
                PopupMenuButton<String>(
                  icon: CircleAvatar(
                    radius: 16,
                    backgroundColor: const Color(0xFF6366F1),
                    backgroundImage: user.photoURL != null
                        ? NetworkImage(user.photoURL!)
                        : null,
                    child: user.photoURL == null
                        ? Text(
                            user.displayName?.substring(0, 1).toUpperCase() ??
                                'U',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                            ),
                          )
                        : null,
                  ),
                  offset: const Offset(0, 50),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  itemBuilder: (context) => [
                    PopupMenuItem(
                      value: 'profile',
                      child: Row(
                        children: [
                          const Icon(Icons.person_outline, size: 20),
                          const SizedBox(width: 12),
                          Text(user.displayName ?? 'Profile'),
                        ],
                      ),
                    ),
                    const PopupMenuItem(
                      value: 'settings',
                      child: Row(
                        children: [
                          Icon(Icons.settings_outlined, size: 20),
                          SizedBox(width: 12),
                          Text('Settings'),
                        ],
                      ),
                    ),
                    const PopupMenuDivider(),
                    const PopupMenuItem(
                      value: 'logout',
                      child: Row(
                        children: [
                          Icon(Icons.logout, size: 20, color: Colors.red),
                          SizedBox(width: 12),
                          Text('Logout', style: TextStyle(color: Colors.red)),
                        ],
                      ),
                    ),
                  ],
                  onSelected: (value) {
                    switch (value) {
                      case 'profile':
                        // Navigate to profile
                        break;
                      case 'settings':
                        Navigator.pushNamed(context, '/settings');
                        break;
                      case 'logout':
                        FirebaseAuth.instance.signOut();
                        Navigator.pushReplacementNamed(context, '/login');
                        break;
                    }
                  },
                ),
              const SizedBox(width: 8),
            ],
      ),
      body: widget.body,
      bottomNavigationBar: widget.showBottomNav && user != null
          ? Container(
              decoration: BoxDecoration(
                color: Colors.white,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 10,
                    offset: const Offset(0, -2),
                  ),
                ],
              ),
              child: SafeArea(
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      _NavBarItem(
                        icon: Icons.dashboard_rounded,
                        label: 'Home',
                        isActive: widget.currentIndex == 0,
                        onTap: () {
                          Navigator.pushReplacementNamed(context, '/home');
                        },
                      ),
                      _NavBarItem(
                        icon: Icons.meeting_room_rounded,
                        label: 'Rooms',
                        isActive: widget.currentIndex == 1,
                        onTap: () {
                          Navigator.pushNamed(context, '/roomspace-selection');
                        },
                      ),
                      _NavBarItem(
                        icon: Icons.receipt_long_rounded,
                        label: 'Expenses',
                        isActive: widget.currentIndex == 2,
                        onTap: () {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Coming soon!')),
                          );
                        },
                      ),
                      _NavBarItem(
                        icon: Icons.people_rounded,
                        label: 'Members',
                        isActive: widget.currentIndex == 3,
                        onTap: () {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Coming soon!')),
                          );
                        },
                      ),
                    ],
                  ),
                ),
              ),
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

  const _NavBarItem({
    required this.icon,
    required this.label,
    required this.isActive,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: isActive
              ? const Color(0xFF6366F1).withOpacity(0.1)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              color: isActive ? const Color(0xFF6366F1) : Colors.grey[600],
              size: 24,
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: isActive ? FontWeight.w600 : FontWeight.normal,
                color: isActive ? const Color(0xFF6366F1) : Colors.grey[600],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
