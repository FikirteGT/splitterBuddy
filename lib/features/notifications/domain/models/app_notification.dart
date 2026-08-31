import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../../core/constants/app_constants.dart';

class AppNotification {
  final String id;
  final String userId;
  final String workspaceId;
  final String type; // ADD_EXPENSE, EDIT_EXPENSE, DELETE_EXPENSE, PENDING_EDIT, EDIT_APPROVED, EDIT_REJECTED, SETTLEMENT
  final String title;
  final String message;
  final String? expenseId;
  final String? pendingChangeId;
  final bool isRead;
  final DateTime createdAt;

  const AppNotification({
    required this.id,
    required this.userId,
    required this.workspaceId,
    required this.type,
    required this.title,
    required this.message,
    this.expenseId,
    this.pendingChangeId,
    this.isRead = false,
    required this.createdAt,
  });

  bool get isPendingEdit => type == AppConstants.notifPendingEdit;

  AppNotification copyWith({
    String? id,
    String? userId,
    String? workspaceId,
    String? type,
    String? title,
    String? message,
    String? expenseId,
    String? pendingChangeId,
    bool? isRead,
    DateTime? createdAt,
  }) {
    return AppNotification(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      workspaceId: workspaceId ?? this.workspaceId,
      type: type ?? this.type,
      title: title ?? this.title,
      message: message ?? this.message,
      expenseId: expenseId ?? this.expenseId,
      pendingChangeId: pendingChangeId ?? this.pendingChangeId,
      isRead: isRead ?? this.isRead,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'userId': userId,
      'workspaceId': workspaceId,
      'type': type,
      'title': title,
      'message': message,
      if (expenseId != null) 'expenseId': expenseId,
      if (pendingChangeId != null) 'pendingChangeId': pendingChangeId,
      'isRead': isRead,
      'createdAt': Timestamp.fromDate(createdAt),
    };
  }

  factory AppNotification.fromMap(Map<String, dynamic> map, String documentId) {
    DateTime parseDate(dynamic val) {
      if (val is Timestamp) return val.toDate();
      if (val is String) return DateTime.tryParse(val) ?? DateTime.now();
      return DateTime.now();
    }

    return AppNotification(
      id: documentId.isNotEmpty ? documentId : (map['id'] ?? ''),
      userId: map['userId'] ?? '',
      workspaceId: map['workspaceId'] ?? '',
      type: map['type'] ?? AppConstants.notifAddExpense,
      title: map['title'] ?? '',
      message: map['message'] ?? '',
      expenseId: map['expenseId'],
      pendingChangeId: map['pendingChangeId'],
      isRead: map['isRead'] ?? false,
      createdAt: parseDate(map['createdAt']),
    );
  }
}
