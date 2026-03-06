import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:provider/provider.dart';
import '../../../services/api_service.dart';
import '../../../core/widgets/mobile_scaffold.dart';
import '../../../core/widgets/global_roomspace_selector.dart';
import '../../../providers/roomspace_provider.dart';

/// Roomspace Details screen — view and manage members, share invite codes, and see room metadata.
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
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadDetails());
  }

  Future<void> _loadDetails() async {
    setState(() => _isLoading = true);
    try {
      final provider = Provider.of<RoomspaceProvider>(context, listen: false);
      final activeId = provider.getActiveRoomspaceId();
      if (activeId == null) {
        if (mounted) Navigator.pushReplacementNamed(context, '/roomspace-selection');
        return;
      }
      final res = await _apiService.getRoomspaces();
      if (res['success'] == true && res['data'] != null) {
        final list = res['data'] as List<dynamic>;
        final active = list.firstWhere((rs) => rs['id'] == activeId, orElse: () => list.isNotEmpty ? list[0] : null);
        if (active != null) {
          setState(() {
            _roomspace = active;
            _members = _roomspace?['members'] ?? [];
            _isCreator = _roomspace?['creator_id'] == _currentUserUid;
            _isLoading = false;
          });
        } else if (mounted) {
          Navigator.pushReplacementNamed(context, '/roomspace-selection');
        }
      }
    } catch (e) {
      setState(() { _error = e.toString(); _isLoading = false; });
    }
  }

  Future<void> _removeMember(String uid, String name) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Remove Member', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
        content: Text('Are you sure you want to remove $name?', style: const TextStyle(fontSize: 14)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: Text('Cancel', style: TextStyle(color: Colors.grey.shade600))),
          TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('Remove', style: TextStyle(color: Color(0xFFC62828), fontWeight: FontWeight.w700))),
        ],
      ),
    );
    if (confirmed != true) return;
    setState(() => _isLoading = true);
    try {
      await _apiService.removeMemberFromRoomspace(_roomspace?['id'], uid);
      _loadDetails();
    } catch (_) {
      setState(() => _isLoading = false);
    }
  }

  void _copyCode() {
    final code = _roomspace?['invite_code'] ?? '';
    if (code.isNotEmpty) {
      Clipboard.setData(ClipboardData(text: code));
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Invite code copied!')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final primaryColor = Theme.of(context).colorScheme.primary;

    return MobileScaffold(
      currentIndex: 1,
      showAppBar: false,
      body: _isLoading
          ? Center(child: CircularProgressIndicator(color: primaryColor))
          : _error != null
              ? _buildError()
              : _buildContent(primaryColor),
    );
  }

  Widget _buildError() {
    return Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
      const Icon(Icons.wifi_off_rounded, size: 48, color: Colors.grey),
      const SizedBox(height: 16),
      const Text('Something went wrong', style: TextStyle(fontWeight: FontWeight.w700)),
      TextButton(onPressed: _loadDetails, child: const Text('Try Again'))
    ]));
  }

  Widget _buildContent(Color primary) {
    return CustomScrollView(
      slivers: [
        SliverAppBar(
          backgroundColor: Colors.white,
          elevation: 0,
          pinned: true,
          centerTitle: true,
          title: const Text('Room Details', style: TextStyle(color: Color(0xFF1A1A2E), fontWeight: FontWeight.w700, fontSize: 17)),
          actions: [
            Padding(
              padding: const EdgeInsets.only(right: 12),
              child: GlobalRoomspaceSelector(onRoomspaceChanged: _loadDetails),
            ),
          ],
          bottom: PreferredSize(preferredSize: const Size.fromHeight(1), child: Container(color: const Color(0xFFF0F0F0), height: 1)),
        ),
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildInfoPanel(primary),
                const SizedBox(height: 24),
                _buildInviteSection(primary),
                const SizedBox(height: 32),
                _buildSectionTitle('RESIDENTS (${_members.length})'),
                const SizedBox(height: 12),
                _buildMemberPanel(primary),
                const SizedBox(height: 100),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildInfoPanel(Color primary) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(color: const Color(0xFFF7F7FB), borderRadius: BorderRadius.circular(16), border: Border.all(color: const Color(0xFFEEEEF2))),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(padding: const EdgeInsets.all(10), decoration: BoxDecoration(color: primary.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(10)), child: Icon(Icons.maps_home_work_outlined, color: primary, size: 24)),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(_roomspace?['name'] ?? 'My Room', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: Color(0xFF1A1A2E))),
                    Text(_roomspace?['description'] ?? 'Shared roomspace', style: TextStyle(fontSize: 12, color: Colors.grey.shade500)),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildInviteSection(Color primary) {
    final code = _roomspace?['invite_code'] ?? 'N/A';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionTitle('SHARE ACCESS'),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(14), border: Border.all(color: const Color(0xFFEEEEF2))),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Invite Code', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Colors.grey)),
                    Text(code, style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: primary, letterSpacing: 1)),
                  ],
                ),
              ),
              ElevatedButton.icon(
                onPressed: _copyCode,
                icon: const Icon(Icons.copy_rounded, size: 16),
                label: const Text('Copy'),
                style: ElevatedButton.styleFrom(backgroundColor: primary, foregroundColor: Colors.white, elevation: 0, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)), padding: const EdgeInsets.symmetric(horizontal: 16)),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildMemberPanel(Color primary) {
    return Container(
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), border: Border.all(color: const Color(0xFFEEEEF2))),
      child: ListView.separated(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        itemCount: _members.length,
        separatorBuilder: (_, __) => Divider(height: 1, color: const Color(0xFFF0F0F3), indent: 64),
        itemBuilder: (context, index) {
          final member = _members[index];
          final user = member['user'];
          final name = user?['name'] ?? user?['email'] ?? 'Unknown';
          final isMe = member['user_id'] == _currentUserUid;
          final isCreator = member['role'] == 'creator';

          return ListTile(
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            leading: CircleAvatar(
              radius: 18,
              backgroundColor: isMe ? primary : primary.withValues(alpha: 0.1),
              child: Text(name[0].toUpperCase(), style: TextStyle(color: isMe ? Colors.white : primary, fontWeight: FontWeight.w700, fontSize: 13)),
            ),
            title: Text(isMe ? '$name (You)' : name, style: TextStyle(fontSize: 14, fontWeight: isMe ? FontWeight.w700 : FontWeight.w500, color: const Color(0xFF1A1A2E))),
            subtitle: Text('Joined ${_formatDate(member['joined_at'])}', style: TextStyle(fontSize: 11, color: Colors.grey.shade400)),
            trailing: isCreator 
              ? Container(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4), decoration: BoxDecoration(color: Colors.blue.shade50, borderRadius: BorderRadius.circular(8)), child: Text('Host', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: Colors.blue.shade700)))
              : _isCreator && !isMe
                ? IconButton(icon: Icon(Icons.remove_circle_outline_rounded, size: 20, color: Colors.grey.shade400), onPressed: () => _removeMember(user?['firebase_uid'] ?? member['user_id'], name))
                : null,
          );
        },
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Text(title, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: Colors.grey.shade400, letterSpacing: 0.8));
  }

  String _formatDate(String? s) {
    if (s == null) return 'N/A';
    try {
      final d = DateTime.parse(s);
      final n = DateTime.now();
      if (n.difference(d).inDays == 0) return 'Today';
      if (n.difference(d).inDays == 1) return 'Yesterday';
      return '${d.day}/${d.month}/${d.year}';
    } catch (_) { return 'Recently'; }
  }
}
