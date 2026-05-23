import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import '../../../services/firebase_auth_service.dart';
import '../../../services/smart_api_service.dart';
import '../../../services/state_management_service.dart';
import '../../../services/cloudinary_service.dart';
import '../../../services/real_time_data_service.dart';
import '../../../core/widgets/mobile_scaffold.dart';
import '../../subscription/presentation/widgets/subscription_status_card.dart';
import 'help_support_screen.dart';
import 'about_roomease_screen.dart';

/// Profile screen — displays and allows editing of the user's profile data.
class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> 
    with AutomaticKeepAliveClientMixin {
  final FirebaseAuthService _authService = FirebaseAuthService();
  final SmartApiService _smartApi = SmartApiService();
  final StateManagementService _state = StateManagementService();
  final CloudinaryService _cloudinaryService = CloudinaryService();
  final RealTimeDataService _realTimeService = RealTimeDataService();
  final ImagePicker _imagePicker = ImagePicker();

  @override
  bool get wantKeepAlive => true; // Keep state alive when switching tabs

  // Cache profile data to prevent reloading
  Map<String, dynamic>? _cachedProfileData;
  DateTime? _lastDataLoad;
  static const Duration _cacheValidDuration = Duration(minutes: 10);

  bool _isEditing = false;
  bool _isSaving = false;
  bool _isUploadingQr = false;
  bool _isUploadingProfilePhoto = false;
  String? _qrImageUrl;

  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  /// Smart data loader for profile with caching
  Future<Map<String, dynamic>> _loadProfileData({bool forceRefresh = false}) async {
    // Return cached data if valid and not forcing refresh
    if (!forceRefresh && 
        _cachedProfileData != null && 
        _lastDataLoad != null &&
        DateTime.now().difference(_lastDataLoad!) < _cacheValidDuration) {
      debugPrint('🚀 Using cached profile data');
      return Future.value(_cachedProfileData!); // Return as completed Future
    }

    debugPrint('🌐 Loading fresh profile data...');
    try {
      final user = _authService.currentUser;
      if (user == null) {
        throw Exception('No user logged in');
      }

      // Start with Firebase user data
      String userName = user.displayName ?? 'User';
      String userEmail = user.email ?? 'No email';
      String? userPhone;

      // Try to get backend profile data (name override, phone)
      try {
        final response = await _smartApi.getUserProfile(forceRefresh: forceRefresh);
        if (response['success'] == true && response['data'] != null) {
          final data = response['data'] as Map<String, dynamic>;
          userName = data['name'] as String? ?? userName;
          userPhone = data['phone'] as String?;
          _qrImageUrl = data['qr_image_url'] as String?;
        }
      } catch (e) {
        debugPrint('Backend profile fetch failed, using Firebase data: $e');
      }

      final profileData = {
        'userName': userName,
        'userEmail': userEmail,
        'userPhone': userPhone,
        'qrImageUrl': _qrImageUrl,
        'photoURL': user.photoURL,
      };

      // Update controllers with loaded data
      _nameController.text = userName;
      _phoneController.text = userPhone ?? '';

      // Cache the data
      _cachedProfileData = profileData;
      _lastDataLoad = DateTime.now();
      debugPrint('💾 Profile data cached at $_lastDataLoad');

      return profileData;
    } catch (e) {
      debugPrint('Error loading profile data: $e');
      return {
        'error': e.toString(),
        'userName': 'Error loading data',
        'userEmail': 'Error loading data',
        'userPhone': null,
        'photoURL': null,
      };
    }
  }

  Future<void> _saveProfile() async {
    setState(() => _isSaving = true);
    try {
      final updatedName = _nameController.text.trim();
      final user = _authService.currentUser;
      final updateResponse = await _smartApi.updateUserProfile(
        name: updatedName,
        phone: _phoneController.text.trim().isEmpty
            ? null
            : _phoneController.text.trim(),
      );

      if (updatedName.isNotEmpty) {
        await user?.updateDisplayName(updatedName);
        await user?.reload();
      }

      // Clear cache to force refresh
      _cachedProfileData = null;
      _lastDataLoad = null;
      _state.forceRefresh(ScreenKeys.profile);
      _state.forceRefresh(ScreenKeys.dashboard);
      _realTimeService.notifyProfileUpdated();

      final responseData = updateResponse['data'] as Map<String, dynamic>?;
      final backendName = responseData?['name'] as String?;
      final backendPhone = responseData?['phone'] as String?;
      final refreshedUser = _authService.currentUser;
      _cachedProfileData = {
        'userName': backendName ?? updatedName,
        'userEmail': refreshedUser?.email ?? 'No email',
        'userPhone': backendPhone ?? (_phoneController.text.trim().isEmpty ? null : _phoneController.text.trim()),
        'qrImageUrl': _qrImageUrl,
        'photoURL': refreshedUser?.photoURL,
      };
      _lastDataLoad = DateTime.now();

      setState(() {
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

  Future<void> _uploadQrImage() async {
    try {
      final pickedFile = await _imagePicker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 85,
      );
      if (pickedFile == null || !mounted) return;

      setState(() => _isUploadingQr = true);
      final uploadedUrl = await _cloudinaryService.uploadQrImage(File(pickedFile.path));
      final updateRes = await _smartApi.updateUserProfile(qrImageUrl: uploadedUrl);
      final backendQrUrl =
          (updateRes['data'] as Map<String, dynamic>?)?['qr_image_url'] as String?;
      final finalQrUrl = (backendQrUrl != null && backendQrUrl.isNotEmpty)
          ? backendQrUrl
          : uploadedUrl;

      _qrImageUrl = finalQrUrl;
      _cachedProfileData = {
        'userName': _nameController.text.trim().isEmpty ? 'User' : _nameController.text.trim(),
        'userEmail': _authService.currentUser?.email ?? 'No email',
        'userPhone': _phoneController.text.trim().isEmpty ? null : _phoneController.text.trim(),
        'qrImageUrl': finalQrUrl,
        'photoURL': _authService.currentUser?.photoURL,
      };
      _lastDataLoad = DateTime.now();
      _state.forceRefresh(ScreenKeys.profile);
      _state.forceRefresh(ScreenKeys.expenses);
      _realTimeService.notifyProfileUpdated();

      if (!mounted) return;
      setState(() {});
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('QR updated successfully')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to upload QR: $e')),
      );
    } finally {
      if (mounted) {
        setState(() => _isUploadingQr = false);
      }
    }
  }

  Future<void> _uploadProfilePhoto() async {
    try {
      final pickedFile = await _imagePicker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 85,
      );
      if (pickedFile == null || !mounted) return;

      setState(() => _isUploadingProfilePhoto = true);
      final uploadedUrl = await _cloudinaryService.uploadQrImage(File(pickedFile.path));

      final user = _authService.currentUser;
      await user?.updatePhotoURL(uploadedUrl);
      await user?.reload();

      final refreshedUser = _authService.currentUser;
      _cachedProfileData = {
        'userName': _nameController.text.trim().isEmpty ? 'User' : _nameController.text.trim(),
        'userEmail': refreshedUser?.email ?? 'No email',
        'userPhone': _phoneController.text.trim().isEmpty ? null : _phoneController.text.trim(),
        'qrImageUrl': _qrImageUrl,
        'photoURL': refreshedUser?.photoURL ?? uploadedUrl,
      };
      _lastDataLoad = DateTime.now();
      _state.forceRefresh(ScreenKeys.profile);
      _realTimeService.notifyProfileUpdated();

      if (!mounted) return;
      setState(() {});
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Profile photo updated')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to update profile photo: $e')),
      );
    } finally {
      if (mounted) {
        setState(() => _isUploadingProfilePhoto = false);
      }
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
                  await _smartApi.logout();
                } catch (_) {}
                await _authService.signOut();
                await _smartApi.clearCookies();
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
    super.build(context); // Required for AutomaticKeepAliveClientMixin
    
    final primaryColor = Theme.of(context).colorScheme.primary;

    return MobileScaffold(
      currentIndex: 4,
      showAppBar: false,
      showBottomNav: false, // Hide bottom nav since MainNavigation handles it
      body: FutureBuilder<Map<String, dynamic>>(
        future: _loadProfileData(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return _buildErrorState(primaryColor);
          }
          
          if (snapshot.hasData) {
            return RefreshIndicator(
              onRefresh: () async {
                _cachedProfileData = null;
                _lastDataLoad = null;
                setState(() {}); // Trigger rebuild with fresh data
              },
              child: _buildProfileContent(context, snapshot.data!, primaryColor),
            );
          }
          
          return _buildLoadingSkeleton(primaryColor);
        },
      ),
    );
  }

  Widget _buildProfileContent(
    BuildContext context,
    Map<String, dynamic> profileData,
    Color primaryColor,
  ) {
    // Check for error
    final error = profileData['error'] as String?;
    if (error != null) {
      return _buildErrorState(primaryColor);
    }

    final userName = profileData['userName'] as String? ?? 'User';
    final userEmail = profileData['userEmail'] as String? ?? 'No email';
    final userPhone = profileData['userPhone'] as String?;
    final qrImageUrl = profileData['qrImageUrl'] as String?;
    final photoURL = profileData['photoURL'] as String?;

    return CustomScrollView(
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
              fontSize: 20,
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
                _buildIdentityCard(userName, userEmail, photoURL, primaryColor),
                const SizedBox(height: 16),

                // Subscription status card
                const SubscriptionStatusCard(),
                const SizedBox(height: 16),

                // Info / Edit section
                if (_isEditing)
                  _buildEditForm(primaryColor, userName, userPhone)
                else
                  _buildProfileInfo(userName, userEmail, userPhone),

                const SizedBox(height: 16),
                _buildQrSection(primaryColor, qrImageUrl),
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
    );
  }

  Widget _buildLoadingSkeleton(Color primaryColor) {
    return CustomScrollView(
      slivers: [
        // App Bar skeleton
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
              fontSize: 20,
            ),
          ),
          bottom: PreferredSize(
            preferredSize: const Size.fromHeight(1),
            child: Container(color: const Color(0xFFF0F0F0), height: 1),
          ),
        ),
        
        // Content skeleton
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              children: [
                // Identity card skeleton
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade200,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Row(
                    children: [
                      CircleAvatar(
                        radius: 32,
                        backgroundColor: Colors.grey.shade300,
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Container(
                              height: 16,
                              width: 120,
                              decoration: BoxDecoration(
                                color: Colors.grey.shade300,
                                borderRadius: BorderRadius.circular(8),
                              ),
                            ),
                            const SizedBox(height: 8),
                            Container(
                              height: 12,
                              width: 160,
                              decoration: BoxDecoration(
                                color: Colors.grey.shade300,
                                borderRadius: BorderRadius.circular(6),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                
                // Profile info skeleton
                Container(
                  height: 120,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade200,
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                const SizedBox(height: 16),
                
                // Menu skeleton
                Container(
                  height: 150,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade200,
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildErrorState(Color primaryColor) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.person_off_rounded, size: 48, color: Colors.grey.shade300),
            const SizedBox(height: 16),
            const Text(
              'Couldn\'t load profile',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: Color(0xFF1A1A2E),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Please try again',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey.shade500, fontSize: 13),
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: () {
                _cachedProfileData = null;
                _lastDataLoad = null;
                _state.forceRefresh(ScreenKeys.profile);
              },
              child: const Text('Try Again'),
            ),
          ],
        ),
      ),
    );
  }

  // ──────────────────────────────────────────
  // IDENTITY CARD
  // ──────────────────────────────────────────
  Widget _buildIdentityCard(String userName, String userEmail, String? photoURL, Color primaryColor) {
    final initials = userName.isNotEmpty ? userName[0].toUpperCase() : '?';

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
            backgroundImage: photoURL != null
                ? NetworkImage(photoURL)
                : null,
            child: photoURL == null
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
                  userName,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF1A1A2E),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  userEmail,
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
  Widget _buildProfileInfo(String userName, String userEmail, String? userPhone) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFEEEEF2)),
      ),
      child: Column(
        children: [
          _infoRow('Name', userName, Icons.person_outline_rounded),
          _divider(),
          _infoRow('Email', userEmail, Icons.email_outlined),
          if (userPhone != null && userPhone.isNotEmpty) ...[
            _divider(),
            _infoRow('Phone', userPhone, Icons.phone_outlined),
          ],
        ],
      ),
    );
  }

  Widget _buildQrSection(Color primaryColor, String? qrImageUrl) {
    final hasQr = qrImageUrl != null && qrImageUrl.isNotEmpty;
    return Container(
      width: double.infinity,
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
            'Your Payment QR',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: Color(0xFF1A1A2E),
            ),
          ),
          const SizedBox(height: 12),
          if (hasQr)
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Image.network(
                qrImageUrl,
                height: 180,
                width: 180,
                fit: BoxFit.cover,
              ),
            )
          else
            Text(
              'No QR uploaded yet',
              style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
            ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            height: 48,
            child: ElevatedButton.icon(
              onPressed: _isUploadingQr ? null : _uploadQrImage,
              icon: _isUploadingQr
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : Icon(hasQr ? Icons.edit_rounded : Icons.add_rounded, size: 18),
              label: Text(hasQr ? 'Change QR' : 'Add Your QR'),
              style: ElevatedButton.styleFrom(
                backgroundColor: primaryColor,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
            ),
          ),
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
  Widget _buildEditForm(Color primaryColor, String userName, String? userPhone) {
    final currentPhotoUrl = _authService.currentUser?.photoURL;
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
          Row(
            children: [
              CircleAvatar(
                radius: 28,
                backgroundColor: primaryColor.withValues(alpha: 0.1),
                backgroundImage: currentPhotoUrl != null && currentPhotoUrl.isNotEmpty
                    ? NetworkImage(currentPhotoUrl)
                    : null,
                child: (currentPhotoUrl == null || currentPhotoUrl.isEmpty)
                    ? Text(
                        (_nameController.text.isNotEmpty ? _nameController.text[0] : '?').toUpperCase(),
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w700,
                          color: primaryColor,
                        ),
                      )
                    : null,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _isUploadingProfilePhoto ? null : _uploadProfilePhoto,
                  icon: _isUploadingProfilePhoto
                      ? const SizedBox(
                          width: 14,
                          height: 14,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.image_outlined, size: 16),
                  label: const Text('Upload / Change Photo'),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
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
                    _nameController.text = userName;
                    _phoneController.text = userPhone ?? '';
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
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => const HelpSupportScreen(),
              ),
            ),
          ),
          _divider(),
          _menuRow(
            icon: Icons.info_outline_rounded,
            title: 'About RoomEase',
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => const AboutRoomEaseScreen(),
              ),
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
