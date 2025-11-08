import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class JoinRoomspaceScreen extends StatefulWidget {
  const JoinRoomspaceScreen({super.key});

  @override
  State<JoinRoomspaceScreen> createState() => _JoinRoomspaceScreenState();
}

class _JoinRoomspaceScreenState extends State<JoinRoomspaceScreen> {
  final _formKey = GlobalKey<FormState>();
  final _roomIdController = TextEditingController();
  
  bool _isLoading = false;
  bool _roomFound = false;
  Map<String, dynamic>? _roomDetails;

  // Mock room data for demonstration
  final Map<String, Map<String, dynamic>> _mockRooms = {
    'ABC12345': {
      'name': 'Downtown Apartment',
      'address': '123 Main St, City Center',
      'members': 2,
      'maxMembers': 4,
      'description': 'Cozy apartment in the heart of the city',
    },
    'XYZ67890': {
      'name': 'College Dorm',
      'address': 'University Campus, Building A',
      'members': 1,
      'maxMembers': 3,
      'description': 'Student housing near campus',
    },
  };

  void _searchRoom() {
    if (_formKey.currentState!.validate()) {
      setState(() {
        _isLoading = true;
        _roomFound = false;
        _roomDetails = null;
      });

      // Mock search process
      Future.delayed(const Duration(seconds: 1), () {
        if (mounted) {
          final roomId = _roomIdController.text.toUpperCase();
          final room = _mockRooms[roomId];
          
          setState(() {
            _isLoading = false;
            _roomFound = room != null;
            _roomDetails = room;
          });
        }
      });
    }
  }

