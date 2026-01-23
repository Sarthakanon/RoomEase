import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../services/api_service.dart';
import '../../../providers/roomspace_provider.dart';

// ==========================================
// 1. LOGIC SECTION (The "Controller")
// ==========================================
// This class handles all the "thinking" (API calls, validation logic).
// The UI doesn't need to know how API works, it just calls this.
class JoinRoomController {
  final ApiService _apiService = ApiService();

  // Returns a Map with { success: boolean, message: String, data: Map? }
  Future<Map<String, dynamic>> attemptJoin(String roomCode) async {
    try {
      // Step 1: Clean the input (make it uppercase, remove spaces)
      String cleanCode = roomCode.toUpperCase().trim();

      // Step 2: Check if room exists
      final searchResponse = await _apiService.searchRoomspaceByCode(cleanCode);
      
      // If room is NOT found or search failed
      if (searchResponse['success'] != true || searchResponse['data'] == null) {
        return {
          'success': false,
          'message': 'Room not found. Please check the code and try again.'
        };
      }

      // Step 3: If room exists, try to join it
      final joinResponse = await _apiService.joinRoomspaceByCode(cleanCode);

      if (joinResponse['success'] == true) {
        return {
          'success': true,
          'message': 'Joined successfully!',
          'data': searchResponse['data'] // Return room details for the popup
        };
      } else {
        return {
          'success': false,
          'message': joinResponse['error'] ?? 'Failed to join the room.'
        };
      }
    } catch (e) {
      return {
        'success': false,
        'message': 'Error: ${e.toString()}'
      };
    }
  }
}

// ==========================================
// 2. UI SECTION (The "View")
// ==========================================
class JoinRoomspaceScreen extends StatefulWidget {
  const JoinRoomspaceScreen({super.key});

  @override
  State<JoinRoomspaceScreen> createState() => _JoinRoomspaceScreenState();
}

class _JoinRoomspaceScreenState extends State<JoinRoomspaceScreen> {
  // Controllers and Keys
  final _formKey = GlobalKey<FormState>();
  final _roomIdController = TextEditingController();
  
  // Instance of our Logic Class
  final _controller = JoinRoomController();
  
  // State Variable
  bool _isLoading = false;
  
