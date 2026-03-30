/// Analytics data models for AI-powered spending insights
/// 
/// This file contains all data models used for analytics features including:
/// - Spending summaries
/// - Predictions and forecasts
/// - Spending patterns
/// - Anomaly detection
/// - Budget recommendations
/// - Roomspace analytics
library;

/// Represents a spending summary with key metrics
class AnalyticsSummary {
  final double totalSpent;
  final double predictedNextMonth;
  final double savingsPotential;
  final List<CategorySpend> topCategories;
  final String spendingTrend; // "increasing", "decreasing", "stable"

  AnalyticsSummary({
    required this.totalSpent,
    required this.predictedNextMonth,
    required this.savingsPotential,
    required this.topCategories,
    required this.spendingTrend,
  });

  factory AnalyticsSummary.fromJson(Map<String, dynamic> json) {
    return AnalyticsSummary(
      totalSpent: (json['total_spent'] ?? 0.0).toDouble(),
      predictedNextMonth: (json['predicted_next_month'] ?? 0.0).toDouble(),
      savingsPotential: (json['savings_potential'] ?? 0.0).toDouble(),
      topCategories: (json['top_categories'] as List<dynamic>?)
              ?.map((cat) => CategorySpend.fromJson(cat as Map<String, dynamic>))
              .toList() ??
          [],
      spendingTrend: json['spending_trend'] ?? 'stable',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'total_spent': totalSpent,
      'predicted_next_month': predictedNextMonth,
      'savings_potential': savingsPotential,
      'top_categories': topCategories.map((cat) => cat.toJson()).toList(),
      'spending_trend': spendingTrend,
    };
  }
}

/// Represents spending in a specific category
class CategorySpend {
  final String category;
  final double amount;
  final double percentage;
  final int count;

  CategorySpend({
    required this.category,
    required this.amount,
    required this.percentage,
    required this.count,
  });

  factory CategorySpend.fromJson(Map<String, dynamic> json) {
    return CategorySpend(
      category: json['category'] ?? '',
      amount: (json['amount'] ?? 0.0).toDouble(),
      percentage: (json['percentage'] ?? 0.0).toDouble(),
      count: json['count'] ?? 0,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'category': category,
      'amount': amount,
      'percentage': percentage,
      'count': count,
    };
  }
}

/// Represents a spending prediction for a category
class SpendingPrediction {
  final String category;
  final double predictedAmount;
  final double confidenceLow;
  final double confidenceHigh;
  final double historicalAvg;

  SpendingPrediction({
    required this.category,
    required this.predictedAmount,
    required this.confidenceLow,
    required this.confidenceHigh,
    required this.historicalAvg,
  });

  factory SpendingPrediction.fromJson(Map<String, dynamic> json) {
    return SpendingPrediction(
      category: json['category'] ?? '',
      predictedAmount: (json['predicted_amount'] ?? 0.0).toDouble(),
      confidenceLow: (json['confidence_low'] ?? 0.0).toDouble(),
      confidenceHigh: (json['confidence_high'] ?? 0.0).toDouble(),
      historicalAvg: (json['historical_avg'] ?? 0.0).toDouble(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'category': category,
      'predicted_amount': predictedAmount,
      'confidence_low': confidenceLow,
      'confidence_high': confidenceHigh,
      'historical_avg': historicalAvg,
    };
  }
}

/// Contains predictions and metadata
class PredictionResult {
  final List<SpendingPrediction> predictions;
  final bool insufficientData;
  final int dataDays;
  final String? message;

  PredictionResult({
    required this.predictions,
    required this.insufficientData,
    required this.dataDays,
    this.message,
  });

  factory PredictionResult.fromJson(Map<String, dynamic> json) {
    return PredictionResult(
      predictions: (json['predictions'] as List<dynamic>?)
              ?.map((pred) => SpendingPrediction.fromJson(pred as Map<String, dynamic>))
              .toList() ??
          [],
      insufficientData: json['insufficient_data'] ?? false,
      dataDays: json['data_days'] ?? 0,
      message: json['message'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'predictions': predictions.map((pred) => pred.toJson()).toList(),
      'insufficient_data': insufficientData,
      'data_days': dataDays,
      if (message != null) 'message': message,
    };
  }
}

/// Represents a detected spending pattern
class SpendingPattern {
  final String category;
  final String patternType; // "daily", "weekly", "monthly", "irregular"
  final double averageAmount;
  final int frequency;
  final double totalAmount;
  final String? nextExpectedDate;

  SpendingPattern({
    required this.category,
    required this.patternType,
    required this.averageAmount,
    required this.frequency,
    required this.totalAmount,
    this.nextExpectedDate,
  });

