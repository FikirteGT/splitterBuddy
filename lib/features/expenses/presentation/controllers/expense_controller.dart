import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:splitterbuddy/core/constants/app_constants.dart';
import 'package:splitterbuddy/core/errors/app_exceptions.dart';
import 'package:splitterbuddy/features/balance/domain/models/balance_result.dart';
import 'package:splitterbuddy/features/balance/services/balance_engine.dart';
import 'package:splitterbuddy/features/expenses/data/repositories/expense_repository.dart';
import 'package:splitterbuddy/features/expenses/domain/models/expense.dart';
import 'package:splitterbuddy/features/expenses/domain/models/pending_change.dart';

class ExpenseController extends ChangeNotifier {
  final ExpenseRepository _expenseRepository;

  List<Expense> _expenses = [];
  List<PendingChange> _pendingChanges = [];
  BalanceResult _balance = BalanceResult.zero();
  bool _isLoading = false;
  String? _errorMessage;

  StreamSubscription<List<Expense>>? _expensesSubscription;
  StreamSubscription<List<PendingChange>>? _pendingChangesSubscription;

  String? _currentWorkspaceId;
  String? _currentPeriodId;
  String? _currentUserId;
  String? _partnerId;
  String _partnerName = 'Partner';

  ExpenseController({ExpenseRepository? expenseRepository})
      : _expenseRepository = expenseRepository ?? ExpenseRepository();

  List<Expense> get expenses => _expenses;
  List<Expense> get activeExpenses => _expenses.where((e) => e.status == AppConstants.expenseActive).toList();
  List<Expense> get recentExpenses => activeExpenses.take(5).toList();
  List<PendingChange> get pendingChanges => _pendingChanges;
  BalanceResult get balance => _balance;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;

  void updateContext({
    required String? workspaceId,
    required String? periodId,
    required String? currentUserId,
    required String? partnerId,
    required String partnerName,
  }) {
    if (_currentWorkspaceId == workspaceId &&
        _currentPeriodId == periodId &&
        _currentUserId == currentUserId &&
        _partnerId == partnerId &&
        _partnerName == partnerName) {
      return;
    }

    _currentWorkspaceId = workspaceId;
    _currentPeriodId = periodId;
    _currentUserId = currentUserId;
    _partnerId = partnerId;
    _partnerName = partnerName;

    _expensesSubscription?.cancel();
    _pendingChangesSubscription?.cancel();
    _expenses = [];
    _pendingChanges = [];
    _balance = BalanceResult.zero(partnerName: partnerName);

    if (workspaceId != null && workspaceId.isNotEmpty && periodId != null && periodId.isNotEmpty) {
      _listenToExpenses(workspaceId, periodId);
      _listenToPendingChanges(workspaceId);
    } else {
      notifyListeners();
    }
  }

  void _listenToExpenses(String workspaceId, String periodId) {
    _isLoading = true;
    notifyListeners();

    _expensesSubscription = _expenseRepository.streamPeriodExpenses(workspaceId, periodId).listen(
      (list) {
        _expenses = list;
        _recalculateBalance();
        _isLoading = false;
        notifyListeners();
      },
      onError: (err) {
        _isLoading = false;
        _errorMessage = 'Failed to sync expenses: $err';
        notifyListeners();
      },
    );
  }

  void _listenToPendingChanges(String workspaceId) {
    _pendingChangesSubscription = _expenseRepository.streamPendingChanges(workspaceId).listen(
      (list) {
        _pendingChanges = list;
        notifyListeners();
      },
    );
  }

  void _recalculateBalance() {
    _balance = BalanceEngine.calculate(
      expenses: _expenses,
      currentUserId: _currentUserId ?? '',
      partnerId: _partnerId ?? '',
      partnerName: _partnerName,
    );
  }

  void clearError() {
    _errorMessage = null;
    notifyListeners();
  }

  Future<bool> addExpense({
    required String description,
    required double amount,
    required String paidBy,
    String? paidByName,
    required String currentUserId,
    required String currentUserName,
    String? partnerId,
  }) async {
    if (_currentWorkspaceId == null || _currentPeriodId == null) {
      _errorMessage = 'No active workspace or period found.';
      notifyListeners();
      return false;
    }

    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final resolvedPaidByName = paidByName ?? (paidBy == currentUserId ? currentUserName : _partnerName);
      await _expenseRepository.addExpense(
        workspaceId: _currentWorkspaceId!,
        periodId: _currentPeriodId!,
        description: description,
        amount: amount,
        paidBy: paidBy,
        paidByName: resolvedPaidByName,
        createdBy: currentUserId,
        actorName: currentUserName,
        partnerId: partnerId,
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
      _errorMessage = 'Failed to add expense: $e';
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  Future<bool> editExpense({
    required Expense expense,
    required String newDescription,
    required double newAmount,
    required String newPaidBy,
    String? newPaidByName,
    required String currentUserId,
    required String currentUserName,
    String? partnerId,
  }) async {
    if (_currentWorkspaceId == null) return false;

    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final resolvedPaidByName = newPaidByName ?? (newPaidBy == currentUserId ? currentUserName : _partnerName);
      await _expenseRepository.editExpense(
        workspaceId: _currentWorkspaceId!,
        expense: expense,
        newDescription: newDescription,
        newAmount: newAmount,
        newPaidBy: newPaidBy,
        newPaidByName: resolvedPaidByName,
        currentUserId: currentUserId,
        currentUserName: currentUserName,
        partnerId: partnerId,
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
      _errorMessage = 'Failed to edit expense: $e';
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  Future<bool> approvePendingChange({
    required PendingChange pendingChange,
    required String reviewerId,
    required String reviewerName,
  }) async {
    if (_currentWorkspaceId == null) return false;

    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      await _expenseRepository.approvePendingChange(
        workspaceId: _currentWorkspaceId!,
        pendingChange: pendingChange,
        reviewerId: reviewerId,
        reviewerName: reviewerName,
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
      _errorMessage = 'Failed to approve change: $e';
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  Future<bool> rejectPendingChange({
    required PendingChange pendingChange,
    required String reviewerId,
    required String reviewerName,
  }) async {
    if (_currentWorkspaceId == null) return false;

    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      await _expenseRepository.rejectPendingChange(
        workspaceId: _currentWorkspaceId!,
        pendingChange: pendingChange,
        reviewerId: reviewerId,
        reviewerName: reviewerName,
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
      _errorMessage = 'Failed to reject change: $e';
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  Future<bool> deleteExpense({
    required Expense expense,
    required String currentUserId,
    required String currentUserName,
    String? partnerId,
  }) async {
    if (_currentWorkspaceId == null) return false;

    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      await _expenseRepository.deleteExpense(
        workspaceId: _currentWorkspaceId!,
        expense: expense,
        currentUserId: currentUserId,
        currentUserName: currentUserName,
        partnerId: partnerId,
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
      _errorMessage = 'Failed to delete expense: $e';
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  @override
  void dispose() {
    _expensesSubscription?.cancel();
    _pendingChangesSubscription?.cancel();
    super.dispose();
  }
}
