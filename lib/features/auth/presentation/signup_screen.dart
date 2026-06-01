import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../controllers/auth_controller.dart';
import '../../../providers/roomspace_provider.dart';
import '../../subscription/providers/subscription_provider.dart';
import '../../../main.dart' show navigatorKey;
import '../../../services/firebase_auth_service.dart';

/// Screen for user registration, supporting email/password and Google authentication.
class SignupScreen extends StatefulWidget {
  const SignupScreen({super.key});

  @override
  State<SignupScreen> createState() => _SignupScreenState();
}

class _SignupScreenState extends State<SignupScreen> {
  static const int _fullNameMaxLength = 50;
  static const int _passwordMinLength = 6;
  static const int _passwordMaxLength = 64;
  static final RegExp _emailPattern = RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]{2,}$');
  static final RegExp _passwordHasNumber = RegExp(r'[0-9]');
  static final RegExp _passwordHasSpecialChar = RegExp(r'[!@#$%^&*(),.?":{}|<>_\-\\/\[\];`~+=]');

  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  final _authController = AuthController();
  
  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;
  bool _isGoogleLoading = false; // Track Google sign-in loading state
  bool _isEmailLoading = false; // Track email/password signup loading state

  Future<void> _handleSuccess(userCredential) async {
    // Initialize subscription provider for the new user
    final subscriptionProvider = Provider.of<SubscriptionProvider>(context, listen: false);
    await subscriptionProvider.initialize();
    
    // Small delay to ensure session cookie is persisted
    await Future.delayed(const Duration(milliseconds: 500));
    
    final provider = Provider.of<RoomspaceProvider>(context, listen: false);
    await provider.loadRoomspaces();
    if (mounted) Navigator.pushReplacementNamed(context, provider.roomspaceCount == 0 ? '/roomspace-selection' : '/home');
  }

  Future<void> _signup() async {
    if (!_formKey.currentState!.validate()) return;
    if (_isEmailLoading) return; // Prevent double-tap
    
    setState(() => _isEmailLoading = true);
    try {
      final cred = await _authController.signUpWithEmail(
        email: _emailController.text.trim(), 
        password: _passwordController.text.trim(), 
        name: _nameController.text.trim(),
      );
      if (mounted) {
        setState(() => _isEmailLoading = false);
        if (cred != null) {
          _showVerifyDialog();
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isEmailLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.toString()), backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<void> _googleLogin() async {
    if (_isGoogleLoading) return; // Prevent double-tap
    
    setState(() => _isGoogleLoading = true);
    try {
      final cred = await _authController.loginWithGoogle();
      if (cred != null) await _handleSuccess(cred);
    } catch (e) {
      if (mounted) {
        setState(() => _isGoogleLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.toString()), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isGoogleLoading = false);
    }
  }

  void _showVerifyDialog() {
    if (!mounted) return;
    
    final primary = Theme.of(context).colorScheme.primary;
    
    // Use WidgetsBinding to ensure dialog is shown after the current frame
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (dialogContext) => PopScope(
          canPop: false, // Prevent back button from dismissing
          child: AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.all(12), 
                  decoration: BoxDecoration(
                    color: Colors.orange.withValues(alpha: 0.1), 
                    shape: BoxShape.circle
                  ), 
                  child: const Icon(Icons.mark_email_unread_rounded, color: Colors.orange, size: 28)
                ),
                const SizedBox(height: 16),
                const Text('Verify Your Email', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
                const SizedBox(height: 8),
                Text(
                  'We\'ve sent a verification link to ${_emailController.text.trim()}. Please check your inbox and verify your email before logging in.',
                  textAlign: TextAlign.center, 
                  style: const TextStyle(fontSize: 13, color: Colors.grey)
                ),
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () async {
                      // Just sign out from Firebase (no backend call needed since user never logged in to backend)
                      try {
                        await FirebaseAuthService().signOut();
                      } catch (e) {
                        debugPrint('Firebase signout error: $e');
                      }
                      
                      // Navigate to login immediately
                      final navigator = navigatorKey.currentState;
                      if (navigator != null) {
                        navigator.pushNamedAndRemoveUntil(
                          '/login',
                          (route) => false,
                        );
                      }
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: primary, 
                      foregroundColor: Colors.white, 
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)), 
                      padding: const EdgeInsets.symmetric(vertical: 12)
                    ),
                    child: const Text('Go to Login'),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final primaryColor = Theme.of(context).colorScheme.primary;

    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Form(
              key: _formKey,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _buildLogo(primaryColor),
                  const SizedBox(height: 16),
                  const Text('Create Account', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: Color(0xFF1A1A2E))),
                  const SizedBox(height: 4),
                  Text('Join RoomEase to manage shared expenses', style: TextStyle(fontSize: 11, color: Colors.grey.shade500)),
                  const SizedBox(height: 20),
                  _buildField(_nameController, 'Full Name', Icons.person_outline),
                  const SizedBox(height: 10),
                  _buildField(_emailController, 'Email', Icons.email_outlined),
                  const SizedBox(height: 10),
                  _buildField(_passwordController, 'Password', Icons.lock_outline_rounded, isPassword: true),
                  const SizedBox(height: 10),
                  _buildField(_confirmPasswordController, 'Confirm Password', Icons.lock_clock_outlined, isPassword: true, isConfirm: true),
                  const SizedBox(height: 18),
                  _buildSignupButton(primaryColor),
                  const SizedBox(height: 18),
                  _buildDivider(),
                  const SizedBox(height: 18),
                  _buildGoogleButton(),
                  const SizedBox(height: 24),
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
      height: 50,
      width: 50,
      decoration: BoxDecoration(color: primary.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(14), border: Border.all(color: primary.withValues(alpha: 0.05))),
      child: Center(child: Icon(Icons.person_add_rounded, color: primary, size: 26)),
    );
  }

  Widget _buildField(TextEditingController ctrl, String label, IconData icon, {bool isPassword = false, bool isConfirm = false}) {
    final isName = label == 'Full Name';
    final isEmail = label == 'Email';
    final isPasswordField = label == 'Password';
    final isConfirmPasswordField = label == 'Confirm Password';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label.toUpperCase(), style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: Colors.grey.shade400, letterSpacing: 0.8)),
        const SizedBox(height: 8),
        TextFormField(
          controller: ctrl,
          obscureText: isPassword && (isConfirm ? _obscureConfirmPassword : _obscurePassword),
          inputFormatters: [
            if (isName) LengthLimitingTextInputFormatter(_fullNameMaxLength),
            if (isPasswordField || isConfirmPasswordField)
              LengthLimitingTextInputFormatter(_passwordMaxLength),
          ],
          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
          decoration: InputDecoration(
            hintText: 'Enter your $label',
            hintStyle: TextStyle(color: Colors.grey.shade400, fontSize: 13),
            filled: true,
            fillColor: const Color(0xFFF7F7FB),
            prefixIcon: Icon(icon, size: 18, color: Colors.grey.shade400),
            errorMaxLines: 4,
            errorStyle: const TextStyle(height: 1.25),
            suffixIcon: isPassword ? IconButton(icon: Icon((isConfirm ? _obscureConfirmPassword : _obscurePassword) ? Icons.visibility_outlined : Icons.visibility_off_outlined, size: 18, color: Colors.grey.shade400), onPressed: () => setState(() { if (isConfirm) {
              _obscureConfirmPassword = !_obscureConfirmPassword;
            } else {
              _obscurePassword = !_obscurePassword;
            } })) : null,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
          ),
          validator: (v) {
            if (v!.isEmpty) return '$label required';
            if (isName) {
              final trimmed = v.trim();
              if (trimmed.length < 2) return 'Full Name must be at least 2 characters';
              if (trimmed.length > _fullNameMaxLength) {
                return 'Full Name must be at most $_fullNameMaxLength characters';
              }
            }
            if (isEmail) {
              final email = v.trim();
              if (!_emailPattern.hasMatch(email)) {
                return 'Enter a valid email address (example@domain.com)';
              }
            }
            if (isPasswordField || isConfirmPasswordField) {
              if (v.length < _passwordMinLength) {
                return 'Password must be at least $_passwordMinLength characters';
              }
              if (!_passwordHasNumber.hasMatch(v)) {
                return 'Password must include at least one number';
              }
              if (!_passwordHasSpecialChar.hasMatch(v)) {
                return 'Password must include at least one special character';
              }
            }
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
      height: 48,
      child: ElevatedButton(
        onPressed: (_isEmailLoading || _isGoogleLoading) ? null : _signup,
        style: ElevatedButton.styleFrom(
          backgroundColor: primary, 
          foregroundColor: Colors.white, 
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)), 
          elevation: 0,
          padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
        ),
        child: _isEmailLoading 
            ? const SizedBox(
                width: 20, 
                height: 20, 
                child: CircularProgressIndicator(
                  color: Colors.white, 
                  strokeWidth: 2.5,
                ),
              )
            : const Text(
                'Create Account', 
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
              ),
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
      height: 48,
      child: OutlinedButton(
        onPressed: _isGoogleLoading ? null : _googleLogin,
        style: OutlinedButton.styleFrom(
          side: const BorderSide(color: Color(0xFFEEEEF2)), 
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)), 
          foregroundColor: const Color(0xFF1A1A2E),
          padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
        ),
        child: _isGoogleLoading
            ? const SizedBox(
                height: 20,
                width: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : Row(
                mainAxisSize: MainAxisSize.min,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Image.asset('png/google.png', height: 18, width: 18),
                  const SizedBox(width: 10),
                  const Flexible(
                    child: Text(
                      'Sign up with Google', 
                      style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
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
