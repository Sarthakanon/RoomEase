enum SubscriptionPlan {
  free,
  pro,
}

enum SubscriptionStatus {
  active,
  expired,
  cancelled,
  pending,
}

class SubscriptionLimits {
  final int maxRoomspaces;
  final int maxMembersPerRoomspace;
  final bool analyticsAccess;
  final bool prioritySupport;
  final bool customCategories;
  final bool exportFeatures;
  final bool advancedReports;
  final bool recurringExpenses;
  final bool receiptScanning;

  const SubscriptionLimits({
    required this.maxRoomspaces,
    required this.maxMembersPerRoomspace,
    required this.analyticsAccess,
    required this.prioritySupport,
    required this.customCategories,
    required this.exportFeatures,
    required this.advancedReports,
    required this.recurringExpenses,
    required this.receiptScanning,
  });

  static const SubscriptionLimits free = SubscriptionLimits(
    maxRoomspaces: 2,
    maxMembersPerRoomspace: 10,
    analyticsAccess: true, // Basic analytics available
    prioritySupport: false,
    customCategories: true, // Basic categories available
    exportFeatures: false, // Export blocked in free plan
    advancedReports: false, // Advanced reports blocked
    recurringExpenses: true, // Available in free
    receiptScanning: true, // Available in free
  );

  static const SubscriptionLimits pro = SubscriptionLimits(
    maxRoomspaces: 10,
    maxMembersPerRoomspace: 10, // Same as free plan
    analyticsAccess: true,
    prioritySupport: false, // Removed
    customCategories: true,
    exportFeatures: true, // Export available in pro
    advancedReports: false, // Removed
    recurringExpenses: true,
    receiptScanning: true,
  );
}

class SubscriptionPlanInfo {
  final SubscriptionPlan plan;
  final String name;
  final String description;
  final double monthlyPrice;
  final double yearlyPrice;
  final SubscriptionLimits limits;
  final List<String> features;
  final String? badge;

  const SubscriptionPlanInfo({
    required this.plan,
    required this.name,
    required this.description,
    required this.monthlyPrice,
    required this.yearlyPrice,
    required this.limits,
    required this.features,
    this.badge,
  });

  static const List<SubscriptionPlanInfo> allPlans = [
    SubscriptionPlanInfo(
      plan: SubscriptionPlan.free,
      name: 'Free',
      description: 'Perfect for getting started',
      monthlyPrice: 0,
      yearlyPrice: 0,
      limits: SubscriptionLimits.free,
      features: [
        'Up to 2 roomspaces',
        'Up to 10 members per roomspace',
        'Basic expense tracking',
        'Split bills equally',
        'Basic analytics',
        'Recurring expenses',
        'Receipt scanning',
      ],
    ),
    SubscriptionPlanInfo(
      plan: SubscriptionPlan.pro,
      name: 'Pro',
      description: 'For power users and teams',
      monthlyPrice: 499,
      yearlyPrice: 4999,
      limits: SubscriptionLimits.pro,
      features: [
        'Up to 10 roomspaces',
        'Advanced analytics & insights',
        'Export to PDF/Excel',
        'All Free features',
      ],
      badge: 'Best Value',
    ),
  ];

  static SubscriptionPlanInfo getPlanInfo(SubscriptionPlan plan) {
    return allPlans.firstWhere((p) => p.plan == plan);
  }
}

class UserSubscription {
  final String id;
  final String userId;
  final SubscriptionPlan plan;
  final SubscriptionStatus status;
  final DateTime? startDate;
  final DateTime? endDate;
  final DateTime? nextBillingDate;
  final bool isYearly;
  final double amount;
  final String? paymentMethod;
  final DateTime createdAt;
  final DateTime updatedAt;

  const UserSubscription({
    required this.id,
    required this.userId,
    required this.plan,
    required this.status,
    this.startDate,
    this.endDate,
    this.nextBillingDate,
    required this.isYearly,
    required this.amount,
    this.paymentMethod,
    required this.createdAt,
    required this.updatedAt,
  });

  factory UserSubscription.fromJson(Map<String, dynamic> json) {
    return UserSubscription(
      id: json['id'] as String,
      userId: json['user_id'] as String,
      plan: SubscriptionPlan.values.firstWhere(
        (e) => e.name == json['plan'],
        orElse: () => SubscriptionPlan.free,
      ),
      status: SubscriptionStatus.values.firstWhere(
        (e) => e.name == json['status'],
        orElse: () => SubscriptionStatus.expired,
      ),
      startDate: json['start_date'] != null 
          ? DateTime.parse(json['start_date']) 
          : null,
      endDate: json['end_date'] != null 
          ? DateTime.parse(json['end_date']) 
          : null,
      nextBillingDate: json['next_billing_date'] != null 
          ? DateTime.parse(json['next_billing_date']) 
          : null,
      isYearly: json['is_yearly'] as bool? ?? false,
      amount: (json['amount'] as num?)?.toDouble() ?? 0.0,
      paymentMethod: json['payment_method'] as String?,
      createdAt: DateTime.parse(json['created_at']),
      updatedAt: DateTime.parse(json['updated_at']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'user_id': userId,
      'plan': plan.name,
      'status': status.name,
      'start_date': startDate?.toIso8601String(),
      'end_date': endDate?.toIso8601String(),
      'next_billing_date': nextBillingDate?.toIso8601String(),
      'is_yearly': isYearly,
      'amount': amount,
      'payment_method': paymentMethod,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }

  bool get isActive => status == SubscriptionStatus.active;
  bool get isExpired => status == SubscriptionStatus.expired;
  bool get isFree => plan == SubscriptionPlan.free;

  SubscriptionLimits get limits {
    switch (plan) {
      case SubscriptionPlan.free:
        return SubscriptionLimits.free;
      case SubscriptionPlan.pro:
        return SubscriptionLimits.pro;
    }
  }

  int get daysUntilExpiry {
    if (endDate == null) return -1;
    return endDate!.difference(DateTime.now()).inDays;
  }

  bool get isNearExpiry => daysUntilExpiry >= 0 && daysUntilExpiry <= 7;
}