import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:splitterbuddy/core/constants/app_constants.dart';
import 'package:splitterbuddy/core/errors/app_exceptions.dart';
import 'package:splitterbuddy/core/utils/currency_formatter.dart';
import 'package:splitterbuddy/features/expenses/domain/models/expense.dart';
import 'package:splitterbuddy/features/expenses/domain/models/pending_change.dart';
import 'package:splitterbuddy/features/history/domain/models/activity_log.dart';
import 'package:splitterbuddy/features/notifications/domain/models/app_notification.dart';

class ExpenseRepository {
  final FirebaseFirestore _firestore;

  ExpenseRepository({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  CollectionReference _expensesRef(String workspaceId) =>
      _firestore.collection(AppConstants.workspacesCollection).doc(workspaceId).collection(AppConstants.expensesCollection);

  CollectionReference _pendingChangesRef(String workspaceId) =>
      _firestore.collection(AppConstants.workspacesCollection).doc(workspaceId).collection(AppConstants.pendingChangesCollection);

  CollectionReference _activityLogsRef(String workspaceId) =>
      _firestore.collection(AppConstants.workspacesCollection).doc(workspaceId).collection(AppConstants.activityLogsCollection);

  CollectionReference _userNotificationsRef(String userId) =>
      _firestore.collection(AppConstants.usersCollection).doc(userId).collection(AppConstants.notificationsCollection);

  Stream<List<Expense>> streamPeriodExpenses(String workspaceId, String periodId) {
    if (workspaceId.isEmpty || periodId.isEmpty) {
      return Stream.value([]);
    }
    return _expensesRef(workspaceId)
        .where('periodId', isEqualTo: periodId)
        .snapshots()
        .map((snapshot) {
      final list = snapshot.docs
          .map((doc) => Expense.fromMap(doc.data() as Map<String, dynamic>, doc.id))
          .toList();
      // Sort newest first
      list.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      return list;
    });
  }

  Stream<List<PendingChange>> streamPendingChanges(String workspaceId) {
    if (workspaceId.isEmpty) return Stream.value([]);
    return _pendingChangesRef(workspaceId)
        .where('status', isEqualTo: AppConstants.pendingChangePending)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => PendingChange.fromMap(doc.data() as Map<String, dynamic>, doc.id))
            .toList());
  }

  Future<Expense> addExpense({
    required String workspaceId,
    required String periodId,
    required String description,
    required double amount,
    required String paidBy,
    required String createdBy,
    required String actorName,
    String? partnerId,
  }) async {
    final trimmedDesc = description.trim();
    if (trimmedDesc.isEmpty) {
      throw const ExpenseException('Expense description cannot be empty.');
    }
    final roundedAmount = CurrencyFormatter.roundMoney(amount);
    if (roundedAmount <= 0) {
      throw const ExpenseException('Expense amount must be greater than 0.');
    }

    try {
      final expDocRef = _expensesRef(workspaceId).doc();
      final actDocRef = _activityLogsRef(workspaceId).doc();
      final now = DateTime.now();

      final expense = Expense(
        id: expDocRef.id,
        workspaceId: workspaceId,
        periodId: periodId,
        description: trimmedDesc,
        amount: roundedAmount,
        paidBy: paidBy,
        createdBy: createdBy,
        createdAt: now,
        updatedAt: now,
        status: AppConstants.expenseActive,
      );

      final activityLog = ActivityLog(
        id: actDocRef.id,
        workspaceId: workspaceId,
        actorId: createdBy,
        actorName: actorName,
        action: AppConstants.actionAdded,
        expenseId: expDocRef.id,
        expenseDescription: trimmedDesc,
        amount: roundedAmount,
        timestamp: now,
      );

      final batch = _firestore.batch();
      batch.set(expDocRef, expense.toMap());
      batch.set(actDocRef, activityLog.toMap());

      // Notify partner if present
      if (partnerId != null && partnerId.isNotEmpty && partnerId != createdBy) {
        final notifDocRef = _userNotificationsRef(partnerId).doc();
        final notif = AppNotification(
          id: notifDocRef.id,
          userId: partnerId,
          workspaceId: workspaceId,
          type: AppConstants.notifAddExpense,
          title: 'New Expense Added',
          message: '$actorName added $trimmedDesc — ${CurrencyFormatter.format(roundedAmount)}',
          expenseId: expDocRef.id,
          createdAt: now,
        );
        batch.set(notifDocRef, notif.toMap());
      }

      await batch.commit();
      return expense;
    } catch (e) {
      throw ExpenseException('Failed to add expense: ${e.toString()}');
    }
  }

