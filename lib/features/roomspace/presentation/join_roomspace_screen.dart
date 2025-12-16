import 'package:flutter/material.dart';
import '../../../services/api_service.dart';

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

  // --- BUTTON ACTION ---
  Future<void> _handleJoinButton() async {
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
                  color: Colors.green.withOpacity(0.1), // Simpler opacity
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
                onPressed: () {
                  Navigator.of(context).pop(); // Close dialog
                  Navigator.pushReplacementNamed(context, '/home'); // Go home
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
                const SizedBox(height: 40),
                _buildInputField(),   // Extracted for readability
                const SizedBox(height: 40),
                _buildSubmitButton(), // Extracted for readability
              ],
            ),
          ),
        ),
      ),
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

  Widget _buildInputField() {
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
          textCapitalization: TextCapitalization.characters,
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, letterSpacing: 1.5),
          decoration: InputDecoration(
            hintText: 'ABC12345',
            filled: true,
            fillColor: Colors.grey[100],
            prefixIcon: const Icon(Icons.tag, color: Colors.grey),
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

  Widget _buildSubmitButton() {
    return SizedBox(
      width: double.infinity,
      height: 54,
      child: ElevatedButton(
        onPressed: _isLoading ? null : _handleJoinButton,
        style: ElevatedButton.styleFrom(
          backgroundColor: Theme.of(context).primaryColor,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        ),
        child: _isLoading
            ? const CircularProgressIndicator(color: Colors.white)
            : const Text(
                'Join Room',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white),
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