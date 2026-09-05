import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../../core/constants/app_constants.dart';

class RecurringExpense {
  final String id;
  final String workspaceId;
  final String description;
  final double amount;
  final String paidBy;
  final String category;
  final String splitType;
  final Map<String, double>? splitDetails;
  final String? splitSingleMemberId;
  final String frequency; // DAILY, WEEKLY, MONTHLY, YEARLY
  final bool isActive;
  final DateTime nextDueDate;
  final DateTime? lastGeneratedDate;
  final String createdBy;
  final DateTime createdAt;
  final DateTime updatedAt;

  const RecurringExpense({
    required this.id,
    required this.workspaceId,
    required this.description,
    required this.amount,
    required this.paidBy,
    this.category = AppConstants.categoryOther,
    this.splitType = AppConstants.splitEqual,
    this.splitDetails,
    this.splitSingleMemberId,
    this.frequency = AppConstants.recurrenceMonthly,
    this.isActive = true,
    required this.nextDueDate,
    this.lastGeneratedDate,
    required this.createdBy,
    required this.createdAt,
    required this.updatedAt,
  });

  /// Computes the next due date based on frequency.
  static DateTime calculateNextDueDate(DateTime fromDate, String frequency) {
    switch (frequency) {
      case AppConstants.recurrenceDaily:
        return fromDate.add(const Duration(days: 1));
      case AppConstants.recurrenceWeekly:
        return fromDate.add(const Duration(days: 7));
      case AppConstants.recurrenceYearly:
        return DateTime(fromDate.year + 1, fromDate.month, fromDate.day, fromDate.hour, fromDate.minute);
      case AppConstants.recurrenceMonthly:
      default:
        // Safe month increment preserving day
        final nextYear = fromDate.month == 12 ? fromDate.year + 1 : fromDate.year;
        final nextMonth = fromDate.month == 12 ? 1 : fromDate.month + 1;
        // Clamp day to month's last day if needed
        final daysInNextMonth = DateTime(nextYear, nextMonth + 1, 0).day;
        final safeDay = fromDate.day > daysInNextMonth ? daysInNextMonth : fromDate.day;
        return DateTime(nextYear, nextMonth, safeDay, fromDate.hour, fromDate.minute);
    }
  }

  RecurringExpense copyWith({
    String? id,
    String? workspaceId,
    String? description,
    double? amount,
    String? paidBy,
    String? category,
    String? splitType,
    Map<String, double>? splitDetails,
    String? splitSingleMemberId,
    String? frequency,
    bool? isActive,
    DateTime? nextDueDate,
    DateTime? lastGeneratedDate,
    String? createdBy,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return RecurringExpense(
      id: id ?? this.id,
      workspaceId: workspaceId ?? this.workspaceId,
      description: description ?? this.description,
      amount: amount ?? this.amount,
      paidBy: paidBy ?? this.paidBy,
      category: category ?? this.category,
      splitType: splitType ?? this.splitType,
      splitDetails: splitDetails ?? this.splitDetails,
      splitSingleMemberId: splitSingleMemberId ?? this.splitSingleMemberId,
      frequency: frequency ?? this.frequency,
      isActive: isActive ?? this.isActive,
      nextDueDate: nextDueDate ?? this.nextDueDate,
      lastGeneratedDate: lastGeneratedDate ?? this.lastGeneratedDate,
      createdBy: createdBy ?? this.createdBy,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'workspaceId': workspaceId,
      'description': description,
      'amount': amount,
      'paidBy': paidBy,
      'category': category,
      'splitType': splitType,
      if (splitDetails != null) 'splitDetails': splitDetails,
      if (splitSingleMemberId != null) 'splitSingleMemberId': splitSingleMemberId,
      'frequency': frequency,
      'isActive': isActive,
      'nextDueDate': Timestamp.fromDate(nextDueDate),
      if (lastGeneratedDate != null) 'lastGeneratedDate': Timestamp.fromDate(lastGeneratedDate!),
      'createdBy': createdBy,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': Timestamp.fromDate(updatedAt),
    };
  }

  factory RecurringExpense.fromMap(Map<String, dynamic> map, String documentId) {
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

    return RecurringExpense(
      id: documentId.isNotEmpty ? documentId : (map['id'] ?? ''),
      workspaceId: map['workspaceId'] ?? '',
      description: map['description'] ?? '',
      amount: (map['amount'] is num) ? (map['amount'] as num).toDouble() : 0.0,
      paidBy: map['paidBy'] ?? '',
      category: map['category'] ?? AppConstants.categoryOther,
      splitType: map['splitType'] ?? AppConstants.splitEqual,
      splitDetails: parseSplitDetails(map['splitDetails']),
      splitSingleMemberId: map['splitSingleMemberId'],
      frequency: map['frequency'] ?? AppConstants.recurrenceMonthly,
      isActive: map['isActive'] ?? true,
      nextDueDate: parseDate(map['nextDueDate']),
      lastGeneratedDate: map['lastGeneratedDate'] != null ? parseDate(map['lastGeneratedDate']) : null,
      createdBy: map['createdBy'] ?? '',
      createdAt: parseDate(map['createdAt']),
      updatedAt: parseDate(map['updatedAt']),
    );
  }
}
