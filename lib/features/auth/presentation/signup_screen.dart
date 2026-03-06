import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../controllers/auth_controller.dart';
import '../../../providers/roomspace_provider.dart';

/// Screen for user registration, supporting email/password and Google authentication.
class SignupScreen extends StatefulWidget {
  const SignupScreen({super.key});

  @override
  State<SignupScreen> createState() => _SignupScreenState();
}

class _SignupScreenState extends State<SignupScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  final _authController = AuthController();
  
  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;

  Future<void> _handleSuccess(userCredential) async {
    final provider = Provider.of<RoomspaceProvider>(context, listen: false);
    await provider.loadRoomspaces();
    if (mounted) Navigator.pushReplacementNamed(context, provider.roomspaceCount == 0 ? '/roomspace-selection' : '/home');
  }

  Future<void> _signup() async {
    if (!_formKey.currentState!.validate()) return;
    try {
      final cred = await _authController.signUpWithEmail(email: _emailController.text.trim(), password: _passwordController.text.trim(), name: _nameController.text.trim());
      if (cred != null) _showVerifyDialog();
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString()), backgroundColor: Colors.red));
    }
  }

  Future<void> _googleLogin() async {
    try {
      final cred = await _authController.loginWithGoogle();
      if (cred != null) await _handleSuccess(cred);
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString()), backgroundColor: Colors.red));
    }
  }

  void _showVerifyDialog() {
    final primary = Theme.of(context).colorScheme.primary;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 8),
            Container(padding: const EdgeInsets.all(12), decoration: BoxDecoration(color: Colors.orange.withValues(alpha: 0.1), shape: BoxShape.circle), child: const Icon(Icons.mark_email_unread_rounded, color: Colors.orange, size: 28)),
            const SizedBox(height: 16),
            const Text('Verify Your Email', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
            const SizedBox(height: 8),
            const Text('Check your inbox for a verification link.', textAlign: TextAlign.center, style: TextStyle(fontSize: 13, color: Colors.grey)),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () => Navigator.pushReplacementNamed(context, '/login'),
                style: ElevatedButton.styleFrom(backgroundColor: primary, foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)), padding: const EdgeInsets.symmetric(vertical: 12)),
                child: const Text('Go to Login'),
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

    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 28),
            child: Form(
              key: _formKey,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _buildLogo(primaryColor),
                  const SizedBox(height: 32),
                  const Text('Create Account', style: TextStyle(fontSize: 24, fontWeight: FontWeight.w800, color: Color(0xFF1A1A2E))),
                  const SizedBox(height: 6),
                  Text('Join RoomEase to manage shared expenses', style: TextStyle(fontSize: 13, color: Colors.grey.shade500)),
                  const SizedBox(height: 48),
                  _buildField(_nameController, 'Full Name', Icons.person_outline),
                  const SizedBox(height: 16),
                  _buildField(_emailController, 'Email', Icons.email_outlined),
                  const SizedBox(height: 16),
                  _buildField(_passwordController, 'Password', Icons.lock_outline_rounded, isPassword: true),
                  const SizedBox(height: 16),
                  _buildField(_confirmPasswordController, 'Confirm Password', Icons.lock_clock_outlined, isPassword: true, isConfirm: true),
                  const SizedBox(height: 32),
                  _buildSignupButton(primaryColor),
                  const SizedBox(height: 32),
                  _buildDivider(),
                  const SizedBox(height: 32),
                  _buildGoogleButton(),
                  const SizedBox(height: 48),
                  _buildLoginLink(primaryColor),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildLogo(Color primary) {
    return Container(
      height: 72,
      width: 72,
      decoration: BoxDecoration(color: primary.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(18), border: Border.all(color: primary.withValues(alpha: 0.05))),
      child: Center(child: Icon(Icons.person_add_rounded, color: primary, size: 36)),
    );
  }

  Widget _buildField(TextEditingController ctrl, String label, IconData icon, {bool isPassword = false, bool isConfirm = false}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label.toUpperCase(), style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: Colors.grey.shade400, letterSpacing: 0.8)),
        const SizedBox(height: 8),
        TextFormField(
          controller: ctrl,
          obscureText: isPassword && (isConfirm ? _obscureConfirmPassword : _obscurePassword),
          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
          decoration: InputDecoration(
            hintText: 'Enter your $label',
            hintStyle: TextStyle(color: Colors.grey.shade400, fontSize: 13),
            filled: true,
            fillColor: const Color(0xFFF7F7FB),
            prefixIcon: Icon(icon, size: 18, color: Colors.grey.shade400),
            suffixIcon: isPassword ? IconButton(icon: Icon((isConfirm ? _obscureConfirmPassword : _obscurePassword) ? Icons.visibility_outlined : Icons.visibility_off_outlined, size: 18, color: Colors.grey.shade400), onPressed: () => setState(() { if (isConfirm) _obscureConfirmPassword = !_obscureConfirmPassword; else _obscurePassword = !_obscurePassword; })) : null,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
          ),
          validator: (v) {
            if (v!.isEmpty) return '$label required';
            if (isConfirm && v != _passwordController.text) return 'Passwords mismatch';
            return null;
          },
        ),
      ],
    );
  }

  Widget _buildSignupButton(Color primary) {
    return SizedBox(
      width: double.infinity,
      height: 52,
      child: ElevatedButton(
        onPressed: _authController.isLoading ? null : _signup,
        style: ElevatedButton.styleFrom(backgroundColor: primary, foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)), elevation: 0),
        child: _authController.isLoading ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5)) : const Text('Create Account', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700)),
      ),
    );
  }

  Widget _buildDivider() {
    return Row(
      children: [
        Expanded(child: Divider(color: Colors.grey.shade200)),
        Padding(padding: const EdgeInsets.symmetric(horizontal: 16), child: Text('OR JOIN VIA', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: Colors.grey.shade300, letterSpacing: 0.8))),
        Expanded(child: Divider(color: Colors.grey.shade200)),
      ],
    );
  }

  Widget _buildGoogleButton() {
    return SizedBox(
      width: double.infinity,
      height: 52,
      child: OutlinedButton(
        onPressed: _authController.isLoading ? null : _googleLogin,
        style: OutlinedButton.styleFrom(side: const BorderSide(color: Color(0xFFEEEEF2)), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)), foregroundColor: const Color(0xFF1A1A2E)),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Image.network('https://upload.wikimedia.org/wikipedia/commons/thumb/c/c1/Google_%22G%22_logo.svg/480px-Google_%22G%22_logo.svg.png', height: 20, width: 20),
            const SizedBox(width: 12),
            const Text('Sign up with Google', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
          ],
        ),
      ),
    );
  }

  Widget _buildLoginLink(Color primary) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text("Already have an account?", style: TextStyle(fontSize: 13, color: Colors.grey.shade500)),
        TextButton(onPressed: () => Navigator.pushReplacementNamed(context, '/login'), child: Text('Sign In', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: primary))),
      ],
    );
  }
}
