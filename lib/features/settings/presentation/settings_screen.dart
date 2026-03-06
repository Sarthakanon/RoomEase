import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../../services/firebase_auth_service.dart';
import '../../../services/api_service.dart';
import '../../../providers/roomspace_provider.dart';
import '../../../models/roomspace_data.dart';
import '../../../core/widgets/skeleton_loader.dart';
import 'payment_notification_settings_screen.dart';

/// Settings screen — configuration for user profile, roomspaces, and app behavior.
class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  String _userName = "Loading...";
  String _userEmail = "Loading...";
  bool _notificationsEnabled = true;
  bool _isLoading = true;

  final FirebaseAuthService _authService = FirebaseAuthService();
  final ApiService _apiService = ApiService();

  @override
  void initState() {
    super.initState();
    _loadUserData();
  }

  Future<void> _loadUserData() async {
    try {
      final user = _authService.currentUser;
      if (user != null) {
        setState(() {
          _userName = user.displayName ?? "User";
          _userEmail = user.email ?? "No email";
        });

        // Load roomspaces through provider
        final roomspaceProvider = Provider.of<RoomspaceProvider>(context, listen: false);
        await roomspaceProvider.loadRoomspaces();

        setState(() => _isLoading = false);
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _userName = "Error loading data";
          _isLoading = false;
        });
      }
    }
  }

  void _copyInviteCode(String inviteCode) {
    Clipboard.setData(ClipboardData(text: inviteCode));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Invite code copied to clipboard!')),
    );
  }

  void _showChangePasswordDialog() {
    final primaryColor = Theme.of(context).colorScheme.primary;
    bool obscureCurrent = true;
    bool obscureNew = true;
    bool obscureConfirm = true;

    final currentController = TextEditingController();
    final newController = TextEditingController();
    final confirmController = TextEditingController();

    showDialog(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Text('Change Password', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _buildDialogInput(
                  controller: currentController,
                  hint: 'Current Password',
                  obscure: obscureCurrent,
                  onToggle: () => setState(() => obscureCurrent = !obscureCurrent),
                ),
                const SizedBox(height: 12),
                _buildDialogInput(
                  controller: newController,
                  hint: 'New Password',
                  obscure: obscureNew,
                  onToggle: () => setState(() => obscureNew = !obscureNew),
                ),
                const SizedBox(height: 12),
                _buildDialogInput(
                  controller: confirmController,
                  hint: 'Confirm New Password',
                  obscure: obscureConfirm,
                  onToggle: () => setState(() => obscureConfirm = !obscureConfirm),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: Text('Cancel', style: TextStyle(color: Colors.grey.shade600)),
            ),
            TextButton(
              onPressed: () async {
                if (newController.text != confirmController.text) {
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Passwords do not match')));
                  return;
                }
                try {
                  Navigator.pop(dialogContext);
                  await _authService.changePassword(
                    currentPassword: currentController.text,
                    newPassword: newController.text,
                  );
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Password updated successfully')));
                  }
                } catch (e) {
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString())));
                  }
                }
              },
              child: Text('Update', style: TextStyle(color: primaryColor, fontWeight: FontWeight.w600)),
            ),
          ],
        ),
      ),
    );
  }

  void _showLogoutDialog() {
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Log Out', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
        content: const Text('Are you sure you want to sign out?', style: TextStyle(fontSize: 14)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: Text('Cancel', style: TextStyle(color: Colors.grey.shade600)),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(dialogContext);
              try {
                await _apiService.logout();
                await _authService.signOut();
                await _apiService.clearCookies();
              } catch (_) {}
              if (mounted) Navigator.pushReplacementNamed(context, '/login');
            },
            child: const Text('Log Out', style: TextStyle(color: Color(0xFFC62828), fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
  }

  void _leaveRoomspace(RoomspaceData roomspace) {
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Leave Room', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
        content: Text('Are you sure you want to leave "${roomspace.name}"?', style: const TextStyle(fontSize: 14)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: Text('Cancel', style: TextStyle(color: Colors.grey.shade600)),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(dialogContext);
              try {
                final roomspaceProvider = Provider.of<RoomspaceProvider>(context, listen: false);
                await roomspaceProvider.leaveRoomspace(roomspace.id);
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Left "${roomspace.name}"')));
                  if (roomspaceProvider.roomspaceCount == 0) {
                    Navigator.pushReplacementNamed(context, '/roomspace-selection');
                  }
                }
              } catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed: $e')));
                }
              }
            },
            child: const Text('Leave', style: TextStyle(color: Colors.orange, fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final primaryColor = Theme.of(context).colorScheme.primary;

    return Consumer<RoomspaceProvider>(
      builder: (context, roomspaceProvider, child) {
        return Scaffold(
          backgroundColor: Colors.white,
          appBar: AppBar(
            backgroundColor: Colors.white,
            elevation: 0,
            title: const Text(
              'Settings',
              style: TextStyle(color: Color(0xFF1A1A2E), fontWeight: FontWeight.w700, fontSize: 17),
            ),
            centerTitle: true,
            leading: IconButton(
              icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Color(0xFF1A1A2E), size: 20),
              onPressed: () => Navigator.pop(context),
            ),
            bottom: PreferredSize(
              preferredSize: const Size.fromHeight(1),
              child: Container(color: const Color(0xFFF0F0F0), height: 1),
            ),
          ),
          body: _isLoading || roomspaceProvider.isLoading
              ? Center(child: CircularProgressIndicator(color: primaryColor))
              : ListView(
                  padding: const EdgeInsets.all(20),
                  children: [
                    _buildProfileHeader(primaryColor),
                    const SizedBox(height: 24),
                    _buildSectionTitle('ROOM MANAGEMENT'),
                    const SizedBox(height: 12),
                    if (roomspaceProvider.roomspaces.isEmpty)
                      _buildNoRoomCard(primaryColor)
                    else
                      _buildRoomSelectorPanel(roomspaceProvider, primaryColor),
                    const SizedBox(height: 12),
                    _buildJoinButton(roomspaceProvider, primaryColor),
                    const SizedBox(height: 24),
                    _buildSectionTitle('ACCOUNT & APP'),
                    const SizedBox(height: 12),
                    _buildSettingsList(primaryColor),
                    const SizedBox(height: 32),
                    _buildLogoutAction(),
                    const SizedBox(height: 40),
                  ],
                ),
        );
      },
    );
  }

  Widget _buildSectionTitle(String title) {
    return Text(
      title,
      style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Colors.grey.shade500, letterSpacing: 0.8),
    );
  }

  Widget _buildProfileHeader(Color primaryColor) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFF7F7FB),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFEEEEF2)),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 28,
            backgroundColor: primaryColor.withValues(alpha: 0.1),
            backgroundImage: _authService.currentUser?.photoURL != null
                ? NetworkImage(_authService.currentUser!.photoURL!)
                : null,
            child: _authService.currentUser?.photoURL == null
                ? Text(_userName.isNotEmpty ? _userName[0].toUpperCase() : '?',
                    style: TextStyle(color: primaryColor, fontWeight: FontWeight.w700))
                : null,
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(_userName, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15, color: Color(0xFF1A1A2E))),
                Text(_userEmail, style: TextStyle(fontSize: 12, color: Colors.grey.shade500)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRoomSelectorPanel(RoomspaceProvider provider, Color primaryColor) {
    final active = provider.activeRoomspace;
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFEEEEF2)),
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.home_work_outlined, size: 16, color: Colors.grey.shade600),
                    const SizedBox(width: 8),
                    const Expanded(child: Text('Active Roomspace', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600))),
                    Text('${provider.roomspaceCount}/5', style: TextStyle(fontSize: 11, color: Colors.grey.shade400)),
                  ],
                ),
                const SizedBox(height: 12),
                _buildDropdown(provider, primaryColor),
              ],
            ),
          ),
          _divider(),
          IntrinsicHeight(
            child: Row(
              children: [
                Expanded(
                  child: _quickActionButton(
                    icon: Icons.copy_rounded,
                    label: 'Invite Code',
                    onTap: active != null ? () => _copyInviteCode(active.inviteCode) : null,
                    color: primaryColor,
                  ),
                ),
                VerticalDivider(width: 1, color: const Color(0xFFF0F0F0), indent: 12, endIndent: 12),
                Expanded(
                  child: _quickActionButton(
                    icon: Icons.exit_to_app_rounded,
                    label: 'Leave Room',
                    onTap: active != null ? () => _leaveRoomspace(active) : null,
                    color: Colors.orange.shade700,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDropdown(RoomspaceProvider provider, Color primaryColor) {
    return DropdownButtonFormField<String>(
      value: provider.activeRoomspace?.id,
      decoration: InputDecoration(
        filled: true,
        fillColor: const Color(0xFFF7F7FB),
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
      ),
      icon: Icon(Icons.keyboard_arrow_down_rounded, color: Colors.grey.shade400),
      items: provider.roomspaces.map((r) {
        return DropdownMenuItem(
          value: r.id,
          child: Text(r.name, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500)),
        );
      }).toList(),
      onChanged: (val) {
        if (val != null) provider.setActiveRoomspace(val);
      },
    );
  }

  Widget _quickActionButton({required IconData icon, required String label, required VoidCallback? onTap, required Color color}) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 16, color: color),
            const SizedBox(width: 8),
            Text(label, style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.w600)),
          ],
        ),
      ),
    );
  }

  Widget _buildJoinButton(RoomspaceProvider provider, Color primaryColor) {
    final canJoin = provider.canJoinMore;
    return SizedBox(
      width: double.infinity,
      child: OutlinedButton.icon(
        onPressed: canJoin ? () => Navigator.pushNamed(context, '/join-roomspace') : null,
        icon: Icon(Icons.add_rounded, size: 20, color: canJoin ? primaryColor : Colors.grey.shade400),
        label: Text(canJoin ? "Join Another Room" : "Limit Reached (5/5)", 
            style: TextStyle(color: canJoin ? primaryColor : Colors.grey.shade400, fontSize: 13, fontWeight: FontWeight.w600)),
        style: OutlinedButton.styleFrom(
          padding: const EdgeInsets.symmetric(vertical: 14),
          side: BorderSide(color: canJoin ? primaryColor.withValues(alpha: 0.2) : const Color(0xFFEEEEF2)),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        ),
      ),
    );
  }

  Widget _buildSettingsList(Color primaryColor) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFEEEEF2)),
      ),
      child: Column(
        children: [
          _switchTile(
            icon: Icons.notifications_none_rounded,
            title: 'Push Notifications',
            value: _notificationsEnabled,
            onChanged: (val) => setState(() => _notificationsEnabled = val),
            color: primaryColor,
          ),
          _divider(),
          _menuItem(
            icon: Icons.lock_outline_rounded,
            title: 'Change Password',
            onTap: _showChangePasswordDialog,
          ),
          _divider(),
          _menuItem(
            icon: Icons.payments_outlined,
            title: 'Payment Detection',
            subtitle: 'Auto-detect logic',
            onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const PaymentNotificationSettingsScreen())),
          ),
        ],
      ),
    );
  }

  Widget _switchTile({required IconData icon, required String title, required bool value, required ValueChanged<bool> onChanged, required Color color}) {
    return SwitchListTile.adaptive(
      value: value,
      onChanged: onChanged,
      activeColor: color,
      secondary: Icon(icon, size: 20, color: Colors.grey.shade600),
      title: Text(title, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500)),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16),
      visualDensity: VisualDensity.compact,
    );
  }

  Widget _menuItem({required IconData icon, required String title, String? subtitle, required VoidCallback onTap}) {
    return ListTile(
      onTap: onTap,
      leading: Icon(icon, size: 20, color: Colors.grey.shade600),
      title: Text(title, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500)),
      subtitle: subtitle != null ? Text(subtitle, style: TextStyle(fontSize: 11, color: Colors.grey.shade400)) : null,
      trailing: Icon(Icons.arrow_forward_ios_rounded, size: 14, color: Colors.grey.shade400),
      visualDensity: VisualDensity.compact,
    );
  }

  Widget _buildLogoutAction() {
    return SizedBox(
      width: double.infinity,
      child: TextButton(
        onPressed: _showLogoutDialog,
        style: TextButton.styleFrom(
          padding: const EdgeInsets.symmetric(vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
            side: const BorderSide(color: Color(0xFFEEEEF2)),
          ),
        ),
        child: const Text('Log Out', style: TextStyle(color: Color(0xFFC62828), fontWeight: FontWeight.w700, fontSize: 14)),
      ),
    );
  }

  Widget _buildNoRoomCard(Color primaryColor) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(color: const Color(0xFFF7F7FB), borderRadius: BorderRadius.circular(14), border: Border.all(color: const Color(0xFFEEEEF2))),
      child: Column(
        children: [
          Icon(Icons.maps_home_work_outlined, size: 32, color: Colors.grey.shade400),
          const SizedBox(height: 12),
          const Text("No Active Roomspace", style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: Color(0xFF1A1A2E))),
          const SizedBox(height: 12),
          ElevatedButton(
            onPressed: () => Navigator.pushReplacementNamed(context, '/roomspace-selection'),
            style: ElevatedButton.styleFrom(backgroundColor: primaryColor, foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
            child: const Text("Create or Join", style: TextStyle(fontSize: 13)),
          ),
        ],
      ),
    );
  }

  Widget _divider() => Divider(height: 1, color: const Color(0xFFF0F0F0), indent: 56);

  Widget _buildDialogInput({required TextEditingController controller, required String hint, required bool obscure, required VoidCallback onToggle}) {
    return TextField(
      controller: controller,
      obscureText: obscure,
      style: const TextStyle(fontSize: 14),
      decoration: InputDecoration(
        labelText: hint,
        labelStyle: const TextStyle(fontSize: 13),
        filled: true,
        fillColor: const Color(0xFFF7F7FB),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
        suffixIcon: IconButton(icon: Icon(obscure ? Icons.visibility_off_outlined : Icons.visibility_outlined, size: 18), onPressed: onToggle),
      ),
    );
  }
}
