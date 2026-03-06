import 'package:flutter/material.dart';
import '../../../services/firebase_auth_service.dart';
import '../../../services/api_service.dart';
import '../../../core/widgets/mobile_scaffold.dart';

/// Profile screen — displays and allows editing of the user's profile data.
class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final FirebaseAuthService _authService = FirebaseAuthService();
  final ApiService _apiService = ApiService();

  String _userName = 'Loading...';
  String _userEmail = 'Loading...';
  String? _userPhone;
  bool _isLoading = true;
  bool _isEditing = false;
  bool _isSaving = false;

  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadUserData();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  Future<void> _loadUserData() async {
    try {
      final user = _authService.currentUser;
      if (user != null) {
        setState(() {
          _userName = user.displayName ?? 'User';
          _userEmail = user.email ?? 'No email';
        });

        // Try to get backend profile data (name override, phone)
        try {
          final response = await _apiService.getUserProfile();
          if (response['success'] == true && response['data'] != null) {
            final data = response['data'] as Map<String, dynamic>;
            setState(() {
              _userName = data['name'] as String? ?? _userName;
              _userPhone = data['phone'] as String?;
            });
          }
        } catch (_) {}

        _nameController.text = _userName;
        _phoneController.text = _userPhone ?? '';
      }
    } catch (_) {
      setState(() => _userName = 'Error loading data');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _saveProfile() async {
    setState(() => _isSaving = true);
    try {
      await _apiService.updateUserProfile(
        name: _nameController.text.trim(),
        phone: _phoneController.text.trim().isEmpty
            ? null
            : _phoneController.text.trim(),
      );

      setState(() {
        _userName = _nameController.text.trim();
        _userPhone = _phoneController.text.trim().isEmpty
            ? null
            : _phoneController.text.trim();
        _isEditing = false;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Profile updated successfully')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to update profile: $e')),
        );
      }
    } finally {
      setState(() => _isSaving = false);
    }
  }

  void _showLogoutDialog() {
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text(
          'Log Out',
          style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
        ),
        content: const Text(
          'Are you sure you want to sign out of your account?',
          style: TextStyle(fontSize: 14),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: Text('Cancel', style: TextStyle(color: Colors.grey.shade600)),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(dialogContext);
              try {
                try {
                  await _apiService.logout();
                } catch (_) {}
                await _authService.signOut();
                await _apiService.clearCookies();
              } catch (_) {}
              if (mounted) {
                Navigator.pushReplacementNamed(context, '/login');
              }
            },
            child: const Text(
              'Log Out',
              style: TextStyle(
                  color: Color(0xFFC62828), fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final primaryColor = Theme.of(context).colorScheme.primary;

    return MobileScaffold(
      currentIndex: 4,
      showAppBar: false,
      body: _isLoading
          ? Center(child: CircularProgressIndicator(color: primaryColor))
          : CustomScrollView(
              slivers: [
                // ── App Bar ──
                SliverAppBar(
                  backgroundColor: Colors.white,
                  elevation: 0,
                  pinned: true,
                  automaticallyImplyLeading: false,
                  title: const Text(
                    'Profile',
                    style: TextStyle(
                      color: Color(0xFF1A1A2E),
                      fontWeight: FontWeight.w700,
                      fontSize: 17,
                    ),
                  ),
                  bottom: PreferredSize(
                    preferredSize: const Size.fromHeight(1),
                    child: Container(color: const Color(0xFFF0F0F0), height: 1),
                  ),
                  actions: [
                    if (!_isEditing)
                      TextButton(
                        onPressed: () => setState(() => _isEditing = true),
                        child: Text(
                          'Edit',
                          style: TextStyle(
                              color: primaryColor, fontWeight: FontWeight.w600),
                        ),
                      ),
                  ],
                ),

                // ── Content ──
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      children: [
                        // Identity card (avatar + name + email)
                        _buildIdentityCard(),
                        const SizedBox(height: 16),

                        // Info / Edit section
                        if (_isEditing)
                          _buildEditForm(primaryColor)
                        else
                          _buildProfileInfo(),

                        const SizedBox(height: 16),

                        // Menu shortcuts
                        _buildMenu(),
                        const SizedBox(height: 16),

                        // Logout
                        _buildLogoutButton(),
                        const SizedBox(height: 40),
                      ],
                    ),
                  ),
                ),
              ],
            ),
    );
  }

  // ──────────────────────────────────────────
  // IDENTITY CARD
  // ──────────────────────────────────────────
  Widget _buildIdentityCard() {
    final initials = _userName.isNotEmpty ? _userName[0].toUpperCase() : '?';
    final primaryColor = Theme.of(context).colorScheme.primary;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFEEEEF2)),
      ),
      child: Row(
        children: [
          // Avatar
          CircleAvatar(
            radius: 32,
            backgroundColor: primaryColor.withValues(alpha: 0.1),
            backgroundImage: _authService.currentUser?.photoURL != null
                ? NetworkImage(_authService.currentUser!.photoURL!)
                : null,
            child: _authService.currentUser?.photoURL == null
                ? Text(
                    initials,
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.w700,
                      color: primaryColor,
                    ),
                  )
                : null,
          ),
          const SizedBox(width: 16),

          // Name + email
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _userName,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF1A1A2E),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  _userEmail,
                  style: TextStyle(fontSize: 12, color: Colors.grey.shade500),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ──────────────────────────────────────────
  // INFO ROWS (read-only)
  // ──────────────────────────────────────────
  Widget _buildProfileInfo() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFEEEEF2)),
      ),
      child: Column(
        children: [
          _infoRow('Name', _userName, Icons.person_outline_rounded),
          _divider(),
          _infoRow('Email', _userEmail, Icons.email_outlined),
          if (_userPhone != null && _userPhone!.isNotEmpty) ...[
            _divider(),
            _infoRow('Phone', _userPhone!, Icons.phone_outlined),
          ],
        ],
      ),
    );
  }

  Widget _infoRow(String label, String value, IconData icon) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Row(
        children: [
          Icon(icon, size: 18, color: Colors.grey.shade400),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label,
                    style: TextStyle(
                        fontSize: 10,
                        color: Colors.grey.shade500,
                        letterSpacing: 0.3)),
                const SizedBox(height: 2),
                Text(value,
                    style: const TextStyle(
                        fontSize: 14, fontWeight: FontWeight.w500)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _divider() =>
      Divider(height: 1, color: const Color(0xFFF0F0F0), indent: 48);

  // ──────────────────────────────────────────
  // EDIT FORM
  // ──────────────────────────────────────────
  Widget _buildEditForm(Color primaryColor) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFEEEEF2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Edit Profile',
            style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: Color(0xFF1A1A2E)),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _nameController,
            style: const TextStyle(fontSize: 14),
            decoration: InputDecoration(
              labelText: 'Full name',
              labelStyle: const TextStyle(fontSize: 13),
              prefixIcon: const Icon(Icons.person_outline_rounded, size: 18),
              border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10)),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _phoneController,
            keyboardType: TextInputType.phone,
            style: const TextStyle(fontSize: 14),
            decoration: InputDecoration(
              labelText: 'Phone (optional)',
              labelStyle: const TextStyle(fontSize: 13),
              prefixIcon: const Icon(Icons.phone_outlined, size: 18),
              border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10)),
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () {
                    _nameController.text = _userName;
                    _phoneController.text = _userPhone ?? '';
                    setState(() => _isEditing = false);
                  },
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10)),
                  ),
                  child: const Text('Cancel', style: TextStyle(fontSize: 13)),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton(
                  onPressed: _isSaving ? null : _saveProfile,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: primaryColor,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10)),
                  ),
                  child: _isSaving
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: Colors.white),
                        )
                      : const Text('Save', style: TextStyle(fontSize: 13)),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ──────────────────────────────────────────
  // MENU
  // ──────────────────────────────────────────
  Widget _buildMenu() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFEEEEF2)),
      ),
      child: Column(
        children: [
          _menuRow(
            icon: Icons.settings_outlined,
            title: 'Settings',
            onTap: () => Navigator.pushNamed(context, '/settings'),
          ),
          _divider(),
          _menuRow(
            icon: Icons.help_outline_rounded,
            title: 'Help & Support',
            onTap: () => ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Help & Support coming soon!')),
            ),
          ),
          _divider(),
          _menuRow(
            icon: Icons.info_outline_rounded,
            title: 'About RoomEase',
            onTap: () => ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('RoomEase v1.0.0')),
            ),
          ),
        ],
      ),
    );
  }

  Widget _menuRow({
    required IconData icon,
    required String title,
    required VoidCallback onTap,
  }) {
    return ListTile(
      onTap: onTap,
      leading: Icon(icon, size: 20, color: Colors.grey.shade600),
      title: Text(title,
          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500)),
      trailing: Icon(Icons.arrow_forward_ios_rounded,
          size: 14, color: Colors.grey.shade400),
      visualDensity: VisualDensity.compact,
    );
  }

  // ──────────────────────────────────────────
  // LOGOUT
  // ──────────────────────────────────────────
  Widget _buildLogoutButton() {
    return SizedBox(
      width: double.infinity,
      child: OutlinedButton(
        onPressed: _showLogoutDialog,
        style: OutlinedButton.styleFrom(
          padding: const EdgeInsets.symmetric(vertical: 14),
          side: const BorderSide(color: Color(0xFFEEEEF2)),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        ),
        child: const Text(
          'Log Out',
          style: TextStyle(
            color: Color(0xFFC62828),
            fontWeight: FontWeight.w600,
            fontSize: 14,
          ),
        ),
      ),
    );
  }
}
