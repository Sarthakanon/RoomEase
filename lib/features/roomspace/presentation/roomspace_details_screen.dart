import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:provider/provider.dart';
import '../../../services/api_service.dart';
import '../../../services/real_time_data_service.dart';
import '../../../core/widgets/mobile_scaffold.dart';
import '../../../core/widgets/global_roomspace_selector.dart';
import '../../../core/mixins/auto_refresh_mixin.dart';
import '../../../providers/roomspace_provider.dart';
import '../../subscription/providers/subscription_provider.dart';
import '../../subscription/utils/subscription_helper.dart';
import 'dart:async';

/// Roomspace Details screen — view and manage members, share invite codes, and see room metadata.
class RoomspaceDetailsScreen extends StatefulWidget {
  const RoomspaceDetailsScreen({super.key});

  @override
  State<RoomspaceDetailsScreen> createState() => _RoomspaceDetailsScreenState();
}

class _RoomspaceDetailsScreenState extends State<RoomspaceDetailsScreen> with AutoRefreshMixin {
  final ApiService _apiService = ApiService();
  final RealTimeDataService _realTimeService = RealTimeDataService();
  bool _isLoading = true;
  Map<String, dynamic>? _roomspace;
  List<dynamic> _members = [];
  List<dynamic> _joinRequests = [];
  String? _error;
  String? _currentUserUid;
  bool _isCreator = false;
  StreamSubscription<JoinRequestUpdateEvent>? _joinRequestSubscription;
  StreamSubscription<MemberUpdateEvent>? _memberUpdateSubscription;
  String? _lastActiveRoomspaceId;

