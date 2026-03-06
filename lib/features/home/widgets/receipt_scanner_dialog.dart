import 'package:flutter/material.dart';
import '../../../services/ocr_service.dart';

/// Premium, responsive dialog for scanning receipts via OCR.
class ReceiptScannerDialog extends StatefulWidget {
  final Function(OcrScanResult) onScanComplete;
  const ReceiptScannerDialog({super.key, required this.onScanComplete});

  static Future<OcrScanResult?> show(BuildContext context) async {
    final width = MediaQuery.of(context).size.width;
    final isTablet = width > 600;

    return showModalBottomSheet<OcrScanResult>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => Padding(
        padding: EdgeInsets.symmetric(horizontal: isTablet ? width * 0.2 : 0),
        child: ReceiptScannerDialog(onScanComplete: (res) => Navigator.pop(context, res)),
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
  bool _showSettings = false;

  Future<void> _scan(Future<OcrScanResult?> Function() method) async {
    setState(() { _isScanning = true; _error = null; _showSettings = false; });
    try {
      final res = await method();
      if (res != null) {
        if (res.hasData) widget.onScanComplete(res);
        else _showResult(res);
      }
    } on PermissionDeniedException catch (e) {
      setState(() { _error = e.message; _showSettings = e.isPermanent; });
    } catch (e) {
      setState(() => _error = 'Failed to scan: ${e.toString()}');
    } finally {
      if (mounted) setState(() => _isScanning = false);
    }
  }

  void _showResult(OcrScanResult res) {
    showDialog(context: context, builder: (context) => AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: const Text('Scan Result', style: TextStyle(fontWeight: FontWeight.w800)),
      content: SingleChildScrollView(child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
        if (res.amount != null) ...[Text('Amount: Rs. ${res.amount!.toStringAsFixed(0)}', style: const TextStyle(fontWeight: FontWeight.bold)), const SizedBox(height: 12)],
        if (res.merchant != null) ...[Text('Merchant: ${res.merchant}'), const SizedBox(height: 12)],
        const Divider(),
        const Text('Detected Text:', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: Colors.grey)),
        const SizedBox(height: 8),
        Container(padding: const EdgeInsets.all(12), decoration: BoxDecoration(color: const Color(0xFFF7F7FB), borderRadius: BorderRadius.circular(12)), child: Text(res.rawText.isEmpty ? 'No text found' : res.rawText, style: const TextStyle(fontSize: 11, color: Colors.black87))),
      ])),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel', style: TextStyle(color: Colors.grey))),
        if (res.hasData) ElevatedButton(onPressed: () { Navigator.pop(context); widget.onScanComplete(res); }, style: ElevatedButton.styleFrom(backgroundColor: Theme.of(context).primaryColor, foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))), child: const Text('Use This')),
      ],
    ));
  }

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;

    return Container(
      decoration: const BoxDecoration(color: Colors.white, borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildHandle(),
          _buildHeader(primary),
          if (_isScanning) _buildLoading(primary) else _buildOptions(primary),
          const SizedBox(height: 32),
          if (_error != null) _buildError(),
          SizedBox(height: MediaQuery.of(context).padding.bottom + 16),
        ],
      ),
    );
  }

  Widget _buildHandle() {
    return Container(margin: const EdgeInsets.only(top: 12), width: 40, height: 4, decoration: BoxDecoration(color: const Color(0xFFEEEEF2), borderRadius: BorderRadius.circular(2)));
  }

  Widget _buildHeader(Color primary) {
    return Padding(padding: const EdgeInsets.all(24), child: Column(children: [
      Container(padding: const EdgeInsets.all(16), decoration: BoxDecoration(color: primary.withValues(alpha: 0.1), shape: BoxShape.circle), child: Icon(Icons.document_scanner_rounded, size: 40, color: primary)),
      const SizedBox(height: 20),
      const Text('Scan Receipt', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: Color(0xFF1A1A2E))),
      const SizedBox(height: 8),
      Text('Automatically extract expense details from a photo', textAlign: TextAlign.center, style: TextStyle(fontSize: 13, color: Colors.grey.shade500)),
    ]));
  }

  Widget _buildLoading(Color primary) {
    return Padding(padding: const EdgeInsets.all(32), child: Column(children: [CircularProgressIndicator(color: primary, strokeWidth: 3), const SizedBox(height: 16), Text('Analyzing receipt...', style: TextStyle(fontSize: 13, color: Colors.grey.shade600, fontWeight: FontWeight.w600))]));
  }

  Widget _buildOptions(Color primary) {
    return Padding(padding: const EdgeInsets.symmetric(horizontal: 24), child: Row(children: [
      Expanded(child: _OptionBtn(icon: Icons.camera_alt_rounded, title: 'Camera', color: primary, onTap: () => _scan(_ocrService.scanFromCamera))),
      const SizedBox(width: 12),
      Expanded(child: _OptionBtn(icon: Icons.photo_library_rounded, title: 'Gallery', color: const Color(0xFF10B981), onTap: () => _scan(_ocrService.scanFromGallery))),
    ]));
  }

  Widget _buildError() {
    return Container(margin: const EdgeInsets.symmetric(horizontal: 24), padding: const EdgeInsets.all(16), decoration: BoxDecoration(color: Colors.red.withValues(alpha: 0.05), border: Border.all(color: Colors.red.withValues(alpha: 0.1)), borderRadius: BorderRadius.circular(16)), child: Column(children: [
      Row(children: [const Icon(Icons.error_outline_rounded, color: Colors.red, size: 20), const SizedBox(width: 8), Expanded(child: Text(_error!, style: const TextStyle(color: Colors.red, fontSize: 13, fontWeight: FontWeight.w600)))]),
      if (_showSettings) Padding(padding: const EdgeInsets.only(top: 12), child: SizedBox(width: double.infinity, height: 40, child: ElevatedButton(onPressed: _ocrService.openSettings, style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)), elevation: 0), child: const Text('Open Settings')))),
    ]));
  }
}

class _OptionBtn extends StatelessWidget {
  final IconData icon;
  final String title;
  final Color color;
  final VoidCallback onTap;
  const _OptionBtn({required this.icon, required this.title, required this.color, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 24),
        decoration: BoxDecoration(color: color.withValues(alpha: 0.05), borderRadius: BorderRadius.circular(20), border: Border.all(color: color.withValues(alpha: 0.1))),
        child: Column(children: [
          Icon(icon, color: color, size: 28),
          const SizedBox(height: 12),
          Text(title, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: Colors.grey.shade800)),
        ]),
      ),
    );
  }
}