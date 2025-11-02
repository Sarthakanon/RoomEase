import 'package:flutter/material.dart';

// Simple forgot password screen for RoomEase app
class ForgotPasswordScreen extends StatefulWidget {
  const ForgotPasswordScreen({Key? key}) : super(key: key);

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

  // Reset password function
  void _resetPassword() {
    // Check if form is valid
    if (_formKey.currentState!.validate()) {
      // Show loading
      setState(() {
        _isLoading = true;
      });

      // Mock password reset - connect to Firebase
      Future.delayed(const Duration(seconds: 1), () {
        setState(() {
          _isLoading = false;
          _emailSent = true;
        });
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    // Get screen size for responsive design
    final screenSize = MediaQuery.of(context).size;
    
    return Scaffold(
      // Apply background color to entire scaffold
      backgroundColor: Theme.of(context).colorScheme.primary.withOpacity(0.7),
      // Add app bar with back button

      body: Container(
        // Full-screen gradient background
        width: double.infinity,
        height: double.infinity,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Theme.of(context).colorScheme.primary.withOpacity(0.7),
              Theme.of(context).colorScheme.primary.withOpacity(0.5),
            ],
          ),
        ),
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: EdgeInsets.symmetric(
                // Responsive horizontal padding
                horizontal: screenSize.width * 0.05,
              ),
              child: Card(
                // Smaller elevation for subtle shadow
                elevation: 4,
                // Responsive width constraint
                child: Container(
                  constraints: BoxConstraints(
                    maxWidth: screenSize.width > 600 ? 400 : screenSize.width * 0.9,
                  ),
                  padding: EdgeInsets.all(16),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // App icon
                        Icon(
                          Icons.apartment_rounded,
                          size: 50,
                          color: Colors.indigo,
                        ),
                        SizedBox(height: 10),
                        // App name
                        Text(
                          'RoomEase',
                          style: TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                            color: Colors.indigo,
                          ),
                        ),
                        SizedBox(height: 4),
                        // Page title
                        Text(
                          'Forgot Password',
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.grey[600],
                          ),
                        ),
                        SizedBox(height: 16),
                        
                        if (!_emailSent) ...[
                          // Instructions
                          Text(
                            'Enter your email and we\'ll send you a link to reset your password.',
                            textAlign: TextAlign.center,
                            style: TextStyle(fontSize: 13),
                          ),
                          SizedBox(height: 16),
                          
                          // Email field
                          TextFormField(
                            controller: _emailController,
                            keyboardType: TextInputType.emailAddress,
                            decoration: InputDecoration(
                              labelText: 'Email',
                              hintText: 'Enter your email',
                              prefixIcon: Icon(
                                Icons.email,
                                size: 18,
                              ),
                              contentPadding: EdgeInsets.symmetric(vertical: 10, horizontal: 10),
                              border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                              borderSide: BorderSide(color: Colors.grey.shade300, width: 1),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                              borderSide: BorderSide(color: Colors.grey.shade300, width: 1),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                              borderSide: BorderSide(color: Theme.of(context).colorScheme.primary, width: 1.5),
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
                          SizedBox(height: 20),
                          
                          // Reset button
                          _isLoading
                              ? CircularProgressIndicator()
                              : ElevatedButton(
                                  onPressed: _resetPassword,
                                  style: ElevatedButton.styleFrom(
                                    minimumSize: Size(double.infinity, 40),
                                  ),
                                  child: Text(
                                    'Reset Password',
                                    style: TextStyle(fontSize: 14),
                                  ),
                                ),
                        ] else ...[
                          // Success message
                          Icon(
                            Icons.check_circle_outline,
                            size: 60,
                            color: Colors.green,
                          ),
                          SizedBox(height: 16),
                          Text(
                            'Email Sent!',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          SizedBox(height: 8),
                          Text(
                            'Check your inbox for a link to reset your password.',
                            textAlign: TextAlign.center,
                            style: TextStyle(fontSize: 13),
                          ),
                          SizedBox(height: 20),
                          ElevatedButton(
                            onPressed: () => Navigator.pushReplacementNamed(context, '/login'),
                            style: ElevatedButton.styleFrom(
                              minimumSize: Size(double.infinity, 40),
                            ),
                            child: Text(
                              'Back to Login',
                              style: TextStyle(fontSize: 14),
                            ),
                          ),
                        ],
                        
                        SizedBox(height: 12),
                        
                        // Login link
                        if (!_emailSent)
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text("Remember your password?"),
                              TextButton(
                                onPressed: () {
                                  Navigator.pushReplacementNamed(context, '/login');
                                },
                                style: TextButton.styleFrom(
                                  padding: EdgeInsets.only(left: 4),
                                  minimumSize: Size(50, 30),
                                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                ),
                                child: Text('Login'),
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
    );
  }
}