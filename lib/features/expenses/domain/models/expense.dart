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
  final String category;
  final String splitType; // EQUAL, CUSTOM, PERCENTAGE, SINGLE
  final Map<String, double>? splitDetails; // memberId -> exact amount or percentage
  final String? splitSingleMemberId; // Used when splitType == SINGLE
  final String? receiptUrl;
  final String? receiptPath;
  final bool isRecurring;
  final String? recurringTemplateId;
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
    this.category = AppConstants.categoryOther,
    this.splitType = AppConstants.splitEqual,
    this.splitDetails,
    this.splitSingleMemberId,
    this.receiptUrl,
    this.receiptPath,
    this.isRecurring = false,
    this.recurringTemplateId,
    required this.createdAt,
    required this.updatedAt,
    this.status = AppConstants.expenseActive,
    this.deletedAt,
    this.deletedBy,
  });

  bool get isActive => status == AppConstants.expenseActive;
  bool get isDeleted => status == AppConstants.expenseDeleted;
  bool get hasReceipt => receiptUrl != null && receiptUrl!.isNotEmpty;

  /// Calculates the exact share (in currency amount) each participant is responsible for.
  /// Backward compatible with V1 50/50 and generalized for N members.
  Map<String, double> calculateShares(List<String> memberIds) {
    if (memberIds.isEmpty) return {};
    final shares = <String, double>{};

    switch (splitType) {
      case AppConstants.splitCustom:
        if (splitDetails != null && splitDetails!.isNotEmpty) {
          for (final memberId in memberIds) {
            shares[memberId] = splitDetails![memberId] ?? 0.0;
          }
        } else {
          // Fallback to equal split if details missing
          final equalShare = amount / memberIds.length;
          for (final memberId in memberIds) {
            shares[memberId] = equalShare;
          }
        }
        break;

      case AppConstants.splitPercentage:
        if (splitDetails != null && splitDetails!.isNotEmpty) {
          for (final memberId in memberIds) {
            final pct = splitDetails![memberId] ?? 0.0;
            shares[memberId] = (amount * (pct / 100.0) * 100).round() / 100.0;
          }
        } else {
          final equalShare = amount / memberIds.length;
          for (final memberId in memberIds) {
            shares[memberId] = equalShare;
          }
        }
        break;

      case AppConstants.splitSingle:
        final targetId = splitSingleMemberId ?? paidBy;
        for (final memberId in memberIds) {
          shares[memberId] = (memberId == targetId) ? amount : 0.0;
        }
        break;

      case AppConstants.splitEqual:
      default:
        final equalShare = amount / memberIds.length;
        for (final memberId in memberIds) {
          shares[memberId] = equalShare;
        }
        break;
    }

    return shares;
  }

  /// Returns the specific share of the expense for a given user.
  double getShareForUser(String userId, List<String> memberIds) {
    final shares = calculateShares(memberIds);
    return shares[userId] ?? 0.0;
  }

  Expense copyWith({
    String? id,
    String? workspaceId,
    String? periodId,
    String? description,
    double? amount,
    String? paidBy,
    String? createdBy,
    String? category,
    String? splitType,
    Map<String, double>? splitDetails,
    String? splitSingleMemberId,
    String? receiptUrl,
    String? receiptPath,
    bool? isRecurring,
    String? recurringTemplateId,
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
      category: category ?? this.category,
      splitType: splitType ?? this.splitType,
      splitDetails: splitDetails ?? this.splitDetails,
      splitSingleMemberId: splitSingleMemberId ?? this.splitSingleMemberId,
      receiptUrl: receiptUrl ?? this.receiptUrl,
      receiptPath: receiptPath ?? this.receiptPath,
      isRecurring: isRecurring ?? this.isRecurring,
      recurringTemplateId: recurringTemplateId ?? this.recurringTemplateId,
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
      'category': category,
      'splitType': splitType,
      if (splitDetails != null) 'splitDetails': splitDetails,
      if (splitSingleMemberId != null) 'splitSingleMemberId': splitSingleMemberId,
      if (receiptUrl != null) 'receiptUrl': receiptUrl,
      if (receiptPath != null) 'receiptPath': receiptPath,
      'isRecurring': isRecurring,
      if (recurringTemplateId != null) 'recurringTemplateId': recurringTemplateId,
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

    Map<String, double>? parseSplitDetails(dynamic val) {
      if (val is Map) {
        final result = <String, double>{};
        val.forEach((k, v) {
          if (v is num) result[k.toString()] = v.toDouble();
        });
        return result;
      }
      return null;
    }

    return Expense(
      id: documentId.isNotEmpty ? documentId : (map['id'] ?? ''),
      workspaceId: map['workspaceId'] ?? '',
      periodId: map['periodId'] ?? '',
      description: map['description'] ?? '',
      amount: (map['amount'] is num) ? (map['amount'] as num).toDouble() : 0.0,
      paidBy: map['paidBy'] ?? '',
      createdBy: map['createdBy'] ?? '',
      category: map['category'] ?? AppConstants.categoryOther,
      splitType: map['splitType'] ?? AppConstants.splitEqual,
      splitDetails: parseSplitDetails(map['splitDetails']),
      splitSingleMemberId: map['splitSingleMemberId'],
      receiptUrl: map['receiptUrl'],
      receiptPath: map['receiptPath'],
      isRecurring: map['isRecurring'] ?? false,
      recurringTemplateId: map['recurringTemplateId'],
      createdAt: parseDate(map['createdAt']),
      updatedAt: parseDate(map['updatedAt']),
      status: map['status'] ?? AppConstants.expenseActive,
      deletedAt: map['deletedAt'] != null ? parseDate(map['deletedAt']) : null,
      deletedBy: map['deletedBy'],
    );
  }
}
