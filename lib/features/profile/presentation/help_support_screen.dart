import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class HelpSupportScreen extends StatelessWidget {
  const HelpSupportScreen({super.key});

  static const String _supportEmail = 'support@roomease.app';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Help & Support'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _sectionCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Need help with RoomEase?',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 8),
                Text(
                  'Get support for account, roomspaces, expenses, payments, and analytics.',
                  style: TextStyle(color: Colors.grey.shade700),
                ),
                const SizedBox(height: 14),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () => _copyToClipboard(
                          context,
                          _supportEmail,
                          'Support email copied',
                        ),
                        icon: const Icon(Icons.email_outlined),
                        label: const Text('Copy Support Email'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          _sectionTitle('Quick Actions'),
          _sectionCard(
            child: Column(
              children: [
                _actionTile(
                  context,
                  icon: Icons.bug_report_outlined,
                  title: 'Report a Bug',
                  subtitle: 'Share issue details with our support team',
                  valueToCopy:
                      'Bug Report - RoomEase\n\nIssue:\nSteps to reproduce:\nExpected result:\nActual result:\nDevice/OS:\nApp version: 1.0.0+1',
                  message: 'Bug report template copied',
                ),
                const Divider(height: 1),
                _actionTile(
                  context,
                  icon: Icons.feedback_outlined,
                  title: 'Send Feedback',
                  subtitle: 'Help us improve your RoomEase experience',
                  valueToCopy:
                      'Feature Feedback - RoomEase\n\nWhat I want:\nWhy it helps:\nSuggested workflow:',
                  message: 'Feedback template copied',
                ),
                const Divider(height: 1),
                _actionTile(
                  context,
                  icon: Icons.privacy_tip_outlined,
                  title: 'Privacy & Data Request',
                  subtitle: 'Request account/data support assistance',
                  valueToCopy:
                      'Privacy/Data Request - RoomEase\n\nRequest type:\nAccount email:\nDetails:',
                  message: 'Privacy request template copied',
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          _sectionTitle('Frequently Asked Questions'),
          _sectionCard(
            child: Theme(
              data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
              child: ExpansionPanelList.radio(
                elevation: 0,
                expandedHeaderPadding: EdgeInsets.zero,
                children: [
                  ExpansionPanelRadio(
                    value: 'faq_1',
                    backgroundColor: Colors.white,
                    headerBuilder: _faqHeader('Why is my balance not updating?'),
                    body: _faqBody(
                      'Make sure all roommates are in the same roomspace and expenses are split correctly. '
                      'If you were offline, reconnect to trigger sync, then refresh the expenses screen.',
                    ),
                  ),
                  ExpansionPanelRadio(
                    value: 'faq_2',
                    backgroundColor: Colors.white,
                    headerBuilder: _faqHeader('Why are analytics empty?'),
                    body: _faqBody(
                      'Analytics needs enough recent expense history to detect trends. Add more personal/shared expenses '
                      'and ensure you are viewing the correct roomspace filter.',
                    ),
                  ),
                  ExpansionPanelRadio(
                    value: 'faq_3',
                    backgroundColor: Colors.white,
                    headerBuilder: _faqHeader('Can I use RoomEase for personal expenses only?'),
                    body: _faqBody(
                      'Yes. You can track personal expenses without roomspaces. Roomspace mode adds shared expense and settlement features.',
                    ),
                  ),
                  ExpansionPanelRadio(
                    value: 'faq_4',
                    backgroundColor: Colors.white,
                    headerBuilder: _faqHeader('How do I recover a deleted expense?'),
                    body: _faqBody(
                      'If deletion approval/recovery is enabled in your workflow, check recent actions or ask roomspace admins. '
                      'If data is permanently removed, contact support for guidance.',
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  static ExpansionPanelHeaderBuilder _faqHeader(String title) {
    return (_, __) => ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 8),
      title: Text(
        title,
        style: const TextStyle(fontSize: 14.5, fontWeight: FontWeight.w600),
      ),
    );
  }

  static Widget _faqBody(String text) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      child: Text(
        text,
        style: const TextStyle(height: 1.45),
      ),
    );
  }

  Widget _sectionCard({required Widget child}) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFEEEEF2)),
      ),
      padding: const EdgeInsets.all(14),
      child: child,
    );
  }

  Widget _sectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(
        title,
        style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
      ),
    );
  }

  Widget _actionTile(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String subtitle,
    required String valueToCopy,
    required String message,
  }) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: Icon(icon, size: 20),
      title: Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
      subtitle: Text(subtitle),
      trailing: const Icon(Icons.copy, size: 18),
      onTap: () => _copyToClipboard(context, valueToCopy, message),
    );
  }

  void _copyToClipboard(BuildContext context, String value, String message) {
    Clipboard.setData(ClipboardData(text: value));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }
}
