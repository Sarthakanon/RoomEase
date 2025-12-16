import 'package:flutter/material.dart';
import '../../../models/payment_notification.dart';
import '../../../services/payment_notification_service.dart';
import '../../../services/payment_parser_service.dart';
import '../../notifications/presentation/payment_history_screen.dart';

class PaymentNotificationSettingsScreen extends StatefulWidget {
  const PaymentNotificationSettingsScreen({super.key});

  @override
  State<PaymentNotificationSettingsScreen> createState() => _PaymentNotificationSettingsScreenState();
}

class _PaymentNotificationSettingsScreenState extends State<PaymentNotificationSettingsScreen> {
  final PaymentNotificationService _service = PaymentNotificationService.instance;
  late PaymentNotificationSettings _settings;
  bool _isLoading = true;
  Map<String, bool> _permissions = {};
  Map<String, dynamic> _stats = {};

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    try {
      _settings = _service.settings;
      _permissions = await _service.checkPermissions();
      _stats = await _service.getTransactionStats();
      setState(() {
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      _showError('Failed to load settings: $e');
    }
  }

  Future<void> _saveSettings() async {
    try {
      await _service.updateSettings(_settings);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Settings saved successfully'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      _showError('Failed to save settings: $e');
    }
  }

  Future<void> _requestPermissions() async {
    try {
      final newPermissions = await _service.requestPermissions();
      setState(() {
        _permissions = newPermissions;
      });
    } catch (e) {
      _showError('Failed to request permissions: $e');
    }
  }

  void _showError(String message) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Payment Notifications'),
        actions: [
          IconButton(
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const PaymentHistoryScreen(),
                ),
              );
            },
            icon: const Icon(Icons.history),
            tooltip: 'Payment History',
          ),
          TextButton(
            onPressed: _saveSettings,
            child: const Text('Save', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _buildMainToggle(),
          const SizedBox(height: 24),
          _buildPermissionsSection(),
          const SizedBox(height: 24),
          _buildMonitoringOptions(),
          const SizedBox(height: 24),
          _buildAmountSettings(),
          const SizedBox(height: 24),
          _buildAppSettings(),
          const SizedBox(height: 24),
          _buildMerchantSettings(),
          const SizedBox(height: 24),
          _buildTestSection(),
          const SizedBox(height: 24),
          _buildStatsSection(),
        ],
      ),
    );
  }

  Widget _buildTestSection() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.bug_report, color: Theme.of(context).primaryColor),
                const SizedBox(width: 12),
                const Text(
                  'Test Payment Detection',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
              ],
            ),
            const SizedBox(height: 8),
            const Text(
              'Test the payment detection system with sample notifications',
              style: TextStyle(color: Colors.grey),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _testPaymentDetection,
                icon: const Icon(Icons.play_arrow),
                label: const Text('Test Notification Detection'),
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _testSmsDetection,
                icon: const Icon(Icons.sms),
                label: const Text('Test SMS Detection'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _testPaymentDetection() async {
    try {
      // Create a test payment notification
      final testNotification = PaymentNotification(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        source: 'test',
        appName: 'eSewa',
        rawText: 'Payment to Bhatbhateni Supermarket of Rs. 2,500.00 successful via eSewa',
        amount: 2500.00,
        merchant: 'Bhatbhateni Supermarket',
        timestamp: DateTime.now(),
        type: PaymentType.debit,
      );

      // Process the test notification
      await _service.processPaymentNotification(testNotification);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Test notification sent! Check your notifications.'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Test failed: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Widget _buildMainToggle() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.notifications_active, color: Theme.of(context).primaryColor),
                const SizedBox(width: 12),
                const Expanded(
                  child: Text(
                    'Payment Detection',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                ),
                Switch(
                  value: _settings.isEnabled,
                  onChanged: (value) {
                    setState(() {
                      _settings = _settings.copyWith(isEnabled: value);
                    });
                  },
                ),
              ],
            ),
            const SizedBox(height: 8),
            const Text(
              'Automatically detect payments and suggest adding them as RoomEase expenses',
              style: TextStyle(color: Colors.grey),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPermissionsSection() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.security, color: Theme.of(context).primaryColor),
                const SizedBox(width: 12),
                const Text(
                  'Permissions',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
              ],
            ),
            const SizedBox(height: 16),
            _buildPermissionItem(
              'Notification Access',
              'Required to read payment notifications from banking apps',
              _permissions['notification'] ?? false,
            ),
            const SizedBox(height: 12),
            _buildPermissionItem(
              'SMS Access',
              'Required to read bank transaction SMS messages',
              _permissions['sms'] ?? false,
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _requestPermissions,
                icon: const Icon(Icons.settings),
                label: const Text('Grant Permissions'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPermissionItem(String title, String description, bool granted) {
    return Row(
      children: [
        Icon(
          granted ? Icons.check_circle : Icons.cancel,
          color: granted ? Colors.green : Colors.red,
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: const TextStyle(fontWeight: FontWeight.w500)),
              Text(description, style: const TextStyle(fontSize: 12, color: Colors.grey)),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildMonitoringOptions() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.monitor, color: Theme.of(context).primaryColor),
                const SizedBox(width: 12),
                const Text(
                  'Monitoring Options',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
              ],
            ),
            const SizedBox(height: 16),
            SwitchListTile(
              title: const Text('App Notifications'),
              subtitle: const Text('Monitor notifications from banking and payment apps'),
              value: _settings.notificationMonitoringEnabled,
              onChanged: _settings.isEnabled ? (value) {
                setState(() {
                  _settings = _settings.copyWith(notificationMonitoringEnabled: value);
                });
              } : null,
            ),
            SwitchListTile(
              title: const Text('SMS Messages'),
              subtitle: const Text('Monitor SMS messages from banks and payment services'),
              value: _settings.smsMonitoringEnabled,
              onChanged: _settings.isEnabled ? (value) {
                setState(() {
                  _settings = _settings.copyWith(smsMonitoringEnabled: value);
                });
              } : null,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAmountSettings() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.attach_money, color: Theme.of(context).primaryColor),
                const SizedBox(width: 12),
                const Text(
                  'Amount Filter',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
              ],
            ),
            const SizedBox(height: 16),
            TextFormField(
              initialValue: _settings.minimumAmount.toString(),
              decoration: const InputDecoration(
                labelText: 'Minimum Amount (Rs.)',
                helperText: 'Only suggest expenses for payments above this amount',
                border: OutlineInputBorder(),
              ),
              keyboardType: TextInputType.number,
              enabled: _settings.isEnabled,
              onChanged: (value) {
                final amount = double.tryParse(value) ?? 0.0;
                _settings = _settings.copyWith(minimumAmount: amount);
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAppSettings() {
    final allApps = [
      ...PaymentParserService.supportedApps['banking']!,
      ...PaymentParserService.supportedApps['payment']!,
    ];

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.apps, color: Theme.of(context).primaryColor),
                const SizedBox(width: 12),
                const Text(
                  'Enabled Apps',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
              ],
            ),
            const SizedBox(height: 8),
            const Text(
              'Select which apps should trigger expense suggestions (leave empty for all)',
              style: TextStyle(color: Colors.grey),
            ),
            const SizedBox(height: 16),
            ...allApps.map((app) => CheckboxListTile(
              title: Text(app),
              value: _settings.enabledApps.isEmpty || _settings.enabledApps.contains(app),
              onChanged: _settings.isEnabled ? (value) {
                setState(() {
                  final newApps = List<String>.from(_settings.enabledApps);
                  if (value == true) {
                    if (!newApps.contains(app)) {
                      newApps.add(app);
                    }
                  } else {
                    newApps.remove(app);
                  }
                  _settings = _settings.copyWith(enabledApps: newApps);
                });
              } : null,
            )),
          ],
        ),
      ),
    );
  }

  Widget _buildMerchantSettings() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.store, color: Theme.of(context).primaryColor),
                const SizedBox(width: 12),
                const Text(
                  'Merchant Filter',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
              ],
            ),
            const SizedBox(height: 8),
            const Text(
              'Add specific merchants that should trigger expense suggestions',
              style: TextStyle(color: Colors.grey),
            ),
            const SizedBox(height: 16),
            TextFormField(
              decoration: const InputDecoration(
                labelText: 'Add Merchant',
                hintText: 'e.g., Bhatbhateni, KFC, etc.',
                border: OutlineInputBorder(),
                suffixIcon: Icon(Icons.add),
              ),
              enabled: _settings.isEnabled,
              onFieldSubmitted: (value) {
                if (value.trim().isNotEmpty) {
                  setState(() {
                    final newMerchants = List<String>.from(_settings.enabledMerchants);
                    if (!newMerchants.contains(value.trim())) {
                      newMerchants.add(value.trim());
                      _settings = _settings.copyWith(enabledMerchants: newMerchants);
                    }
                  });
                }
              },
            ),
            const SizedBox(height: 16),
            if (_settings.enabledMerchants.isNotEmpty)
              Wrap(
                spacing: 8,
                children: _settings.enabledMerchants.map((merchant) => Chip(
                  label: Text(merchant),
                  deleteIcon: const Icon(Icons.close, size: 18),
                  onDeleted: _settings.isEnabled ? () {
                    setState(() {
                      final newMerchants = List<String>.from(_settings.enabledMerchants);
                      newMerchants.remove(merchant);
                      _settings = _settings.copyWith(enabledMerchants: newMerchants);
                    });
                  } : null,
                )).toList(),
              ),
          ],
        ),
      ),
    );
  }

  Future<void> _testSmsDetection() async {
    // Show dialog to enter SMS text
    final controller = TextEditingController();
    
    final result = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Test SMS Detection'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Paste your bank/eSewa SMS message here:'),
            const SizedBox(height: 16),
            TextField(
              controller: controller,
              maxLines: 3,
              decoration: const InputDecoration(
                hintText: 'e.g., Dear Customer, Rs. 500.00 has been debited from your account for payment to ABC Store via eSewa.',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, controller.text),
            child: const Text('Test'),
          ),
        ],
      ),
    );

    if (result != null && result.isNotEmpty) {
      try {
        // Test the SMS parsing
        final testNotification = PaymentNotification(
          id: DateTime.now().millisecondsSinceEpoch.toString(),
          source: 'sms_test',
          appName: 'Test Bank',
          rawText: result,
          amount: _extractAmountFromText(result),
          merchant: _extractMerchantFromText(result),
          timestamp: DateTime.now(),
          type: PaymentType.debit,
        );

        await _service.processPaymentNotification(testNotification);

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('SMS test processed! Check notifications.'),
              backgroundColor: Colors.green,
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('SMS test failed: $e'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }

  double? _extractAmountFromText(String text) {
    // Simple amount extraction for testing
    final patterns = [
      r'Rs\.?\s*([0-9,]+(?:\.[0-9]{2})?)',
      r'([0-9,]+(?:\.[0-9]{2})?)\s*Rs',
      r'NPR\s*([0-9,]+(?:\.[0-9]{2})?)',
    ];

    for (final pattern in patterns) {
      final regex = RegExp(pattern, caseSensitive: false);
      final match = regex.firstMatch(text);
      
      if (match != null) {
        String amountStr = match.group(1)!;
        amountStr = amountStr.replaceAll(',', '');
        final amount = double.tryParse(amountStr);
        if (amount != null && amount > 0) {
          return amount;
        }
      }
    }
    return null;
  }

  String? _extractMerchantFromText(String text) {
    // Simple merchant extraction for testing
    final patterns = [
      r'payment to (.+?)(?:\s|$|\.)',
      r'to (.+?) via',
      r'at (.+?)(?:\s|$|\.)',
    ];

    for (final pattern in patterns) {
      final regex = RegExp(pattern, caseSensitive: false);
      final match = regex.firstMatch(text);
      
      if (match != null) {
        final merchant = match.group(1)?.trim();
        if (merchant != null && merchant.length > 2) {
          return merchant;
        }
      }
    }
    return null;
  }

  Widget _buildStatsSection() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.analytics, color: Theme.of(context).primaryColor),
                const SizedBox(width: 12),
                const Text(
                  'Detection Statistics',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: _buildStatItem(
                    'Total Detected',
                    '${_stats['total'] ?? 0}',
                    Icons.receipt_long,
                  ),
                ),
                Expanded(
                  child: _buildStatItem(
                    'Last 24 Hours',
                    '${_stats['last24Hours'] ?? 0}',
                    Icons.today,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _buildStatItem(
                    'Last Week',
                    '${_stats['lastWeek'] ?? 0}',
                    Icons.date_range,
                  ),
                ),
                Expanded(
                  child: _buildStatItem(
                    'SMS Detected',
                    '${(_stats['bySource'] as Map<String, dynamic>?)?['sms'] ?? 0}',
                    Icons.sms,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () async {
                  await _service.clearTransactionHistory();
                  await _loadSettings();
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Transaction history cleared'),
                      backgroundColor: Colors.orange,
                    ),
                  );
                },
                icon: const Icon(Icons.clear_all),
                label: const Text('Clear History'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatItem(String label, String value, IconData icon) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.grey[50],
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        children: [
          Icon(icon, color: Theme.of(context).primaryColor, size: 20),
          const SizedBox(height: 4),
          Text(
            value,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey[600],
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

}