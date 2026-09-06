import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../../core/constants/app_constants.dart';

class SettlementObligation {
  final String id;
  final String workspaceId;
  final String periodId;
  final String fromUserId;
  final String toUserId;
  final String fromUserName;
  final String toUserName;
  final double originalAmount;
  final double settledAmount;
  final String status; // OPEN, PARTIALLY_SETTLED, SETTLED
  final DateTime createdAt;
  final DateTime updatedAt;

  const SettlementObligation({
    required this.id,
    required this.workspaceId,
    required this.periodId,
    required this.fromUserId,
    required this.toUserId,
    required this.fromUserName,
    required this.toUserName,
    required this.originalAmount,
    this.settledAmount = 0.0,
    this.status = AppConstants.obligationOpen,
    required this.createdAt,
    required this.updatedAt,
  });

  double get remainingAmount {
    final rem = originalAmount - settledAmount;
    return rem > 0 ? (rem * 100).round() / 100.0 : 0.0;
  }

  bool get isSettled => status == AppConstants.obligationSettled || remainingAmount <= 0.005;
  bool get isPartiallySettled => status == AppConstants.obligationPartiallySettled;
  bool get isOpen => status == AppConstants.obligationOpen;

  SettlementObligation copyWith({
    String? id,
    String? workspaceId,
    String? periodId,
    String? fromUserId,
    String? toUserId,
    String? fromUserName,
    String? toUserName,
    double? originalAmount,
    double? settledAmount,
    String? status,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return SettlementObligation(
      id: id ?? this.id,
      workspaceId: workspaceId ?? this.workspaceId,
      periodId: periodId ?? this.periodId,
      fromUserId: fromUserId ?? this.fromUserId,
      toUserId: toUserId ?? this.toUserId,
      fromUserName: fromUserName ?? this.fromUserName,
      toUserName: toUserName ?? this.toUserName,
      originalAmount: originalAmount ?? this.originalAmount,
      settledAmount: settledAmount ?? this.settledAmount,
      status: status ?? this.status,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'workspaceId': workspaceId,
      'periodId': periodId,
      'fromUserId': fromUserId,
      'toUserId': toUserId,
      'fromUserName': fromUserName,
      'toUserName': toUserName,
      'originalAmount': originalAmount,
      'settledAmount': settledAmount,
      'status': status,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': Timestamp.fromDate(updatedAt),
    };
  }

  factory SettlementObligation.fromMap(Map<String, dynamic> map, String documentId) {
    DateTime parseDate(dynamic val) {
      if (val is Timestamp) return val.toDate();
      if (val is String) return DateTime.tryParse(val) ?? DateTime.now();
      return DateTime.now();
    }

    return SettlementObligation(
      id: documentId.isNotEmpty ? documentId : (map['id'] ?? ''),
      workspaceId: map['workspaceId'] ?? '',
      periodId: map['periodId'] ?? '',
      fromUserId: map['fromUserId'] ?? '',
      toUserId: map['toUserId'] ?? '',
      fromUserName: map['fromUserName'] ?? 'Member',
      toUserName: map['toUserName'] ?? 'Member',
      originalAmount: (map['originalAmount'] is num) ? (map['originalAmount'] as num).toDouble() : 0.0,
      settledAmount: (map['settledAmount'] is num) ? (map['settledAmount'] as num).toDouble() : 0.0,
      status: map['status'] ?? AppConstants.obligationOpen,
      createdAt: parseDate(map['createdAt']),
      updatedAt: parseDate(map['updatedAt']),
    );
  }
}
