import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../../services/firebase_auth_service.dart';
import '../../../services/api_service.dart';
import '../../../providers/roomspace_provider.dart';
import '../../../models/roomspace_data.dart';
import '../../../core/widgets/skeleton_loader.dart';
import 'payment_notification_settings_screen.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  // ---------------------------------------------------
  // Variables & Controllers
  // ---------------------------------------------------
  String _userName = "Loading...";
  String _userEmail = "Loading...";

  bool _notificationsEnabled = true;
  bool _isLoading = true;

  final FirebaseAuthService _authService = FirebaseAuthService();
  final ApiService _apiService = ApiService();

  // ---------------------------------------------------
  // Lifecycle & Data Loading
  // ---------------------------------------------------
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
      setState(() {
        _userName = "Error loading data";
        _isLoading = false;
      });
    }
  }

  // ---------------------------------------------------
  // Actions
  // ---------------------------------------------------

  void _copyInviteCode(String inviteCode) {
    Clipboard.setData(ClipboardData(text: inviteCode));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text('Invite code copied to clipboard!'),
        backgroundColor: Colors.green,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
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
        builder: (context, setState) => Dialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          backgroundColor: Colors.white,
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Change Password',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 20),

                  _buildDialogInput(
                    controller: currentController,
                    hint: 'Current Password',
                    obscure: obscureCurrent,
                    onToggle: () =>
                        setState(() => obscureCurrent = !obscureCurrent),
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
                    onToggle: () =>
                        setState(() => obscureConfirm = !obscureConfirm),
                  ),

                  const SizedBox(height: 24),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      TextButton(
                        onPressed: () => Navigator.pop(context),
                        child: Text(
                          'Cancel',
                          style: TextStyle(color: Colors.grey[600]),
                        ),
                      ),
                      const SizedBox(width: 8),
                      ElevatedButton(
                        onPressed: () async {
                          if (newController.text != confirmController.text) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Passwords do not match'),
                                backgroundColor: Colors.red,
                              ),
                            );
                            return;
                          }
                          try {
                            Navigator.pop(context);
                            await _authService.changePassword(
                              currentPassword: currentController.text,
                              newPassword: newController.text,
                            );
                            if (mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text(
                                    'Password changed successfully',
                                  ),
                                  backgroundColor: Colors.green,
                                ),
                              );
                            }
                          } catch (e) {
                            if (mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(e.toString()),
                                  backgroundColor: Colors.red,
                                ),
                              );
                            }
                          }
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: primaryColor,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 20,
                            vertical: 10,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                        child: const Text(
                          'Update',
                          style: TextStyle(color: Colors.white),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _showLogoutDialog() {
    final navigator = Navigator.of(context);
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text(
          'Log Out',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        content: const Text(
          'Are you sure you want to sign out of your account?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: Text('Cancel', style: TextStyle(color: Colors.grey[600])),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(dialogContext);
              try {
                try {
                  await _apiService.logout();
                } catch (_) {}
                await _authService.signOut();
                await _apiService.clearCookies();
              } catch (_) {}
              navigator.pushReplacementNamed('/login');
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            child: const Text('Log Out', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  void _leaveRoomspace(RoomspaceData roomspace) {
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text(
          'Leave Room',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        content: Text('Are you sure you want to leave "${roomspace.name}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: Text('Cancel', style: TextStyle(color: Colors.grey[600])),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(dialogContext);
              
              // Show loading indicator
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: const Text('Leaving roomspace...'),
                  duration: const Duration(seconds: 2),
                  backgroundColor: Colors.orange,
                ),
              );
              
              try {
                final roomspaceProvider = Provider.of<RoomspaceProvider>(context, listen: false);
                await roomspaceProvider.leaveRoomspace(roomspace.id);
                
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Left "${roomspace.name}" successfully'),
                      backgroundColor: Colors.green,
                      behavior: SnackBarBehavior.floating,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                  );
                  
                  // If no roomspaces left, navigate to roomspace selection
                  if (roomspaceProvider.roomspaceCount == 0) {
                    Navigator.pushReplacementNamed(context, '/roomspace-selection');
                  }
                }
              } catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Failed to leave roomspace: ${e.toString()}'),
                      backgroundColor: Colors.red,
                      behavior: SnackBarBehavior.floating,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                  );
                }
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.orange,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            child: const Text('Leave', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------
  // UI Code
  // ---------------------------------------------------
  @override
  Widget build(BuildContext context) {
    final primaryColor = Theme.of(context).colorScheme.primary;

    return Consumer<RoomspaceProvider>(
      builder: (context, roomspaceProvider, child) {
        return Scaffold(
          backgroundColor: const Color(0xFFF8F9FA),
          body: _isLoading || roomspaceProvider.isLoading
              ? Center(child: CircularProgressIndicator(color: primaryColor))
              : CustomScrollView(
                  slivers: [
                    // Custom Header
                    SliverAppBar(
                      backgroundColor: const Color(0xFFF8F9FA),
                      elevation: 0,
                      pinned: true,
                      centerTitle: true,
                      title: const Text(
                        'Settings',
                        style: TextStyle(
                          color: Colors.black87,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),

                    // Content
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 20,
                          vertical: 10,
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // 1. Profile Card
                            _buildProfileCard(),
                            const SizedBox(height: 24),

                            // 2. Roomspace Section
                            const Text(
                              "Room Management",
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                                color: Colors.grey,
                              ),
                            ),
                            const SizedBox(height: 10),
                            
                            // Roomspace Dropdown Selector
                            if (roomspaceProvider.isLoading)
                              const RoomspaceListSkeleton(itemCount: 1)
                            else if (roomspaceProvider.roomspaces.isEmpty)
                              _buildNoRoomCard()
                            else
                              _buildRoomspaceDropdown(roomspaceProvider),
                            
                            const SizedBox(height: 16),
                            
                            // Join Another Room button
                            _buildJoinAnotherRoomButton(roomspaceProvider),
                            
                            const SizedBox(height: 24),

                            // 3. General Settings
                            const Text(
                              "Account & App",
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                                color: Colors.grey,
                              ),
                            ),
                            const SizedBox(height: 10),
                            _buildSettingsContainer(),

                            const SizedBox(height: 30),

                            // 4. Logout Button
                            SizedBox(
                              width: double.infinity,
                              child: TextButton(
                                onPressed: _showLogoutDialog,
                                style: TextButton.styleFrom(
                                  padding: const EdgeInsets.symmetric(vertical: 16),
                                  backgroundColor: Colors.white,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(16),
                                    side: BorderSide(color: Colors.grey.shade200),
                                  ),
                                ),
                                child: const Text(
                                  "Log Out",
                                  style: TextStyle(
                                    color: Colors.red,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 16,
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(height: 40),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
        );
      },
    );
  }

  // --- Widget Builders ---

  Widget _buildProfileCard() {
    final primaryColor = Theme.of(context).colorScheme.primary;
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(3),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(
                color: primaryColor.withOpacity(0.2),
                width: 2,
              ),
            ),
            child: CircleAvatar(
              radius: 32,
              backgroundColor: primaryColor.withOpacity(0.1),
              backgroundImage: _authService.currentUser?.photoURL != null
                  ? NetworkImage(_authService.currentUser!.photoURL!)
                  : null,
              child: _authService.currentUser?.photoURL == null
                  ? Icon(Icons.person, size: 32, color: primaryColor)
                  : null,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _userName,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  _userEmail,
                  style: TextStyle(fontSize: 14, color: Colors.grey[500]),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// Build list of all roomspace cards
  List<Widget> _buildRoomspacesList(List<RoomspaceData> roomspaces) {
    return roomspaces.map((roomspace) => Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: _buildRoomspaceCard(roomspace),
    )).toList();
  }

  /// Build roomspace dropdown selector
  Widget _buildRoomspaceDropdown(RoomspaceProvider roomspaceProvider) {
    final primaryColor = Theme.of(context).colorScheme.primary;
    final activeRoomspace = roomspaceProvider.activeRoomspace;
    
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.home_work_rounded, color: primaryColor, size: 20),
              const SizedBox(width: 8),
              Text(
                'Active Roomspace',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: Colors.grey[600],
                ),
              ),
              const Spacer(),
              Text(
                '${roomspaceProvider.roomspaceCount}/5',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: Colors.grey[500],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(
            value: activeRoomspace?.id,
            decoration: InputDecoration(
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: Colors.grey[300]!),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: Colors.grey[300]!),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: primaryColor, width: 2),
              ),
            ),
            icon: Icon(Icons.arrow_drop_down, color: primaryColor),
            isExpanded: true,
            items: roomspaceProvider.roomspaces.map((roomspace) {
              return DropdownMenuItem<String>(
                value: roomspace.id,
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: roomspace.visualColor.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(
                        roomspace.visualIcon,
                        color: roomspace.visualColor,
                        size: 16,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        '${roomspace.name} (${roomspace.memberCount})',
                        style: const TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 14,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              );
            }).toList(),
            onChanged: (String? newRoomspaceId) async {
              if (newRoomspaceId != null && newRoomspaceId != activeRoomspace?.id) {
                try {
                  await roomspaceProvider.setActiveRoomspace(newRoomspaceId);
                  final newRoomspace = roomspaceProvider.getRoomspaceById(newRoomspaceId);
                  if (mounted && newRoomspace != null) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Switched to "${newRoomspace.name}"'),
                        backgroundColor: Colors.green,
                        behavior: SnackBarBehavior.floating,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                    );
                  }
                } catch (e) {
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Failed to switch roomspace'),
                        backgroundColor: Colors.red,
                      ),
                    );
                  }
                }
              }
            },
          ),
          const SizedBox(height: 12),
          // Quick actions row
          Row(
            children: [
              Expanded(
                child: TextButton.icon(
                  onPressed: activeRoomspace != null 
                      ? () => _copyInviteCode(activeRoomspace.inviteCode)
                      : null,
                  icon: Icon(Icons.copy_rounded, size: 16, color: primaryColor),
                  label: Text(
                    'Copy Code',
                    style: TextStyle(color: primaryColor, fontSize: 12),
                  ),
                  style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                  ),
                ),
              ),
              Container(width: 1, height: 20, color: Colors.grey[200]),
              Expanded(
                child: TextButton.icon(
                  onPressed: activeRoomspace != null 
                      ? () => _leaveRoomspace(activeRoomspace)
                      : null,
                  icon: const Icon(Icons.exit_to_app_rounded, size: 16, color: Colors.orange),
                  label: const Text(
                    'Leave',
                    style: TextStyle(color: Colors.orange, fontSize: 12),
                  ),
                  style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// Build a single roomspace card
  Widget _buildRoomspaceCard(RoomspaceData roomspace) {
    return Consumer<RoomspaceProvider>(
      builder: (context, roomspaceProvider, child) {
        final primaryColor = Theme.of(context).colorScheme.primary;
        final isActive = roomspaceProvider.getActiveRoomspaceId() == roomspace.id;
        
        return Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            border: isActive 
                ? Border.all(color: primaryColor, width: 2)
                : null,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.03),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            children: [
              Row(
                children: [
                  // Visual indicator (color + icon)
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: roomspace.visualColor.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      roomspace.visualIcon,
                      color: roomspace.visualColor,
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Flexible(
                              child: Text(
                                roomspace.name,
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                ),
                              ),
                            ),
                            if (isActive) ...[
                              const SizedBox(width: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(
                                  color: primaryColor,
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: const Text(
                                  'ACTIVE',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          "Invite Code: ${roomspace.inviteCode}",
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey[500],
                            fontFamily: 'monospace',
                            letterSpacing: 1,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          "${roomspace.memberCount} member${roomspace.memberCount != 1 ? 's' : ''}",
                          style: TextStyle(
                            fontSize: 11,
                            color: Colors.grey[400],
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    onPressed: () => _copyInviteCode(roomspace.inviteCode),
                    icon: Icon(Icons.copy_rounded, color: primaryColor, size: 20),
                    tooltip: 'Copy invite code',
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Divider(height: 1, color: Colors.grey[100]),
              const SizedBox(height: 12),
              Row(
                children: [
                  // Switch to this roomspace button
                  if (!isActive)
                    Expanded(
                      child: InkWell(
                        onTap: () async {
                          try {
                            await roomspaceProvider.setActiveRoomspace(roomspace.id);
                            if (mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text('Switched to "${roomspace.name}"'),
                                  backgroundColor: Colors.green,
                                  behavior: SnackBarBehavior.floating,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                ),
                              );
                            }
                          } catch (e) {
                            if (mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text('Failed to switch roomspace'),
                                  backgroundColor: Colors.red,
                                ),
                              );
                            }
                          }
                        },
                        child: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 4),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.swap_horiz_rounded,
                                color: primaryColor,
                                size: 18,
                              ),
                              const SizedBox(width: 8),
                              Text(
                                "Switch to this room",
                                style: TextStyle(
                                  color: primaryColor,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  if (!isActive) ...[
                    Container(
                      width: 1,
                      height: 20,
                      color: Colors.grey[200],
                    ),
                  ],
                  // Leave room button
                  Expanded(
                    child: InkWell(
                      onTap: () => _leaveRoomspace(roomspace),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 4),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: const [
                            Icon(
                              Icons.exit_to_app_rounded,
                              color: Colors.orange,
                              size: 18,
                            ),
                            SizedBox(width: 8),
                            Text(
                              "Leave Room",
                              style: TextStyle(
                                color: Colors.orange,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildNoRoomCard() {
    final primaryColor = Theme.of(context).colorScheme.primary;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        children: [
          Icon(
            Icons.maps_home_work_outlined,
            size: 40,
            color: Colors.grey[400],
          ),
          const SizedBox(height: 12),
          const Text(
            "No Active Roomspace",
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: Colors.black87,
            ),
          ),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: () =>
                Navigator.pushReplacementNamed(context, '/roomspace-selection'),
            style: ElevatedButton.styleFrom(
              backgroundColor: primaryColor,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
              elevation: 0,
            ),
            child: const Text(
              "Create or Join",
              style: TextStyle(color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }

  /// Build "Join Another Room" button
  Widget _buildJoinAnotherRoomButton(RoomspaceProvider provider) {
    final primaryColor = Theme.of(context).colorScheme.primary;
    final canJoin = provider.canJoinMore;
    
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton.icon(
        onPressed: canJoin
            ? () => Navigator.pushNamed(context, '/join-roomspace')
            : null,
        icon: Icon(
          Icons.add_home_rounded,
          color: canJoin ? Colors.white : Colors.grey[400],
        ),
        label: Text(
          canJoin ? "Join Another Room" : "Maximum Limit Reached (5/5)",
          style: TextStyle(
            color: canJoin ? Colors.white : Colors.grey[400],
            fontWeight: FontWeight.w600,
          ),
        ),
        style: ElevatedButton.styleFrom(
          backgroundColor: canJoin ? primaryColor : Colors.grey[200],
          padding: const EdgeInsets.symmetric(vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          elevation: canJoin ? 2 : 0,
        ),
      ),
    );
  }

  Widget _buildSettingsContainer() {
    final primaryColor = Theme.of(context).colorScheme.primary;
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          // Push Notifications
          SwitchListTile(
            value: _notificationsEnabled,
            activeColor: primaryColor,
            onChanged: (val) => setState(() => _notificationsEnabled = val),
            title: const Text(
              "Push Notifications",
              style: TextStyle(fontWeight: FontWeight.w600),
            ),
            secondary: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.grey[100],
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(
                Icons.notifications_outlined,
                color: Colors.black87,
                size: 20,
              ),
            ),
          ),
          Divider(height: 1, indent: 60, color: Colors.grey[100]),

          // Change Password
          ListTile(
            onTap: _showChangePasswordDialog,
            title: const Text(
              "Change Password",
              style: TextStyle(fontWeight: FontWeight.w600),
            ),
            leading: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.grey[100],
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(Icons.lock_outline, color: Colors.black87, size: 20),
            ),
            trailing: Icon(
              Icons.arrow_forward_ios_rounded,
              size: 16,
              color: Colors.grey[400],
            ),
          ),
          Divider(height: 1, indent: 60, color: Colors.grey[100]),

          // Payment Notifications
          ListTile(
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const PaymentNotificationSettingsScreen(),
                ),
              );
            },
            title: const Text(
              "Payment Detection",
              style: TextStyle(fontWeight: FontWeight.w600),
            ),
            subtitle: const Text(
              "Auto-detect payments for expenses",
              style: TextStyle(fontSize: 12, color: Colors.grey),
            ),
            leading: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.grey[100],
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(Icons.payment, color: Colors.black87, size: 20),
            ),
            trailing: Icon(
              Icons.arrow_forward_ios_rounded,
              size: 16,
              color: Colors.grey[400],
            ),
          ),
          Divider(height: 1, indent: 60, color: Colors.grey[100]),

          // Help
          ListTile(
            onTap: () {},
            title: const Text(
              "Help & Support",
              style: TextStyle(fontWeight: FontWeight.w600),
            ),
            leading: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.grey[100],
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(Icons.help_outline, color: Colors.black87, size: 20),
            ),
            trailing: Icon(
              Icons.arrow_forward_ios_rounded,
              size: 16,
              color: Colors.grey[400],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDialogInput({
    required TextEditingController controller,
    required String hint,
    required bool obscure,
    required VoidCallback onToggle,
  }) {
    return TextField(
      controller: controller,
      obscureText: obscure,
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: TextStyle(color: Colors.grey[400], fontSize: 14),
        filled: true,
        fillColor: const Color(0xFFF3F4F6),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 14,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        suffixIcon: IconButton(
          icon: Icon(
            obscure ? Icons.visibility_outlined : Icons.visibility_off_outlined,
            color: Colors.grey[500],
            size: 20,
          ),
          onPressed: onToggle,
        ),
      ),
    );
  }
}
