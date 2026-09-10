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
    String? paidByName,
    String category = AppConstants.categoryOther,
    String splitType = AppConstants.splitEqual,
    Map<String, double>? splitDetails,
    String? splitSingleMemberId,
    String? receiptUrl,
    String? receiptPath,
    bool isRecurring = false,
    String? recurringTemplateId,
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
        category: category,
        splitType: splitType,
        splitDetails: splitDetails,
        splitSingleMemberId: splitSingleMemberId,
        receiptUrl: receiptUrl,
        receiptPath: receiptPath,
        isRecurring: isRecurring,
        recurringTemplateId: recurringTemplateId,
        createdAt: now,
        updatedAt: now,
        status: AppConstants.expenseActive,
      );

      final resolvedPaidByName = paidByName ?? (paidBy == createdBy ? actorName : 'Partner');

      final activityLog = ActivityLog(
        id: actDocRef.id,
        workspaceId: workspaceId,
        actorId: createdBy,
        actorName: actorName,
        action: AppConstants.actionAdded,
        expenseId: expDocRef.id,
        expenseDescription: trimmedDesc,
        amount: roundedAmount,
        paidBy: paidBy,
        paidByName: resolvedPaidByName,
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
  /// If there are partner(s) in the workspace, creates a pending change for partner review & acceptance.
  /// If the user is the only member, updates the expense directly.
  Future<void> editExpense({
    required String workspaceId,
    required Expense expense,
    required String newDescription,
    required double newAmount,
    required String newPaidBy,
    String? newPaidByName,
    String? newCategory,
    String? newSplitType,
    Map<String, double>? newSplitDetails,
    String? newSplitSingleMemberId,
    String? newReceiptUrl,
    String? newReceiptPath,
    required String currentUserId,
    required String currentUserName,
    String? partnerId,
    List<String>? allMemberIds,
    Map<String, String>? memberNames,
  }) async {
    final trimmedDesc = newDescription.trim();
    if (trimmedDesc.isEmpty) {
      throw const ExpenseException('Expense description cannot be empty.');
    }
    final roundedAmount = CurrencyFormatter.roundMoney(newAmount);
    if (roundedAmount <= 0) {
      throw const ExpenseException('Expense amount must be greater than 0.');
    }

    final otherMembers = (allMemberIds != null && allMemberIds.isNotEmpty)
        ? allMemberIds.where((id) => id != currentUserId).toList()
        : (partnerId != null && partnerId.isNotEmpty && partnerId != currentUserId ? [partnerId] : <String>[]);

    final now = DateTime.now();

    try {
      if (otherMembers.isEmpty) {
        // Solo workspace: Direct modification
        final batch = _firestore.batch();
        final expDocRef = _expensesRef(workspaceId).doc(expense.id);
        final actDocRef = _activityLogsRef(workspaceId).doc();

        final updateData = <String, dynamic>{
          'description': trimmedDesc,
          'amount': roundedAmount,
          'paidBy': newPaidBy,
          'category': newCategory ?? expense.category,
          'splitType': newSplitType ?? expense.splitType,
          'updatedAt': Timestamp.fromDate(now),
        };

        if (newSplitDetails != null) updateData['splitDetails'] = newSplitDetails;
        if (newSplitSingleMemberId != null) updateData['splitSingleMemberId'] = newSplitSingleMemberId;
        if (newReceiptUrl != null) updateData['receiptUrl'] = newReceiptUrl;
        if (newReceiptPath != null) updateData['receiptPath'] = newReceiptPath;

        batch.update(expDocRef, updateData);

        final resolvedPaidByName = newPaidByName ?? (newPaidBy == currentUserId ? currentUserName : 'Partner');

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
          paidBy: newPaidBy,
          paidByName: resolvedPaidByName,
          timestamp: now,
        );
        batch.set(actDocRef, activityLog.toMap());
        await batch.commit();
      } else {
        // Shared workspace: Propose pending change for partner approval & notify all partners
        final primaryPartnerId = otherMembers.first;
        final pendingDocRef = _pendingChangesRef(workspaceId).doc();
        final actDocRef = _activityLogsRef(workspaceId).doc();

        final originalValues = <String, dynamic>{
          'description': expense.description,
          'amount': expense.amount,
          'paidBy': expense.paidBy,
          'category': expense.category,
          'splitType': expense.splitType,
          if (expense.splitDetails != null) 'splitDetails': expense.splitDetails,
          if (expense.splitSingleMemberId != null) 'splitSingleMemberId': expense.splitSingleMemberId,
          if (expense.receiptUrl != null) 'receiptUrl': expense.receiptUrl,
          if (expense.receiptPath != null) 'receiptPath': expense.receiptPath,
        };

        final proposedValues = <String, dynamic>{
          'description': trimmedDesc,
          'amount': roundedAmount,
          'paidBy': newPaidBy,
          'category': newCategory ?? expense.category,
          'splitType': newSplitType ?? expense.splitType,
          if (newSplitDetails != null) 'splitDetails': newSplitDetails,
          if (newSplitSingleMemberId != null) 'splitSingleMemberId': newSplitSingleMemberId,
          if (newReceiptUrl != null) 'receiptUrl': newReceiptUrl,
          if (newReceiptPath != null) 'receiptPath': newReceiptPath,
        };

        final pendingChange = PendingChange(
          id: pendingDocRef.id,
          expenseId: expense.id,
          workspaceId: workspaceId,
          periodId: expense.periodId,
          requesterId: currentUserId,
          requesterName: currentUserName,
          partnerId: primaryPartnerId,
          originalValues: originalValues,
          proposedValues: proposedValues,
          status: AppConstants.pendingChangePending,
          createdAt: now,
        );

        final diffSummary = pendingChange.formatDiffSummary(memberNames: memberNames);
        final resolvedPaidByName = newPaidByName ?? (newPaidBy == currentUserId ? currentUserName : 'Partner');

        final activityLog = ActivityLog(
          id: actDocRef.id,
          workspaceId: workspaceId,
          actorId: currentUserId,
          actorName: currentUserName,
          action: AppConstants.actionProposedEdit,
          expenseId: expense.id,
          expenseDescription: '$trimmedDesc ($diffSummary)',
          amount: roundedAmount,
          previousAmount: expense.amount,
          paidBy: newPaidBy,
          paidByName: resolvedPaidByName,
          timestamp: now,
        );

        final batch = _firestore.batch();
        batch.set(pendingDocRef, pendingChange.toMap());
        batch.set(actDocRef, activityLog.toMap());

        // Notify every partner in the workspace with exact change diff
        for (final recipientId in otherMembers) {
          final notifDocRef = _userNotificationsRef(recipientId).doc();
          final notif = AppNotification(
            id: notifDocRef.id,
            userId: recipientId,
            workspaceId: workspaceId,
            type: AppConstants.notifPendingEdit,
            title: 'Edit Requested: ${expense.description}',
            message: '$currentUserName proposed changes: $diffSummary',
            expenseId: expense.id,
            pendingChangeId: pendingDocRef.id,
            createdAt: now,
          );
          batch.set(notifDocRef, notif.toMap());
        }

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
    List<String>? allMemberIds,
    Map<String, String>? memberNames,
  }) async {
    try {
      final now = DateTime.now();
      final batch = _firestore.batch();

      final pendingDocRef = _pendingChangesRef(workspaceId).doc(pendingChange.id);
      final expDocRef = _expensesRef(workspaceId).doc(pendingChange.expenseId);
      final actDocRef = _activityLogsRef(workspaceId).doc();

      // 1. Update pending change status to APPROVED
      batch.update(pendingDocRef, {
        'status': AppConstants.pendingChangeApproved,
        'reviewedAt': Timestamp.fromDate(now),
      });

      // 2. Officially update the expense with all proposed fields
      final expUpdate = <String, dynamic>{
        'description': pendingChange.proposedDescription,
        'amount': pendingChange.proposedAmount,
        'paidBy': pendingChange.proposedPaidBy,
        'updatedAt': Timestamp.fromDate(now),
      };

      if (pendingChange.proposedCategory != null) {
        expUpdate['category'] = pendingChange.proposedCategory;
      }
      if (pendingChange.proposedSplitType != null) {
        expUpdate['splitType'] = pendingChange.proposedSplitType;
      }
      if (pendingChange.proposedSplitDetails != null) {
        expUpdate['splitDetails'] = pendingChange.proposedSplitDetails;
      }
      if (pendingChange.proposedSplitSingleMemberId != null) {
        expUpdate['splitSingleMemberId'] = pendingChange.proposedSplitSingleMemberId;
      }
      if (pendingChange.proposedReceiptUrl != null) {
        expUpdate['receiptUrl'] = pendingChange.proposedReceiptUrl;
      }
      if (pendingChange.proposedReceiptPath != null) {
        expUpdate['receiptPath'] = pendingChange.proposedReceiptPath;
      }

      batch.update(expDocRef, expUpdate);

      final diffSummary = pendingChange.formatDiffSummary(memberNames: memberNames);

      // 3. Log activity
      final activityLog = ActivityLog(
        id: actDocRef.id,
        workspaceId: workspaceId,
        actorId: reviewerId,
        actorName: reviewerName,
        action: AppConstants.actionApprovedEdit,
        expenseId: pendingChange.expenseId,
        expenseDescription: '${pendingChange.proposedDescription} ($diffSummary)',
        amount: pendingChange.proposedAmount,
        previousAmount: pendingChange.originalAmount,
        paidBy: pendingChange.proposedPaidBy,
        paidByName: memberNames?[pendingChange.proposedPaidBy] ?? pendingChange.proposedPaidBy,
        timestamp: now,
      );
      batch.set(actDocRef, activityLog.toMap());

      // 4. Notify all partners and requester about approval with diff
      final recipients = (allMemberIds != null && allMemberIds.isNotEmpty)
          ? allMemberIds.where((id) => id != reviewerId).toSet()
          : {pendingChange.requesterId};

      for (final recipientId in recipients) {
        final notifDocRef = _userNotificationsRef(recipientId).doc();
        final notif = AppNotification(
          id: notifDocRef.id,
          userId: recipientId,
          workspaceId: workspaceId,
          type: AppConstants.notifEditApproved,
          title: 'Edit Accepted: ${pendingChange.proposedDescription}',
          message: '$reviewerName accepted edit on "${pendingChange.proposedDescription}". ($diffSummary)',
          expenseId: pendingChange.expenseId,
          createdAt: now,
        );
        batch.set(notifDocRef, notif.toMap());
      }

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
    List<String>? allMemberIds,
    Map<String, String>? memberNames,
  }) async {
    try {
      final now = DateTime.now();
      final batch = _firestore.batch();

      final pendingDocRef = _pendingChangesRef(workspaceId).doc(pendingChange.id);
      final actDocRef = _activityLogsRef(workspaceId).doc();

      // 1. Update pending change status to REJECTED
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
        paidBy: pendingChange.originalPaidBy,
        timestamp: now,
      );
      batch.set(actDocRef, activityLog.toMap());

      // 3. Notify requester and other partners
      final recipients = (allMemberIds != null && allMemberIds.isNotEmpty)
          ? allMemberIds.where((id) => id != reviewerId).toSet()
          : {pendingChange.requesterId};

      for (final recipientId in recipients) {
        final notifDocRef = _userNotificationsRef(recipientId).doc();
        final notif = AppNotification(
          id: notifDocRef.id,
          userId: recipientId,
          workspaceId: workspaceId,
          type: AppConstants.notifEditRejected,
          title: 'Edit Declined: ${pendingChange.originalDescription}',
          message: '$reviewerName declined proposed edit on "${pendingChange.originalDescription}".',
          expenseId: pendingChange.expenseId,
          createdAt: now,
        );
        batch.set(notifDocRef, notif.toMap());
      }

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
        paidBy: expense.paidBy,
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
