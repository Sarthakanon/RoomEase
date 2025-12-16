import 'dart:developer';
import '../models/payment_notification.dart';

class PaymentParserService {
  // Supported banking and payment apps in Nepal
  static const Map<String, List<String>> supportedApps = {
    'banking': [
      'NMB Bank',
      'Sanima Bank', 
      'Everest Bank',
      'Nepal Bank',
      'Rastriya Banijya Bank',
      'Nabil Bank',
      'Standard Chartered',
      'Himalayan Bank',
      'Nepal Investment Bank',
      'Machhapuchchhre Bank',
    ],
    'payment': [
      'eSewa',
      'Khalti',
      'IME Pay',
      'ConnectIPS',
      'FonePay',
      'iPay',
    ],
  };

  // Common debit keywords in English and Nepali
  static const List<String> debitKeywords = [
    'debited', 'debit', 'paid', 'payment', 'purchase', 'transaction',
    'withdrawn', 'transfer', 'sent', 'charged', 'deducted',
    // Nepali terms (in English script)
    'kateko', 'bhuktan', 'paisā', 'rākam'
  ];

  // Common credit keywords
  static const List<String> creditKeywords = [
    'credited', 'credit', 'received', 'deposit', 'refund', 'cashback',
    'bonus', 'reward', 'added', 'topped up',
    // Nepali terms
    'āeko', 'jamma'
  ];

  /// Parses notification text to extract payment information
  static PaymentNotification? parseNotification({
    required String appName,
    required String notificationText,
    required String source,
  }) {
    try {
      log('Parsing notification from $appName: $notificationText');

      // Check if this is a supported app
      if (!_isSupportedApp(appName)) {
        log('Unsupported app: $appName');
        return null;
      }

      // Extract amount
      final amount = _extractAmount(notificationText);
      if (amount == null) {
        log('No amount found in notification');
        return null;
      }

      // Determine transaction type
      final type = _determineTransactionType(notificationText);
      
      // Only process debit transactions for expense suggestions
      if (type != PaymentType.debit) {
        log('Ignoring credit transaction');
        return null;
      }

      // Extract merchant information
      final merchant = _extractMerchant(notificationText, appName);

      return PaymentNotification(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        source: source,
        appName: appName,
        rawText: notificationText,
        amount: amount,
        merchant: merchant,
        timestamp: DateTime.now(),
        type: type,
      );
    } catch (e) {
      log('Error parsing notification: $e');
      return null;
    }
  }

  /// Checks if the app is supported for payment detection
  static bool _isSupportedApp(String appName) {
    final allApps = [
      ...supportedApps['banking']!,
      ...supportedApps['payment']!,
    ];
    
    return allApps.any((app) => 
      appName.toLowerCase().contains(app.toLowerCase()) ||
      app.toLowerCase().contains(appName.toLowerCase())
    );
  }

  /// Extracts amount from notification text
  static double? _extractAmount(String text) {
    // Patterns for different amount formats
    final patterns = [
      // eSewa specific: "transfered Rs. 1.0 to" or "transferred Rs. 1.0 to"
      r'transfer(?:r)?ed\s+Rs\.?\s*([0-9,]+(?:\.[0-9]+)?)',
      // Rs. 1,234.56 or NPR 1,234.56
      r'(?:Rs\.?|NPR)\s*([0-9,]+(?:\.[0-9]{1,2})?)',
      // 1,234.56 Rs or 1,234.56 NPR
      r'([0-9,]+(?:\.[0-9]{1,2})?)\s*(?:Rs\.?|NPR)',
      // Just numbers with decimals: 1,234.56 or 1.0
      r'([0-9,]+\.[0-9]{1,2})',
      // Numbers with commas without decimals: 1,234
      r'([0-9,]+)(?!\.[0-9])',
      // Nepali numerals (basic support)
      r'रु\.?\s*([०-९,]+(?:\.[०-९]{1,2})?)',
    ];

    for (final pattern in patterns) {
      final regex = RegExp(pattern, caseSensitive: false);
      final match = regex.firstMatch(text);
      
      if (match != null) {
        String amountStr = match.group(1)!;
        
        // Convert Nepali numerals to English if needed
        amountStr = _convertNepaliToEnglish(amountStr);
        
        // Remove commas and parse
        amountStr = amountStr.replaceAll(',', '');
        
        final amount = double.tryParse(amountStr);
        if (amount != null && amount > 0) {
          return amount;
        }
      }
    }

    return null;
  }

  /// Determines if transaction is debit or credit
  static PaymentType _determineTransactionType(String text) {
    final lowerText = text.toLowerCase();

    // Check for debit keywords
    for (final keyword in debitKeywords) {
      if (lowerText.contains(keyword.toLowerCase())) {
        return PaymentType.debit;
      }
    }

    // Check for credit keywords
    for (final keyword in creditKeywords) {
      if (lowerText.contains(keyword.toLowerCase())) {
        return PaymentType.credit;
      }
    }

    // Default to debit if unclear (safer for expense tracking)
    return PaymentType.debit;
  }

