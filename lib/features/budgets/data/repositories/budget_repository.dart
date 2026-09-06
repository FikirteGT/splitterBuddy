import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:splitterbuddy/core/constants/app_constants.dart';
import 'package:splitterbuddy/core/errors/app_exceptions.dart';
import 'package:splitterbuddy/features/budgets/domain/models/budget.dart';

class BudgetRepository {
  final FirebaseFirestore _firestore;

  BudgetRepository({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  CollectionReference _budgetsRef(String workspaceId) => _firestore
      .collection(AppConstants.workspacesCollection)
      .doc(workspaceId)
      .collection(AppConstants.budgetsCollection);

  Stream<List<Budget>> streamBudgets(String workspaceId) {
    if (workspaceId.isEmpty) return Stream.value([]);
    return _budgetsRef(workspaceId)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs.map((doc) => Budget.fromDoc(doc)).toList());
  }

  Future<void> createBudget({
    required String workspaceId,
    required Budget budget,
  }) async {
    try {
      final docRef = _budgetsRef(workspaceId).doc();
      final newBudget = budget.copyWith(id: docRef.id);
      await docRef.set(newBudget.toMap());
    } on FirebaseException catch (e) {
      throw DatabaseException('Failed to create budget: ${e.message}');
    } catch (e) {
      throw DatabaseException('Unexpected error creating budget: $e');
    }
  }

  Future<void> updateBudget({
    required String workspaceId,
    required Budget budget,
  }) async {
    try {
      await _budgetsRef(workspaceId).doc(budget.id).update(budget.toMap());
    } on FirebaseException catch (e) {
      throw DatabaseException('Failed to update budget: ${e.message}');
    } catch (e) {
      throw DatabaseException('Unexpected error updating budget: $e');
    }
  }

  Future<void> deleteBudget({
    required String workspaceId,
    required String budgetId,
  }) async {
    try {
      await _budgetsRef(workspaceId).doc(budgetId).delete();
    } on FirebaseException catch (e) {
      throw DatabaseException('Failed to delete budget: ${e.message}');
    } catch (e) {
      throw DatabaseException('Unexpected error deleting budget: $e');
    }
  }

  Future<void> updateNotifiedThresholds({
    required String workspaceId,
    required String budgetId,
    required List<int> thresholds,
  }) async {
    try {
      await _budgetsRef(workspaceId).doc(budgetId).update({
        'notifiedThresholds': thresholds,
      });
    } catch (_) {
      // Best-effort update
    }
  }
}