  factory SpendingPattern.fromJson(Map<String, dynamic> json) {
    return SpendingPattern(
      category: json['category'] ?? '',
      patternType: json['pattern_type'] ?? 'irregular',
      averageAmount: (json['average_amount'] ?? 0.0).toDouble(),
      frequency: json['frequency'] ?? 0,
      totalAmount: (json['total_amount'] ?? 0.0).toDouble(),
      nextExpectedDate: json['next_expected_date'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'category': category,
      'pattern_type': patternType,
      'average_amount': averageAmount,
      'frequency': frequency,
      'total_amount': totalAmount,
      if (nextExpectedDate != null) 'next_expected_date': nextExpectedDate,
    };
  }
}

/// Represents a detected spending anomaly
class Anomaly {
  final int expenseId;
  final double amount;
  final String category;
  final double anomalyScore;
  final String reason;
  final double categoryAverage;
  final String date;

  Anomaly({
    required this.expenseId,
    required this.amount,
    required this.category,
    required this.anomalyScore,
    required this.reason,
    required this.categoryAverage,
    required this.date,
  });

  factory Anomaly.fromJson(Map<String, dynamic> json) {
    return Anomaly(
      expenseId: json['expense_id'] ?? 0,
      amount: (json['amount'] ?? 0.0).toDouble(),
      category: json['category'] ?? '',
      anomalyScore: (json['anomaly_score'] ?? 0.0).toDouble(),
      reason: json['reason'] ?? '',
      categoryAverage: (json['category_average'] ?? 0.0).toDouble(),
      date: json['date'] ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'expense_id': expenseId,
      'amount': amount,
      'category': category,
      'anomaly_score': anomalyScore,
      'reason': reason,
      'category_average': categoryAverage,
      'date': date,
    };
  }
}

/// Represents a budget recommendation
class Recommendation {
  final String id;
  final String type; // "budget_limit", "reduce_spending", "savings_opportunity"
  final String category;
  final double currentSpending;
  final double suggestedLimit;
  final double potentialSavings;
  final String description;
  final int priority; // 1=high, 2=medium, 3=low

  Recommendation({
    required this.id,
    required this.type,
    required this.category,
    required this.currentSpending,
    required this.suggestedLimit,
    required this.potentialSavings,
    required this.description,
    required this.priority,
  });

  factory Recommendation.fromJson(Map<String, dynamic> json) {
    return Recommendation(
      id: json['id'] ?? '',
      type: json['type'] ?? '',
      category: json['category'] ?? '',
      currentSpending: (json['current_spending'] ?? 0.0).toDouble(),
      suggestedLimit: (json['suggested_limit'] ?? 0.0).toDouble(),
      potentialSavings: (json['potential_savings'] ?? 0.0).toDouble(),
      description: json['description'] ?? '',
      priority: json['priority'] ?? 3,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'type': type,
      'category': category,
      'current_spending': currentSpending,
      'suggested_limit': suggestedLimit,
      'potential_savings': potentialSavings,
      'description': description,
      'priority': priority,
    };
  }
}

/// Represents spending trends over time
class SpendingTrend {
  final String date;
  final double amount;

  SpendingTrend({
    required this.date,
    required this.amount,
  });

  factory SpendingTrend.fromJson(Map<String, dynamic> json) {
    return SpendingTrend(
      date: json['date'] ?? '',
      amount: (json['amount'] ?? 0.0).toDouble(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'date': date,
      'amount': amount,
    };
  }
}

/// Represents trends response with metadata
class TrendsResponse {
  final List<SpendingTrend> trends;
  final String groupBy;
  final String startDate;
  final String endDate;

  TrendsResponse({
    required this.trends,
    required this.groupBy,
    required this.startDate,
    required this.endDate,
  });

  factory TrendsResponse.fromJson(Map<String, dynamic> json) {
    return TrendsResponse(
      trends: (json['trends'] as List<dynamic>?)
              ?.map((trend) => SpendingTrend.fromJson(trend as Map<String, dynamic>))
              .toList() ??
          [],
      groupBy: json['group_by'] ?? 'day',
      startDate: json['start_date'] ?? '',
      endDate: json['end_date'] ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'trends': trends.map((trend) => trend.toJson()).toList(),
      'group_by': groupBy,
      'start_date': startDate,
      'end_date': endDate,
    };
  }
}

/// Represents patterns response with metadata
class PatternsResponse {
  final List<SpendingPattern> patterns;
  final String startDate;
  final String endDate;

  PatternsResponse({
    required this.patterns,
    required this.startDate,
    required this.endDate,
  });

