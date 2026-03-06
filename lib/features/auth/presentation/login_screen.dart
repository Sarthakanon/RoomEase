import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../controllers/auth_controller.dart';
import '../../../services/auth_state_service.dart';
import '../../../providers/roomspace_provider.dart';

/// Screen for user login, supporting email/password and Google authentication.
class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _authController = AuthController();
  bool _obscurePassword = true;
  bool _rememberMe = false;

  @override
  void initState() {
    super.initState();
    _loadSaved();
  }

  Future<void> _loadSaved() async {
    final rem = await AuthStateService.getRememberMe();
    final email = await AuthStateService.getSavedEmail();
    setState(() { _rememberMe = rem; if (rem && email != null) _emailController.text = email; });
  }

  Future<void> _handleSuccess(userCredential) async {
    if (_rememberMe) await AuthStateService.saveLoginState(userCredential.user?.email ?? '', true);
    final provider = Provider.of<RoomspaceProvider>(context, listen: false);
    await provider.loadRoomspaces();
    if (mounted) Navigator.pushReplacementNamed(context, provider.roomspaceCount == 0 ? '/roomspace-selection' : '/home');
  }

  Future<void> _login() async {
    if (!_formKey.currentState!.validate()) return;
    try {
      final cred = await _authController.loginWithEmail(_emailController.text.trim(), _passwordController.text.trim());
      if (cred != null) await _handleSuccess(cred);
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
                  const Text('Welcome Back', style: TextStyle(fontSize: 24, fontWeight: FontWeight.w800, color: Color(0xFF1A1A2E))),
                  const SizedBox(height: 6),
                  Text('Sign in to manage your RoomEase expenses', style: TextStyle(fontSize: 13, color: Colors.grey.shade500)),
                  const SizedBox(height: 48),
                  _buildField(_emailController, 'Email', Icons.email_outlined),
                  const SizedBox(height: 16),
                  _buildField(_passwordController, 'Password', Icons.lock_outline_rounded, isPassword: true),
                  _buildOptions(primaryColor),
                  const SizedBox(height: 24),
                  _buildLoginButton(primaryColor),
                  const SizedBox(height: 32),
                  _buildDivider(),
                  const SizedBox(height: 32),
                  _buildGoogleButton(),
                  const SizedBox(height: 48),
                  _buildSignupLink(primaryColor),
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
      child: Center(child: Icon(Icons.home_work_rounded, color: primary, size: 36)),
    );
  }

  Widget _buildField(TextEditingController ctrl, String label, IconData icon, {bool isPassword = false}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label.toUpperCase(), style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: Colors.grey.shade400, letterSpacing: 0.8)),
        const SizedBox(height: 8),
        TextFormField(
          controller: ctrl,
          obscureText: isPassword && _obscurePassword,
          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
          decoration: InputDecoration(
            hintText: 'Enter your $label',
            hintStyle: TextStyle(color: Colors.grey.shade400, fontSize: 13),
            filled: true,
            fillColor: const Color(0xFFF7F7FB),
            prefixIcon: Icon(icon, size: 18, color: Colors.grey.shade400),
            suffixIcon: isPassword ? IconButton(icon: Icon(_obscurePassword ? Icons.visibility_outlined : Icons.visibility_off_outlined, size: 18, color: Colors.grey.shade400), onPressed: () => setState(() => _obscurePassword = !_obscurePassword)) : null,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
          ),
          validator: (v) => v!.isEmpty ? '$label required' : null,
        ),
      ],
    );
  }

  Widget _buildOptions(Color primary) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Checkbox(value: _rememberMe, activeColor: primary, side: BorderSide(color: Colors.grey.shade300, width: 1.5), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)), onChanged: (v) => setState(() => _rememberMe = v ?? false)),
            Text('Remember me', style: TextStyle(fontSize: 12, color: Colors.grey.shade500)),
          ],
        ),
        TextButton(onPressed: () => Navigator.pushNamed(context, '/forgot-password'), child: Text('Forgot Password?', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: primary))),
      ],
    );
  }

  Widget _buildLoginButton(Color primary) {
    return SizedBox(
      width: double.infinity,
      height: 52,
      child: ElevatedButton(
        onPressed: _authController.isLoading ? null : _login,
        style: ElevatedButton.styleFrom(backgroundColor: primary, foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)), elevation: 0),
        child: _authController.isLoading ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5)) : const Text('Sign In', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700)),
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
            const Text('Continue with Google', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
          ],
        ),
      ),
    );
  }

  Widget _buildSignupLink(Color primary) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text("Don't have an account?", style: TextStyle(fontSize: 13, color: Colors.grey.shade500)),
        TextButton(onPressed: () => Navigator.pushNamed(context, '/signup'), child: Text('Sign Up', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: primary))),
      ],
    );
  }
}
