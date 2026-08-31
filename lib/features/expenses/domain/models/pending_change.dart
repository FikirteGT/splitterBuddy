import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../../core/constants/app_constants.dart';

class PendingChange {
  final String id;
  final String expenseId;
  final String workspaceId;
  final String periodId;
  final String requesterId;
  final String requesterName;
  final String partnerId;
  final Map<String, dynamic> originalValues; // description, amount, paidBy
  final Map<String, dynamic> proposedValues; // description, amount, paidBy
  final String status; // PENDING, APPROVED, REJECTED
  final DateTime createdAt;
  final DateTime? reviewedAt;

  const PendingChange({
    required this.id,
    required this.expenseId,
    required this.workspaceId,
    required this.periodId,
    required this.requesterId,
    required this.requesterName,
    required this.partnerId,
    required this.originalValues,
    required this.proposedValues,
    this.status = AppConstants.pendingChangePending,
    required this.createdAt,
    this.reviewedAt,
  });

  bool get isPending => status == AppConstants.pendingChangePending;
  bool get isApproved => status == AppConstants.pendingChangeApproved;
  bool get isRejected => status == AppConstants.pendingChangeRejected;

  String get originalDescription => originalValues['description']?.toString() ?? '';
  double get originalAmount => (originalValues['amount'] is num) ? (originalValues['amount'] as num).toDouble() : 0.0;
  String get originalPaidBy => originalValues['paidBy']?.toString() ?? '';

  String get proposedDescription => proposedValues['description']?.toString() ?? '';
  double get proposedAmount => (proposedValues['amount'] is num) ? (proposedValues['amount'] as num).toDouble() : 0.0;
  String get proposedPaidBy => proposedValues['paidBy']?.toString() ?? '';

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'expenseId': expenseId,
      'workspaceId': workspaceId,
      'periodId': periodId,
      'requesterId': requesterId,
      'requesterName': requesterName,
      'partnerId': partnerId,
      'originalValues': originalValues,
      'proposedValues': proposedValues,
      'status': status,
      'createdAt': Timestamp.fromDate(createdAt),
      if (reviewedAt != null) 'reviewedAt': Timestamp.fromDate(reviewedAt!),
    };
  }

  factory PendingChange.fromMap(Map<String, dynamic> map, String documentId) {
    DateTime parseDate(dynamic val) {
      if (val is Timestamp) return val.toDate();
      if (val is String) return DateTime.tryParse(val) ?? DateTime.now();
      return DateTime.now();
    }

    return PendingChange(
      id: documentId.isNotEmpty ? documentId : (map['id'] ?? ''),
      expenseId: map['expenseId'] ?? '',
      workspaceId: map['workspaceId'] ?? '',
      periodId: map['periodId'] ?? '',
      requesterId: map['requesterId'] ?? '',
      requesterName: map['requesterName'] ?? 'Partner',
      partnerId: map['partnerId'] ?? '',
      originalValues: Map<String, dynamic>.from(map['originalValues'] ?? {}),
      proposedValues: Map<String, dynamic>.from(map['proposedValues'] ?? {}),
      status: map['status'] ?? AppConstants.pendingChangePending,
      createdAt: parseDate(map['createdAt']),
      reviewedAt: map['reviewedAt'] != null ? parseDate(map['reviewedAt']) : null,
    );
  }
}
