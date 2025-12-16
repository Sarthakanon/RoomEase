class PaymentNotification {
  final String id;
  final String source; // 'sms', 'notification', or 'test'
  final String appName; // e.g., 'eSewa', 'NMB Bank'
  final String rawText;
  final double? amount;
  final String? merchant;
  final DateTime timestamp;
  final PaymentType type; // debit or credit
  final bool isProcessed;

  PaymentNotification({
    required this.id,
    required this.source,
    required this.appName,
    required this.rawText,
    this.amount,
    this.merchant,
    required this.timestamp,
    required this.type,
    this.isProcessed = false,
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'source': source,
      'appName': appName,
      'rawText': rawText,
      'amount': amount,
      'merchant': merchant,
      'timestamp': timestamp.toIso8601String(),
      'type': type.toString(),
      'isProcessed': isProcessed,
    };
  }

  factory PaymentNotification.fromJson(Map<String, dynamic> json) {
    return PaymentNotification(
      id: json['id'],
      source: json['source'],
      appName: json['appName'],
      rawText: json['rawText'],
      amount: json['amount']?.toDouble(),
      merchant: json['merchant'],
      timestamp: DateTime.parse(json['timestamp']),
      type: PaymentType.values.firstWhere(
        (e) => e.toString() == json['type'],
        orElse: () => PaymentType.debit,
      ),
      isProcessed: json['isProcessed'] ?? false,
    );
  }
}

enum PaymentType { debit, credit }

class PaymentNotificationSettings {
  final bool isEnabled;
  final bool smsMonitoringEnabled;
  final bool notificationMonitoringEnabled;
  final double minimumAmount;
  final List<String> enabledApps;
  final List<String> enabledMerchants;

  PaymentNotificationSettings({
    this.isEnabled = true,
    this.smsMonitoringEnabled = true,
    this.notificationMonitoringEnabled = true,
    this.minimumAmount = 0.0,
    this.enabledApps = const [],
    this.enabledMerchants = const [],
  });

  Map<String, dynamic> toJson() {
    return {
      'isEnabled': isEnabled,
      'smsMonitoringEnabled': smsMonitoringEnabled,
      'notificationMonitoringEnabled': notificationMonitoringEnabled,
      'minimumAmount': minimumAmount,
      'enabledApps': enabledApps,
      'enabledMerchants': enabledMerchants,
    };
  }

  factory PaymentNotificationSettings.fromJson(Map<String, dynamic> json) {
    return PaymentNotificationSettings(
      isEnabled: json['isEnabled'] ?? true,
      smsMonitoringEnabled: json['smsMonitoringEnabled'] ?? true,
      notificationMonitoringEnabled: json['notificationMonitoringEnabled'] ?? true,
      minimumAmount: json['minimumAmount']?.toDouble() ?? 0.0,
      enabledApps: List<String>.from(json['enabledApps'] ?? []),
      enabledMerchants: List<String>.from(json['enabledMerchants'] ?? []),
    );
  }

  PaymentNotificationSettings copyWith({
    bool? isEnabled,
    bool? smsMonitoringEnabled,
    bool? notificationMonitoringEnabled,
    double? minimumAmount,
    List<String>? enabledApps,
    List<String>? enabledMerchants,
  }) {
    return PaymentNotificationSettings(
      isEnabled: isEnabled ?? this.isEnabled,
      smsMonitoringEnabled: smsMonitoringEnabled ?? this.smsMonitoringEnabled,
      notificationMonitoringEnabled: notificationMonitoringEnabled ?? this.notificationMonitoringEnabled,
      minimumAmount: minimumAmount ?? this.minimumAmount,
      enabledApps: enabledApps ?? this.enabledApps,
      enabledMerchants: enabledMerchants ?? this.enabledMerchants,
    );
  }
}