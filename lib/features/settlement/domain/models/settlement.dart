import 'package:cloud_firestore/cloud_firestore.dart';

class Settlement {
  final String id;
  final String workspaceId;
  final String periodId;
  final double amount;
  final String payerId;
  final String receiverId;
  final String payerName;
  final String receiverName;
  final String initiatedBy;
  final String initiatedByName;
  final DateTime timestamp;

  const Settlement({
    required this.id,
    required this.workspaceId,
    required this.periodId,
    required this.amount,
    required this.payerId,
    required this.receiverId,
    required this.payerName,
    required this.receiverName,
    required this.initiatedBy,
    required this.initiatedByName,
    required this.timestamp,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'workspaceId': workspaceId,
      'periodId': periodId,
      'amount': amount,
      'payerId': payerId,
      'receiverId': receiverId,
      'payerName': payerName,
      'receiverName': receiverName,
      'initiatedBy': initiatedBy,
      'initiatedByName': initiatedByName,
      'timestamp': Timestamp.fromDate(timestamp),
    };
  }

  factory Settlement.fromMap(Map<String, dynamic> map, String documentId) {
    DateTime parseDate(dynamic val) {
      if (val is Timestamp) return val.toDate();
      if (val is String) return DateTime.tryParse(val) ?? DateTime.now();
      return DateTime.now();
    }

    return Settlement(
      id: documentId.isNotEmpty ? documentId : (map['id'] ?? ''),
      workspaceId: map['workspaceId'] ?? '',
      periodId: map['periodId'] ?? '',
      amount: (map['amount'] is num) ? (map['amount'] as num).toDouble() : 0.0,
      payerId: map['payerId'] ?? '',
      receiverId: map['receiverId'] ?? '',
      payerName: map['payerName'] ?? 'Partner',
      receiverName: map['receiverName'] ?? 'Partner',
      initiatedBy: map['initiatedBy'] ?? '',
      initiatedByName: map['initiatedByName'] ?? 'User',
      timestamp: parseDate(map['timestamp']),
    );
  }
}