  /// Handles editing an expense.
  /// Case A: User's own expense -> Direct modification.
  /// Case B: Partner's expense -> Creates pending change for review without modifying balance.
  Future<void> editExpense({
    required String workspaceId,
    required Expense expense,
    required String newDescription,
    required double newAmount,
    required String newPaidBy,
    required String currentUserId,
    required String currentUserName,
    String? partnerId,
  }) async {
    final trimmedDesc = newDescription.trim();
    if (trimmedDesc.isEmpty) {
      throw const ExpenseException('Expense description cannot be empty.');
    }
    final roundedAmount = CurrencyFormatter.roundMoney(newAmount);
    if (roundedAmount <= 0) {
      throw const ExpenseException('Expense amount must be greater than 0.');
    }

    final isOwnExpense = expense.paidBy == currentUserId || expense.createdBy == currentUserId;
    final now = DateTime.now();

    try {
      if (isOwnExpense) {
        // CASE A: Direct modification of own expense
        final batch = _firestore.batch();
        final expDocRef = _expensesRef(workspaceId).doc(expense.id);
        final actDocRef = _activityLogsRef(workspaceId).doc();

        batch.update(expDocRef, {
          'description': trimmedDesc,
          'amount': roundedAmount,
          'paidBy': newPaidBy,
          'updatedAt': Timestamp.fromDate(now),
        });

        final activityLog = ActivityLog(
          id: actDocRef.id,
          workspaceId: workspaceId,
          actorId: currentUserId,
          actorName: currentUserName,
          action: AppConstants.actionEdited,
          expenseId: expense.id,
          expenseDescription: trimmedDesc,
          amount: roundedAmount,
          previousAmount: expense.amount,
          timestamp: now,
        );
        batch.set(actDocRef, activityLog.toMap());

        if (partnerId != null && partnerId.isNotEmpty && partnerId != currentUserId) {
          final notifDocRef = _userNotificationsRef(partnerId).doc();
          final notif = AppNotification(
            id: notifDocRef.id,
            userId: partnerId,
            workspaceId: workspaceId,
            type: AppConstants.notifEditExpense,
            title: 'Expense Updated',
            message: '$currentUserName updated $trimmedDesc to ${CurrencyFormatter.format(roundedAmount)}',
            expenseId: expense.id,
            createdAt: now,
          );
          batch.set(notifDocRef, notif.toMap());
        }

        await batch.commit();
      } else {
        // CASE B: Partner's expense -> Propose pending change (DO NOT touch official balance/expense)
        final targetPartnerId = partnerId ?? expense.paidBy;
        final pendingDocRef = _pendingChangesRef(workspaceId).doc();
        final actDocRef = _activityLogsRef(workspaceId).doc();
        final notifDocRef = _userNotificationsRef(targetPartnerId).doc();

        final pendingChange = PendingChange(
          id: pendingDocRef.id,
          expenseId: expense.id,
          workspaceId: workspaceId,
          periodId: expense.periodId,
          requesterId: currentUserId,
          requesterName: currentUserName,
          partnerId: targetPartnerId,
          originalValues: {
            'description': expense.description,
            'amount': expense.amount,
            'paidBy': expense.paidBy,
          },
          proposedValues: {
            'description': trimmedDesc,
            'amount': roundedAmount,
            'paidBy': newPaidBy,
          },
          status: AppConstants.pendingChangePending,
          createdAt: now,
        );

        final activityLog = ActivityLog(
          id: actDocRef.id,
          workspaceId: workspaceId,
          actorId: currentUserId,
          actorName: currentUserName,
          action: AppConstants.actionProposedEdit,
          expenseId: expense.id,
          expenseDescription: trimmedDesc,
          amount: roundedAmount,
          previousAmount: expense.amount,
          timestamp: now,
        );

        final notif = AppNotification(
          id: notifDocRef.id,
          userId: targetPartnerId,
          workspaceId: workspaceId,
          type: AppConstants.notifPendingEdit,
          title: 'Review Proposed Edit',
          message: '$currentUserName proposed changing ${expense.description} from ${CurrencyFormatter.format(expense.amount)} to ${CurrencyFormatter.format(roundedAmount)}',
          expenseId: expense.id,
          pendingChangeId: pendingDocRef.id,
          createdAt: now,
        );

        final batch = _firestore.batch();
        batch.set(pendingDocRef, pendingChange.toMap());
        batch.set(actDocRef, activityLog.toMap());
        batch.set(notifDocRef, notif.toMap());

        await batch.commit();
      }
    } catch (e) {
      throw ExpenseException('Failed to edit expense: ${e.toString()}');
    }
  }

