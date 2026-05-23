
/// Enum for recurring payment intervals
enum RecurringInterval {
  weekly('Weekly', 'week', 7),
  monthly('Monthly', 'month', 30),
  yearly('Yearly', 'year', 365);

  const RecurringInterval(this.label, this.apiValue, this.days);
  
  final String label;
  final String apiValue;
  final int days;

  static RecurringInterval fromString(String value) {
    switch (value.toLowerCase()) {
      case 'weekly':
      case 'week':
        return RecurringInterval.weekly;
      case 'monthly':
      case 'month':
        return RecurringInterval.monthly;
      case 'yearly':
      case 'year':
        return RecurringInterval.yearly;
      default:
        return RecurringInterval.monthly;
    }
  }
}

/// Model for recurring expense configuration
class RecurringExpenseConfig {
  final bool isRecurring;
  final RecurringInterval? interval;
  final DateTime? startDate;
  final DateTime? endDate;
  final int? maxOccurrences;
  final bool notifyBeforeCreation;
  final int notificationDaysBefore;

  RecurringExpenseConfig({
    this.isRecurring = false,
    this.interval,
    this.startDate,
    this.endDate,
    this.maxOccurrences,
    this.notifyBeforeCreation = true,
    this.notificationDaysBefore = 1,
  });

  Map<String, dynamic> toJson() {
    return {
      'is_recurring': isRecurring,
      'interval': interval?.apiValue,
      'start_date': startDate?.toUtc().toIso8601String(),
      'end_date': endDate?.toUtc().toIso8601String(),
      'max_occurrences': maxOccurrences,
      'notify_before_creation': notifyBeforeCreation,
      'notification_days_before': notificationDaysBefore,
    };
  }

  factory RecurringExpenseConfig.fromJson(Map<String, dynamic> json) {
    return RecurringExpenseConfig(
      isRecurring: json['is_recurring'] ?? false,
      interval: json['interval'] != null 
          ? RecurringInterval.fromString(json['interval']) 
          : null,
      startDate: json['start_date'] != null 
          ? DateTime.parse(json['start_date']) 
          : null,
      endDate: json['end_date'] != null 
          ? DateTime.parse(json['end_date']) 
          : null,
      maxOccurrences: json['max_occurrences'],
      notifyBeforeCreation: json['notify_before_creation'] ?? true,
      notificationDaysBefore: json['notification_days_before'] ?? 1,
    );
  }

  RecurringExpenseConfig copyWith({
    bool? isRecurring,
    RecurringInterval? interval,
    DateTime? startDate,
    DateTime? endDate,
    int? maxOccurrences,
    bool? notifyBeforeCreation,
    int? notificationDaysBefore,
  }) {
    return RecurringExpenseConfig(
      isRecurring: isRecurring ?? this.isRecurring,
      interval: interval ?? this.interval,
      startDate: startDate ?? this.startDate,
      endDate: endDate ?? this.endDate,
      maxOccurrences: maxOccurrences ?? this.maxOccurrences,
      notifyBeforeCreation: notifyBeforeCreation ?? this.notifyBeforeCreation,
      notificationDaysBefore: notificationDaysBefore ?? this.notificationDaysBefore,
    );
  }

  /// Calculate next occurrence date
  DateTime? getNextOccurrence(DateTime fromDate) {
    if (!isRecurring || interval == null) return null;
    
    switch (interval!) {
      case RecurringInterval.weekly:
        return fromDate.add(const Duration(days: 7));
      case RecurringInterval.monthly:
        return DateTime(
          fromDate.year,
          fromDate.month + 1,
          fromDate.day,
        );
      case RecurringInterval.yearly:
        return DateTime(
          fromDate.year + 1,
          fromDate.month,
          fromDate.day,
        );
    }
  }

  /// Check if recurring expense should end
  bool shouldEnd(DateTime currentDate, int occurrenceCount) {
    if (!isRecurring) return true;
    
    // Check end date
    if (endDate != null && currentDate.isAfter(endDate!)) {
      return true;
    }
    
    // Check max occurrences
    if (maxOccurrences != null && occurrenceCount >= maxOccurrences!) {
      return true;
    }
    
    return false;
  }
}

