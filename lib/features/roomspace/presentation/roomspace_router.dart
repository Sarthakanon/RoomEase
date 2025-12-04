import 'package:flutter/material.dart';
import '../../../services/api_service.dart';
import 'roomspace_details_screen.dart';
import 'roomspace_selection_screen.dart';

/// Routes to either RoomspaceDetailsScreen or RoomspaceSelectionScreen
/// based on whether the user has joined a roomspace
class RoomspaceRouter extends StatefulWidget {
  const RoomspaceRouter({super.key});

  @override
  State<RoomspaceRouter> createState() => _RoomspaceRouterState();
}

class _RoomspaceRouterState extends State<RoomspaceRouter> {
  final ApiService _apiService = ApiService();
  bool _isLoading = true;
  bool _hasRoomspace = false;
  Map<String, dynamic>? _pendingRequest;

  @override
  void initState() {
    super.initState();
    _checkRoomspace();
  }

  Future<void> _checkRoomspace() async {
    try {
      // Check for existing roomspace first
      final response = await _apiService.getRoomspaces();
      if (response['success'] == true && response['data'] != null) {
        final roomspaces = response['data'] as List<dynamic>;
        if (roomspaces.isNotEmpty) {
          setState(() {
            _hasRoomspace = true;
            _isLoading = false;
          });
          return;
        }
      }

      // No roomspace, check for pending join request
      final pendingResponse = await _apiService.getPendingJoinRequest();
      if (pendingResponse['success'] == true &&
          pendingResponse['data'] != null) {
        setState(() {
          _pendingRequest = pendingResponse['data'];
          _hasRoomspace = false;
          _isLoading = false;
        });
        return;
      }

      setState(() {
        _hasRoomspace = false;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _hasRoomspace = false;
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final primaryColor = Theme.of(context).colorScheme.primary;

    if (_isLoading) {
      return Scaffold(
        backgroundColor: const Color(0xFFF8F9FA),
        body: Center(child: CircularProgressIndicator(color: primaryColor)),
      );
    }

    if (_hasRoomspace) {
      return const RoomspaceDetailsScreen();
    }

    if (_pendingRequest != null) {
      return _buildPendingRequestScreen(primaryColor);
    }

    return const RoomspaceSelectionScreen();
  }

  Widget _buildPendingRequestScreen(Color primaryColor) {
    final roomspace = _pendingRequest?['roomspace'];
    final roomName = roomspace?['name'] ?? 'Unknown';

    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: Colors.orange.withValues(alpha: 0.1),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.hourglass_top_rounded,
                    size: 64,
                    color: Colors.orange,
                  ),
                ),
                const SizedBox(height: 32),
                const Text(
                  'Pending Approval',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  'Your request to join "$roomName" is waiting for approval from a member.',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 16, color: Colors.grey[600]),
                ),
                const SizedBox(height: 32),
                Container(
                  padding: const EdgeInsets.all(16),
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
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.home_rounded, color: primaryColor),
                      const SizedBox(width: 12),
                      Text(
                        roomName,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 18,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 32),
                TextButton.icon(
                  onPressed: () {
                    setState(() => _isLoading = true);
                    _checkRoomspace();
                  },
                  icon: const Icon(Icons.refresh),
                  label: const Text('Check Status'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
