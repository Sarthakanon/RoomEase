import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../services/roomspace_service.dart';
import '../../../providers/roomspace_provider.dart';

// ==========================================
// 1. LOGIC SECTION (The "Controller")
// ==========================================
class CreateRoomController {
  final _roomspaceService = RoomspaceService();

  // Returns { success: bool, message: String, inviteCode: String? }
  Future<Map<String, dynamic>> createRoom({
    required String name,
    required String address,
    required String description,
  }) async {
    try {
      // Step 1: Prepare the data
      // We trim spaces to ensure clean data
      final cleanName = name.trim();
      final cleanDesc = description.trim();
      
      // Note: Address isn't used in the API call yet based on your previous code,
      // but we collect it here for future use.

      // Step 2: Call the Service
      final response = await _roomspaceService.createRoomspace(
        name: cleanName,
        description: cleanDesc.isEmpty ? null : cleanDesc,
      );

      // Step 3: Extract the Invite Code safely
      final inviteCode = response['data']?['invite_code']?.toString() ?? 'N/A';

      return {
        'success': true,
        'message': 'Room created successfully!',
        'inviteCode': inviteCode,
      };

    } catch (e) {
      return {
        'success': false,
        'message': 'Error: ${e.toString()}',
      };
    }
  }
}

// ==========================================
// 2. UI SECTION (The "View")
// ==========================================
class CreateRoomspaceScreen extends StatefulWidget {
  const CreateRoomspaceScreen({super.key});

  @override
  State<CreateRoomspaceScreen> createState() => _CreateRoomspaceScreenState();
}

class _CreateRoomspaceScreenState extends State<CreateRoomspaceScreen> {
  // --- STATE VARIABLES ---
  final _formKey = GlobalKey<FormState>();
  final _roomNameController = TextEditingController();
  final _addressController = TextEditingController();
  final _descriptionController = TextEditingController();
  
  // Instance of our Logic Class
  final _controller = CreateRoomController();
  
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
  Future<void> _handleCreateButton() async {
    // Check limit before attempting to create
    final roomspaceProvider = Provider.of<RoomspaceProvider>(context, listen: false);
    
    if (!roomspaceProvider.canJoinMore) {
      _showErrorSnackBar('Maximum roomspace limit reached. You can only create up to 5 roomspaces.');
      return;
    }
    // 1. Check if form is valid (no empty fields)
    if (!_formKey.currentState!.validate()) return;

    // 2. Start Loading
    setState(() => _isLoading = true);

    // 3. Call the Controller
    final result = await _controller.createRoom(
      name: _roomNameController.text,
      address: _addressController.text,
      description: _descriptionController.text,
    );

    // 4. Safety Check (Is screen still visible?)
    if (!mounted) return;

    // 5. Stop Loading
    setState(() => _isLoading = false);

    // 6. Handle Success or Failure
    if (result['success'] == true) {
      _showSuccessDialog(result['inviteCode']);
    } else {
      _showErrorSnackBar(result['message']);
    }
  }

