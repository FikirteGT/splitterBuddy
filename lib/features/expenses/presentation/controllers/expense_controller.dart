import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:splitterbuddy/core/constants/app_constants.dart';
import 'package:splitterbuddy/core/errors/app_exceptions.dart';
import 'package:splitterbuddy/features/balance/domain/models/balance_result.dart';
import 'package:splitterbuddy/features/balance/services/balance_engine.dart';
import 'package:splitterbuddy/features/expenses/data/repositories/expense_repository.dart';
import 'package:splitterbuddy/features/expenses/domain/models/expense.dart';
import 'package:splitterbuddy/features/expenses/domain/models/pending_change.dart';

enum ExpenseSortOption {
  newest,
  oldest,
  highestAmount,
  lowestAmount,
}

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

  // Search and Filter State
  String _searchQuery = '';
  String? _selectedCategory;
  String? _selectedPayer;
  String? _selectedSplitType;
  DateTime? _startDate;
  DateTime? _endDate;
  double? _minAmount;
  double? _maxAmount;
  ExpenseSortOption _sortOption = ExpenseSortOption.newest;

  ExpenseController({ExpenseRepository? expenseRepository})
      : _expenseRepository = expenseRepository ?? ExpenseRepository();

  List<Expense> get expenses => _expenses;
  List<Expense> get activeExpenses => _expenses.where((e) => e.status == AppConstants.expenseActive).toList();
  List<Expense> get recentExpenses => activeExpenses.take(5).toList();
  List<PendingChange> get pendingChanges => _pendingChanges;
  BalanceResult get balance => _balance;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;

  // Search & Filter Getters
  String get searchQuery => _searchQuery;
  String? get selectedCategory => _selectedCategory;
  String? get selectedPayer => _selectedPayer;
  String? get selectedSplitType => _selectedSplitType;
  DateTime? get startDate => _startDate;
  DateTime? get endDate => _endDate;
  double? get minAmount => _minAmount;
  double? get maxAmount => _maxAmount;
  ExpenseSortOption get sortOption => _sortOption;

  bool get hasActiveFilters =>
      _searchQuery.isNotEmpty ||
      _selectedCategory != null ||
      _selectedPayer != null ||
      _selectedSplitType != null ||
      _startDate != null ||
      _endDate != null ||
      _minAmount != null ||
      _maxAmount != null ||
      _sortOption != ExpenseSortOption.newest;

  List<Expense> get filteredExpenses {
    var list = activeExpenses;

    if (_searchQuery.isNotEmpty) {
      final q = _searchQuery.toLowerCase();
      list = list.where((e) => e.description.toLowerCase().contains(q) || e.category.toLowerCase().contains(q)).toList();
    }

    if (_selectedCategory != null && _selectedCategory!.isNotEmpty) {
      list = list.where((e) => e.category == _selectedCategory).toList();
    }

    if (_selectedPayer != null && _selectedPayer!.isNotEmpty) {
      list = list.where((e) => e.paidBy == _selectedPayer).toList();
    }

    if (_selectedSplitType != null && _selectedSplitType!.isNotEmpty) {
      list = list.where((e) => e.splitType == _selectedSplitType).toList();
    }

    if (_startDate != null) {
      list = list.where((e) => e.createdAt.isAfter(_startDate!) || e.createdAt.isAtSameMomentAs(_startDate!)).toList();
    }

    if (_endDate != null) {
      final endOfDay = DateTime(_endDate!.year, _endDate!.month, _endDate!.day, 23, 59, 59);
      list = list.where((e) => e.createdAt.isBefore(endOfDay) || e.createdAt.isAtSameMomentAs(endOfDay)).toList();
    }

    if (_minAmount != null) {
      list = list.where((e) => e.amount >= _minAmount!).toList();
    }

    if (_maxAmount != null) {
      list = list.where((e) => e.amount <= _maxAmount!).toList();
    }

    switch (_sortOption) {
      case ExpenseSortOption.oldest:
        list.sort((a, b) => a.createdAt.compareTo(b.createdAt));
        break;
      case ExpenseSortOption.highestAmount:
        list.sort((a, b) => b.amount.compareTo(a.amount));
        break;
      case ExpenseSortOption.lowestAmount:
        list.sort((a, b) => a.amount.compareTo(b.amount));
        break;
      case ExpenseSortOption.newest:
        list.sort((a, b) => b.createdAt.compareTo(a.createdAt));
        break;
    }

    return list;
  }

  void setSearchQuery(String query) {
    _searchQuery = query.trim();
    notifyListeners();
  }

  void setCategoryFilter(String? category) {
    _selectedCategory = category;
    notifyListeners();
  }

  void setPayerFilter(String? payerId) {
    _selectedPayer = payerId;
    notifyListeners();
  }

  void setSplitTypeFilter(String? splitType) {
    _selectedSplitType = splitType;
    notifyListeners();
  }

  void setDateRangeFilter(DateTime? start, DateTime? end) {
    _startDate = start;
    _endDate = end;
    notifyListeners();
  }

  void setAmountRangeFilter(double? min, double? max) {
    _minAmount = min;
    _maxAmount = max;
    notifyListeners();
  }

  void setSortOption(ExpenseSortOption option) {
    _sortOption = option;
    notifyListeners();
  }

  void resetFilters() {
    _searchQuery = '';
    _selectedCategory = null;
    _selectedPayer = null;
    _selectedSplitType = null;
    _startDate = null;
    _endDate = null;
    _minAmount = null;
    _maxAmount = null;
    _sortOption = ExpenseSortOption.newest;
    notifyListeners();
  }

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
    String category = AppConstants.categoryOther,
    String splitType = AppConstants.splitEqual,
    Map<String, double>? splitDetails,
    String? splitSingleMemberId,
    String? receiptUrl,
    String? receiptPath,
    bool isRecurring = false,
    String? recurringTemplateId,
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
        category: category,
        splitType: splitType,
        splitDetails: splitDetails,
        splitSingleMemberId: splitSingleMemberId,
        receiptUrl: receiptUrl,
        receiptPath: receiptPath,
        isRecurring: isRecurring,
        recurringTemplateId: recurringTemplateId,
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
        newCategory: newCategory,
        newSplitType: newSplitType,
        newSplitDetails: newSplitDetails,
        newSplitSingleMemberId: newSplitSingleMemberId,
        newReceiptUrl: newReceiptUrl,
        newReceiptPath: newReceiptPath,
        currentUserId: currentUserId,
        currentUserName: currentUserName,
        partnerId: partnerId,
        allMemberIds: allMemberIds,
        memberNames: memberNames,
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
    List<String>? allMemberIds,
    Map<String, String>? memberNames,
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
        allMemberIds: allMemberIds,
        memberNames: memberNames,
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
    List<String>? allMemberIds,
    Map<String, String>? memberNames,
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
        allMemberIds: allMemberIds,
        memberNames: memberNames,
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
