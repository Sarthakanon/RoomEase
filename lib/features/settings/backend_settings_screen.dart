import 'package:flutter/material.dart';
import '../../core/constants.dart';
import '../../services/api_service.dart';

class BackendSettingsScreen extends StatefulWidget {
  const BackendSettingsScreen({super.key});

  @override
  State<BackendSettingsScreen> createState() => _BackendSettingsScreenState();
}

class _BackendSettingsScreenState extends State<BackendSettingsScreen> {
  final _formKey = GlobalKey<FormState>();
  final _ipController = TextEditingController();
  bool _isLoading = true;
  bool _isSaving = false;
  String? _connectionStatus;

  @override
  void initState() {
    super.initState();
    _loadCurrentIp();
  }

  Future<void> _loadCurrentIp() async {
    final ip = await AppConstants.getBackendIp();
    setState(() {
      _ipController.text = ip;
      _isLoading = false;
    });
  }

  Future<void> _testConnection() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isSaving = true;
      _connectionStatus = null;
    });

    try {
      final testIp = _ipController.text.trim();
      final apiService = ApiService();
      
      // Temporarily update the IP to test
      await apiService.updateBackendIp(testIp);
      
      // Try to hit the health endpoint
      final response = await apiService.dio.get('/health').timeout(
        const Duration(seconds: 5),
      );

      if (response.statusCode == 200) {
        setState(() {
          _connectionStatus = 'success';
          _isSaving = false;
        });
        
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('✓ Connected successfully!'),
              backgroundColor: Colors.green,
            ),
          );
        }
      }
    } catch (e) {
      setState(() {
        _connectionStatus = 'failed';
        _isSaving = false;
      });
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('✗ Connection failed: ${e.toString()}'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 4),
          ),
        );
      }
    }
  }

  Future<void> _saveAndClose() async {
    if (_connectionStatus != 'success') {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please test the connection first'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    Navigator.pop(context, true);
  }

  Future<void> _resetToDefault() async {
    setState(() {
      _ipController.text = AppConstants.defaultBackendIp;
      _connectionStatus = null;
    });
  }

  @override
  void dispose() {
    _ipController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Backend Settings'),
        elevation: 0,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Info card
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.blue.shade50,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.blue.shade100),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.info_outline, color: Colors.blue.shade700),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              'Enter your backend server IP address. Find it by running "hostname -I" on your server.',
                              style: TextStyle(
                                fontSize: 13,
                                color: Colors.blue.shade900,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 24),

                    // IP Address field
                    const Text(
                      'Backend IP Address',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextFormField(
                      controller: _ipController,
                      decoration: InputDecoration(
                        hintText: '192.168.1.89',
                        prefixIcon: const Icon(Icons.computer),
                        suffixIcon: _connectionStatus != null
                            ? Icon(
                                _connectionStatus == 'success'
                                    ? Icons.check_circle
                                    : Icons.error,
                                color: _connectionStatus == 'success'
                                    ? Colors.green
                                    : Colors.red,
                              )
                            : null,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      keyboardType: TextInputType.number,
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Please enter an IP address';
                        }
                        // Basic IP validation
                        final parts = value.split('.');
                        if (parts.length != 4) {
                          return 'Invalid IP format (e.g., 192.168.1.89)';
                        }
                        for (final part in parts) {
                          final num = int.tryParse(part);
                          if (num == null || num < 0 || num > 255) {
                            return 'Invalid IP format';
                          }
                        }
                        return null;
                      },
                      onChanged: (_) {
                        setState(() {
                          _connectionStatus = null;
                        });
                      },
                    ),

                    const SizedBox(height: 12),

                    // Port info
                    Text(
                      'Port: ${AppConstants.backendPort}',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey.shade600,
                      ),
                    ),

                    const SizedBox(height: 24),

                    // Test Connection button
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: _isSaving ? null : _testConnection,
                        icon: _isSaving
                            ? const SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : const Icon(Icons.wifi_find),
                        label: Text(_isSaving ? 'Testing...' : 'Test Connection'),
                        style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                      ),
                    ),

                    const SizedBox(height: 12),

                    // Save button
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton.icon(
                        onPressed: _connectionStatus == 'success' ? _saveAndClose : null,
                        icon: const Icon(Icons.save),
                        label: const Text('Save & Close'),
                        style: FilledButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                      ),
                    ),

                    const SizedBox(height: 12),

                    // Reset button
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        onPressed: _resetToDefault,
                        icon: const Icon(Icons.refresh),
                        label: const Text('Reset to Default'),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                      ),
                    ),

                    const SizedBox(height: 32),

                    // Help section
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.grey.shade50,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.grey.shade200),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(Icons.help_outline, 
                                size: 18, 
                                color: Colors.grey.shade700),
                              const SizedBox(width: 8),
                              Text(
                                'How to find your IP',
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.grey.shade800,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          _buildHelpItem('Linux/Mac', 'hostname -I'),
                          _buildHelpItem('Windows', 'ipconfig'),
                          const SizedBox(height: 8),
                          Text(
                            'Make sure your phone and backend are on the same WiFi network.',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey.shade600,
                              fontStyle: FontStyle.italic,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildHelpItem(String platform, String command) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.grey.shade200,
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text(
              platform,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: Colors.grey.shade700,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Text(
            command,
            style: TextStyle(
              fontSize: 12,
              fontFamily: 'monospace',
              color: Colors.grey.shade700,
            ),
          ),
        ],
      ),
    );
  }
}
