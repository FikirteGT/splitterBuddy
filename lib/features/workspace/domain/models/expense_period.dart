import 'package:cloud_firestore/cloud_firestore.dart';

class ExpensePeriod {
  final String id;
  final String workspaceId;
  final int periodNumber;
  final bool isSettled;
  final DateTime? settledAt;
  final String? settledBy;
  final double? settledAmount;
  final DateTime createdAt;

  const ExpensePeriod({
    required this.id,
    required this.workspaceId,
    required this.periodNumber,
    this.isSettled = false,
    this.settledAt,
    this.settledBy,
    this.settledAmount,
    required this.createdAt,
  });

  ExpensePeriod copyWith({
    String? id,
    String? workspaceId,
    int? periodNumber,
    bool? isSettled,
    DateTime? settledAt,
    String? settledBy,
    double? settledAmount,
    DateTime? createdAt,
  }) {
    return ExpensePeriod(
      id: id ?? this.id,
      workspaceId: workspaceId ?? this.workspaceId,
      periodNumber: periodNumber ?? this.periodNumber,
      isSettled: isSettled ?? this.isSettled,
      settledAt: settledAt ?? this.settledAt,
      settledBy: settledBy ?? this.settledBy,
      settledAmount: settledAmount ?? this.settledAmount,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'workspaceId': workspaceId,
      'periodNumber': periodNumber,
      'isSettled': isSettled,
      if (settledAt != null) 'settledAt': Timestamp.fromDate(settledAt!),
      if (settledBy != null) 'settledBy': settledBy,
      if (settledAmount != null) 'settledAmount': settledAmount,
      'createdAt': Timestamp.fromDate(createdAt),
    };
  }

  factory ExpensePeriod.fromMap(Map<String, dynamic> map, String documentId) {
    DateTime parseDate(dynamic val) {
      if (val is Timestamp) return val.toDate();
      if (val is String) return DateTime.tryParse(val) ?? DateTime.now();
      return DateTime.now();
    }

    return ExpensePeriod(
      id: documentId.isNotEmpty ? documentId : (map['id'] ?? ''),
      workspaceId: map['workspaceId'] ?? '',
      periodNumber: map['periodNumber'] is int ? map['periodNumber'] : 1,
      isSettled: map['isSettled'] ?? false,
      settledAt: map['settledAt'] != null ? parseDate(map['settledAt']) : null,
      settledBy: map['settledBy'],
      settledAmount: (map['settledAmount'] is num) ? (map['settledAmount'] as num).toDouble() : null,
      createdAt: parseDate(map['createdAt']),
    );
  }
}