/// Model for recurring expense template
class RecurringExpenseTemplate {
  final int? id;
  final String roomspaceId;
  final String title;
  final String description;
  final double amount;
  final String category;
  final String createdBy;
  final String paidBy;
  final List<String> selectedRoommates;
  final String splitType;
  final Map<String, double> customSplits;
  final RecurringExpenseConfig recurringConfig;
  final DateTime createdAt;
  final DateTime? lastGenerated;
  final int occurrenceCount;
  final bool isActive;
  final bool isDeleted;
  final DateTime? deletedAt;

  RecurringExpenseTemplate({
    this.id,
    required this.roomspaceId,
    required this.title,
    required this.description,
    required this.amount,
    required this.category,
    required this.createdBy,
    required this.paidBy,
    required this.selectedRoommates,
    required this.splitType,
    required this.customSplits,
    required this.recurringConfig,
    required this.createdAt,
    this.lastGenerated,
    this.occurrenceCount = 0,
    this.isActive = true,
    this.isDeleted = false,
    this.deletedAt,
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'roomspace_id': roomspaceId,
      'title': title,
      'description': description,
      'amount': amount,
      'category': category,
      'created_by': createdBy,
      'paid_by': paidBy,
      'selected_roommates': selectedRoommates,
      'split_type': splitType,
      'custom_splits': customSplits,
      'recurring_config': recurringConfig.toJson(),
      'created_at': createdAt.toUtc().toIso8601String(),
      'last_generated': lastGenerated?.toUtc().toIso8601String(),
      'occurrence_count': occurrenceCount,
      'is_active': isActive,
      'is_deleted': isDeleted,
      'deleted_at': deletedAt?.toUtc().toIso8601String(),
    };
  }

  factory RecurringExpenseTemplate.fromJson(Map<String, dynamic> json) {
    return RecurringExpenseTemplate(
      id: json['id'],
      roomspaceId: json['roomspace_id'],
      title: json['title'],
      description: json['description'],
      amount: (json['amount'] as num).toDouble(),
      category: json['category'],
      createdBy: json['created_by'],
      paidBy: json['paid_by'] ?? json['created_by'] ?? '',
      selectedRoommates: List<String>.from(json['selected_roommates'] ?? []),
      splitType: json['split_type'],
      customSplits: Map<String, double>.from(
        (json['custom_splits'] as Map<String, dynamic>? ?? {})
            .map((k, v) => MapEntry(k, (v as num).toDouble())),
      ),
      recurringConfig: RecurringExpenseConfig.fromJson(
        json['recurring_config'] ?? {},
      ),
      createdAt: DateTime.parse(json['created_at']),
      lastGenerated: json['last_generated'] != null 
          ? DateTime.parse(json['last_generated']) 
          : null,
      occurrenceCount: json['occurrence_count'] ?? 0,
      isActive: json['is_active'] ?? true,
      isDeleted: json['is_deleted'] ?? false,
      deletedAt: json['deleted_at'] != null ? DateTime.parse(json['deleted_at']) : null,
    );
  }

  /// Get next scheduled date for this recurring expense
  DateTime? getNextScheduledDate() {
    final baseDate = lastGenerated ?? createdAt;
    return recurringConfig.getNextOccurrence(baseDate);
  }

  /// Check if this template should generate a new expense
  bool shouldGenerateExpense(DateTime currentDate) {
    if (!isActive || !recurringConfig.isRecurring) return false;
    
    final nextDate = getNextScheduledDate();
    if (nextDate == null) return false;
    
    // Check if it's time to generate
    final shouldGenerate = currentDate.isAfter(nextDate) || 
                          currentDate.isAtSameMomentAs(nextDate);
    
    if (!shouldGenerate) return false;
    
    // Check if recurring should end
    return !recurringConfig.shouldEnd(currentDate, occurrenceCount);
  }

  /// Check if notification should be sent
  bool shouldSendNotification(DateTime currentDate) {
    if (!isActive || !recurringConfig.isRecurring || !recurringConfig.notifyBeforeCreation) {
      return false;
    }
    
    final nextDate = getNextScheduledDate();
    if (nextDate == null) return false;
    
    final notificationDate = nextDate.subtract(
      Duration(days: recurringConfig.notificationDaysBefore),
    );
    
    return currentDate.isAfter(notificationDate) && 
           currentDate.isBefore(nextDate);
  }

