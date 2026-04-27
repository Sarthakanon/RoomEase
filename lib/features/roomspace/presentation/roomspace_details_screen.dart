import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:provider/provider.dart';
import '../../../services/api_service.dart';
import '../../../core/widgets/mobile_scaffold.dart';
import '../../../core/widgets/global_roomspace_selector.dart';
import '../../../core/mixins/auto_refresh_mixin.dart';
import '../../../providers/roomspace_provider.dart';
import '../../subscription/providers/subscription_provider.dart';
import '../../subscription/utils/subscription_helper.dart';

/// Roomspace Details screen — view and manage members, share invite codes, and see room metadata.
class RoomspaceDetailsScreen extends StatefulWidget {
  const RoomspaceDetailsScreen({super.key});

  @override
  State<RoomspaceDetailsScreen> createState() => _RoomspaceDetailsScreenState();
}

class _RoomspaceDetailsScreenState extends State<RoomspaceDetailsScreen> with AutoRefreshMixin {
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
          
          // Debug information
          print('🔍 Debug Info:');
          print('   Current User UID: $_currentUserUid');
          print('   Creator ID: ${_roomspace?['creator_id']}');
          print('   Is Creator: $_isCreator');
          print('   Roomspace Data: ${_roomspace?.keys}');
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
    
