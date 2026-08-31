import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../../core/constants/app_constants.dart';

class Expense {
  final String id;
  final String workspaceId;
  final String periodId;
  final String description;
  final double amount;
  final String paidBy;
  final String createdBy;
  final DateTime createdAt;
  final DateTime updatedAt;
  final String status; // ACTIVE or DELETED
  final DateTime? deletedAt;
  final String? deletedBy;

  const Expense({
    required this.id,
    required this.workspaceId,
    required this.periodId,
    required this.description,
    required this.amount,
    required this.paidBy,
    required this.createdBy,
    required this.createdAt,
    required this.updatedAt,
    this.status = AppConstants.expenseActive,
    this.deletedAt,
    this.deletedBy,
  });

  bool get isActive => status == AppConstants.expenseActive;
  bool get isDeleted => status == AppConstants.expenseDeleted;

  Expense copyWith({
    String? id,
    String? workspaceId,
    String? periodId,
    String? description,
    double? amount,
    String? paidBy,
    String? createdBy,
    DateTime? createdAt,
    DateTime? updatedAt,
    String? status,
    DateTime? deletedAt,
    String? deletedBy,
  }) {
    return Expense(
      id: id ?? this.id,
      workspaceId: workspaceId ?? this.workspaceId,
      periodId: periodId ?? this.periodId,
      description: description ?? this.description,
      amount: amount ?? this.amount,
      paidBy: paidBy ?? this.paidBy,
      createdBy: createdBy ?? this.createdBy,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      status: status ?? this.status,
      deletedAt: deletedAt ?? this.deletedAt,
      deletedBy: deletedBy ?? this.deletedBy,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'workspaceId': workspaceId,
      'periodId': periodId,
      'description': description,
      'amount': amount,
      'paidBy': paidBy,
      'createdBy': createdBy,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': Timestamp.fromDate(updatedAt),
      'status': status,
      if (deletedAt != null) 'deletedAt': Timestamp.fromDate(deletedAt!),
      if (deletedBy != null) 'deletedBy': deletedBy,
    };
  }

  factory Expense.fromMap(Map<String, dynamic> map, String documentId) {
    DateTime parseDate(dynamic val) {
      if (val is Timestamp) return val.toDate();
      if (val is String) return DateTime.tryParse(val) ?? DateTime.now();
      if (val is int) return DateTime.fromMillisecondsSinceEpoch(val);
      return DateTime.now();
    }

    return Expense(
      id: documentId.isNotEmpty ? documentId : (map['id'] ?? ''),
      workspaceId: map['workspaceId'] ?? '',
      periodId: map['periodId'] ?? '',
      description: map['description'] ?? '',
      amount: (map['amount'] is num) ? (map['amount'] as num).toDouble() : 0.0,
      paidBy: map['paidBy'] ?? '',
      createdBy: map['createdBy'] ?? '',
      createdAt: parseDate(map['createdAt']),
      updatedAt: parseDate(map['updatedAt']),
      status: map['status'] ?? AppConstants.expenseActive,
      deletedAt: map['deletedAt'] != null ? parseDate(map['deletedAt']) : null,
      deletedBy: map['deletedBy'],
    );
  }
}
