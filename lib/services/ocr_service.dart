import 'dart:io';
import 'package:flutter/material.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:image_picker/image_picker.dart';
import 'package:permission_handler/permission_handler.dart';

/// Result of OCR scanning containing extracted expense data
class OcrScanResult {
  final double? amount;
  final String? merchant;
  final String? date;
  final String rawText;
  final List<String> allAmounts;

  OcrScanResult({
    this.amount,
    this.merchant,
    this.date,
    required this.rawText,
    this.allAmounts = const [],
  });

  bool get hasData => amount != null || merchant != null;
}

/// Service for OCR text recognition from images
class OcrService {
  static final OcrService _instance = OcrService._internal();
  factory OcrService() => _instance;
  OcrService._internal();

  final ImagePicker _imagePicker = ImagePicker();
  final TextRecognizer _textRecognizer = TextRecognizer();

  /// Request camera permission and return status
  Future<PermissionResult> requestCameraPermission() async {
    var status = await Permission.camera.status;
    debugPrint('Camera permission status: $status');
    
    if (status.isGranted) {
      return PermissionResult.granted;
    }
    
    if (status.isPermanentlyDenied) {
      return PermissionResult.permanentlyDenied;
    }
    
    // Check if we should show rationale BEFORE requesting
    // This is true only if user has denied before but not permanently
    final shouldShowRationaleBefore = await Permission.camera.shouldShowRequestRationale;
    debugPrint('Camera shouldShowRationale before request: $shouldShowRationaleBefore');
    
    // Request permission - this should show the system dialog
    status = await Permission.camera.request();
    debugPrint('Camera permission after request: $status');
    
    if (status.isGranted) {
      return PermissionResult.granted;
    }
    
    if (status.isPermanentlyDenied) {
      return PermissionResult.permanentlyDenied;
    }
    
    if (status.isDenied) {
      // Check shouldShowRationale AFTER request
      final shouldShowRationaleAfter = await Permission.camera.shouldShowRequestRationale;
      debugPrint('Camera shouldShowRationale after request: $shouldShowRationaleAfter');
      
      // If shouldShowRationale is false AFTER a denial, it means:
      // - Either user selected "Don't ask again" (permanently denied)
      // - Or this is the first time and dialog wasn't shown (shouldn't happen normally)
      // 
      // If shouldShowRationale was true BEFORE but false AFTER, user selected "Don't ask again"
      if (shouldShowRationaleBefore && !shouldShowRationaleAfter) {
        return PermissionResult.permanentlyDenied;
      }
      
      // If both are false and status is denied, user likely selected "Don't ask again"
      // But we need to be careful - on first denial, shouldShowRationale becomes true
      // So if it's still false after denial, it's permanently denied
      if (!shouldShowRationaleAfter) {
        return PermissionResult.permanentlyDenied;
      }
      
      return PermissionResult.denied;
    }
    
    return PermissionResult.denied;
  }

  /// Request storage/photos permission and return status
  Future<PermissionResult> requestStoragePermission() async {
    if (Platform.isAndroid) {
      // For Android 13+ (API 33+), we need READ_MEDIA_IMAGES
      // For older versions, we need READ_EXTERNAL_STORAGE
      
      // Check photos permission first (Android 13+)
      var photosStatus = await Permission.photos.status;
      debugPrint('Photos permission status: $photosStatus');
      
      if (photosStatus.isGranted) {
        return PermissionResult.granted;
      }
      
      // Check storage permission (older Android)
      var storageStatus = await Permission.storage.status;
      debugPrint('Storage permission status: $storageStatus');
      
      if (storageStatus.isGranted) {
        return PermissionResult.granted;
      }
      
      // Check if already permanently denied
      if (photosStatus.isPermanentlyDenied || storageStatus.isPermanentlyDenied) {
        return PermissionResult.permanentlyDenied;
      }
      
      // Store rationale status before request
      final photosShouldShowBefore = await Permission.photos.shouldShowRequestRationale;
      final storageShouldShowBefore = await Permission.storage.shouldShowRequestRationale;
      debugPrint('Photos shouldShowRationale before: $photosShouldShowBefore');
      debugPrint('Storage shouldShowRationale before: $storageShouldShowBefore');
      
      // Try requesting photos permission first (Android 13+)
      photosStatus = await Permission.photos.request();
      debugPrint('Photos permission after request: $photosStatus');
      
      if (photosStatus.isGranted) {
        return PermissionResult.granted;
      }
      
      // Try storage permission for older Android
      storageStatus = await Permission.storage.request();
      debugPrint('Storage permission after request: $storageStatus');
      
      if (storageStatus.isGranted) {
        return PermissionResult.granted;
      }
      
      // Check if permanently denied
      if (photosStatus.isPermanentlyDenied || storageStatus.isPermanentlyDenied) {
        return PermissionResult.permanentlyDenied;
      }
      
      // Check shouldShowRequestRationale AFTER request to determine if permanently denied
      final photosShouldShowAfter = await Permission.photos.shouldShowRequestRationale;
      final storageShouldShowAfter = await Permission.storage.shouldShowRequestRationale;
      debugPrint('Photos shouldShowRationale after: $photosShouldShowAfter');
      debugPrint('Storage shouldShowRationale after: $storageShouldShowAfter');
      
      // If rationale was true before but false after, user selected "Don't ask again"
      if ((photosShouldShowBefore && !photosShouldShowAfter) ||
          (storageShouldShowBefore && !storageShouldShowAfter)) {
        return PermissionResult.permanentlyDenied;
      }
      
      // If both are false after denial, likely permanently denied
      if (!photosShouldShowAfter && !storageShouldShowAfter &&
          (photosStatus.isDenied || storageStatus.isDenied)) {
        return PermissionResult.permanentlyDenied;
      }
      
      return PermissionResult.denied;
    } else {
      // iOS
      var status = await Permission.photos.status;
      
      if (status.isGranted) {
        return PermissionResult.granted;
      }
      
      if (status.isPermanentlyDenied) {
        return PermissionResult.permanentlyDenied;
      }
      
      status = await Permission.photos.request();
      
      if (status.isGranted) {
        return PermissionResult.granted;
      } else if (status.isPermanentlyDenied) {
        return PermissionResult.permanentlyDenied;
      }
      
      return PermissionResult.denied;
    }
  }

