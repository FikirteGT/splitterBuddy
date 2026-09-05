import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../core/errors/app_exceptions.dart';
import '../../../../core/utils/currency_formatter.dart';
import '../../../expenses/domain/models/expense.dart';
import '../../../history/domain/models/activity_log.dart';
import '../../../notifications/domain/models/app_notification.dart';
import '../domain/models/recurring_expense.dart';

class RecurringExpenseRepository {
  final FirebaseFirestore _firestore;

  RecurringExpenseRepository({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  CollectionReference _recurringRef(String workspaceId) => _firestore
      .collection(AppConstants.workspacesCollection)
      .doc(workspaceId)
      .collection(AppConstants.recurringExpensesCollection);

  CollectionReference _expensesRef(String workspaceId) => _firestore
      .collection(AppConstants.workspacesCollection)
      .doc(workspaceId)
      .collection(AppConstants.expensesCollection);

  CollectionReference _activityLogsRef(String workspaceId) => _firestore
      .collection(AppConstants.workspacesCollection)
      .doc(workspaceId)
      .collection(AppConstants.activityLogsCollection);

  CollectionReference _userNotificationsRef(String userId) => _firestore
      .collection(AppConstants.usersCollection)
      .doc(userId)
      .collection(AppConstants.notificationsCollection);

  Stream<List<RecurringExpense>> streamRecurringExpenses(String workspaceId) {
    if (workspaceId.isEmpty) return Stream.value([]);
    return _recurringRef(workspaceId)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => RecurringExpense.fromMap(doc.data() as Map<String, dynamic>, doc.id))
            .toList());
  }

  Future<RecurringExpense> createRecurringExpense({
    required String workspaceId,
    required String description,
    required double amount,
    required String paidBy,
    String category = AppConstants.categoryOther,
    String splitType = AppConstants.splitEqual,
    Map<String, double>? splitDetails,
    String? splitSingleMemberId,
    String frequency = AppConstants.recurrenceMonthly,
    required DateTime firstDueDate,
    required String createdBy,
    required String currentUserName,
  }) async {
    final trimmedDesc = description.trim();
    if (trimmedDesc.isEmpty) {
      throw const ExpenseException('Recurring expense description cannot be empty.');
    }
    final roundedAmount = CurrencyFormatter.roundMoney(amount);
    if (roundedAmount <= 0) {
      throw const ExpenseException('Amount must be greater than 0.');
    }

    try {
      final docRef = _recurringRef(workspaceId).doc();
      final actDocRef = _activityLogsRef(workspaceId).doc();
      final now = DateTime.now();

      final recurring = RecurringExpense(
        id: docRef.id,
        workspaceId: workspaceId,
        description: trimmedDesc,
        amount: roundedAmount,
        paidBy: paidBy,
        category: category,
        splitType: splitType,
        splitDetails: splitDetails,
        splitSingleMemberId: splitSingleMemberId,
        frequency: frequency,
        isActive: true,
        nextDueDate: firstDueDate,
        createdBy: createdBy,
        createdAt: now,
        updatedAt: now,
      );

      final activityLog = ActivityLog(
        id: actDocRef.id,
        workspaceId: workspaceId,
        actorId: createdBy,
        actorName: currentUserName,
        action: AppConstants.actionRecurringCreated,
        expenseDescription: '$trimmedDesc ($frequency recurring)',
        amount: roundedAmount,
        paidBy: paidBy,
        timestamp: now,
      );

      final batch = _firestore.batch();
      batch.set(docRef, recurring.toMap());
      batch.set(actDocRef, activityLog.toMap());
      await batch.commit();

      return recurring;
    } catch (e) {
      throw ExpenseException('Failed to create recurring expense: ${e.toString()}');
    }
  }

  Future<void> toggleRecurringActive({
    required String workspaceId,
    required String recurringId,
    required bool isCurrentlyActive,
    required String currentUserId,
    required String currentUserName,
  }) async {
    try {
      final docRef = _recurringRef(workspaceId).doc(recurringId);
      final actDocRef = _activityLogsRef(workspaceId).doc();
      final now = DateTime.now();
      final newStatus = !isCurrentlyActive;

      final batch = _firestore.batch();
      batch.update(docRef, {
        'isActive': newStatus,
        'updatedAt': Timestamp.fromDate(now),
      });

      final activityLog = ActivityLog(
        id: actDocRef.id,
        workspaceId: workspaceId,
        actorId: currentUserId,
        actorName: currentUserName,
        action: AppConstants.actionRecurringToggled,
        expenseDescription: newStatus ? 'Resumed recurring expense' : 'Paused recurring expense',
        timestamp: now,
      );
      batch.set(actDocRef, activityLog.toMap());

      await batch.commit();
    } catch (e) {
      throw ExpenseException('Failed to update recurring expense: ${e.toString()}');
    }
  }

