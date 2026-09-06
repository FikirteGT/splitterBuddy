import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:splitterbuddy/core/errors/app_exceptions.dart';
import 'package:splitterbuddy/features/settlement/data/repositories/settlement_repository.dart';
import 'package:splitterbuddy/features/settlement/domain/models/settlement.dart';
import 'package:splitterbuddy/features/settlement/domain/models/settlement_obligation.dart';
import 'package:splitterbuddy/features/workspace/domain/models/expense_period.dart';

class SettlementController extends ChangeNotifier {
  final SettlementRepository _settlementRepository;

  List<Settlement> _settlements = [];
  List<ExpensePeriod> _periods = [];
  List<SettlementObligation> _obligations = [];
  bool _isLoading = false;
  String? _errorMessage;

  StreamSubscription<List<Settlement>>? _settlementsSubscription;
  StreamSubscription<List<ExpensePeriod>>? _periodsSubscription;
  StreamSubscription<List<SettlementObligation>>? _obligationsSubscription;
  String? _currentWorkspaceId;
  String? _currentPeriodId;

  SettlementController({SettlementRepository? settlementRepository})
      : _settlementRepository = settlementRepository ?? SettlementRepository();

  List<Settlement> get settlements => _settlements;
  List<ExpensePeriod> get periods => _periods;
  List<SettlementObligation> get obligations => _obligations;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;

  void updateWorkspace(String? workspaceId, {String? activePeriodId}) {
    if (_currentWorkspaceId == workspaceId && _currentPeriodId == activePeriodId) return;
    _currentWorkspaceId = workspaceId;
    _currentPeriodId = activePeriodId;

    _settlementsSubscription?.cancel();
    _periodsSubscription?.cancel();
    _obligationsSubscription?.cancel();
    _settlements = [];
    _periods = [];
    _obligations = [];

    if (workspaceId != null && workspaceId.isNotEmpty) {
      _listenToSettlements(workspaceId);
      _listenToPeriods(workspaceId);
      if (activePeriodId != null && activePeriodId.isNotEmpty) {
        _listenToObligations(workspaceId, activePeriodId);
      }
    } else {
      notifyListeners();
    }
  }

  void updateActivePeriod(String periodId) {
    if (_currentPeriodId == periodId) return;
    _currentPeriodId = periodId;
    if (_currentWorkspaceId != null && _currentWorkspaceId!.isNotEmpty) {
      _listenToObligations(_currentWorkspaceId!, periodId);
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

  void _listenToObligations(String workspaceId, String periodId) {
    _obligationsSubscription?.cancel();
    _obligationsSubscription = _settlementRepository.streamObligations(workspaceId, periodId).listen(
      (list) {
        _obligations = list;
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
    List<String>? allMemberIds,
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
        allMemberIds: allMemberIds,
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

  Future<bool> recordPartialSettlement({
    required ExpensePeriod currentPeriod,
    required String obligationId,
    required double paymentAmount,
    required double totalOriginalAmount,
    required double previousSettledAmount,
    required String payerId,
    required String receiverId,
    required String payerName,
    required String receiverName,
    required String initiatedBy,
    required String initiatedByName,
  }) async {
    if (_currentWorkspaceId == null) return false;

    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      await _settlementRepository.recordPartialSettlement(
        workspaceId: _currentWorkspaceId!,
        currentPeriod: currentPeriod,
        obligationId: obligationId,
        paymentAmount: paymentAmount,
        totalOriginalAmount: totalOriginalAmount,
        previousSettledAmount: previousSettledAmount,
        payerId: payerId,
        receiverId: receiverId,
        payerName: payerName,
        receiverName: receiverName,
        initiatedBy: initiatedBy,
        initiatedByName: initiatedByName,
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
      _errorMessage = 'Failed to record partial payment: $e';
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  @override
  void dispose() {
    _settlementsSubscription?.cancel();
    _periodsSubscription?.cancel();
    _obligationsSubscription?.cancel();
    super.dispose();
  }
}
