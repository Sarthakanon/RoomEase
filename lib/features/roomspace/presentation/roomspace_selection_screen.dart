import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

// ==========================================
// 1. LOGIC SECTION (The "Controller")
// ==========================================
class RoomSelectionController {
  
  // Navigate to Create Room Screen
  void goToCreateRoom(BuildContext context) {
    Navigator.pushNamed(context, '/create-roomspace');
  }

  // Navigate to Join Room Screen
  void goToJoinRoom(BuildContext context) {
    Navigator.pushNamed(context, '/join-roomspace');
  }

  // Skip and go to Dashboard
  void skipToHome(BuildContext context) {
    Navigator.pushReplacementNamed(context, '/home');
  }
}

// ==========================================
// 2. UI SECTION (The "View")
// ==========================================
class RoomspaceSelectionScreen extends StatelessWidget {
  const RoomspaceSelectionScreen({super.key});

  @override
  Widget build(BuildContext context) {
    // We create an instance of our controller
    final controller = RoomSelectionController();
    final theme = Theme.of(context);
    final primaryColor = theme.primaryColor;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      // Transparent AppBar just to control Status Bar color
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        toolbarHeight: 0, // Hides the AppBar space
        systemOverlayStyle: SystemUiOverlayStyle.dark,
      ),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _buildHeader(), // Extracted Header
                const SizedBox(height: 40),
                
                // Option 1: Create
                _buildOptionCard(
                  context,
                  title: 'Create New Room',
                  subtitle: 'Start fresh and invite your roommates',
                  icon: Icons.add_home_rounded,
                  iconColor: primaryColor,
                  onTap: () => controller.goToCreateRoom(context),
                ),

                const SizedBox(height: 16),

                // Option 2: Join
                _buildOptionCard(
                  context,
                  title: 'Join Existing Room',
                  subtitle: 'Enter a Room ID to join your friends',
                  icon: Icons.login_rounded,
                  iconColor: Colors.orangeAccent, // Hardcoded for variety, or use theme
                  onTap: () => controller.goToJoinRoom(context),
                ),

                const SizedBox(height: 40),
                
                // Skip Button
                _buildSkipButton(context, controller),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // --- SMALLER WIDGET PIECES ---

  // 1. Header Text Widget
  Widget _buildHeader() {
    return Column(
      children: [
        const Text(
          'Choose an Option',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.bold,
            color: Colors.black87,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Select how you want to proceed',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 16, color: Colors.grey[600]),
        ),
      ],
    );
  }

  // 2. Skip Button Widget
  Widget _buildSkipButton(BuildContext context, RoomSelectionController controller) {
    return TextButton(
      onPressed: () => controller.skipToHome(context),
      child: Text(
        'Skip for now',
        style: TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w600,
          color: Colors.grey[500],
        ),
      ),
    );
  }

  // 3. Reusable Card Widget
  Widget _buildOptionCard(
    BuildContext context, {
    required String title,
    required String subtitle,
    required IconData icon,
    required Color iconColor,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.grey.shade200),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05), // Beginner friendly opacity
              blurRadius: 15,
              offset: const Offset(0, 5),
            ),
          ],
        ),
        child: Row(
          children: [
            // Icon Box
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: iconColor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(15),
              ),
              child: Icon(icon, color: iconColor, size: 28),
            ),
            const SizedBox(width: 16),

            // Text Info
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: TextStyle(fontSize: 13, color: Colors.grey[600]),
                  ),
                ],
              ),
            ),

            // Arrow Icon
            Icon(
              Icons.arrow_forward_ios_rounded,
              size: 16,
              color: Colors.grey[400],
            ),
          ],
        ),
      ),
    );
  }
}