    await performOperationWithRefresh(
      () async {
        await _apiService.removeMemberFromRoomspace(_roomspace?['id'], uid);
      },
      successMessage: 'Removed $name from the room',
      errorMessage: 'Failed to remove member',
    );
  }

  @override
  Future<void> refreshData() async {
    await _loadDetails();
  }

  void _copyCode() {
    final code = _roomspace?['invite_code'] ?? '';
    if (code.isNotEmpty) {
      Clipboard.setData(ClipboardData(text: code));
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Invite code copied!')));
    }
  }

  Future<void> _leaveRoomspace() async {
    final roomspaceName = _roomspace?['name'] ?? 'this room';
    final roomspaceId = _roomspace?['id'];
    final isCreatorLeaving = _isCreator;
    
    if (roomspaceId == null) return;
    
    // First, check if user has outstanding balances
    setState(() => _isLoading = true);
    try {
      final balanceResponse = await _apiService.getRoomspaceBalances(roomspaceId);
      
      // Check if user owes money to anyone
      List<Map<String, dynamic>> userDebts = [];
      if (balanceResponse['success'] == true && balanceResponse['data'] != null) {
        final balanceData = balanceResponse['data'] as Map<String, dynamic>;
        final userBalance = balanceData['user_balance'] as Map<String, dynamic>?;
        
        if (userBalance != null) {
          final youOwe = userBalance['you_owe'] as List<dynamic>? ?? [];
          
          for (var debt in youOwe) {
            final amount = debt['amount'] as num? ?? 0;
            if (amount > 0) {
              userDebts.add({
                'user_name': debt['user_name'] ?? 'Unknown User',
                'amount': amount,
              });
            }
          }
        }
      }
      
      setState(() => _isLoading = false);
      
      // If user has outstanding debts, show warning dialog
      if (userDebts.isNotEmpty) {
        final shouldProceed = await _showDebtWarningDialog(userDebts, roomspaceName);
        if (!shouldProceed) return;
      }
      
    } catch (e) {
      setState(() => _isLoading = false);
      print('Error checking balance: $e');
      // Continue with leave process even if balance check fails
    }
    
    // Show confirmation dialog
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Leave Room', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Are you sure you want to leave "$roomspaceName"?', 
              style: const TextStyle(fontSize: 14),
            ),
            if (isCreatorLeaving) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.orange.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.orange.shade200),
                ),
                child: Row(
                  children: [
                    Icon(Icons.info_outline, color: Colors.orange.shade700, size: 20),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'As the host, your role will be transferred to the oldest member.',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.orange.shade700,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('Cancel', style: TextStyle(color: Colors.grey.shade600)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(
              'Leave',
              style: TextStyle(
                color: Colors.orange.shade700, 
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    setState(() => _isLoading = true);
    try {
      final provider = Provider.of<RoomspaceProvider>(context, listen: false);
      await provider.leaveRoomspace(_roomspace?['id']);
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              isCreatorLeaving 
                  ? 'Left "$roomspaceName" and transferred host role'
                  : 'Left "$roomspaceName"'
            ),
          ),
        );
        // Navigate back to roomspace selection or main screen
        Navigator.pushReplacementNamed(context, '/roomspace-selection');
      }
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to leave room: ${e.toString()}')),
        );
      }
    }
  }

  Future<bool> _showDebtWarningDialog(List<Map<String, dynamic>> debts, String roomspaceName) async {
    final totalDebt = debts.fold<double>(0, (sum, debt) => sum + (debt['amount'] as num).toDouble());
    
    return await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: Colors.red.shade600, size: 24),
            const SizedBox(width: 8),
            const Text('Outstanding Balance', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'You cannot leave "$roomspaceName" because you have outstanding balances:',
              style: const TextStyle(fontSize: 14),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.red.shade50,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.red.shade200),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  ...debts.map((debt) => Padding(
                    padding: const EdgeInsets.only(bottom: 4),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Text(
                            'You owe ${debt['user_name']}:',
                            style: TextStyle(
                              fontSize: 13,
                              color: Colors.red.shade700,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                        Text(
                          '₹${(debt['amount'] as num).toStringAsFixed(2)}',
                          style: TextStyle(
                            fontSize: 13,
                            color: Colors.red.shade700,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  )).toList(),
                  if (debts.length > 1) ...[
                    const Divider(height: 16),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Total Amount:',
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.red.shade700,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        Text(
                          '₹${totalDebt.toStringAsFixed(2)}',
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.red.shade700,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'Please clear all outstanding balances before leaving the room.',
              style: TextStyle(
                fontSize: 13,
                color: Colors.grey.shade600,
                fontStyle: FontStyle.italic,
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(
              'Clear Balances First',
              style: TextStyle(
                color: Colors.blue.shade600,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(
              'Leave Anyway',
              style: TextStyle(
                color: Colors.red.shade600,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    ) ?? false;
  }

  @override
  Widget build(BuildContext context) {
    final primaryColor = Theme.of(context).colorScheme.primary;

    return MobileScaffold(
      currentIndex: 1,
      showAppBar: false,
      showBottomNav: false, // Hide bottom nav since MainNavigation handles it
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
          centerTitle: false,
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
    final screenWidth = MediaQuery.of(context).size.width;
    final isTablet = screenWidth > 600;
    
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(isTablet ? 24 : 20),
      decoration: BoxDecoration(color: const Color(0xFFF7F7FB), borderRadius: BorderRadius.circular(16), border: Border.all(color: const Color(0xFFEEEEF2))),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: EdgeInsets.all(isTablet ? 12 : 10), 
                decoration: BoxDecoration(color: primary.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(10)), 
                child: Icon(Icons.maps_home_work_outlined, color: primary, size: isTablet ? 28 : 24),
              ),
              SizedBox(width: isTablet ? 16 : 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _roomspace?['name'] ?? 'My Room', 
                      style: TextStyle(
                        fontSize: isTablet ? 20 : 18, 
                        fontWeight: FontWeight.w800, 
                        color: const Color(0xFF1A1A2E),
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                    Text(
                      _roomspace?['description'] ?? 'Shared roomspace', 
                      style: TextStyle(
                        fontSize: isTablet ? 14 : 12, 
                        color: Colors.grey.shade500,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              
              // Leave Room button - Show for everyone (including creators)
              SizedBox(width: isTablet ? 16 : 8),
              
              TextButton.icon(
                onPressed: () {
                  print('🚪 LEAVE BUTTON CLICKED!');
                  _leaveRoomspace();
                },
                icon: Icon(
                  Icons.exit_to_app_rounded, 
                  size: isTablet ? 18 : 16,
                  color: Colors.orange.shade700,
                ),
                label: Text(
                  'Leave',
                  style: TextStyle(
                    fontSize: isTablet ? 14 : 12,
                    fontWeight: FontWeight.w600,
                    color: Colors.orange.shade700,
                  ),
                ),
                style: TextButton.styleFrom(
                  padding: EdgeInsets.symmetric(
                    horizontal: isTablet ? 12 : 6, 
                    vertical: isTablet ? 8 : 4,
                  ),
                  minimumSize: Size(0, isTablet ? 36 : 28),
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
        _buildSectionTitle('ROOM ACTIONS'),
        const SizedBox(height: 12),
        // Create/Join Room Buttons
        Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: () => _handleCreateRoom(context),
                icon: Icon(Icons.add_home_work_rounded, size: 18, color: primary),
                label: Text("Create Room", 
                    style: TextStyle(color: primary, fontSize: 13, fontWeight: FontWeight.w600)),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  side: BorderSide(color: primary.withValues(alpha: 0.3)),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: OutlinedButton.icon(
                onPressed: () => _handleJoinRoom(context),
                icon: Icon(Icons.add_rounded, size: 18, color: primary),
                label: Text("Join Room", 
                    style: TextStyle(color: primary, fontSize: 13, fontWeight: FontWeight.w600)),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  side: BorderSide(color: primary.withValues(alpha: 0.3)),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 20),
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

  // Subscription-aware handlers
  Future<void> _handleCreateRoom(BuildContext context) async {
    final subscriptionProvider = context.read<SubscriptionProvider>();
    
    final canProceed = await SubscriptionHelper.checkAndHandleRoomspaceLimit(
      context,
      subscriptionProvider,
      action: 'create',
    );
    
    if (canProceed) {
      Navigator.pushNamed(context, '/create-roomspace');
    }
  }

  Future<void> _handleJoinRoom(BuildContext context) async {
    final subscriptionProvider = context.read<SubscriptionProvider>();
    
    final canProceed = await SubscriptionHelper.checkAndHandleRoomspaceLimit(
      context,
      subscriptionProvider,
      action: 'join',
    );
    
    if (canProceed) {
      Navigator.pushNamed(context, '/join-roomspace');
    }
  }
}