  Future<void> deleteRecurringExpense({
    required String workspaceId,
    required String recurringId,
  }) async {
    try {
      await _recurringRef(workspaceId).doc(recurringId).delete();
    } catch (e) {
      throw ExpenseException('Failed to delete recurring expense: ${e.toString()}');
    }
  }

  /// Evaluates and generates expenses for all active templates whose due date has arrived.
  /// Deduplicates via unique nextDueDate + lastGeneratedDate state updates.
  Future<List<Expense>> processDueRecurringExpenses({
    required String workspaceId,
    required String activePeriodId,
    required String currentUserId,
    required String currentUserName,
    String? partnerId,
  }) async {
    if (workspaceId.isEmpty || activePeriodId.isEmpty) return [];

    try {
      final now = DateTime.now();
      final snapshot = await _recurringRef(workspaceId)
          .where('isActive', isEqualTo: true)
          .get();

      final generatedExpenses = <Expense>[];

      for (final doc in snapshot.docs) {
        final recurring = RecurringExpense.fromMap(doc.data() as Map<String, dynamic>, doc.id);

        // Check if nextDueDate is due today or earlier
        if (recurring.nextDueDate.isBefore(now) || recurring.nextDueDate.isAtSameMomentAs(now)) {
          final expDocRef = _expensesRef(workspaceId).doc();
          final actDocRef = _activityLogsRef(workspaceId).doc();

          final generatedExpense = Expense(
            id: expDocRef.id,
            workspaceId: workspaceId,
            periodId: activePeriodId,
            description: '${recurring.description} (Recurring)',
            amount: recurring.amount,
            paidBy: recurring.paidBy,
            createdBy: currentUserId,
            category: recurring.category,
            splitType: recurring.splitType,
            splitDetails: recurring.splitDetails,
            splitSingleMemberId: recurring.splitSingleMemberId,
            isRecurring: true,
            recurringTemplateId: recurring.id,
            createdAt: now,
            updatedAt: now,
            status: AppConstants.expenseActive,
          );

          final nextDue = RecurringExpense.calculateNextDueDate(recurring.nextDueDate, recurring.frequency);

          final batch = _firestore.batch();
          batch.set(expDocRef, generatedExpense.toMap());

          // Update template to advance nextDueDate
          batch.update(doc.reference, {
            'lastGeneratedDate': Timestamp.fromDate(now),
            'nextDueDate': Timestamp.fromDate(nextDue),
            'updatedAt': Timestamp.fromDate(now),
          });

          // Activity Log
          final activityLog = ActivityLog(
            id: actDocRef.id,
            workspaceId: workspaceId,
            actorId: currentUserId,
            actorName: 'System (Recurring)',
            action: AppConstants.actionAdded,
            expenseId: expDocRef.id,
            expenseDescription: generatedExpense.description,
            amount: recurring.amount,
            paidBy: recurring.paidBy,
            timestamp: now,
          );
          batch.set(actDocRef, activityLog.toMap());

          // Notify partner if present
          if (partnerId != null && partnerId.isNotEmpty && partnerId != recurring.paidBy) {
            final notifDocRef = _userNotificationsRef(partnerId).doc();
            final notif = AppNotification(
              id: notifDocRef.id,
              userId: partnerId,
              workspaceId: workspaceId,
              type: AppConstants.notifRecurringGenerated,
              title: 'Recurring Expense Applied',
              message: '${recurring.description} — ${CurrencyFormatter.format(recurring.amount)} was automatically recorded.',
              expenseId: expDocRef.id,
              createdAt: now,
            );
            batch.set(notifDocRef, notif.toMap());
          }

          await batch.commit();
          generatedExpenses.add(generatedExpense);
        }
      }

      return generatedExpenses;
    } catch (e) {
      debugPrint('Error processing recurring expenses: $e');
      return [];
    }
  }
}
