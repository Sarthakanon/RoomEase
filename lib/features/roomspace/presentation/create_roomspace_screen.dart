import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../services/roomspace_service.dart';
import '../../../providers/roomspace_provider.dart';
import '../../subscription/providers/subscription_provider.dart';

class CreateRoomController {
  final _roomspaceService = RoomspaceService();

  Future<Map<String, dynamic>> createRoom({
    required String name,
    required String address,
    required String description,
  }) async {
    try {
      final response = await _roomspaceService.createRoomspace(
        name: name.trim(),
        description: description.trim().isEmpty ? null : description.trim(),
      );
      final inviteCode = response['data']?['invite_code']?.toString() ?? 'N/A';
      return {'success': true, 'message': 'Room created successfully!', 'inviteCode': inviteCode};
    } catch (e) {
      return {'success': false, 'message': 'Error: ${e.toString()}'};
    }
  }
}

/// Create Roomspace screen — form for establishing a new collaborative space.
class CreateRoomspaceScreen extends StatefulWidget {
  const CreateRoomspaceScreen({super.key});

  @override
  State<CreateRoomspaceScreen> createState() => _CreateRoomspaceScreenState();
}

class _CreateRoomspaceScreenState extends State<CreateRoomspaceScreen> {
  final _formKey = GlobalKey<FormState>();
  final _roomNameController = TextEditingController();
  final _addressController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _controller = CreateRoomController();
  bool _isLoading = false;
  
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _checkLimit());
  }
  
  void _checkLimit() {
    if (!mounted) return;
    final roomspaceProvider = Provider.of<RoomspaceProvider>(context, listen: false);
    final subscriptionProvider = Provider.of<SubscriptionProvider>(context, listen: false);
    final maxRoomspaces = subscriptionProvider.currentLimits.maxRoomspaces;
    
    if (roomspaceProvider.roomspaceCount >= maxRoomspaces) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Limit reached (${roomspaceProvider.roomspaceCount}/$maxRoomspaces)'), 
          backgroundColor: Colors.orange
        )
      );
    }
  }

  Future<void> _handleCreate() async {
    final roomspaceProvider = Provider.of<RoomspaceProvider>(context, listen: false);
    final subscriptionProvider = Provider.of<SubscriptionProvider>(context, listen: false);
    final maxRoomspaces = subscriptionProvider.currentLimits.maxRoomspaces;
    if (roomspaceProvider.roomspaceCount >= maxRoomspaces) return;
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);
    final result = await _controller.createRoom(
      name: _roomNameController.text,
      address: _addressController.text,
      description: _descriptionController.text,
    );
    
    if (!mounted) return;
    setState(() => _isLoading = false);

    if (result['success'] == true) {
      _showSuccess(result['inviteCode']);
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(result['message']), 
            backgroundColor: Colors.red
          )
        );
      }
    }
  }

  void _showSuccess(String code) {
    final primaryColor = Theme.of(context).colorScheme.primary;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 8),
            Container(padding: const EdgeInsets.all(12), decoration: BoxDecoration(color: primaryColor.withValues(alpha: 0.1), shape: BoxShape.circle), child: Icon(Icons.check_rounded, color: primaryColor, size: 28)),
            const SizedBox(height: 16),
            const Text('Room Created!', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
            const SizedBox(height: 8),
            const Text('Share this code with roommates:', textAlign: TextAlign.center, style: TextStyle(fontSize: 13, color: Colors.grey)),
            const SizedBox(height: 20),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 14),
              decoration: BoxDecoration(color: const Color(0xFFF7F7FB), borderRadius: BorderRadius.circular(10), border: Border.all(color: const Color(0xFFEEEEF2))),
              child: Text(code, textAlign: TextAlign.center, style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: primaryColor, letterSpacing: 2)),
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () async {
                  await Provider.of<RoomspaceProvider>(context, listen: false).refreshRoomspaces();
                  if (context.mounted) Navigator.pushReplacementNamed(context, '/home');
                },
                style: ElevatedButton.styleFrom(backgroundColor: primaryColor, foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)), padding: const EdgeInsets.symmetric(vertical: 12)),
                child: const Text('Go Home'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final primaryColor = Theme.of(context).colorScheme.primary;

    return Consumer2<RoomspaceProvider, SubscriptionProvider>(
      builder: (context, roomspaceProvider, subscriptionProvider, child) {
        final maxRoomspaces = subscriptionProvider.currentLimits.maxRoomspaces;
        final isDisabled = roomspaceProvider.roomspaceCount >= maxRoomspaces;
        
        return Scaffold(
          backgroundColor: Colors.white,
          appBar: AppBar(
            backgroundColor: Colors.white,
            elevation: 0,
            centerTitle: true,
            title: const Text('New Roomspace', style: TextStyle(color: Color(0xFF1A1A2E), fontWeight: FontWeight.w700, fontSize: 17)),
            leading: IconButton(icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Color(0xFF1A1A2E), size: 18), onPressed: () => Navigator.pop(context)),
            bottom: PreferredSize(preferredSize: const Size.fromHeight(1), child: Container(color: const Color(0xFFF0F0F0), height: 1)),
          ),
          body: SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Form(
                key: _formKey,
                child: Column(
                  children: [
                    _buildCounter(roomspaceProvider, maxRoomspaces),
                    const SizedBox(height: 32),
                    _buildField(controller: _roomNameController, label: 'Room Name', hint: 'e.g. Dream Suite', icon: Icons.home_outlined, isDisabled: isDisabled, validator: (v) => v!.isEmpty ? 'Name required' : null),
                    const SizedBox(height: 16),
                    _buildField(controller: _addressController, label: 'Address', hint: 'e.g. 5th Ave, NY', icon: Icons.location_on_outlined, isDisabled: isDisabled, validator: (v) => v!.isEmpty ? 'Address required' : null),
                    const SizedBox(height: 16),
                    _buildField(controller: _descriptionController, label: 'Notes (Optional)', hint: 'Room rules, etc.', icon: Icons.notes_rounded, isDisabled: isDisabled, maxLines: 3),
                    const SizedBox(height: 48),
                    _buildSubmit(isDisabled, primaryColor),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildCounter(RoomspaceProvider provider, int maxRoomspaces) {
    final isLimit = provider.roomspaceCount >= maxRoomspaces;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(color: isLimit ? Colors.orange.shade50 : const Color(0xFFF7F7FB), borderRadius: BorderRadius.circular(10), border: Border.all(color: isLimit ? Colors.orange.shade200 : const Color(0xFFEEEEF2))),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(isLimit ? Icons.warning_amber_rounded : Icons.info_outline_rounded, size: 16, color: isLimit ? Colors.orange.shade800 : Colors.grey.shade600),
          const SizedBox(width: 10),
          Text('${provider.roomspaceCount}/$maxRoomspaces roomspaces used', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: isLimit ? Colors.orange.shade800 : Colors.grey.shade600)),
        ],
      ),
    );
  }

  Widget _buildField({required TextEditingController controller, required String label, required String hint, required IconData icon, required bool isDisabled, int maxLines = 1, String? Function(String?)? validator}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label.toUpperCase(), style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: Colors.grey.shade500, letterSpacing: 0.5)),
        const SizedBox(height: 8),
        TextFormField(
          controller: controller,
          maxLines: maxLines,
          validator: validator,
          enabled: !isDisabled,
          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: TextStyle(color: Colors.grey.shade400, fontSize: 13),
            filled: true,
            fillColor: isDisabled ? const Color(0xFFF0F0F0) : const Color(0xFFF7F7FB),
            prefixIcon: Icon(icon, size: 18, color: Colors.grey.shade400),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
          ),
        ),
      ],
    );
  }

  Widget _buildSubmit(bool disabled, Color primary) {
    return SizedBox(
      width: double.infinity,
      height: 50,
      child: ElevatedButton(
        onPressed: (_isLoading || disabled) ? null : _handleCreate,
        style: ElevatedButton.styleFrom(backgroundColor: primary, foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)), elevation: 0),
        child: _isLoading ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)) : Text(disabled ? 'Limit Reached' : 'Create Room', style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700)),
      ),
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
