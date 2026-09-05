import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../../core/constants/app_constants.dart';

class ActivityLog {
  final String id;
  final String workspaceId;
  final String actorId;
  final String actorName;
  final String action; // ADDED, EDITED, PROPOSED_EDIT, APPROVED_EDIT, REJECTED_EDIT, DELETED, SETTLED
  final String? expenseId;
  final String? expenseDescription;
  final double? amount;
  final double? previousAmount;
  final String? paidBy;
  final String? paidByName;
  final DateTime timestamp;

  const ActivityLog({
    required this.id,
    required this.workspaceId,
    required this.actorId,
    required this.actorName,
    required this.action,
    this.expenseId,
    this.expenseDescription,
    this.amount,
    this.previousAmount,
    this.paidBy,
    this.paidByName,
    required this.timestamp,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'workspaceId': workspaceId,
      'actorId': actorId,
      'actorName': actorName,
      'action': action,
      if (expenseId != null) 'expenseId': expenseId,
      if (expenseDescription != null) 'expenseDescription': expenseDescription,
      if (amount != null) 'amount': amount,
      if (previousAmount != null) 'previousAmount': previousAmount,
      if (paidBy != null) 'paidBy': paidBy,
      if (paidByName != null) 'paidByName': paidByName,
      'timestamp': Timestamp.fromDate(timestamp),
    };
  }

  factory ActivityLog.fromMap(Map<String, dynamic> map, String documentId) {
    DateTime parseDate(dynamic val) {
      if (val is Timestamp) return val.toDate();
      if (val is String) return DateTime.tryParse(val) ?? DateTime.now();
      return DateTime.now();
    }

    return ActivityLog(
      id: documentId.isNotEmpty ? documentId : (map['id'] ?? ''),
      workspaceId: map['workspaceId'] ?? '',
      actorId: map['actorId'] ?? '',
      actorName: map['actorName'] ?? 'User',
      action: map['action'] ?? AppConstants.actionAdded,
      expenseId: map['expenseId'],
      expenseDescription: map['expenseDescription'],
      amount: (map['amount'] is num) ? (map['amount'] as num).toDouble() : null,
      previousAmount: (map['previousAmount'] is num) ? (map['previousAmount'] as num).toDouble() : null,
      paidBy: map['paidBy'],
      paidByName: map['paidByName'],
      timestamp: parseDate(map['timestamp']),
    );
  }
}
