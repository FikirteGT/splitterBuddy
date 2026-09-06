import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:splitterbuddy/core/constants/app_constants.dart';
import 'package:splitterbuddy/core/errors/app_exceptions.dart';
import 'package:splitterbuddy/core/utils/currency_formatter.dart';
import 'package:splitterbuddy/features/analytics/domain/models/spending_period.dart';
import 'package:splitterbuddy/features/budgets/data/repositories/budget_repository.dart';
import 'package:splitterbuddy/features/budgets/domain/models/budget.dart';
import 'package:splitterbuddy/features/expenses/domain/models/expense.dart';
import 'package:splitterbuddy/features/expenses/domain/models/expense_category.dart';
import 'package:splitterbuddy/features/notifications/domain/models/app_notification.dart';

class BudgetController extends ChangeNotifier {
  final BudgetRepository _repository;
  final FirebaseFirestore _firestore;

  List<Budget> _budgets = [];
  bool _isLoading = false;
  String? _errorMessage;
  StreamSubscription<List<Budget>>? _subscription;
  String? _currentWorkspaceId;

  BudgetController({
    BudgetRepository? repository,
    FirebaseFirestore? firestore,
  })  : _repository = repository ?? BudgetRepository(),
        _firestore = firestore ?? FirebaseFirestore.instance;

  List<Budget> get budgets => _budgets;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;

  void updateWorkspace(String? workspaceId) {
    if (_currentWorkspaceId == workspaceId) return;
    _currentWorkspaceId = workspaceId;
    _subscription?.cancel();
    _budgets = [];

    if (workspaceId != null && workspaceId.isNotEmpty) {
      _listenToBudgets(workspaceId);
    } else {
      notifyListeners();
    }
  }

  void _listenToBudgets(String workspaceId) {
    _isLoading = true;
    notifyListeners();

    _subscription = _repository.streamBudgets(workspaceId).listen(
      (list) {
        _budgets = list;
        _isLoading = false;
        _errorMessage = null;
        notifyListeners();
      },
      onError: (err) {
        _errorMessage = 'Failed to load budgets: $err';
        _isLoading = false;
        notifyListeners();
      },
    );
  }

  /// Calculates spending and progress for all active budgets based on expenses in current period.
  List<BudgetCalculation> getBudgetCalculations(List<Expense> expenses) {
    final now = DateTime.now();
    final currentMonthPeriod = SpendingPeriod.thisMonth(now);
    final periodExpenses = expenses.where((e) => e.isActive && currentMonthPeriod.contains(e.createdAt)).toList();

    return _budgets.map((budget) {
      double spent = 0.0;
      if (budget.isOverall) {
        spent = periodExpenses.fold(0.0, (acc, e) => acc + e.amount);
      } else {
        spent = periodExpenses
            .where((e) => e.category.toLowerCase() == budget.category.toLowerCase())
            .fold(0.0, (acc, e) => acc + e.amount);
      }
      return budget.calculateProgress(spent);
    }).toList();
  }

  /// Evaluates spending thresholds and dispatches notifications if new thresholds are reached.
  Future<void> evaluateBudgetAlerts({
    required List<Expense> expenses,
    required String currentUserId,
    required List<String> memberIds,
  }) async {
    if (_currentWorkspaceId == null || _budgets.isEmpty) return;

    final calculations = getBudgetCalculations(expenses);

    for (final calc in calculations) {
      final budget = calc.budget;
      final pct = calc.percentage;
      final notified = List<int>.from(budget.notifiedThresholds);
      final List<int> newThresholds = [];

      final thresholdsToCheck = [50, 75, 90, 100];
      for (final t in thresholdsToCheck) {
        if (pct >= t && !notified.contains(t)) {
          newThresholds.add(t);
        }
      }

      if (newThresholds.isNotEmpty) {
        notified.addAll(newThresholds);
        await _repository.updateNotifiedThresholds(
          workspaceId: _currentWorkspaceId!,
          budgetId: budget.id,
          thresholds: notified,
        );

        final catName = budget.isOverall ? 'Overall' : ExpenseCategory.find(budget.category).name;
        final maxThresholdReached = newThresholds.last;
        final title = 'Budget Alert: $catName ($maxThresholdReached%)';
        final message = maxThresholdReached >= 100
            ? '$catName budget of ${CurrencyFormatter.format(budget.limitAmount)} has been reached! (Current: ${CurrencyFormatter.format(calc.spentAmount)})'
            : '$catName budget has reached $maxThresholdReached% (${CurrencyFormatter.format(calc.spentAmount)} of ${CurrencyFormatter.format(budget.limitAmount)}).';

        // Notify all workspace members
        for (final memberId in memberIds) {
          final notifRef = _firestore
              .collection(AppConstants.usersCollection)
              .doc(memberId)
              .collection(AppConstants.notificationsCollection)
              .doc();

          final notif = AppNotification(
            id: notifRef.id,
            userId: memberId,
            workspaceId: _currentWorkspaceId!,
            type: AppConstants.notifBudgetAlert,
            title: title,
            message: message,
            createdAt: DateTime.now(),
          );

          await notifRef.set(notif.toMap()).catchError((_) {});
        }
      }
    }
  }

  Future<bool> createBudget({
    required String category,
    required double limitAmount,
    String period = 'monthly',
    required String createdBy,
  }) async {
    if (_currentWorkspaceId == null) return false;

    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final budget = Budget(
        id: '',
        workspaceId: _currentWorkspaceId!,
        category: category,
        limitAmount: limitAmount,
        period: period,
        createdBy: createdBy,
        createdAt: DateTime.now(),
      );

      await _repository.createBudget(
        workspaceId: _currentWorkspaceId!,
        budget: budget,
      );

      _isLoading = false;
      notifyListeners();
      return true;
    } on AppException catch (e) {
      _errorMessage = e.message;
      _isLoading = false;
      notifyListeners();
      return false;
    } catch (e) {
      _errorMessage = 'Failed to create budget: $e';
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  Future<bool> deleteBudget(String budgetId) async {
    if (_currentWorkspaceId == null) return false;

    try {
      await _repository.deleteBudget(
        workspaceId: _currentWorkspaceId!,
        budgetId: budgetId,
      );
      return true;
    } catch (e) {
      _errorMessage = 'Failed to delete budget: $e';
      notifyListeners();
      return false;
    }
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }
}
