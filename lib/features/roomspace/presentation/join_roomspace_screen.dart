import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../services/api_service.dart';
import '../../../providers/roomspace_provider.dart';

class JoinRoomController {
  final ApiService _apiService = ApiService();

  Future<Map<String, dynamic>> attemptJoin(String roomCode) async {
    try {
      String cleanCode = roomCode.toUpperCase().trim();
      final searchRes = await _apiService.searchRoomspaceByCode(cleanCode);
      if (searchRes['success'] != true || searchRes['data'] == null) return {'success': false, 'message': 'Room not found.'};
      final joinRes = await _apiService.joinRoomspaceByCode(cleanCode);
      if (joinRes['success'] == true) return {'success': true, 'message': 'Success!', 'data': searchRes['data']};
      return {'success': false, 'message': joinRes['error'] ?? 'Failed to join.'};
    } catch (e) {
      return {'success': false, 'message': e.toString()};
    }
  }
}

/// Join Roomspace screen — interface for entering invite codes to access roomspaces.
class JoinRoomspaceScreen extends StatefulWidget {
  const JoinRoomspaceScreen({super.key});

  @override
  State<JoinRoomspaceScreen> createState() => _JoinRoomspaceScreenState();
}

class _JoinRoomspaceScreenState extends State<JoinRoomspaceScreen> {
  final _formKey = GlobalKey<FormState>();
  final _roomIdController = TextEditingController();
  final _controller = JoinRoomController();
  bool _isLoading = false;
  
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _checkLimit());
  }
  
  void _checkLimit() {
    if (!Provider.of<RoomspaceProvider>(context, listen: false).canJoinMore) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Limit reached (5/5)'), backgroundColor: Colors.orange));
    }
  }

  Future<void> _handleJoin() async {
    if (!Provider.of<RoomspaceProvider>(context, listen: false).canJoinMore) return;
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isLoading = true);
    final result = await _controller.attemptJoin(_roomIdController.text);
    if (!mounted) return;
    setState(() => _isLoading = false);
    if (result['success'] == true) _showSuccess(result['data']);
    else ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(result['message']), backgroundColor: Colors.red));
  }

  void _showSuccess(Map<String, dynamic> room) {
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
            Container(padding: const EdgeInsets.all(12), decoration: BoxDecoration(color: Colors.green.withValues(alpha: 0.1), shape: BoxShape.circle), child: const Icon(Icons.check_rounded, color: Colors.green, size: 28)),
            const SizedBox(height: 16),
            const Text('Welcome Aboard!', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
            const SizedBox(height: 8),
            Text('You joined "${room['name']}"', textAlign: TextAlign.center, style: const TextStyle(fontSize: 13, color: Colors.grey)),
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
    return Consumer<RoomspaceProvider>(builder: (context, provider, child) {
      final isDisabled = !provider.canJoinMore;
      return Scaffold(
        backgroundColor: Colors.white,
        appBar: AppBar(
          backgroundColor: Colors.white,
          elevation: 0,
          leading: IconButton(icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Color(0xFF1A1A2E), size: 18), onPressed: () => Navigator.pop(context)),
          bottom: PreferredSize(preferredSize: const Size.fromHeight(1), child: Container(color: const Color(0xFFF0F0F0), height: 1)),
        ),
        body: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Join Room', style: TextStyle(fontSize: 24, fontWeight: FontWeight.w800, color: Color(0xFF1A1A2E))),
                  const SizedBox(height: 8),
                  Text('Enter the invite code shared by your roommate.', style: TextStyle(fontSize: 14, color: Colors.grey.shade500)),
                  const SizedBox(height: 32),
                  _buildCounter(provider),
                  const SizedBox(height: 32),
                  _buildInputField(isDisabled),
                  const SizedBox(height: 48),
                  _buildSubmit(isDisabled, primaryColor),
                ],
              ),
            ),
          ),
        ),
      );
    });
  }

  Widget _buildCounter(RoomspaceProvider provider) {
    final isLimit = !provider.canJoinMore;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(color: isLimit ? Colors.orange.shade50 : const Color(0xFFF7F7FB), borderRadius: BorderRadius.circular(10), border: Border.all(color: isLimit ? Colors.orange.shade200 : const Color(0xFFEEEEF2))),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(isLimit ? Icons.warning_amber_rounded : Icons.info_outline_rounded, size: 16, color: isLimit ? Colors.orange.shade800 : Colors.grey.shade600),
          const SizedBox(width: 10),
          Text('${provider.roomspaceCount}/5 roomspaces', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: isLimit ? Colors.orange.shade800 : Colors.grey.shade600)),
        ],
      ),
    );
  }

  Widget _buildInputField(bool isDisabled) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('INVITE CODE', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: Colors.grey.shade500, letterSpacing: 0.5)),
        const SizedBox(height: 8),
        TextFormField(
          controller: _roomIdController,
          enabled: !isDisabled,
          textCapitalization: TextCapitalization.characters,
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900, letterSpacing: 2),
          decoration: InputDecoration(
            hintText: 'ABC12345',
            hintStyle: TextStyle(color: Colors.grey.shade400, letterSpacing: 1.5, fontSize: 16),
            filled: true,
            fillColor: isDisabled ? const Color(0xFFF0F0F0) : const Color(0xFFF7F7FB),
            prefixIcon: Icon(Icons.vpn_key_outlined, size: 18, color: Colors.grey.shade400),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
          ),
          validator: (v) => v == null || v.length < 6 ? 'Invalid code' : null,
        ),
      ],
    );
  }

  Widget _buildSubmit(bool disabled, Color primary) {
    return SizedBox(
      width: double.infinity,
      height: 50,
      child: ElevatedButton(
        onPressed: (_isLoading || disabled) ? null : _handleJoin,
        style: ElevatedButton.styleFrom(backgroundColor: primary, foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)), elevation: 0),
        child: _isLoading ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)) : Text(disabled ? 'Limit Reached' : 'Join Room', style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700)),
      ),
    );
  }

  @override
  void dispose() {
    _roomIdController.dispose();
    super.dispose();
  }
}