  factory PatternsResponse.fromJson(Map<String, dynamic> json) {
    return PatternsResponse(
      patterns: (json['patterns'] as List<dynamic>?)
              ?.map((pattern) => SpendingPattern.fromJson(pattern as Map<String, dynamic>))
              .toList() ??
          [],
      startDate: json['start_date'] ?? '',
      endDate: json['end_date'] ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'patterns': patterns.map((pattern) => pattern.toJson()).toList(),
      'start_date': startDate,
      'end_date': endDate,
    };
  }
}

/// Represents anomalies response with metadata
class AnomaliesResponse {
  final List<Anomaly> anomalies;
  final int count;

  AnomaliesResponse({
    required this.anomalies,
    required this.count,
  });

  factory AnomaliesResponse.fromJson(Map<String, dynamic> json) {
    return AnomaliesResponse(
      anomalies: (json['anomalies'] as List<dynamic>?)
              ?.map((anomaly) => Anomaly.fromJson(anomaly as Map<String, dynamic>))
              .toList() ??
          [],
      count: json['count'] ?? 0,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'anomalies': anomalies.map((anomaly) => anomaly.toJson()).toList(),
      'count': count,
    };
  }
}

/// Represents recommendations response with metadata
class RecommendationsResponse {
  final List<Recommendation> recommendations;
  final int count;

  RecommendationsResponse({
    required this.recommendations,
    required this.count,
  });

  factory RecommendationsResponse.fromJson(Map<String, dynamic> json) {
    return RecommendationsResponse(
      recommendations: (json['recommendations'] as List<dynamic>?)
              ?.map((rec) => Recommendation.fromJson(rec as Map<String, dynamic>))
              .toList() ??
          [],
      count: json['count'] ?? 0,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'recommendations': recommendations.map((rec) => rec.toJson()).toList(),
      'count': count,
    };
  }
}

/// Represents a member's contribution to roomspace expenses
class MemberContribution {
  final String userUid;
  final String userName;
  final double totalPaid;
  final double totalOwed;
  final double netContribution;
  final double percentage;

  MemberContribution({
    required this.userUid,
    required this.userName,
    required this.totalPaid,
    required this.totalOwed,
    required this.netContribution,
    required this.percentage,
  });

  factory MemberContribution.fromJson(Map<String, dynamic> json) {
    return MemberContribution(
      userUid: json['user_uid'] ?? '',
      userName: json['user_name'] ?? '',
      totalPaid: (json['total_paid'] ?? 0.0).toDouble(),
      totalOwed: (json['total_owed'] ?? 0.0).toDouble(),
      netContribution: (json['net_contribution'] ?? 0.0).toDouble(),
      percentage: (json['percentage'] ?? 0.0).toDouble(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'user_uid': userUid,
      'user_name': userName,
      'total_paid': totalPaid,
      'total_owed': totalOwed,
      'net_contribution': netContribution,
      'percentage': percentage,
    };
  }
}

/// Represents the time range for analytics
class TimeRange {
  final String startDate;
  final String endDate;

  TimeRange({
    required this.startDate,
    required this.endDate,
  });

  factory TimeRange.fromJson(Map<String, dynamic> json) {
    return TimeRange(
      startDate: json['start_date'] ?? '',
      endDate: json['end_date'] ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'start_date': startDate,
      'end_date': endDate,
    };
  }
}

/// Represents analytics for a specific roomspace
class RoomspaceAnalytics {
  final String roomspaceId;
  final String roomspaceName;
  final double totalSharedExpenses;
  final List<MemberContribution> memberContributions;
  final List<CategorySpend> categoryBreakdown;
  final TimeRange timeRange;

  RoomspaceAnalytics({
    required this.roomspaceId,
    required this.roomspaceName,
    required this.totalSharedExpenses,
    required this.memberContributions,
    required this.categoryBreakdown,
    required this.timeRange,
  });

  factory RoomspaceAnalytics.fromJson(Map<String, dynamic> json) {
    return RoomspaceAnalytics(
      roomspaceId: json['roomspace_id'] ?? '',
      roomspaceName: json['roomspace_name'] ?? '',
      totalSharedExpenses: (json['total_shared_expenses'] ?? 0.0).toDouble(),
      memberContributions: (json['member_contributions'] as List<dynamic>?)
              ?.map((contrib) => MemberContribution.fromJson(contrib as Map<String, dynamic>))
              .toList() ??
          [],
      categoryBreakdown: (json['category_breakdown'] as List<dynamic>?)
              ?.map((cat) => CategorySpend.fromJson(cat as Map<String, dynamic>))
              .toList() ??
          [],
      timeRange: TimeRange.fromJson(json['time_range'] ?? {}),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'roomspace_id': roomspaceId,
      'roomspace_name': roomspaceName,
      'total_shared_expenses': totalSharedExpenses,
      'member_contributions': memberContributions.map((contrib) => contrib.toJson()).toList(),
      'category_breakdown': categoryBreakdown.map((cat) => cat.toJson()).toList(),
      'time_range': timeRange.toJson(),
    };
  }
}
