/// Models for payment confirmation system
library;

enum PaymentStatus {
  pending('PENDING'),
  confirmed('CONFIRMED'),
  rejected('REJECTED');

  final String value;
  const PaymentStatus(this.value);

  static PaymentStatus fromString(String value) {
    switch (value.toUpperCase()) {
      case 'PENDING':
        return PaymentStatus.pending;
      case 'CONFIRMED':
        return PaymentStatus.confirmed;
      case 'REJECTED':
        return PaymentStatus.rejected;
      default:
        return PaymentStatus.pending;
    }
  }
}

enum PaymentType {
  full('FULL'),
  partial('PARTIAL');

  final String value;
  const PaymentType(this.value);

  static PaymentType fromString(String value) {
    switch (value.toUpperCase()) {
      case 'FULL':
        return PaymentType.full;
      case 'PARTIAL':
        return PaymentType.partial;
      default:
        return PaymentType.partial;
    }
  }
}

/// Payment confirmation model
class PaymentConfirmation {
  final int id;
  final String roomspaceId;
  final String fromUserId;
  final String fromUserName;
  final String toUserId;
  final String toUserName;
  final double amount;
  final PaymentType paymentType;
  final PaymentStatus status;
  final String? notes;
  final String? paymentProofUrl;
  final DateTime paymentDate;
  final DateTime? confirmedAt;
  final String? rejectionReason;
  final DateTime createdAt;
  final DateTime updatedAt;

  PaymentConfirmation({
    required this.id,
    required this.roomspaceId,
    required this.fromUserId,
    required this.fromUserName,
    required this.toUserId,
    required this.toUserName,
    required this.amount,
    required this.paymentType,
    required this.status,
    this.notes,
    this.paymentProofUrl,
    required this.paymentDate,
    this.confirmedAt,
    this.rejectionReason,
    required this.createdAt,
    required this.updatedAt,
  });

  factory PaymentConfirmation.fromJson(Map<String, dynamic> json) {
    return PaymentConfirmation(
      id: json['id'] as int,
      roomspaceId: json['roomspace_id'] as String,
      fromUserId: json['from_user_id'] as String,
      fromUserName: json['from_user_name'] as String? ?? 'Unknown',
      toUserId: json['to_user_id'] as String,
      toUserName: json['to_user_name'] as String? ?? 'Unknown',
      amount: (json['amount'] as num).toDouble(),
      paymentType: PaymentType.fromString(json['payment_type'] as String),
      status: PaymentStatus.fromString(json['status'] as String),
      notes: json['notes'] as String?,
      paymentProofUrl: json['payment_proof_url'] as String?,
      paymentDate: DateTime.parse(json['payment_date'] as String),
      confirmedAt: json['confirmed_at'] != null
          ? DateTime.parse(json['confirmed_at'] as String)
          : null,
      rejectionReason: json['rejection_reason'] as String?,
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'roomspace_id': roomspaceId,
      'from_user_id': fromUserId,
      'from_user_name': fromUserName,
      'to_user_id': toUserId,
      'to_user_name': toUserName,
      'amount': amount,
      'payment_type': paymentType.value,
      'status': status.value,
      'notes': notes,
      'payment_proof_url': paymentProofUrl,
      'payment_date': paymentDate.toIso8601String(),
      'confirmed_at': confirmedAt?.toIso8601String(),
      'rejection_reason': rejectionReason,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }

  bool get isPending => status == PaymentStatus.pending;
  bool get isConfirmed => status == PaymentStatus.confirmed;
  bool get isRejected => status == PaymentStatus.rejected;
  bool get isFull => paymentType == PaymentType.full;
  bool get isPartial => paymentType == PaymentType.partial;

  String get statusText {
    switch (status) {
      case PaymentStatus.pending:
        return 'Pending';
      case PaymentStatus.confirmed:
        return 'Confirmed';
      case PaymentStatus.rejected:
        return 'Rejected';
    }
  }

  String get paymentTypeText {
    switch (paymentType) {
      case PaymentType.full:
        return 'Full Payment';
      case PaymentType.partial:
        return 'Partial Payment';
    }
  }
}

/// Request model for creating payment confirmation
class PaymentConfirmationRequest {
  final String toUserId;
  final double amount;
  final PaymentType paymentType;
  final String? notes;
  final String? paymentProofUrl;
  final DateTime paymentDate;

  PaymentConfirmationRequest({
    required this.toUserId,
    required this.amount,
    required this.paymentType,
    this.notes,
    this.paymentProofUrl,
    required this.paymentDate,
  });

  Map<String, dynamic> toJson() {
    return {
      'to_user_id': toUserId,
      'amount': amount,
      'payment_type': paymentType.value,
      'notes': notes,
      'payment_proof_url': paymentProofUrl,
      'payment_date': paymentDate.toUtc().toIso8601String(),
    };
  }
}

/// Payment statistics model
class PaymentStats {
  final int totalConfirmed;
  final int totalPending;
  final int totalRejected;
  final double totalAmount;

  PaymentStats({
    required this.totalConfirmed,
    required this.totalPending,
    required this.totalRejected,
    required this.totalAmount,
  });

  factory PaymentStats.fromJson(Map<String, dynamic> json) {
    return PaymentStats(
      totalConfirmed: json['total_confirmed'] as int,
      totalPending: json['total_pending'] as int,
      totalRejected: json['total_rejected'] as int,
      totalAmount: (json['total_amount'] as num).toDouble(),
    );
  }

  int get totalPayments => totalConfirmed + totalPending + totalRejected;
}