  @override
  void initState() {
    super.initState();
    // Check limit on screen load
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkRoomspaceLimit();
    });
  }
  
  // Check if user has reached the roomspace limit
  void _checkRoomspaceLimit() {
    final roomspaceProvider = Provider.of<RoomspaceProvider>(context, listen: false);
    
    if (!roomspaceProvider.canJoinMore) {
      // Show error message if at limit
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Maximum roomspace limit reached (${roomspaceProvider.roomspaceCount}/5)'),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 4),
        ),
      );
    }
  }

  // --- BUTTON ACTION ---
  Future<void> _handleJoinButton() async {
    // Check limit before attempting to join
    final roomspaceProvider = Provider.of<RoomspaceProvider>(context, listen: false);
    
    if (!roomspaceProvider.canJoinMore) {
      _showErrorSnackBar('Maximum roomspace limit reached. You can only join up to 5 roomspaces.');
      return;
    }
    
    // 1. Validate the form (check if text field is empty)
    if (!_formKey.currentState!.validate()) return;

    // 2. Start Loading
    setState(() {
      _isLoading = true;
    });

    // 3. Call our Logic Class
    final result = await _controller.attemptJoin(_roomIdController.text);

    // 4. Check if widget is still on screen (Safety check)
    if (!mounted) return;

    // 5. Stop Loading
    setState(() {
      _isLoading = false;
    });

    // 6. Handle Result
    if (result['success'] == true) {
      _showSuccessDialog(result['data']);
    } else {
      _showErrorSnackBar(result['message']);
    }
  }

  // --- HELPER: Show Error Message ---
  void _showErrorSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
      ),
    );
  }

  // --- HELPER: Show Success Popup ---
  void _showSuccessDialog(Map<String, dynamic> roomDetails) {
    final primaryColor = Theme.of(context).primaryColor;
    
    showDialog(
      context: context,
      barrierDismissible: false, // User must click button to close
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min, // Wrap content height
            children: [
              // Icon Circle
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.green.withValues(alpha: 0.1), // Simpler opacity
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.check_rounded, color: Colors.green, size: 32),
              ),
              const SizedBox(height: 16),
              
              // Title
              const Text(
                'Joined Successfully!',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              
              // Subtitle
              Text(
                'You are now a member of "${roomDetails['name']}"',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.grey[600]),
              ),
              const SizedBox(height: 24),
              
              // Button
              ElevatedButton(
                onPressed: () async {
                  Navigator.of(context).pop(); // Close dialog
                  
                  // Refresh roomspaces in the provider before navigating
                  final roomspaceProvider = Provider.of<RoomspaceProvider>(context, listen: false);
                  await roomspaceProvider.refreshRoomspaces();
                  
                  if (context.mounted) {
                    Navigator.pushReplacementNamed(context, '/home'); // Go home
                  }
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: primaryColor,
                  minimumSize: const Size(double.infinity, 45),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: const Text('Go to Dashboard', style: TextStyle(color: Colors.white)),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ==========================================
  // 3. WIDGET BUILDING (The Layout)
  // ==========================================
  @override
  Widget build(BuildContext context) {
    return Consumer<RoomspaceProvider>(
      builder: (context, roomspaceProvider, child) {
        return Scaffold(
          backgroundColor: Colors.white, // Standard background
          appBar: AppBar(
            backgroundColor: Colors.transparent,
            elevation: 0,
            leading: IconButton(
              icon: const Icon(Icons.arrow_back_ios_new, color: Colors.black),
              onPressed: () => Navigator.of(context).pop(),
            ),
          ),
          body: SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildHeader(),       // Extracted for readability
                    const SizedBox(height: 16),
                    _buildRoomspaceCounter(roomspaceProvider), // Show count
                    const SizedBox(height: 24),
                    if (!roomspaceProvider.canJoinMore)
                      _buildLimitReachedWarning(), // Show warning if at limit
                    if (!roomspaceProvider.canJoinMore)
                      const SizedBox(height: 24),
                    _buildInputField(roomspaceProvider),   // Extracted for readability
                    const SizedBox(height: 40),
                    _buildSubmitButton(roomspaceProvider), // Extracted for readability
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  // --- SMALLER WIDGET PIECES ---

  Widget _buildHeader() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 20),
        const Text(
          'Join Room',
          style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        Text(
          'Enter the unique 8-character code shared by your roommate.',
          style: TextStyle(fontSize: 16, color: Colors.grey[600]),
        ),
      ],
    );
  }
  
  Widget _buildRoomspaceCounter(RoomspaceProvider provider) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: provider.canJoinMore ? Colors.blue.withValues(alpha: 0.1) : Colors.orange.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: provider.canJoinMore ? Colors.blue.withValues(alpha: 0.3) : Colors.orange.withValues(alpha: 0.3),
          width: 1,
        ),
      ),
      child: Row(
        children: [
          Icon(
            provider.canJoinMore ? Icons.info_outline : Icons.warning_amber_rounded,
            color: provider.canJoinMore ? Colors.blue : Colors.orange,
            size: 20,
          ),
          const SizedBox(width: 12),
          Text(
            'You have ${provider.roomspaceCount}/5 roomspaces',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: provider.canJoinMore ? Colors.blue[800] : Colors.orange[800],
            ),
          ),
        ],
      ),
    );
  }
  
  Widget _buildLimitReachedWarning() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.red.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: Colors.red.withValues(alpha: 0.3),
          width: 1,
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(
            Icons.error_outline,
            color: Colors.red,
            size: 24,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Maximum roomspace limit reached',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.red,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'You can only join up to 5 roomspaces. Please leave a roomspace before joining a new one.',
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.red[700],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInputField(RoomspaceProvider provider) {
    final isDisabled = !provider.canJoinMore;
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Room ID',
          style: TextStyle(fontWeight: FontWeight.w600, color: Colors.grey[800]),
        ),
        const SizedBox(height: 8),
        TextFormField(
          controller: _roomIdController,
          enabled: !isDisabled,
          textCapitalization: TextCapitalization.characters,
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            letterSpacing: 1.5,
            color: isDisabled ? Colors.grey[400] : Colors.black,
          ),
          decoration: InputDecoration(
            hintText: 'ABC12345',
            filled: true,
            fillColor: isDisabled ? Colors.grey[200] : Colors.grey[100],
            prefixIcon: Icon(Icons.tag, color: isDisabled ? Colors.grey[400] : Colors.grey),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: BorderSide.none,
            ),
          ),
          // Simple Validator
          validator: (value) {
            if (value == null || value.isEmpty) {
              return 'Please enter a Room ID';
            }
            if (value.length < 6) {
              return 'ID is too short';
            }
            return null;
          },
        ),
      ],
    );
  }

  Widget _buildSubmitButton(RoomspaceProvider provider) {
    final isDisabled = !provider.canJoinMore;
    
    return SizedBox(
      width: double.infinity,
      height: 54,
      child: ElevatedButton(
        onPressed: (_isLoading || isDisabled) ? null : _handleJoinButton,
        style: ElevatedButton.styleFrom(
          backgroundColor: isDisabled ? Colors.grey[400] : Theme.of(context).primaryColor,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          disabledBackgroundColor: Colors.grey[300],
        ),
        child: _isLoading
            ? const CircularProgressIndicator(color: Colors.white)
            : Text(
                isDisabled ? 'Limit Reached' : 'Join Room',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: isDisabled ? Colors.grey[600] : Colors.white,
                ),
              ),
      ),
    );
  }

  @override
  void dispose() {
    _roomIdController.dispose();
    super.dispose();
  }
}