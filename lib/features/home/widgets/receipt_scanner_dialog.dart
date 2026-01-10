import 'package:flutter/material.dart';
import '../../../services/ocr_service.dart';

class ReceiptScannerDialog extends StatefulWidget {
  final Function(OcrScanResult) onScanComplete;

  const ReceiptScannerDialog({
    super.key,
    required this.onScanComplete,
  });

  static Future<OcrScanResult?> show(BuildContext context) async {
    return showModalBottomSheet<OcrScanResult>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => ReceiptScannerDialog(
        onScanComplete: (result) {
          Navigator.pop(context, result);
        },
      ),
    );
  }

  @override
  State<ReceiptScannerDialog> createState() => _ReceiptScannerDialogState();
}

class _ReceiptScannerDialogState extends State<ReceiptScannerDialog> {
  final OcrService _ocrService = OcrService();
  bool _isScanning = false;
  String? _error;
  bool _showSettingsButton = false;

  Future<void> _scanFromCamera() async {
    setState(() {
      _isScanning = true;
      _error = null;
      _showSettingsButton = false;
    });

    try {
      final result = await _ocrService.scanFromCamera();
      if (result != null) {
        if (result.hasData) {
          widget.onScanComplete(result);
        } else {
          _showResultDialog(result);
        }
      }
    } on PermissionDeniedException catch (e) {
      setState(() {
        _error = e.message;
        _showSettingsButton = e.isPermanent;
      });
    } catch (e) {
      setState(() {
        _error = 'Failed to scan: ${e.toString()}';
        _showSettingsButton = false;
      });
    } finally {
      setState(() {
        _isScanning = false;
      });
    }
  }

  Future<void> _scanFromGallery() async {
    setState(() {
      _isScanning = true;
      _error = null;
      _showSettingsButton = false;
    });

    try {
      final result = await _ocrService.scanFromGallery();
      if (result != null) {
        if (result.hasData) {
          widget.onScanComplete(result);
        } else {
          _showResultDialog(result);
        }
      }
    } on PermissionDeniedException catch (e) {
      setState(() {
        _error = e.message;
        _showSettingsButton = e.isPermanent;
      });
    } catch (e) {
      setState(() {
        _error = 'Failed to scan: ${e.toString()}';
        _showSettingsButton = false;
      });
    } finally {
      setState(() {
        _isScanning = false;
      });
    }
  }

  Future<void> _openSettings() async {
    await _ocrService.openSettings();
  }

  void _showResultDialog(OcrScanResult result) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Scan Result'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (result.amount != null) ...[
                Text('Amount: Rs. ${result.amount!.toStringAsFixed(2)}',
                    style: const TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
              ],
              if (result.merchant != null) ...[
                Text('Merchant: ${result.merchant}'),
                const SizedBox(height: 8),
              ],
              if (result.date != null) ...[
                Text('Date: ${result.date}'),
                const SizedBox(height: 8),
              ],
              if (result.allAmounts.isNotEmpty) ...[
                const Text('All amounts found:',
                    style: TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(height: 4),
                ...result.allAmounts.take(5).map((a) => Text('  • $a')),
                const SizedBox(height: 8),
              ],
              const Divider(),
              const Text('Raw Text:',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
              const SizedBox(height: 4),
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.grey[100],
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  result.rawText.isEmpty ? 'No text found' : result.rawText,
                  style: const TextStyle(fontSize: 11),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          if (result.hasData)
            ElevatedButton(
              onPressed: () {
                Navigator.pop(context);
                widget.onScanComplete(result);
              },
              child: const Text('Use This'),
            ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final primaryColor = Theme.of(context).colorScheme.primary;

    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Handle bar
            Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.symmetric(vertical: 12),
              decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius: BorderRadius.circular(2),
              ),
            ),

            // Header
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  Icon(
                    Icons.document_scanner,
                    size: 48,
                    color: primaryColor,
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'Scan Receipt',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Take a photo or select an image of your receipt to automatically extract expense details',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Colors.grey[600],
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
            ),

            // Error message
            if (_error != null)
              Container(
                margin: const EdgeInsets.symmetric(horizontal: 16),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.red.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.red.withValues(alpha: 0.3)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.error_outline, color: Colors.red, size: 20),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            _error!,
                            style: const TextStyle(color: Colors.red, fontSize: 13),
                          ),
                        ),
                      ],
                    ),
                    if (_showSettingsButton) ...[
                      const SizedBox(height: 12),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          onPressed: _openSettings,
                          icon: const Icon(Icons.settings, size: 18),
                          label: const Text('Open Settings'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.red,
                            foregroundColor: Colors.white,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),

            const SizedBox(height: 16),

            // Scanning indicator
            if (_isScanning)
              Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  children: [
                    CircularProgressIndicator(color: primaryColor),
                    const SizedBox(height: 16),
                    const Text('Scanning receipt...'),
                  ],
                ),
              )
            else
              // Options
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Row(
                  children: [
                    Expanded(
                      child: _buildOptionCard(
                        icon: Icons.camera_alt,
                        title: 'Camera',
                        subtitle: 'Take a photo',
                        color: primaryColor,
                        onTap: _scanFromCamera,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _buildOptionCard(
                        icon: Icons.photo_library,
                        title: 'Gallery',
                        subtitle: 'Choose image',
                        color: Colors.green,
                        onTap: _scanFromGallery,
                      ),
                    ),
                  ],
                ),
              ),

            const SizedBox(height: 24),
            SizedBox(height: MediaQuery.of(context).padding.bottom),
          ],
        ),
      ),
    );
  }

  Widget _buildOptionCard({
    required IconData icon,
    required String title,
    required String subtitle,
    required Color color,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: color.withValues(alpha: 0.3)),
        ),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: color,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: Colors.white, size: 28),
            ),
            const SizedBox(height: 12),
            Text(
              title,
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 16,
                color: Colors.grey[800],
              ),
            ),
            const SizedBox(height: 4),
            Text(
              subtitle,
              style: TextStyle(
                color: Colors.grey[600],
                fontSize: 12,
              ),
            ),
          ],
        ),
      ),
    );
  }
}