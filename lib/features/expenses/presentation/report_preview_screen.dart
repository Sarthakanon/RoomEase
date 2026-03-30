import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:printing/printing.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:open_file/open_file.dart';
import 'dart:io';
import '../../../services/report_service.dart';
import '../../../models/expense_models.dart';
import '../../../models/balance_models.dart';
import 'dart:typed_data';

class ReportPreviewScreen extends StatefulWidget {
  final List<ExpenseData> sharedExpenses;
  final List<PersonalExpenseData> personalExpenses;
  final DateTimeRange dateRange;
  final String roomspaceName;
  final String userName;
  final BalanceSummary? balanceSummary;
  final List<SettlementSuggestion> settlements;

  const ReportPreviewScreen({
    super.key,
    required this.sharedExpenses,
    required this.personalExpenses,
    required this.dateRange,
    required this.roomspaceName,
    required this.userName,
    this.balanceSummary,
    this.settlements = const [],
  });

  @override
  State<ReportPreviewScreen> createState() => _ReportPreviewScreenState();
}

class _ReportPreviewScreenState extends State<ReportPreviewScreen> {
  final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin = FlutterLocalNotificationsPlugin();

  @override
  void initState() {
    super.initState();
    _initializeNotifications();
  }

  Future<void> _initializeNotifications() async {
    const AndroidInitializationSettings initializationSettingsAndroid =
        AndroidInitializationSettings('@mipmap/ic_launcher');
    const InitializationSettings initializationSettings =
        InitializationSettings(android: initializationSettingsAndroid);
    
    // Initialize with callback to handle notification taps
    await flutterLocalNotificationsPlugin.initialize(
      initializationSettings,
      onDidReceiveNotificationResponse: (NotificationResponse response) async {
        if (response.payload != null) {
          // Open the PDF file when notification is tapped
          await OpenFile.open(response.payload!);
        }
      },
    );
  }

  Future<void> _showNotification(String filePath, String fileName) async {
    const AndroidNotificationDetails androidPlatformChannelSpecifics =
        AndroidNotificationDetails(
      'report_downloads',
      'Report Downloads',
      channelDescription: 'Notifications for generated expense reports',
      importance: Importance.max,
      priority: Priority.high,
      showWhen: true,
      icon: '@mipmap/ic_launcher',
    );
    const NotificationDetails platformChannelSpecifics =
        NotificationDetails(android: androidPlatformChannelSpecifics);
    await flutterLocalNotificationsPlugin.show(
      0,
      'Report Downloaded',
      'Tap to open $fileName',
      platformChannelSpecifics,
      payload: filePath,
    );
  }

  Future<Uint8List> _generatePdf() async {
    return await ReportService().generateExpenseReport(
      sharedExpenses: widget.sharedExpenses,
      personalExpenses: widget.personalExpenses,
      dateRange: widget.dateRange,
      roomspaceName: widget.roomspaceName,
      userName: widget.userName,
      balanceSummary: widget.balanceSummary,
      settlements: widget.settlements,
    );
  }

  Future<void> _handleDownload() async {
    try {
      final bytes = await _generatePdf();
      final fileName = 'RoomEase_Report_${DateFormat('yyyyMMdd_HHmm').format(DateTime.now())}.pdf';
      
      String? savedPath;

      if (Platform.isAndroid) {
        // Request storage permission
        PermissionStatus status;
        
        // For Android 13+ (API 33+), we need to handle differently
        if (Platform.version.contains('33') || Platform.version.contains('34')) {
          // Android 13+ doesn't need storage permission for Downloads
          status = PermissionStatus.granted;
        } else {
          // Android 12 and below
          status = await Permission.storage.request();
          if (status.isDenied) {
            status = await Permission.manageExternalStorage.request();
          }
        }

        if (status.isGranted || status.isLimited) {
          // Try to save to Downloads folder
          final downloadsPath = '/storage/emulated/0/Download';
          final downloadsDir = Directory(downloadsPath);
          
          if (await downloadsDir.exists()) {
            try {
              final file = File('$downloadsPath/$fileName');
              await file.writeAsBytes(bytes);
              savedPath = file.path;
              debugPrint('✅ Saved to Downloads: $savedPath');
            } catch (e) {
              debugPrint('❌ Failed to save to Downloads: $e');
            }
          } else {
            debugPrint('❌ Downloads directory does not exist');
          }
          
          // If Downloads didn't work, try external storage
          if (savedPath == null) {
            try {
              final Directory? extDir = await getExternalStorageDirectory();
              if (extDir != null) {
                // Navigate to the public Downloads folder
                String basePath = extDir.path.split('/Android')[0];
                String downloadPath = '$basePath/Download';
                
                final downloadDir = Directory(downloadPath);
                if (await downloadDir.exists()) {
                  final file = File('$downloadPath/$fileName');
                  await file.writeAsBytes(bytes);
                  savedPath = file.path;
                  debugPrint('✅ Saved to external Downloads: $savedPath');
                }
              }
            } catch (e) {
              debugPrint('❌ Failed to save to external storage: $e');
            }
          }
        } else {
          debugPrint('❌ Storage permission denied');
        }
      }

      // Final fallback to app documents directory
      if (savedPath == null) {
        final directory = await getApplicationDocumentsDirectory();
        final file = File('${directory.path}/$fileName');
        await file.writeAsBytes(bytes);
        savedPath = file.path;
        debugPrint('⚠️ Saved to app directory (fallback): $savedPath');
      }

      // Show system notification with file path
      await _showNotification(savedPath, fileName);

      if (mounted) {
        // Determine display path
        String displayPath = savedPath.contains('/Download') 
            ? 'Downloads/$fileName' 
            : savedPath.split('/').last;
            
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: const Color(0xFF1A1A2E),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            content: Row(
              children: [
                const Icon(Icons.download_done_rounded, color: Colors.greenAccent),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('DOWNLOAD COMPLETE', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Colors.white)),
                      Text('Saved to: $displayPath', style: TextStyle(fontSize: 10, color: Colors.white.withOpacity(0.7))),
                    ],
                  ),
                ),
              ],
            ),
            duration: const Duration(seconds: 5),
            action: SnackBarAction(
              label: 'OPEN',
              textColor: Colors.orange,
              onPressed: () async {
                await OpenFile.open(savedPath);
              },
            ),
          ),
        );
      }
    } catch (e) {
      debugPrint('❌ Download error: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Download failed: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Report Preview', style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.white,
        foregroundColor: const Color(0xFF1A1A2E),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 18),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          IconButton(
            key: const ValueKey('share_report_btn'),
            icon: const Icon(Icons.share_rounded, size: 20),
            onPressed: () async {
              final pdf = await _generatePdf();
              await Printing.sharePdf(bytes: pdf, filename: 'RoomEase_Report_${DateFormat('yyyyMMdd').format(DateTime.now())}.pdf');
            },
            tooltip: 'Share Report',
          ),
          IconButton(
            key: const ValueKey('download_report_btn'),
            icon: const Icon(Icons.file_download_rounded),
            onPressed: _handleDownload,
            tooltip: 'Download PDF',
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: PdfPreview(
        build: (format) => _generatePdf(),
        allowPrinting: true,
        allowSharing: true,
        canDebug: false,
        canChangePageFormat: false,
        canChangeOrientation: false,
      ),
    );
  }
}