  /// Extracts merchant information from notification text
  static String? _extractMerchant(String text, String appName) {
    // Common patterns for merchant extraction
    final patterns = [
      // eSewa specific: "Rs. X.X to Name" pattern
      r'Rs\.?\s*[0-9,]+(?:\.[0-9]+)?\s+to\s+([A-Za-z\s]+?)(?:\.|$)',
      // General patterns
      r'(?:at|to|from)\s+([A-Za-z\s]+?)(?:\s|$|\.)',
      r'merchant:?\s*([A-Za-z\s]+?)(?:\s|$|\.)',
      r'shop:?\s*([A-Za-z\s]+?)(?:\s|$|\.)',
      r'store:?\s*([A-Za-z\s]+?)(?:\s|$|\.)',
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

    // If no specific merchant found, try to extract from app-specific patterns
    return _extractAppSpecificMerchant(text, appName);
  }

  /// App-specific merchant extraction
  static String? _extractAppSpecificMerchant(String text, String appName) {
    if (appName.toLowerCase().contains('esewa')) {
      // eSewa specific patterns
      final patterns = [
        // "Payment to Name successful"
        RegExp(r'Payment to (.+?) successful', caseSensitive: false),
        // "transfered Rs. X to Name"
        RegExp(r'transfer(?:r)?ed\s+Rs\.?\s*[0-9,]+(?:\.[0-9]+)?\s+to\s+([A-Za-z\s]+?)(?:\.|$)', caseSensitive: false),
        // "Rs. X to Name"
        RegExp(r'Rs\.?\s*[0-9,]+(?:\.[0-9]+)?\s+to\s+([A-Za-z\s]+?)(?:\.|$)', caseSensitive: false),
      ];
      
      for (final pattern in patterns) {
        final match = pattern.firstMatch(text);
        if (match != null) {
          return match.group(1)?.trim();
        }
      }
    }
    
    if (appName.toLowerCase().contains('khalti')) {
      // Khalti specific patterns
      final khaltiPattern = RegExp(r'Paid (.+?) via Khalti', caseSensitive: false);
      final match = khaltiPattern.firstMatch(text);
      return match?.group(1)?.trim();
    }

    return null;
  }

  /// Converts Nepali numerals to English numerals
  static String _convertNepaliToEnglish(String nepaliText) {
    const nepaliToEnglish = {
      '०': '0', '१': '1', '२': '2', '३': '3', '४': '4',
      '५': '5', '६': '6', '७': '7', '८': '8', '९': '9'
    };

    String result = nepaliText;
    nepaliToEnglish.forEach((nepali, english) {
      result = result.replaceAll(nepali, english);
    });
    
    return result;
  }

  /// Suggests expense category based on merchant or transaction details
  static String suggestExpenseCategory(String? merchant, String notificationText) {
    if (merchant == null) return 'General';

    final lowerMerchant = merchant.toLowerCase();
    final lowerText = notificationText.toLowerCase();

    // Food and restaurants
    if (_containsAny(lowerMerchant, ['restaurant', 'cafe', 'food', 'kitchen', 'hotel', 'pizza', 'burger']) ||
        _containsAny(lowerText, ['food', 'restaurant', 'cafe', 'meal'])) {
      return 'Food';
    }

    // Groceries and shopping
    if (_containsAny(lowerMerchant, ['mart', 'supermarket', 'grocery', 'store', 'shop', 'bazar']) ||
        _containsAny(lowerText, ['grocery', 'shopping', 'mart'])) {
      return 'Groceries';
    }

    // Utilities
    if (_containsAny(lowerMerchant, ['electricity', 'water', 'internet', 'phone', 'mobile', 'wifi']) ||
        _containsAny(lowerText, ['bill', 'utility', 'electricity', 'water', 'internet'])) {
      return 'Utilities';
    }

    // Transport
    if (_containsAny(lowerMerchant, ['taxi', 'bus', 'transport', 'fuel', 'petrol', 'pathao', 'uber']) ||
        _containsAny(lowerText, ['transport', 'taxi', 'fuel', 'petrol'])) {
      return 'Transport';
    }

    // Entertainment
    if (_containsAny(lowerMerchant, ['cinema', 'movie', 'game', 'entertainment', 'club', 'bar']) ||
        _containsAny(lowerText, ['movie', 'entertainment', 'game'])) {
      return 'Entertainment';
    }

    return 'General';
  }

  /// Helper method to check if text contains any of the given keywords
  static bool _containsAny(String text, List<String> keywords) {
    return keywords.any((keyword) => text.contains(keyword));
  }
}