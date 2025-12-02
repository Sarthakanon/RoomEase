import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../core/widgets/mobile_scaffold.dart';
import '../../services/api_service.dart';

class MobileDashboard extends StatefulWidget {
  const MobileDashboard({super.key});

  @override
  State<MobileDashboard> createState() => _MobileDashboardState();
}

class _MobileDashboardState extends State<MobileDashboard> {
  final ApiService _apiService = ApiService();
  bool _hasRoomspace = false;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _checkRoomspace();
  }

  Future<void> _checkRoomspace() async {
    try {
      final response = await _apiService.getRoomspaces();
      if (response.containsKey('data')) {
        final roomspaces = response['data'] as List<dynamic>;
        if (mounted) {
          setState(() {
            _hasRoomspace = roomspaces.isNotEmpty;
            _isLoading = false;
          });
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _hasRoomspace = false;
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    // 1. Get current user
    final user = FirebaseAuth.instance.currentUser;
    // 2. Use theme colors
    final Color primaryColor = Theme.of(context).colorScheme.primary;

    return MobileScaffold(
      // Ensure this is 0 so the first tab is selected
      currentIndex: 0,
      // We use a Column inside SingleChildScrollView for scrolling
      body: SingleChildScrollView(
        child: Column(
          children: [
            // ---------------------------------------------
            // SECTION 1: CUSTOM HEADER (Replaces AppBar)
            // ---------------------------------------------
            Container(
              width: double.infinity,
              padding: const EdgeInsets.only(
                left: 20,
                right: 20,
                top: 60, // Extra top padding to avoid status bar
                bottom: 30,
              ),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [primaryColor, primaryColor.withValues(alpha: 0.7)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: const BorderRadius.only(
                  bottomLeft: Radius.circular(30),
                  bottomRight: Radius.circular(30),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Row with Name and Profile Icon
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Welcome back,',
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.8),
                              fontSize: 16,
                            ),
                          ),
                          const SizedBox(height: 5),
                          Text(
                            user?.displayName ?? 'User',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                      // Profile Icon with Popup Menu
                      PopupMenuButton<String>(
                        icon: Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.2),
                            shape: BoxShape.circle,
                          ),
                          child: user?.photoURL != null
                              ? CircleAvatar(
                                  radius: 14,
                                  backgroundImage: NetworkImage(
                                    user!.photoURL!,
                                  ),
                                )
                              : const Icon(
                                  Icons.person,
                                  color: Colors.white,
                                  size: 28,
                                ),
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
                                Text(user?.displayName ?? 'Profile'),
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
                        ],
                        onSelected: (value) {
                          switch (value) {
                            case 'profile':
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('Profile coming soon!'),
                                ),
                              );
                              break;
                            case 'settings':
                              Navigator.pushNamed(context, '/settings');
                              break;
                          }
                        },
                      ),
                    ],
                  ),
                  const SizedBox(height: 25),

                  // Balance Information
                  const Text(
                    'Your Total Balance',
                    style: TextStyle(color: Colors.white70, fontSize: 14),
                  ),
                  const SizedBox(height: 5),
                  const Text(
                    '\$ 450.00',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 40,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const Text(
                    'you are owed',
                    style: TextStyle(
                      color: Colors
                          .greenAccent, // Green because you are owed money
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),

            // ---------------------------------------------
            // SECTION 2: MAIN ACTION BUTTONS
            // ---------------------------------------------
            Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                children: [
                  // Row for OCR and Add Expense
                  Row(
                    children: [
                      // BUTTON A: SCAN RECEIPT
                      Expanded(
                        child: InkWell(
                          onTap: () {
                            // Logic for OCR Scanning
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Opening Scanner...'),
                              ),
                            );
                          },
                          child: Container(
                            height: 100,
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(20),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.grey.withValues(alpha: 0.1),
                                  blurRadius: 10,
                                  offset: const Offset(0, 4),
                                ),
                              ],
                            ),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons.document_scanner_rounded,
                                  color: primaryColor,
                                  size: 30,
                                ),
                                const SizedBox(height: 8),
                                const Text(
                                  "Scan Receipt",
                                  style: TextStyle(fontWeight: FontWeight.bold),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 15),
                      // BUTTON B: ADD EXPENSE
                      Expanded(
                        child: InkWell(
                          onTap: () {
                            // Logic: Show snackbar "Coming Soon" as requested
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('Coming soon!')),
                            );
                          },
                          child: Container(
                            height: 100,
                            decoration: BoxDecoration(
                              color: primaryColor,
                              borderRadius: BorderRadius.circular(20),
                              boxShadow: [
                                BoxShadow(
                                  color: primaryColor.withValues(alpha: 0.4),
                                  blurRadius: 10,
                                  offset: const Offset(0, 4),
                                ),
                              ],
                            ),
                            child: const Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.add, color: Colors.white, size: 30),
                                SizedBox(height: 8),
                                Text(
                                  "Add Expense",
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: Colors.white,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),

                  // ---------------------------------------------
                  // SECTION 3: ROOM MANAGEMENT (Only show if no roomspace)
                  // ---------------------------------------------
                  if (!_hasRoomspace && !_isLoading) ...[
                    const SizedBox(height: 20),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: () {
                              Navigator.pushNamed(context, '/create-roomspace');
                            },
                            icon: Icon(
                              Icons.add_home_rounded,
                              color: primaryColor,
                            ),
                            label: Text(
                              "Create Room",
                              style: TextStyle(color: primaryColor),
                            ),
                            style: OutlinedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              side: BorderSide(color: primaryColor),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 15),
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: () {
                              Navigator.pushNamed(context, '/join-roomspace');
                            },
                            icon: Icon(
                              Icons.login_rounded,
                              color: primaryColor,
                            ),
                            label: Text(
                              "Join Room",
                              style: TextStyle(color: primaryColor),
                            ),
                            style: OutlinedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              side: BorderSide(color: primaryColor),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),

            // ---------------------------------------------
            // SECTION 4: RECENT ACTIVITY
            // ---------------------------------------------
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  "Recent Activity",
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.grey[800],
                  ),
                ),
              ),
            ),

            const SizedBox(height: 10),

            // List of Recent Expenses (Hardcoded Examples)
            ListView(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              padding: const EdgeInsets.symmetric(horizontal: 20),
              children: [
                _expenseTile(
                  "Grocery Run",
                  "Yesterday",
                  45.50,
                  true,
                  primaryColor,
                ),
                _expenseTile(
                  "Internet Bill",
                  "Oct 24",
                  30.00,
                  false,
                  primaryColor,
                ),
                _expenseTile(
                  "House Party",
                  "Oct 22",
                  120.00,
                  true,
                  primaryColor,
                ),
                const SizedBox(height: 30),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // Helper widget to build a single expense row
  Widget _expenseTile(
    String title,
    String date,
    double amount,
    bool youPaid,
    Color primaryColor,
  ) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withValues(alpha: 0.05),
            blurRadius: 5,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: primaryColor.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(Icons.receipt_long, color: primaryColor),
          ),
          const SizedBox(width: 15),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
                Text(
                  youPaid ? "You paid" : "Someone else paid",
                  style: TextStyle(color: Colors.grey[500], fontSize: 12),
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                "\$${amount.toStringAsFixed(2)}",
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                  color: youPaid ? const Color(0xFF10B981) : Colors.redAccent,
                ),
              ),
              Text(
                date,
                style: TextStyle(color: Colors.grey[400], fontSize: 12),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
