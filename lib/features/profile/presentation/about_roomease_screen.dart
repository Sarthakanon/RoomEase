import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class AboutRoomEaseScreen extends StatelessWidget {
  const AboutRoomEaseScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('About RoomEase')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: const Color(0xFFEEEEF2)),
            ),
            child: Column(
              children: [
                CircleAvatar(
                  radius: 32,
                  backgroundColor: Theme.of(context).primaryColor.withValues(alpha: 0.1),
                  child: Icon(
                    Icons.home_work_outlined,
                    size: 30,
                    color: Theme.of(context).primaryColor,
                  ),
                ),
                const SizedBox(height: 10),
                const Text(
                  'RoomEase',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 4),
                Text(
                  'Version 1.0.0+1',
                  style: TextStyle(color: Colors.grey.shade700),
                ),
                const SizedBox(height: 12),
                const Text(
                  'RoomEase helps roommates and individuals track expenses, split costs fairly, '
                  'monitor balances, and use smart analytics to improve spending decisions.',
                  textAlign: TextAlign.center,
                  style: TextStyle(height: 1.45),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          _infoCard(
            title: 'What RoomEase Offers',
            points: const [
              'Shared roomspace expense splitting',
              'Personal expense tracking',
              'Payment and settlement visibility',
              'Spending trends and AI-based insights',
              'Offline-friendly synced experience',
            ],
          ),
          const SizedBox(height: 14),
          _infoCard(
            title: 'Data & Privacy',
            points: const [
              'Your account uses authenticated access.',
              'Analytics uses your expense history to generate insights.',
              'Avoid sharing credentials or OTPs with anyone.',
              'Contact support for account privacy/data requests.',
            ],
          ),
          const SizedBox(height: 14),
          _infoCard(
            title: 'Legal & Contact',
            points: const [
              'Terms and policy documents are managed by the RoomEase team.',
              'Support: support@roomease.app',
            ],
            footer: Align(
              alignment: Alignment.centerLeft,
              child: TextButton.icon(
                onPressed: () {
                  Clipboard.setData(
                    const ClipboardData(text: 'support@roomease.app'),
                  );
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Support email copied')),
                  );
                },
                icon: const Icon(Icons.copy, size: 16),
                label: const Text('Copy Support Email'),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _infoCard({
    required String title,
    required List<String> points,
    Widget? footer,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFEEEEF2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 10),
          ...points.map(
            (point) => Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Padding(
                    padding: EdgeInsets.only(top: 4),
                    child: Icon(Icons.circle, size: 7, color: Color(0xFF6B6B80)),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      point,
                      style: const TextStyle(height: 1.4),
                    ),
                  ),
                ],
              ),
            ),
          ),
          if (footer != null) ...[
            const SizedBox(height: 4),
            footer,
          ],
        ],
      ),
    );
  }
}