  @override
  void initState() {
    super.initState();
    _currentUserUid = FirebaseAuth.instance.currentUser?.uid;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadDetails();
      // Store the initial active roomspace ID
      final provider = Provider.of<RoomspaceProvider>(context, listen: false);
      _lastActiveRoomspaceId = provider.getActiveRoomspaceId();
    });

    _setupRealTimeListeners();
  }
  
  void _setupRealTimeListeners() {
    // Listen for join request updates
    _joinRequestSubscription = _realTimeService.joinRequestUpdates.listen((event) {
      debugPrint('🔄 RoomspaceDetails: Join request update received');
      _loadDetails();
    });
    
    // Listen for member updates
    _memberUpdateSubscription = _realTimeService.memberUpdates.listen((event) {
      debugPrint('🔄 RoomspaceDetails: Member update received');
      final currentRoomspaceId = _roomspace?['id']?.toString();
      if (currentRoomspaceId == event.roomspaceId) {
        _loadDetails();
      }
    });
  }
  
  @override
  void dispose() {
    _joinRequestSubscription?.cancel();
    _memberUpdateSubscription?.cancel();
    super.dispose();
  }
  
  // Check if active roomspace changed and reload if needed
  void _checkActiveRoomspaceChanged() {
    final provider = Provider.of<RoomspaceProvider>(context, listen: false);
    final newActiveId = provider.getActiveRoomspaceId();
    
    if (newActiveId != _lastActiveRoomspaceId) {
      debugPrint('🔄 RoomspaceDetails: Active roomspace changed from $_lastActiveRoomspaceId to $newActiveId');
      _lastActiveRoomspaceId = newActiveId;
      _loadDetails();
    }
  }

  Future<void> _loadDetails() async {
    setState(() => _isLoading = true);
    try {
      final provider = Provider.of<RoomspaceProvider>(context, listen: false);
      await provider.loadRoomspaces(forceRefresh: true);

      if (provider.roomspaces.isEmpty) {
        setState(() {
          _roomspace = null;
          _members = [];
          _joinRequests = [];
          _isCreator = false;
          _isLoading = false;
        });
        return;
      }

      String? activeId = provider.getActiveRoomspaceId();
      if (activeId == null) {
        activeId = provider.roomspaces.first.id;
        await provider.setActiveRoomspace(activeId);
      }

      final detailsRes = await _apiService.get('/api/roomspaces/$activeId');
      if (detailsRes['success'] == true && detailsRes['data'] != null) {
        final active = detailsRes['data'] as Map<String, dynamic>;
        if (active.isNotEmpty) {
          // Load join requests for this roomspace
          List<dynamic> joinRequests = [];
          try {
            final joinRequestsRes = await _apiService.getJoinRequests();
            if (joinRequestsRes['success'] == true && joinRequestsRes['data'] != null) {
              joinRequests = joinRequestsRes['data'] as List<dynamic>;
            }
          } catch (e) {
            print('Error loading join requests: $e');
            // Continue even if join requests fail to load
          }
          
          setState(() {
            _roomspace = active;
            _members = _roomspace?['members'] ?? [];
            _joinRequests = joinRequests;
            _isCreator = _roomspace?['creator_id'] == _currentUserUid;
            _isLoading = false;
          });
          
          // Debug information
          print('🔍 Debug Info:');
          print('   Current User UID: $_currentUserUid');
          print('   Creator ID: ${_roomspace?['creator_id']}');
          print('   Is Creator: $_isCreator');
          print('   Join Requests: ${_joinRequests.length}');
          print('   Roomspace Data: ${_roomspace?.keys}');
        }
      } else {
        setState(() {
          _roomspace = null;
          _members = [];
          _joinRequests = [];
          _isCreator = false;
          _isLoading = false;
        });
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
        final roomspaceId = _roomspace?['id']?.toString();
        if (roomspaceId == null) {
          throw Exception('Roomspace ID not found');
        }
        await _apiService.removeMemberFromRoomspace(roomspaceId, uid);
        
        // Force reload roomspaces in provider to update member count
        final provider = Provider.of<RoomspaceProvider>(context, listen: false);
        await provider.loadRoomspaces(forceRefresh: true);
      },
      successMessage: 'Removed $name from the room',
      errorMessage: 'Failed to remove member',
    );
  }

  Future<void> _processJoinRequest(String requestId, bool accept, String name) async {
    try {
      await _apiService.processJoinRequest(requestId, accept);
      
      // Notify real-time service
      _realTimeService.notifyJoinRequestProcessed(requestId, accept);
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              accept ? '$name has been added!' : 'Request rejected',
            ),
          ),
        );
        // Reload details to update join requests and members
        await _loadDetails();
        
        // Also reload roomspaces in provider to update member count
        final provider = Provider.of<RoomspaceProvider>(context, listen: false);
        await provider.loadRoomspaces(forceRefresh: true);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    }
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
    print('🚪 _leaveRoomspace called');
    final roomspaceName = _roomspace?['name'] ?? 'this room';
    final roomspaceId = _roomspace?['id'];
    final isCreatorLeaving = _isCreator;
    
    print('📊 Roomspace ID: $roomspaceId');
    print('📊 Is Creator: $isCreatorLeaving');
    print('📊 Roomspace Name: $roomspaceName');
    
    if (roomspaceId == null) {
      print('❌ Roomspace ID is null, cannot leave');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Cannot leave: Roomspace not found')),
        );
      }
      return;
    }
    
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
    print('💬 Showing confirmation dialog');
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

    if (confirmed != true) {
      print('❌ User cancelled leave operation');
      return;
    }

    print('✅ User confirmed, proceeding to leave roomspace');
    setState(() => _isLoading = true);
    try {
      final roomspaceIdStr = roomspaceId.toString();
      print('📡 Calling provider.leaveRoomspace with ID: $roomspaceIdStr');
      final provider = Provider.of<RoomspaceProvider>(context, listen: false);
      await provider.leaveRoomspace(roomspaceIdStr);
      
      print('✅ Successfully left roomspace');
      
      // Reload roomspaces to update the UI everywhere
      await provider.loadRoomspaces(forceRefresh: true);
      final stillMember = provider.roomspaces.any((r) => r.id == roomspaceIdStr);
      if (stillMember) {
        throw Exception('Leave operation did not persist on server. Please try again.');
      }

      // Ensure we are no longer bound to the old active roomspace context.
      if (provider.getActiveRoomspaceId() == roomspaceIdStr) {
        await provider.switchToPersonalSpace();
      }
      
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              isCreatorLeaving 
                  ? 'Left "$roomspaceName" and transferred host role'
                  : 'Left "$roomspaceName"'
            ),
          ),
        );
        
        // Navigate back to home first
        Navigator.of(context).popUntil((route) => route.isFirst);
        
        // If there's a new active roomspace, navigate to its details
        // Use a small delay to ensure the home screen is fully loaded
        final newActiveRoomspace = provider.activeRoomspace;
        if (newActiveRoomspace != null) {
          Future.delayed(const Duration(milliseconds: 100), () {
            if (mounted) {
              Navigator.of(context).pushReplacementNamed(
                '/roomspace-details',
                arguments: {'id': newActiveRoomspace.id},
              );
            }
          });
        }
      }
    } catch (e) {
      print('❌ Error leaving roomspace: $e');
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
                  )),
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

    return Consumer<RoomspaceProvider>(
      builder: (context, provider, child) {
        // Check if active roomspace changed
        WidgetsBinding.instance.addPostFrameCallback((_) {
          _checkActiveRoomspaceChanged();
        });
        
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
      },
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
    // If no roomspace (Personal Space mode), show a special UI
    if (_roomspace == null) {
      return _buildPersonalSpaceUI(primary);
    }
    
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
                // Join Requests Section (only show if there are pending requests)
                if (_joinRequests.isNotEmpty) ...[
                  _buildSectionTitle('PENDING JOIN REQUESTS (${_joinRequests.length})'),
                  const SizedBox(height: 12),
                  _buildJoinRequestsSection(primary),
                  const SizedBox(height: 32),
                ],
                _buildSectionTitle('RESIDENTS (${_members.length})'),
                const SizedBox(height: 8),
                _buildMemberPanel(primary),
                const SizedBox(height: 100),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildPersonalSpaceUI(Color primary) {
    return CustomScrollView(
      slivers: [
        SliverAppBar(
          backgroundColor: Colors.white,
          elevation: 0,
          pinned: true,
          centerTitle: false,
          title: const Text('Personal Space', style: TextStyle(color: Color(0xFF1A1A2E), fontWeight: FontWeight.w700, fontSize: 17)),
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
                // Personal Space Info
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF7F7FB),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: const Color(0xFFEEEEF2)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: primary.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Icon(Icons.person_outline, color: primary, size: 24),
                          ),
                          const SizedBox(width: 14),
                          const Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Personal Space',
                                  style: TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.w800,
                                    color: Color(0xFF1A1A2E),
                                  ),
                                ),
                                Text(
                                  'Track your personal expenses',
                                  style: TextStyle(fontSize: 12, color: Colors.grey),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
                
                // Create/Join Room Actions
                _buildSectionTitle('ROOM ACTIONS'),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () => _handleCreateRoom(context),
                        icon: Icon(Icons.add_home_work_rounded, size: 18, color: primary),
                        label: Text(
                          "Create Room",
                          style: TextStyle(color: primary, fontSize: 13, fontWeight: FontWeight.w600),
                        ),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          side: BorderSide(color: primary.withValues(alpha: 0.3)),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: () => _handleJoinRoom(context),
                        icon: const Icon(Icons.group_add_rounded, size: 18),
                        label: const Text("Join Room", style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: primary,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                      ),
                    ),
                  ],
                ),
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

  Widget _buildJoinRequestsSection(Color primary) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFEEEEF2)),
      ),
      child: ListView.separated(
        padding: EdgeInsets.zero,
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        itemCount: _joinRequests.length,
        separatorBuilder: (_, __) => Divider(
          height: 1,
          color: const Color(0xFFF0F0F3),
          indent: 16,
          endIndent: 16,
        ),
        itemBuilder: (context, index) {
          final request = _joinRequests[index];
          final requester = request['requester'];
          final name = requester?['name'] ?? requester?['email'] ?? 'Unknown';
          final initial = name.isNotEmpty ? name[0].toUpperCase() : '?';
          final requestId = request['id'].toString();
          final isProcessing = request['_isProcessing'] == true;

          return Container(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    CircleAvatar(
                      radius: 18,
                      backgroundColor: Colors.orange.shade50,
                      child: Text(
                        initial,
                        style: TextStyle(
                          color: Colors.orange.shade800,
                          fontWeight: FontWeight.w700,
                          fontSize: 13,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            name,
                            style: const TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: 14,
                              color: Color(0xFF1A1A2E),
                            ),
                          ),
                          Text(
                            'Wants to join',
                            style: TextStyle(
                              color: Colors.grey.shade500,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: isProcessing
                            ? null
                            : () {
                                setState(() {
                                  _joinRequests[index]['_isProcessing'] = true;
                                });
                                _processJoinRequest(requestId, false, name);
                              },
                        style: OutlinedButton.styleFrom(
                          foregroundColor: const Color(0xFFC62828),
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                        child: isProcessing
                            ? const SizedBox(
                                height: 16,
                                width: 16,
                                child: CircularProgressIndicator(strokeWidth: 2),
                              )
                            : const Text(
                                'Reject',
                                style: TextStyle(fontSize: 13),
                              ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: isProcessing
                            ? null
                            : () {
                                setState(() {
                                  _joinRequests[index]['_isProcessing'] = true;
                                });
                                _processJoinRequest(requestId, true, name);
                              },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF2E7D32),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                        child: isProcessing
                            ? const SizedBox(
                                height: 16,
                                width: 16,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : const Text(
                                'Accept',
                                style: TextStyle(fontSize: 13),
                              ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildMemberPanel(Color primary) {
    return Container(
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), border: Border.all(color: const Color(0xFFEEEEF2))),
      child: ListView.separated(
        padding: EdgeInsets.zero,
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
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 0),
            minVerticalPadding: 0,
            visualDensity: VisualDensity.compact,
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
