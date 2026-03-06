import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class RoomSelectionController {
  void goToCreateRoom(BuildContext context) {
    Navigator.pushNamed(context, '/create-roomspace');
  }

  void goToJoinRoom(BuildContext context) {
    Navigator.pushNamed(context, '/join-roomspace');
  }

  void skipToHome(BuildContext context) {
    Navigator.pushReplacementNamed(context, '/home');
  }
}

/// Selection screen — initial choice for users to create or join a roomspace.
class RoomspaceSelectionScreen extends StatelessWidget {
  const RoomspaceSelectionScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = RoomSelectionController();
    final primaryColor = Theme.of(context).colorScheme.primary;

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        toolbarHeight: 0,
        systemOverlayStyle: SystemUiOverlayStyle.dark,
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Spacer(flex: 2),
              _buildHeader(),
              const SizedBox(height: 48),
              
              _buildOptionCard(
                context,
                title: 'Create Room',
                subtitle: 'Invite your roommates to a new space',
                icon: Icons.add_home_outlined,
                iconColor: primaryColor,
                onTap: () => controller.goToCreateRoom(context),
              ),

              const SizedBox(height: 16),

              _buildOptionCard(
                context,
                title: 'Join Room',
                subtitle: 'Enter a code to join an existing space',
                icon: Icons.meeting_room_outlined,
                iconColor: Colors.orange.shade700,
                onTap: () => controller.goToJoinRoom(context),
              ),

              const Spacer(flex: 2),
              
              TextButton(
                onPressed: () => controller.skipToHome(context),
                child: Text(
                  'Maybe later',
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Colors.grey.shade400),
                ),
              ),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Column(
      children: [
        const Text(
          'Manage Your Space',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 24, fontWeight: FontWeight.w800, color: Color(0xFF1A1A2E)),
        ),
        const SizedBox(height: 8),
        Text(
          'Start fresh or jump into an existing room',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 14, color: Colors.grey.shade500),
        ),
      ],
    );
  }

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
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFFEEEEF2)),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(color: iconColor.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(12)),
              child: Icon(icon, color: iconColor, size: 24),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: Color(0xFF1A1A2E))),
                  const SizedBox(height: 2),
                  Text(subtitle, style: TextStyle(fontSize: 12, color: Colors.grey.shade500)),
                ],
              ),
            ),
            Icon(Icons.arrow_forward_ios_rounded, size: 14, color: Colors.grey.shade300),
          ],
        ),
      ),
    );
  }
}