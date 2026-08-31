import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:splitterbuddy/core/errors/app_exceptions.dart';
import 'package:splitterbuddy/features/settlement/data/repositories/settlement_repository.dart';
import 'package:splitterbuddy/features/settlement/domain/models/settlement.dart';
import 'package:splitterbuddy/features/workspace/domain/models/expense_period.dart';

class SettlementController extends ChangeNotifier {
  final SettlementRepository _settlementRepository;

  List<Settlement> _settlements = [];
  List<ExpensePeriod> _periods = [];
  bool _isLoading = false;
  String? _errorMessage;

  StreamSubscription<List<Settlement>>? _settlementsSubscription;
  StreamSubscription<List<ExpensePeriod>>? _periodsSubscription;
  String? _currentWorkspaceId;

  SettlementController({SettlementRepository? settlementRepository})
      : _settlementRepository = settlementRepository ?? SettlementRepository();

  List<Settlement> get settlements => _settlements;
  List<ExpensePeriod> get periods => _periods;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;

  void updateWorkspace(String? workspaceId) {
    if (_currentWorkspaceId == workspaceId) return;
    _currentWorkspaceId = workspaceId;

    _settlementsSubscription?.cancel();
    _periodsSubscription?.cancel();
    _settlements = [];
    _periods = [];

    if (workspaceId != null && workspaceId.isNotEmpty) {
      _listenToSettlements(workspaceId);
      _listenToPeriods(workspaceId);
    } else {
      notifyListeners();
    }
  }

  void _listenToSettlements(String workspaceId) {
    _isLoading = true;
    notifyListeners();

    _settlementsSubscription = _settlementRepository.streamSettlements(workspaceId).listen(
      (list) {
        _settlements = list;
        _isLoading = false;
        notifyListeners();
      },
      onError: (err) {
        _isLoading = false;
        _errorMessage = 'Failed to load settlements: $err';
        notifyListeners();
      },
    );
  }

  void _listenToPeriods(String workspaceId) {
    _periodsSubscription = _settlementRepository.streamPeriods(workspaceId).listen(
      (list) {
        _periods = list;
        notifyListeners();
      },
    );
  }

  void clearError() {
    _errorMessage = null;
    notifyListeners();
  }

  Future<bool> settleBalance({
    required ExpensePeriod currentPeriod,
    required double amount,
    required String payerId,
    required String receiverId,
    required String payerName,
    required String receiverName,
    required String initiatedBy,
    required String initiatedByName,
    String? partnerId,
  }) async {
    if (_currentWorkspaceId == null) return false;

    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      await _settlementRepository.settleBalance(
        workspaceId: _currentWorkspaceId!,
        currentPeriod: currentPeriod,
        amount: amount,
        payerId: payerId,
        receiverId: receiverId,
        payerName: payerName,
        receiverName: receiverName,
        initiatedBy: initiatedBy,
        initiatedByName: initiatedByName,
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
      _errorMessage = 'Failed to settle balance: $e';
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  @override
  void dispose() {
    _settlementsSubscription?.cancel();
    _periodsSubscription?.cancel();
    super.dispose();
  }
}