  RecurringExpenseTemplate copyWith({
    int? id,
    String? roomspaceId,
    String? title,
    String? description,
    double? amount,
    String? category,
    String? createdBy,
    String? paidBy,
    List<String>? selectedRoommates,
    String? splitType,
    Map<String, double>? customSplits,
    RecurringExpenseConfig? recurringConfig,
    DateTime? createdAt,
    DateTime? lastGenerated,
    int? occurrenceCount,
    bool? isActive,
    bool? isDeleted,
    DateTime? deletedAt,
  }) {
    return RecurringExpenseTemplate(
      id: id ?? this.id,
      roomspaceId: roomspaceId ?? this.roomspaceId,
      title: title ?? this.title,
      description: description ?? this.description,
      amount: amount ?? this.amount,
      category: category ?? this.category,
      createdBy: createdBy ?? this.createdBy,
      paidBy: paidBy ?? this.paidBy,
      selectedRoommates: selectedRoommates ?? this.selectedRoommates,
      splitType: splitType ?? this.splitType,
      customSplits: customSplits ?? this.customSplits,
      recurringConfig: recurringConfig ?? this.recurringConfig,
      createdAt: createdAt ?? this.createdAt,
      lastGenerated: lastGenerated ?? this.lastGenerated,
      occurrenceCount: occurrenceCount ?? this.occurrenceCount,
      isActive: isActive ?? this.isActive,
      isDeleted: isDeleted ?? this.isDeleted,
      deletedAt: deletedAt ?? this.deletedAt,
    );
  }

  bool get canUndoDelete {
    if (!isDeleted || deletedAt == null) return false;
    return DateTime.now().isBefore(deletedAt!.add(const Duration(days: 1)));
  }
}

/// Model for pending recurring expense notifications
class RecurringExpenseNotification {
  final int? id;
  final int templateId;
  final String roomspaceId;
  final String title;
  final double amount;
  final DateTime scheduledDate;
  final DateTime notificationDate;
  final bool isRead;
  final bool isProcessed;
  final DateTime createdAt;

  RecurringExpenseNotification({
    this.id,
    required this.templateId,
    required this.roomspaceId,
    required this.title,
    required this.amount,
    required this.scheduledDate,
    required this.notificationDate,
    this.isRead = false,
    this.isProcessed = false,
    required this.createdAt,
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'template_id': templateId,
      'roomspace_id': roomspaceId,
      'title': title,
      'amount': amount,
      'scheduled_date': scheduledDate.toUtc().toIso8601String(),
      'notification_date': notificationDate.toUtc().toIso8601String(),
      'is_read': isRead,
      'is_processed': isProcessed,
      'created_at': createdAt.toUtc().toIso8601String(),
    };
  }

  factory RecurringExpenseNotification.fromJson(Map<String, dynamic> json) {
    return RecurringExpenseNotification(
      id: json['id'],
      templateId: json['template_id'],
      roomspaceId: json['roomspace_id'],
      title: json['title'],
      amount: (json['amount'] as num).toDouble(),
      scheduledDate: DateTime.parse(json['scheduled_date']),
      notificationDate: DateTime.parse(json['notification_date']),
      isRead: json['is_read'] ?? false,
      isProcessed: json['is_processed'] ?? false,
      createdAt: DateTime.parse(json['created_at']),
    );
  }

  RecurringExpenseNotification copyWith({
    int? id,
    int? templateId,
    String? roomspaceId,
    String? title,
    double? amount,
    DateTime? scheduledDate,
    DateTime? notificationDate,
    bool? isRead,
    bool? isProcessed,
    DateTime? createdAt,
  }) {
    return RecurringExpenseNotification(
      id: id ?? this.id,
      templateId: templateId ?? this.templateId,
      roomspaceId: roomspaceId ?? this.roomspaceId,
      title: title ?? this.title,
      amount: amount ?? this.amount,
      scheduledDate: scheduledDate ?? this.scheduledDate,
      notificationDate: notificationDate ?? this.notificationDate,
      isRead: isRead ?? this.isRead,
      isProcessed: isProcessed ?? this.isProcessed,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}
