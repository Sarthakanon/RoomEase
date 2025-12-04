import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../../services/api_service.dart';
import '../../../core/widgets/mobile_scaffold.dart';

class RoomspaceDetailsScreen extends StatefulWidget {
  const RoomspaceDetailsScreen({super.key});

  @override
  State<RoomspaceDetailsScreen> createState() => _RoomspaceDetailsScreenState();
}

class _RoomspaceDetailsScreenState extends State<RoomspaceDetailsScreen> {
  final ApiService _apiService = ApiService();
  bool _isLoading = true;
  Map<String, dynamic>? _roomspace;
  List<dynamic> _members = [];
  String? _error;
  String? _currentUserUid;
  bool _isCreator = false;

  @override
  void initState() {
    super.initState();
    _currentUserUid = FirebaseAuth.instance.currentUser?.uid;
    _loadRoomspaceDetails();
  }

  Future<void> _loadRoomspaceDetails() async {
    try {
      final response = await _apiService.getRoomspaces();
      if (response['success'] == true && response['data'] != null) {
        final roomspaces = response['data'] as List<dynamic>;
        if (roomspaces.isNotEmpty) {
          setState(() {
            _roomspace = roomspaces[0];
            _members = _roomspace?['members'] ?? [];
            _isCreator = _roomspace?['created_by'] == _currentUserUid;
            _isLoading = false;
          });
        } else {
          // No roomspace, redirect to selection
          if (mounted) {
            Navigator.pushReplacementNamed(context, '/roomspace-selection');
          }
        }
      }
    } catch (e) {
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  Future<void> _removeMember(
    String memberFirebaseUid,
    String memberName,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Remove Member'),
        content: Text(
          'Are you sure you want to remove $memberName from this roomspace?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('Cancel', style: TextStyle(color: Colors.grey[600])),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            child: const Text('Remove'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    setState(() => _isLoading = true);

    try {
      final roomspaceId = _roomspace?['id'];
      if (roomspaceId == null) throw Exception('Roomspace ID not found');

      await _apiService.removeMemberFromRoomspace(
        roomspaceId,
        memberFirebaseUid,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Member removed successfully'),
            backgroundColor: Colors.green,
          ),
        );
        _loadRoomspaceDetails(); // Refresh the list
      }
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Failed to remove member: ${e.toString().replaceFirst("Exception: ", "")}',
            ),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _copyInviteCode() {
    final code = _roomspace?['invite_code'] ?? '';
    if (code.isNotEmpty) {
      Clipboard.setData(ClipboardData(text: code));
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Invite code copied!'),
          backgroundColor: Colors.green,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final primaryColor = Theme.of(context).colorScheme.primary;

    return MobileScaffold(
      currentIndex: 1,
      body: _isLoading
          ? Center(child: CircularProgressIndicator(color: primaryColor))
          : _error != null
          ? _buildErrorState()
          : _buildContent(primaryColor),
    );
  }

  Widget _buildErrorState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline, size: 64, color: Colors.red[300]),
            const SizedBox(height: 16),
            Text(
              'Failed to load roomspace',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.grey[800],
              ),
            ),
            const SizedBox(height: 8),
            Text(
              _error ?? 'Unknown error',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey[600]),
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: () {
                setState(() {
                  _isLoading = true;
                  _error = null;
                });
                _loadRoomspaceDetails();
              },
              child: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildContent(Color primaryColor) {
    return CustomScrollView(
      slivers: [
        // Header
        SliverAppBar(
          backgroundColor: const Color(0xFFF8F9FA),
          elevation: 0,
          pinned: true,
          centerTitle: true,
          title: const Text(
            'My Roomspace',
            style: TextStyle(
              color: Colors.black87,
              fontWeight: FontWeight.bold,
            ),
          ),
          actions: [
            IconButton(
              icon: const Icon(Icons.settings_outlined),
              color: Colors.black87,
              onPressed: () => Navigator.pushNamed(context, '/settings'),
            ),
          ],
        ),

        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Roomspace Card
                _buildRoomspaceCard(primaryColor),
                const SizedBox(height: 24),

                // Invite Code Section
                _buildInviteCodeSection(primaryColor),
                const SizedBox(height: 24),

                // Members Section
                Text(
                  'Members (${_members.length})',
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                  ),
                ),
                const SizedBox(height: 12),
                _buildMembersList(primaryColor),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildRoomspaceCard(Color primaryColor) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [primaryColor, primaryColor.withValues(alpha: 0.8)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: primaryColor.withValues(alpha: 0.3),
            blurRadius: 15,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.home_rounded,
                  color: Colors.white,
                  size: 28,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _roomspace?['name'] ?? 'My Roomspace',
                      style: const TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    if (_roomspace?['description'] != null &&
                        _roomspace!['description'].toString().isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Text(
                          _roomspace!['description'],
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.white.withValues(alpha: 0.8),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              _buildStatItem(Icons.people, '${_members.length}', 'Members'),
              const SizedBox(width: 24),
              _buildStatItem(Icons.receipt_long, '0', 'Expenses'),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatItem(IconData icon, String value, String label) {
    return Row(
      children: [
        Icon(icon, color: Colors.white.withValues(alpha: 0.8), size: 18),
        const SizedBox(width: 6),
        Text(
          value,
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 16,
          ),
        ),
        const SizedBox(width: 4),
        Text(
          label,
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.8),
            fontSize: 14,
          ),
        ),
      ],
    );
  }

  Widget _buildInviteCodeSection(Color primaryColor) {
    final inviteCode = _roomspace?['invite_code'] ?? 'N/A';

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
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
              Icon(Icons.share_rounded, color: primaryColor, size: 20),
              const SizedBox(width: 8),
              const Text(
                'Invite Roommates',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            'Share this code with your roommates so they can join:',
            style: TextStyle(fontSize: 14, color: Colors.grey[600]),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 14,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.grey[100],
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    inviteCode,
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: primaryColor,
                      letterSpacing: 2,
                      fontFamily: 'monospace',
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              ElevatedButton.icon(
                onPressed: _copyInviteCode,
                icon: const Icon(Icons.copy, size: 18),
                label: const Text('Copy'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: primaryColor,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 14,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMembersList(Color primaryColor) {
    if (_members.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Center(
          child: Column(
            children: [
              Icon(Icons.people_outline, size: 48, color: Colors.grey[400]),
              const SizedBox(height: 12),
              Text('No members yet', style: TextStyle(color: Colors.grey[600])),
            ],
          ),
        ),
      );
    }

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ListView.separated(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        itemCount: _members.length,
        separatorBuilder: (_, __) =>
            Divider(height: 1, indent: 70, color: Colors.grey[100]),
        itemBuilder: (context, index) {
          final member = _members[index];
          final memberUid = member['firebase_uid'];
          final isCreator = memberUid == _roomspace?['created_by'];
          final isCurrentUser = memberUid == _currentUserUid;
          final user = member['user'];
          final memberName = user?['name'] ?? user?['email'] ?? 'Unknown';
          final displayName = isCurrentUser ? '$memberName (You)' : memberName;
          final memberInitial = memberName.isNotEmpty
              ? memberName[0].toUpperCase()
              : '?';

          return Container(
            decoration: isCurrentUser
                ? BoxDecoration(
                    color: primaryColor.withValues(alpha: 0.05),
                    border: Border(
                      left: BorderSide(color: primaryColor, width: 3),
                    ),
                  )
                : null,
            child: ListTile(
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 8,
              ),
              leading: CircleAvatar(
                backgroundColor: isCurrentUser
                    ? primaryColor
                    : primaryColor.withValues(alpha: 0.1),
                child: Text(
                  memberInitial,
                  style: TextStyle(
                    color: isCurrentUser ? Colors.white : primaryColor,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              title: Text(
                displayName,
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  color: isCurrentUser ? primaryColor : null,
                ),
              ),
              subtitle: Text(
                'Joined ${_formatDate(member['joined_at'])}',
                style: TextStyle(fontSize: 12, color: Colors.grey[500]),
              ),
              trailing: isCreator
                  ? Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.blue.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Text(
                        'Creator',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.blue,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    )
                  : _isCreator && !isCurrentUser
                  ? IconButton(
                      icon: const Icon(Icons.remove_circle_outline),
                      color: Colors.red[400],
                      onPressed: () => _removeMember(memberUid, memberName),
                      tooltip: 'Remove member',
                    )
                  : null,
            ),
          );
        },
      ),
    );
  }

  String _formatDate(String? dateStr) {
    if (dateStr == null) return 'Unknown';
    try {
      final date = DateTime.parse(dateStr);
      final now = DateTime.now();
      final diff = now.difference(date);

      if (diff.inDays == 0) return 'Today';
      if (diff.inDays == 1) return 'Yesterday';
      if (diff.inDays < 7) return '${diff.inDays} days ago';
      return '${date.day}/${date.month}/${date.year}';
    } catch (_) {
      return 'Unknown';
    }
  }
}
