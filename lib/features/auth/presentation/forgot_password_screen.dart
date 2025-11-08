import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../services/firebase_auth_service.dart';

class ForgotPasswordScreen extends StatefulWidget {
  const ForgotPasswordScreen({super.key});

  @override
  State<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen> {
  // Form key for validation
  final _formKey = GlobalKey<FormState>();

  // Email controller
  final _emailController = TextEditingController();

  // Loading state
  bool _isLoading = false;
  bool _emailSent = false;

  // Firebase Auth Service
  final FirebaseAuthService _authService = FirebaseAuthService();

  // Reset password function
  Future<void> _resetPassword() async {
    // Check if form is valid
    if (_formKey.currentState!.validate()) {
      // Show loading
      setState(() {
        _isLoading = true;
      });

      try {
        // Send password reset email via Firebase
        await _authService.sendPasswordResetEmail(
          email: _emailController.text.trim(),
        );

        if (mounted) {
          setState(() {
            _isLoading = false;
            _emailSent = true;
          });

          // Show success message
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Password reset email sent! Check your inbox.'),
              backgroundColor: Colors.green,
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          setState(() {
            _isLoading = false;
          });

          // Show error message
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(e.toString()), backgroundColor: Colors.red),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    // Get screen size for responsive design
    final screenSize = MediaQuery.of(context).size;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.dark,
        statusBarBrightness: Brightness.light,
        systemNavigationBarColor: Colors.grey[50],
        systemNavigationBarIconBrightness: Brightness.dark,
      ),
      child: Scaffold(
        body: Container(
          // Gradient background using primary and tertiary colors
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Color(0xFFE8EAF6), // Indigo 50 - Light
                Color(0xFFE0F2F1), // Teal 50 - Light
                Colors.white,
              ],
              stops: [0.0, 0.5, 1.0],
            ),
          ),
          child: SizedBox(
            width: double.infinity,
            height: double.infinity,
            child: SafeArea(
              child: Center(
                child: SingleChildScrollView(
                  padding: EdgeInsets.symmetric(
                    horizontal: screenSize.width * 0.05,
                  ),
                  child: Card(
                    elevation: 12,
                    color: Colors.white,
                    shadowColor: Theme.of(
                      context,
                    ).colorScheme.primary.withValues(alpha: 0.3),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Container(
                      constraints: BoxConstraints(
                        maxWidth: screenSize.width > 600
                            ? 400
                            : screenSize.width * 0.9,
                      ),
                      padding: EdgeInsets.all(screenSize.width > 600 ? 32 : 24),
                      child: Form(
                        key: _formKey,
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            // App logo
                            SizedBox(
                              width: 70,
                              height: 70,
                              child: Image.asset(
                                'png/logo.png',
                                fit: BoxFit.contain,
                              ),
                            ),
                            SizedBox(height: 16),
                            // App name with better typography
                            Text(
                              'RoomEase',
                              style: Theme.of(context).textTheme.displayMedium
                                  ?.copyWith(
                                    color: Theme.of(
                                      context,
                                    ).colorScheme.primary,
                                    fontWeight: FontWeight.bold,
                                  ),
                            ),
                            SizedBox(height: 8),
                            // Page title with better styling
                            Text(
                              'Reset Password',
                              style: Theme.of(context).textTheme.bodyLarge
                                  ?.copyWith(
                                    color: Colors.grey[600],
                                    fontWeight: FontWeight.w500,
                                  ),
                            ),
                            SizedBox(height: 24),

                            if (!_emailSent) ...[
                              // Enhanced instructions
                              Container(
                                padding: EdgeInsets.all(16),
                                decoration: BoxDecoration(
                                  color: Theme.of(
                                    context,
                                  ).colorScheme.primary.withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Text(
                                  'Enter your email address and we\'ll send you a link to reset your password.',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    fontSize: 14,
                                    color: Colors.grey[700],
                                    height: 1.4,
                                  ),
                                ),
                              ),
                              SizedBox(height: 24),

                              // Email field
                              TextFormField(
                                controller: _emailController,
                                keyboardType: TextInputType.emailAddress,
                                style: TextStyle(
                                  fontSize: 14,
                                  color: Colors.black,
                                ),
                                decoration: InputDecoration(
                                  labelText: 'Email Address',
                                  labelStyle: TextStyle(
                                    color: Colors.grey[500],
                                    fontSize: 14,
                                    fontWeight: FontWeight.w400,
                                  ),
                                  hintText: 'Enter your email',
                                  hintStyle: TextStyle(
                                    color: Colors.grey[400],
                                    fontSize: 14,
                                  ),
                                  prefixIcon: Icon(
                                    Icons.email_outlined,
                                    color: Theme.of(
                                      context,
                                    ).colorScheme.primary,
                                  ),
                                  filled: true,
                                  fillColor: Colors.grey[50],
                                  contentPadding: EdgeInsets.symmetric(
                                    vertical: 16,
                                    horizontal: 16,
                                  ),
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12),
                                    borderSide: BorderSide(
                                      color: Colors.grey.shade300,
                                      width: 1,
                                    ),
                                  ),
                                  enabledBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12),
                                    borderSide: BorderSide(
                                      color: Colors.grey.shade300,
                                      width: 1,
                                    ),
                                  ),
                                  focusedBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12),
                                    borderSide: BorderSide(
                                      color: Theme.of(
                                        context,
                                      ).colorScheme.primary,
                                      width: 2,
                                    ),
                                  ),
                                  errorBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12),
                                    borderSide: BorderSide(
                                      color: Colors.red,
                                      width: 1,
                                    ),
                                  ),
                                ),
                                validator: (value) {
                                  if (value == null || value.isEmpty) {
                                    return 'Please enter your email';
                                  }
                                  // Simple email validation
                                  if (!value.contains('@')) {
                                    return 'Please enter a valid email';
                                  }
                                  return null;
                                },
                              ),
                              SizedBox(height: 24),

                              // Enhanced reset button
                              _isLoading
                                  ? SizedBox(
                                      height: 50,
                                      child: Center(
                                        child: CircularProgressIndicator(
                                          color: Theme.of(
                                            context,
                                          ).colorScheme.primary,
                                        ),
                                      ),
                                    )
                                  : ElevatedButton(
                                      onPressed: _resetPassword,
                                      style: ElevatedButton.styleFrom(
                                        minimumSize: Size(double.infinity, 50),
                                        backgroundColor: Theme.of(
                                          context,
                                        ).colorScheme.primary,
                                        foregroundColor: Colors.white,
                                        elevation: 2,
                                        shadowColor: Theme.of(context)
                                            .colorScheme
                                            .primary
                                            .withValues(alpha: 0.3),
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(
                                            12,
                                          ),
                                        ),
                                      ),
                                      child: Text(
                                        'Send Reset Link',
                                        style: TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ),
                            ] else ...[
                              // Enhanced success message
                              Container(
                                padding: EdgeInsets.all(24),
                                decoration: BoxDecoration(
                                  color: Colors.green.withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(16),
                                ),
                                child: Column(
                                  children: [
                                    Container(
                                      padding: EdgeInsets.all(16),
                                      decoration: BoxDecoration(
                                        color: Colors.green,
                                        borderRadius: BorderRadius.circular(50),
                                      ),
                                      child: Icon(
                                        Icons.check,
                                        size: 32,
                                        color: Colors.white,
                                      ),
                                    ),
                                    SizedBox(height: 16),
                                    Text(
                                      'Email Sent Successfully!',
                                      style: TextStyle(
                                        fontSize: 20,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.green[700],
                                      ),
                                    ),
                                    SizedBox(height: 12),
                                    Text(
                                      'We\'ve sent a password reset link to your email address. Please check your inbox and follow the instructions.',
                                      textAlign: TextAlign.center,
                                      style: TextStyle(
                                        fontSize: 14,
                                        color: Colors.grey[700],
                                        height: 1.4,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              SizedBox(height: 24),
                              ElevatedButton(
                                onPressed: () => Navigator.pushReplacementNamed(
                                  context,
                                  '/login',
                                ),
                                style: ElevatedButton.styleFrom(
                                  minimumSize: Size(double.infinity, 50),
                                  backgroundColor: Theme.of(
                                    context,
                                  ).colorScheme.primary,
                                  foregroundColor: Colors.white,
                                  elevation: 2,
                                  shadowColor: Theme.of(
                                    context,
                                  ).colorScheme.primary.withValues(alpha: 0.3),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                ),
                                child: Text(
                                  'Back to Sign In',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            ],

                            SizedBox(height: 24),

                            // Enhanced login link
                            if (!_emailSent)
                              Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Text(
                                    "Remember your password? ",
                                    style: TextStyle(
                                      color: Colors.grey[600],
                                      fontSize: 14,
                                    ),
                                  ),
                                  TextButton(
                                    onPressed: () {
                                      Navigator.pushReplacementNamed(
                                        context,
                                        '/login',
                                      );
                                    },
                                    style: TextButton.styleFrom(
                                      padding: EdgeInsets.symmetric(
                                        horizontal: 8,
                                        vertical: 4,
                                      ),
                                      minimumSize: Size(40, 30),
                                      tapTargetSize:
                                          MaterialTapTargetSize.shrinkWrap,
                                    ),
                                    child: Text(
                                      'Sign In',
                                      style: TextStyle(
                                        fontSize: 14,
                                        fontWeight: FontWeight.w600,
                                        color: Theme.of(
                                          context,
                                        ).colorScheme.primary,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