  void _joinRoom() {
    setState(() {
      _isLoading = true;
    });

    // Mock join process
    Future.delayed(const Duration(seconds: 2), () {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
        
        // Show success and navigate
        _showSuccessDialog();
      }
    });
  }

  void _showSuccessDialog() {
    final screenSize = MediaQuery.of(context).size;
    
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Container(
          constraints: BoxConstraints(
            maxWidth: screenSize.width * 0.9,
            maxHeight: screenSize.height * 0.8,
          ),
          padding: EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Title section
              SizedBox(
                width: double.infinity,
                child: Row(
                  children: [
                    Container(
                      padding: EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.green.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(
                        Icons.check_circle,
                        color: Colors.green,
                        size: 24,
                      ),
                    ),
                    SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'Welcome!',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: Colors.black87,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              
              SizedBox(height: 20),
              
              // Content section
              SizedBox(
                width: double.infinity,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: double.infinity,
                      padding: EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.green.shade50,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.green.shade200),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Successfully Joined!',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              color: Colors.green.shade700,
                            ),
                          ),
                          SizedBox(height: 8),
                          Text(
                            'You have successfully joined "${_roomDetails!['name']}". Your roommates will be notified.',
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.green.shade600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              
              SizedBox(height: 24),
              
              // Action button
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () {
                    Navigator.of(context).pop();
                    Navigator.pushReplacementNamed(context, '/home');
                  },
                  style: ElevatedButton.styleFrom(
                    minimumSize: Size(double.infinity, 50),
                    backgroundColor: Colors.green,
                    foregroundColor: Colors.white,
                    elevation: 2,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: Text(
                    'Continue to Home',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
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
        backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: Text('Join Roomspace'),
        backgroundColor: Colors.transparent,
        elevation: 0,
        foregroundColor: Theme.of(context).colorScheme.primary,
        systemOverlayStyle: SystemUiOverlayStyle(
          statusBarColor: Colors.transparent,
          statusBarIconBrightness: Brightness.dark,
          statusBarBrightness: Brightness.light,
        ),
      ),
      body: SizedBox(
        width: double.infinity,
        height: double.infinity,
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: EdgeInsets.symmetric(
                horizontal: screenSize.width * 0.05,
              ),
              child: Card(
                elevation: 8,
                shadowColor: Theme.of(context).colorScheme.primary.withValues(alpha: 0.2),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Container(
                  constraints: BoxConstraints(
                    maxWidth: screenSize.width > 600 ? 400 : screenSize.width * 0.9,
                  ),
                  padding: EdgeInsets.all(screenSize.width > 600 ? 32 : 24),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // Header
                        Container(
                          padding: EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: Theme.of(context).colorScheme.primary,
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Icon(
                            Icons.group_add_rounded,
                            size: 40,
                            color: Colors.white,
                          ),
                        ),
                        SizedBox(height: 16),
                        Text(
                          'Join Roomspace',
                          style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                            color: Theme.of(context).colorScheme.primary,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        SizedBox(height: 8),
                        Text(
                          'Enter the Room ID shared by your roommate',
                          style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                            color: Colors.grey[600],
                            fontWeight: FontWeight.w500,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        SizedBox(height: 24),
                        
                        // Room ID field
                        SizedBox(
                          width: double.infinity,
                          child: TextFormField(
                            controller: _roomIdController,
                            textCapitalization: TextCapitalization.characters,
                            decoration: InputDecoration(
                              labelText: 'Room ID',
                              hintText: 'e.g., ABC12345',
                              prefixIcon: Icon(
                                Icons.key_outlined,
                                color: Theme.of(context).colorScheme.primary,
                              ),
                              filled: true,
                              fillColor: Colors.grey[50],
                              contentPadding: EdgeInsets.symmetric(vertical: 16, horizontal: 12),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: BorderSide(color: Colors.grey.shade300),
                              ),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: BorderSide(color: Colors.grey.shade300),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: BorderSide(color: Theme.of(context).colorScheme.primary, width: 2),
                              ),
                            ),
                            validator: (value) {
                              if (value == null || value.isEmpty) {
                                return 'Please enter a Room ID';
                              }
                              if (value.length < 6) {
                                return 'Room ID must be at least 6 characters';
                              }
                              return null;
                            },
                            onChanged: (value) {
                              if (_roomFound) {
                                setState(() {
                                  _roomFound = false;
                                  _roomDetails = null;
                                });
                              }
                            },
                          ),
                        ),
                        SizedBox(height: 16),
                        
                        // Search button
                        if (!_roomFound)
                          SizedBox(
                            width: double.infinity,
                            child: _isLoading
                                ? SizedBox(
                                    height: 50,
                                    child: Center(
                                      child: CircularProgressIndicator(
                                        color: Theme.of(context).colorScheme.primary,
                                      ),
                                    ),
                                  )
                                : ElevatedButton(
                                    onPressed: _searchRoom,
                                    style: ElevatedButton.styleFrom(
                                      minimumSize: Size(double.infinity, 50),
                                      backgroundColor: Theme.of(context).colorScheme.primary,
                                      foregroundColor: Colors.white,
                                      elevation: 2,
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                    ),
                                    child: Text(
                                      'Search Room',
                                      style: TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ),
                          ),
                        
                        // Room details card
                        if (_roomFound && _roomDetails != null) ...[
                          SizedBox(height: 16),
                          Container(
                            width: double.infinity,
                            padding: EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: Colors.green.shade50,
                              border: Border.all(color: Colors.green.shade200),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Icon(
                                      Icons.check_circle,
                                      color: Colors.green,
                                      size: 20,
                                    ),
                                    SizedBox(width: 8),
                                    Text(
                                      'Room Found!',
                                      style: TextStyle(
                                        color: Colors.green.shade700,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ],
                                ),
                                SizedBox(height: 12),
                                Text(
                                  _roomDetails!['name'],
                                  style: TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.black87,
                                  ),
                                ),
                                SizedBox(height: 4),
                                Text(
                                  _roomDetails!['address'],
                                  style: TextStyle(
                                    color: Colors.grey[600],
                                    fontSize: 14,
                                  ),
                                ),
                                SizedBox(height: 8),
                                Row(
                                  children: [
                                    Icon(
                                      Icons.people_outline,
                                      size: 16,
                                      color: Colors.grey[600],
                                    ),
                                    SizedBox(width: 4),
                                    Text(
                                      '${_roomDetails!['members']}/${_roomDetails!['maxMembers']} members',
                                      style: TextStyle(
                                        color: Colors.grey[600],
                                        fontSize: 14,
                                      ),
                                    ),
                                  ],
                                ),
                                if (_roomDetails!['description'] != null) ...[
                                  SizedBox(height: 8),
                                  Text(
                                    _roomDetails!['description'],
                                    style: TextStyle(
                                      color: Colors.grey[700],
                                      fontSize: 14,
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),
                          SizedBox(height: 16),
                          
                          // Join button
                          SizedBox(
                            width: double.infinity,
                            child: _isLoading
                                ? SizedBox(
                                    height: 50,
                                    child: Center(
                                      child: CircularProgressIndicator(
                                        color: Theme.of(context).colorScheme.primary,
                                      ),
                                    ),
                                  )
                                : ElevatedButton(
                                    onPressed: _joinRoom,
                                    style: ElevatedButton.styleFrom(
                                      minimumSize: Size(double.infinity, 50),
                                      backgroundColor: Colors.green,
                                      foregroundColor: Colors.white,
                                      elevation: 2,
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                    ),
                                    child: Text(
                                      'Join Roomspace',
                                      style: TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ),
                          ),
                        ],
                        
                        // Error message for room not found
                        if (!_isLoading && _roomIdController.text.isNotEmpty && !_roomFound && _roomDetails == null) ...[
                          SizedBox(height: 16),
                          Container(
                            width: double.infinity,
                            padding: EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Colors.red.shade50,
                              border: Border.all(color: Colors.red.shade200),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Row(
                              children: [
                                Icon(
                                  Icons.error_outline,
                                  color: Colors.red,
                                  size: 20,
                                ),
                                SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    'Room not found. Please check the Room ID and try again.',
                                    style: TextStyle(
                                      color: Colors.red.shade700,
                                      fontSize: 14,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                        
                        SizedBox(height: 16),
                        
                        // Help text
                        Container(
                          padding: EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.blue.shade50,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Row(
                            children: [
                              Icon(
                                Icons.info_outline,
                                color: Colors.blue,
                                size: 20,
                              ),
                              SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  'Ask your roommate for the Room ID. Try "ABC12345" or "XYZ67890" for demo.',
                                  style: TextStyle(
                                    color: Colors.blue.shade700,
                                    fontSize: 12,
                                  ),
                                ),
                              ),
                            ],
                          ),
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
    );
  }

  @override
  void dispose() {
    _roomIdController.dispose();
    super.dispose();
  }
}