  /// Open app settings
  Future<void> openSettings() async {
    await openAppSettings();
  }

  /// Pick image from camera and scan for text
  Future<OcrScanResult?> scanFromCamera() async {
    // Check and request camera permission first
    var status = await Permission.camera.status;
    debugPrint('Camera permission initial status: $status');
    
    if (!status.isGranted) {
      // Request permission - this should show the system dialog
      status = await Permission.camera.request();
      debugPrint('Camera permission after request: $status');
      
      if (!status.isGranted) {
        throw PermissionDeniedException(
          'Camera permission is required. Please enable it in Settings.',
          isPermanent: status.isPermanentlyDenied,
        );
      }
    }

    try {
      final XFile? image = await _imagePicker.pickImage(
        source: ImageSource.camera,
        preferredCameraDevice: CameraDevice.rear,
        imageQuality: 85,
      );

      if (image == null) return null;
      return _processImage(File(image.path));
    } catch (e) {
      debugPrint('Camera error: $e');
      throw Exception('Failed to capture image. Please try again.');
    }
  }

  /// Pick image from gallery and scan for text
  Future<OcrScanResult?> scanFromGallery() async {
    // Check and request storage permission first (for Android < 13)
    if (Platform.isAndroid) {
      var status = await Permission.storage.status;
      debugPrint('Storage permission initial status: $status');
      
      if (!status.isGranted) {
        // Request permission - this should show the system dialog
        status = await Permission.storage.request();
        debugPrint('Storage permission after request: $status');
        
        if (!status.isGranted) {
          throw PermissionDeniedException(
            'Storage permission is required. Please enable it in Settings.',
            isPermanent: status.isPermanentlyDenied,
          );
        }
      }
    }

    try {
      final XFile? image = await _imagePicker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 85,
      );

      if (image == null) return null;
      return _processImage(File(image.path));
    } catch (e) {
      debugPrint('Gallery error: $e');
      throw Exception('Failed to select image. Please try again.');
    }
  }

  /// Process image and extract text
  Future<OcrScanResult> _processImage(File imageFile) async {
    final inputImage = InputImage.fromFile(imageFile);
    final RecognizedText recognizedText = await _textRecognizer.processImage(inputImage);

    final String rawText = recognizedText.text;
    
    // Extract expense data from recognized text
    final amount = _extractAmount(rawText);
    final merchant = _extractMerchant(recognizedText);
    final date = _extractDate(rawText);
    final allAmounts = _extractAllAmounts(rawText);

    return OcrScanResult(
      amount: amount,
      merchant: merchant,
      date: date,
      rawText: rawText,
      allAmounts: allAmounts,
    );
  }

  /// Extract the most likely total amount from text
  double? _extractAmount(String text) {
    // Common patterns for total amount on receipts
    final patterns = [
      // Total patterns (highest priority)
      RegExp(r'(?:total|grand\s*total|amount\s*due|net\s*amount|payable)[\s:]*(?:rs\.?|₹|inr)?\s*([\d,]+\.?\d*)', caseSensitive: false),
      // Rs/₹ followed by amount
      RegExp(r'(?:rs\.?|₹|inr)\s*([\d,]+\.?\d*)', caseSensitive: false),
      // Amount followed by Rs/₹
      RegExp(r'([\d,]+\.?\d*)\s*(?:rs\.?|₹|inr)', caseSensitive: false),
      // Generic large number (likely total)
      RegExp(r'\b([\d,]+\.\d{2})\b'),
    ];

    List<double> amounts = [];

    for (final pattern in patterns) {
      final matches = pattern.allMatches(text);
      for (final match in matches) {
        final amountStr = match.group(1)?.replaceAll(',', '');
        if (amountStr != null) {
          final amount = double.tryParse(amountStr);
          if (amount != null && amount > 0 && amount < 1000000) {
            amounts.add(amount);
          }
        }
      }
    }

    if (amounts.isEmpty) return null;

    // Return the largest amount (usually the total)
    amounts.sort((a, b) => b.compareTo(a));
    return amounts.first;
  }

  /// Extract all amounts found in the text
  List<String> _extractAllAmounts(String text) {
    final pattern = RegExp(r'(?:rs\.?|₹|inr)?\s*([\d,]+\.?\d*)\s*(?:rs\.?|₹|inr)?', caseSensitive: false);
    final matches = pattern.allMatches(text);
    
    Set<String> amounts = {};
    for (final match in matches) {
      final amountStr = match.group(1)?.replaceAll(',', '');
      if (amountStr != null) {
        final amount = double.tryParse(amountStr);
        if (amount != null && amount > 0 && amount < 1000000) {
          amounts.add('Rs. ${amount.toStringAsFixed(2)}');
        }
      }
    }
    
    return amounts.toList()..sort((a, b) {
      final aVal = double.tryParse(a.replaceAll(RegExp(r'[^\d.]'), '')) ?? 0;
      final bVal = double.tryParse(b.replaceAll(RegExp(r'[^\d.]'), '')) ?? 0;
      return bVal.compareTo(aVal);
    });
  }

  /// Extract merchant name from recognized text
  String? _extractMerchant(RecognizedText recognizedText) {
    if (recognizedText.blocks.isEmpty) return null;

    // Usually the merchant name is in the first few lines
    // and is often in larger text or at the top
    final firstBlocks = recognizedText.blocks.take(3).toList();
    
    for (final block in firstBlocks) {
      final text = block.text.trim();
      
      // Skip if it looks like a date, amount, or common receipt text
      if (_isDateOrAmount(text)) continue;
      if (_isCommonReceiptText(text)) continue;
      
      // Return the first meaningful text block
      if (text.length > 2 && text.length < 50) {
        return _cleanMerchantName(text);
      }
    }

    return null;
  }

  /// Extract date from text
  String? _extractDate(String text) {
    // Common date patterns
    final patterns = [
      // DD/MM/YYYY or DD-MM-YYYY
      RegExp(r'\b(\d{1,2}[/-]\d{1,2}[/-]\d{2,4})\b'),
      // YYYY/MM/DD or YYYY-MM-DD
      RegExp(r'\b(\d{4}[/-]\d{1,2}[/-]\d{1,2})\b'),
      // Month DD, YYYY
      RegExp(r'\b((?:Jan|Feb|Mar|Apr|May|Jun|Jul|Aug|Sep|Oct|Nov|Dec)[a-z]*\s+\d{1,2},?\s+\d{4})\b', caseSensitive: false),
      // DD Month YYYY
      RegExp(r'\b(\d{1,2}\s+(?:Jan|Feb|Mar|Apr|May|Jun|Jul|Aug|Sep|Oct|Nov|Dec)[a-z]*\s+\d{4})\b', caseSensitive: false),
    ];

    for (final pattern in patterns) {
      final match = pattern.firstMatch(text);
      if (match != null) {
        return match.group(1);
      }
    }

    return null;
  }

  bool _isDateOrAmount(String text) {
    // Check if text is primarily numbers, dates, or currency
    final numericPattern = RegExp(r'^[\d\s,./₹\$€£-]+$');
    return numericPattern.hasMatch(text);
  }

  bool _isCommonReceiptText(String text) {
    final commonTexts = [
      'receipt', 'invoice', 'bill', 'tax', 'gst', 'cgst', 'sgst',
      'total', 'subtotal', 'amount', 'cash', 'card', 'payment',
      'thank you', 'thanks', 'visit again', 'welcome',
      'qty', 'quantity', 'price', 'rate', 'discount',
    ];
    
    final lowerText = text.toLowerCase();
    return commonTexts.any((t) => lowerText.contains(t));
  }

  String _cleanMerchantName(String name) {
    // Remove common prefixes/suffixes
    var cleaned = name
        .replaceAll(RegExp(r'^(M/s\.?|Mr\.?|Mrs\.?|Ms\.?)\s*', caseSensitive: false), '')
        .replaceAll(RegExp(r'\s*(Pvt\.?|Ltd\.?|Private|Limited|Inc\.?|LLC).*$', caseSensitive: false), '')
        .trim();
    
    // Capitalize first letter of each word
    cleaned = cleaned.split(' ').map((word) {
      if (word.isEmpty) return word;
      return word[0].toUpperCase() + word.substring(1).toLowerCase();
    }).join(' ');
    
    return cleaned;
  }

  /// Dispose resources
  void dispose() {
    _textRecognizer.close();
  }
}

/// Permission result enum
enum PermissionResult {
  granted,
  denied,
  permanentlyDenied,
}

/// Custom exception for permission denied
class PermissionDeniedException implements Exception {
  final String message;
  final bool isPermanent;
  
  PermissionDeniedException(this.message, {this.isPermanent = false});
  
  @override
  String toString() => message;
}
