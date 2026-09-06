import 'package:cloud_firestore/cloud_firestore.dart';

enum BudgetStatus {
  onTrack, // < 75%
  approachingLimit, // 75% - 99%
  exceeded, // >= 100%
}

class Budget {
  final String id;
  final String workspaceId;
  final String category; // 'overall' or category id e.g. 'food', 'rent'
  final double limitAmount;
  final String period; // 'monthly', 'weekly'
  final String createdBy;
  final DateTime createdAt;
  final List<int> notifiedThresholds; // e.g. [50, 75, 90, 100]

  const Budget({
    required this.id,
    required this.workspaceId,
    required this.category,
    required this.limitAmount,
    this.period = 'monthly',
    required this.createdBy,
    required this.createdAt,
    this.notifiedThresholds = const [],
  });

  bool get isOverall => category.toLowerCase() == 'overall';

  Map<String, dynamic> toMap() {
    return {
      'workspaceId': workspaceId,
      'category': category,
      'limitAmount': limitAmount,
      'period': period,
      'createdBy': createdBy,
      'createdAt': Timestamp.fromDate(createdAt),
      'notifiedThresholds': notifiedThresholds,
    };
  }

  factory Budget.fromDoc(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>? ?? {};
    return Budget.fromMap(data, doc.id);
  }

  factory Budget.fromMap(Map<String, dynamic> map, String id) {
    return Budget(
      id: id,
      workspaceId: map['workspaceId'] as String? ?? '',
      category: map['category'] as String? ?? 'overall',
      limitAmount: (map['limitAmount'] as num?)?.toDouble() ?? 0.0,
      period: map['period'] as String? ?? 'monthly',
      createdBy: map['createdBy'] as String? ?? '',
      createdAt: (map['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      notifiedThresholds: List<int>.from(map['notifiedThresholds'] as List? ?? []),
    );
  }

  Budget copyWith({
    String? id,
    String? workspaceId,
    String? category,
    double? limitAmount,
    String? period,
    String? createdBy,
    DateTime? createdAt,
    List<int>? notifiedThresholds,
  }) {
    return Budget(
      id: id ?? this.id,
      workspaceId: workspaceId ?? this.workspaceId,
      category: category ?? this.category,
      limitAmount: limitAmount ?? this.limitAmount,
      period: period ?? this.period,
      createdBy: createdBy ?? this.createdBy,
      createdAt: createdAt ?? this.createdAt,
      notifiedThresholds: notifiedThresholds ?? this.notifiedThresholds,
    );
  }

  /// Calculates budget status, spent percentage, and remaining amount.
  BudgetCalculation calculateProgress(double spentAmount) {
    final percentage = limitAmount > 0 ? (spentAmount / limitAmount) * 100.0 : 0.0;
    final remaining = limitAmount - spentAmount;

    BudgetStatus status;
    if (percentage >= 100.0) {
      status = BudgetStatus.exceeded;
    } else if (percentage >= 75.0) {
      status = BudgetStatus.approachingLimit;
    } else {
      status = BudgetStatus.onTrack;
    }

    return BudgetCalculation(
      budget: this,
      spentAmount: spentAmount,
      limitAmount: limitAmount,
      remainingAmount: remaining > 0 ? remaining : 0.0,
      overAmount: remaining < 0 ? remaining.abs() : 0.0,
      percentage: double.parse(percentage.toStringAsFixed(1)),
      status: status,
    );
  }
}

class BudgetCalculation {
  final Budget budget;
  final double spentAmount;
  final double limitAmount;
  final double remainingAmount;
  final double overAmount;
  final double percentage;
  final BudgetStatus status;

  const BudgetCalculation({
    required this.budget,
    required this.spentAmount,
    required this.limitAmount,
    required this.remainingAmount,
    required this.overAmount,
    required this.percentage,
    required this.status,
  });

  String get statusLabel {
    switch (status) {
      case BudgetStatus.onTrack:
        return 'On Track';
      case BudgetStatus.approachingLimit:
        return 'Approaching Limit';
      case BudgetStatus.exceeded:
        return 'Exceeded Limit';
    }
  }
}