  Future<void> approvePendingChange({
    required String workspaceId,
    required PendingChange pendingChange,
    required String reviewerId,
    required String reviewerName,
  }) async {
    try {
      final now = DateTime.now();
      final batch = _firestore.batch();

      final pendingDocRef = _pendingChangesRef(workspaceId).doc(pendingChange.id);
      final expDocRef = _expensesRef(workspaceId).doc(pendingChange.expenseId);
      final actDocRef = _activityLogsRef(workspaceId).doc();
      final notifDocRef = _userNotificationsRef(pendingChange.requesterId).doc();

      // 1. Update pending change status to APPROVED
      batch.update(pendingDocRef, {
        'status': AppConstants.pendingChangeApproved,
        'reviewedAt': Timestamp.fromDate(now),
      });

      // 2. Officially update the expense (this updates the authoritative balance!)
      batch.update(expDocRef, {
        'description': pendingChange.proposedDescription,
        'amount': pendingChange.proposedAmount,
        'paidBy': pendingChange.proposedPaidBy,
        'updatedAt': Timestamp.fromDate(now),
      });

      // 3. Log activity
      final activityLog = ActivityLog(
        id: actDocRef.id,
        workspaceId: workspaceId,
        actorId: reviewerId,
        actorName: reviewerName,
        action: AppConstants.actionApprovedEdit,
        expenseId: pendingChange.expenseId,
        expenseDescription: pendingChange.proposedDescription,
        amount: pendingChange.proposedAmount,
        previousAmount: pendingChange.originalAmount,
        timestamp: now,
      );
      batch.set(actDocRef, activityLog.toMap());

      // 4. Notify requester
      final notif = AppNotification(
        id: notifDocRef.id,
        userId: pendingChange.requesterId,
        workspaceId: workspaceId,
        type: AppConstants.notifEditApproved,
        title: 'Edit Approved',
        message: '$reviewerName approved your edit on "${pendingChange.proposedDescription}" (${CurrencyFormatter.format(pendingChange.proposedAmount)})',
        expenseId: pendingChange.expenseId,
        createdAt: now,
      );
      batch.set(notifDocRef, notif.toMap());

      await batch.commit();
    } catch (e) {
      throw ExpenseException('Failed to approve edit: ${e.toString()}');
    }
  }

  Future<void> rejectPendingChange({
    required String workspaceId,
    required PendingChange pendingChange,
    required String reviewerId,
    required String reviewerName,
  }) async {
    try {
      final now = DateTime.now();
      final batch = _firestore.batch();

      final pendingDocRef = _pendingChangesRef(workspaceId).doc(pendingChange.id);
      final actDocRef = _activityLogsRef(workspaceId).doc();
      final notifDocRef = _userNotificationsRef(pendingChange.requesterId).doc();

      // 1. Update pending change status to REJECTED (Official expense is untouched)
      batch.update(pendingDocRef, {
        'status': AppConstants.pendingChangeRejected,
        'reviewedAt': Timestamp.fromDate(now),
      });

      // 2. Log activity
      final activityLog = ActivityLog(
        id: actDocRef.id,
        workspaceId: workspaceId,
        actorId: reviewerId,
        actorName: reviewerName,
        action: AppConstants.actionRejectedEdit,
        expenseId: pendingChange.expenseId,
        expenseDescription: pendingChange.originalDescription,
        amount: pendingChange.originalAmount,
        timestamp: now,
      );
      batch.set(actDocRef, activityLog.toMap());

      // 3. Notify requester
      final notif = AppNotification(
        id: notifDocRef.id,
        userId: pendingChange.requesterId,
        workspaceId: workspaceId,
        type: AppConstants.notifEditRejected,
        title: 'Edit Declined',
        message: '$reviewerName declined your proposed edit on "${pendingChange.originalDescription}"',
        expenseId: pendingChange.expenseId,
        createdAt: now,
      );
      batch.set(notifDocRef, notif.toMap());

      await batch.commit();
    } catch (e) {
      throw ExpenseException('Failed to reject edit: ${e.toString()}');
    }
  }

  Future<void> deleteExpense({
    required String workspaceId,
    required Expense expense,
    required String currentUserId,
    required String currentUserName,
    String? partnerId,
  }) async {
    try {
      final now = DateTime.now();
      final batch = _firestore.batch();

      final expDocRef = _expensesRef(workspaceId).doc(expense.id);
      final actDocRef = _activityLogsRef(workspaceId).doc();

      // Audit-friendly soft delete
      batch.update(expDocRef, {
        'status': AppConstants.expenseDeleted,
        'deletedAt': Timestamp.fromDate(now),
        'deletedBy': currentUserId,
        'updatedAt': Timestamp.fromDate(now),
      });

      final activityLog = ActivityLog(
        id: actDocRef.id,
        workspaceId: workspaceId,
        actorId: currentUserId,
        actorName: currentUserName,
        action: AppConstants.actionDeleted,
        expenseId: expense.id,
        expenseDescription: expense.description,
        amount: expense.amount,
        timestamp: now,
      );
      batch.set(actDocRef, activityLog.toMap());

      if (partnerId != null && partnerId.isNotEmpty && partnerId != currentUserId) {
        final notifDocRef = _userNotificationsRef(partnerId).doc();
        final notif = AppNotification(
          id: notifDocRef.id,
          userId: partnerId,
          workspaceId: workspaceId,
          type: AppConstants.notifDeleteExpense,
          title: 'Expense Deleted',
          message: '$currentUserName deleted ${expense.description} (${CurrencyFormatter.format(expense.amount)})',
          expenseId: expense.id,
          createdAt: now,
        );
        batch.set(notifDocRef, notif.toMap());
      }

      await batch.commit();
    } catch (e) {
      throw ExpenseException('Failed to delete expense: ${e.toString()}');
    }
  }
}