  // --- HELPER: Error Message ---
  void _showErrorSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.red),
    );
  }

  // --- HELPER: Success Dialog ---
  void _showSuccessDialog(String inviteCode) {
    final primaryColor = Theme.of(context).primaryColor;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Success Icon
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: primaryColor.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(Icons.home_rounded, color: primaryColor, size: 32),
              ),
              const SizedBox(height: 16),
              
              // Title
              const Text(
                'Room Created!',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              
              // Instruction
              Text(
                'Share this code with your roommates to let them join.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.grey[600]),
              ),
              const SizedBox(height: 20),
              
              // Invite Code Box
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 16),
                decoration: BoxDecoration(
                  color: Colors.grey[100],
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.grey[300]!),
                ),
                child: Column(
                  children: [
                    Text(
                      'INVITE CODE',
                      style: TextStyle(
                        fontSize: 12, 
                        fontWeight: FontWeight.bold, 
                        color: Colors.grey[500]
                      ),
                    ),
                    const SizedBox(height: 4),
                    SelectableText(
                      inviteCode,
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: primaryColor,
                        letterSpacing: 2,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              
              // Go to Dashboard Button
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
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
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
          appBar: AppBar(
            title: const Text("Create Room", style: TextStyle(fontWeight: FontWeight.bold)),
            centerTitle: true,
            leading: IconButton(
              icon: const Icon(Icons.arrow_back_ios_new),
              onPressed: () => Navigator.of(context).pop(),
            ),
          ),
          body: SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Form(
                key: _formKey,
                child: Column(
                  children: [
                    _buildRoomspaceCounter(roomspaceProvider), // Show count
                    const SizedBox(height: 16),
                    if (!roomspaceProvider.canJoinMore)
                      _buildLimitReachedWarning(), // Show warning if at limit
                    if (!roomspaceProvider.canJoinMore)
                      const SizedBox(height: 16),
                    _buildFormFields(roomspaceProvider),   // Extracted for cleanliness
                    const SizedBox(height: 40),
                    _buildSubmitButton(roomspaceProvider), // Extracted for cleanliness
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
                  'You can only create up to 5 roomspaces. Please leave a roomspace before creating a new one.',
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

  Widget _buildFormFields(RoomspaceProvider provider) {
    final isDisabled = !provider.canJoinMore;
    
    return Column(
      children: [
        _buildTextField(
          controller: _roomNameController,
          label: "Room Name",
          hint: "e.g. Downtown Apartment",
          icon: Icons.home_outlined,
          validator: (v) => v == null || v.isEmpty ? "Name is required" : null,
          isDisabled: isDisabled,
        ),
        const SizedBox(height: 16),
        _buildTextField(
          controller: _addressController,
          label: "Address",
          hint: "e.g. 123 Main St",
          icon: Icons.location_on_outlined,
          validator: (v) => v == null || v.isEmpty ? "Address is required" : null,
          isDisabled: isDisabled,
        ),
        const SizedBox(height: 16),
        _buildTextField(
          controller: _descriptionController,
          label: "Description (Optional)",
          hint: "Any rules or notes...",
          icon: Icons.description_outlined,
          maxLines: 3,
          isDisabled: isDisabled,
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
        onPressed: (_isLoading || isDisabled) ? null : _handleCreateButton,
        style: ElevatedButton.styleFrom(
          backgroundColor: isDisabled ? Colors.grey[400] : Theme.of(context).primaryColor,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          disabledBackgroundColor: Colors.grey[300],
        ),
        child: _isLoading
            ? const CircularProgressIndicator(color: Colors.white)
            : Text(
                isDisabled ? 'Limit Reached' : 'Create Room',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: isDisabled ? Colors.grey[600] : Colors.white,
                ),
              ),
      ),
    );
  }

  // Reusable Input Widget
  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required String hint,
    required IconData icon,
    int maxLines = 1,
    String? Function(String?)? validator,
    bool isDisabled = false,
  }) {
    final primaryColor = Theme.of(context).primaryColor;
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(fontWeight: FontWeight.w600, color: Colors.grey[800]),
        ),
        const SizedBox(height: 8),
        TextFormField(
          controller: controller,
          maxLines: maxLines,
          validator: validator,
          enabled: !isDisabled,
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: TextStyle(color: Colors.grey[400]),
            filled: true,
            fillColor: isDisabled ? Colors.grey[200] : Colors.grey[100],
            // Only show icon on first line if multiline
            prefixIcon: maxLines > 1 
                ? Padding(padding: const EdgeInsets.only(bottom: 40), child: Icon(icon, color: isDisabled ? Colors.grey[400] : Colors.grey))
                : Icon(icon, color: isDisabled ? Colors.grey[400] : Colors.grey),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: BorderSide.none,
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: BorderSide(color: primaryColor, width: 1.5),
            ),
          ),
        ),
      ],
    );
  }

  @override
  void dispose() {
    _roomNameController.dispose();
    _addressController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }
}