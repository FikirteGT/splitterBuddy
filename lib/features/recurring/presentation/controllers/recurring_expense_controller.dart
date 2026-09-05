import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:splitterbuddy/core/constants/app_constants.dart';
import 'package:splitterbuddy/core/errors/app_exceptions.dart';
import 'package:splitterbuddy/features/expenses/domain/models/expense.dart';
import 'package:splitterbuddy/features/recurring/data/repositories/recurring_expense_repository.dart';
import 'package:splitterbuddy/features/recurring/domain/models/recurring_expense.dart';

class RecurringExpenseController extends ChangeNotifier {
  final RecurringExpenseRepository _repository;

  List<RecurringExpense> _recurringExpenses = [];
  bool _isLoading = false;
  String? _errorMessage;
  StreamSubscription<List<RecurringExpense>>? _subscription;
  String? _currentWorkspaceId;

  RecurringExpenseController({RecurringExpenseRepository? repository})
      : _repository = repository ?? RecurringExpenseRepository();

  List<RecurringExpense> get recurringExpenses => _recurringExpenses;
  List<RecurringExpense> get activeTemplates => _recurringExpenses.where((r) => r.isActive).toList();
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;

  void updateWorkspace(String? workspaceId) {
    if (_currentWorkspaceId == workspaceId) return;
    _currentWorkspaceId = workspaceId;
    _subscription?.cancel();
    _recurringExpenses = [];

    if (workspaceId != null && workspaceId.isNotEmpty) {
      _listenToRecurring(workspaceId);
    } else {
      notifyListeners();
    }
  }

  void _listenToRecurring(String workspaceId) {
    _isLoading = true;
    notifyListeners();

    _subscription = _repository.streamRecurringExpenses(workspaceId).listen(
      (list) {
        _recurringExpenses = list;
        _isLoading = false;
        notifyListeners();
      },
      onError: (err) {
        _isLoading = false;
        _errorMessage = 'Failed to sync recurring expenses: $err';
        notifyListeners();
      },
    );
  }

  Future<bool> createRecurringExpense({
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
    if (_currentWorkspaceId == null) return false;

    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      await _repository.createRecurringExpense(
        workspaceId: _currentWorkspaceId!,
        description: description,
        amount: amount,
        paidBy: paidBy,
        category: category,
        splitType: splitType,
        splitDetails: splitDetails,
        splitSingleMemberId: splitSingleMemberId,
        frequency: frequency,
        firstDueDate: firstDueDate,
        createdBy: createdBy,
        currentUserName: currentUserName,
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
      _errorMessage = 'Failed to create recurring template: $e';
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  Future<bool> toggleActive({
    required RecurringExpense recurring,
    required String currentUserId,
    required String currentUserName,
  }) async {
    if (_currentWorkspaceId == null) return false;

    try {
      await _repository.toggleRecurringActive(
        workspaceId: _currentWorkspaceId!,
        recurringId: recurring.id,
        isCurrentlyActive: recurring.isActive,
        currentUserId: currentUserId,
        currentUserName: currentUserName,
      );
      return true;
    } catch (e) {
      _errorMessage = 'Failed to toggle status: $e';
      notifyListeners();
      return false;
    }
  }

  Future<bool> deleteRecurring(String recurringId) async {
    if (_currentWorkspaceId == null) return false;

    try {
      await _repository.deleteRecurringExpense(
        workspaceId: _currentWorkspaceId!,
        recurringId: recurringId,
      );
      return true;
    } catch (e) {
      _errorMessage = 'Failed to delete template: $e';
      notifyListeners();
      return false;
    }
  }

  Future<List<Expense>> checkAndProcessDue({
    required String activePeriodId,
    required String currentUserId,
    required String currentUserName,
    String? partnerId,
  }) async {
    if (_currentWorkspaceId == null || activePeriodId.isEmpty) return [];

    return await _repository.processDueRecurringExpenses(
      workspaceId: _currentWorkspaceId!,
      activePeriodId: activePeriodId,
      currentUserId: currentUserId,
      currentUserName: currentUserName,
      partnerId: partnerId,
    );
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }
}
