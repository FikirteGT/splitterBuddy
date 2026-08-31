import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:splitterbuddy/core/errors/app_exceptions.dart';
import 'package:splitterbuddy/features/workspace/data/repositories/workspace_repository.dart';
import 'package:splitterbuddy/features/workspace/domain/models/expense_period.dart';
import 'package:splitterbuddy/features/workspace/domain/models/workspace.dart';

class WorkspaceController extends ChangeNotifier {
  final WorkspaceRepository _workspaceRepository;

  List<Workspace> _workspaces = [];
  Workspace? _currentWorkspace;
  ExpensePeriod? _currentPeriod;
  bool _isLoading = false;
  String? _errorMessage;

  StreamSubscription<List<Workspace>>? _workspacesSubscription;
  StreamSubscription<Workspace?>? _currentWorkspaceSubscription;
  StreamSubscription<ExpensePeriod?>? _currentPeriodSubscription;
  String? _currentUserId;

  WorkspaceController({WorkspaceRepository? workspaceRepository})
      : _workspaceRepository = workspaceRepository ?? WorkspaceRepository();

  List<Workspace> get workspaces => _workspaces;
  Workspace? get currentWorkspace => _currentWorkspace;
  ExpensePeriod? get currentPeriod => _currentPeriod;
  bool get hasWorkspace => _currentWorkspace != null;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;

  void updateUserId(String? userId) {
    if (_currentUserId == userId) return;
    _currentUserId = userId;

    _workspacesSubscription?.cancel();
    _currentWorkspaceSubscription?.cancel();
    _currentPeriodSubscription?.cancel();
    _workspaces = [];
    _currentWorkspace = null;
    _currentPeriod = null;

    if (userId != null && userId.isNotEmpty) {
      _listenToWorkspaces(userId);
    } else {
      notifyListeners();
    }
  }

  void _listenToWorkspaces(String userId) {
    _isLoading = true;
    notifyListeners();

    _workspacesSubscription = _workspaceRepository.streamUserWorkspaces(userId).listen(
      (list) {
        _workspaces = list;
        _isLoading = false;

        // Auto-select current workspace or first available
        if (_currentWorkspace == null && list.isNotEmpty) {
          selectWorkspace(list.first);
        } else if (_currentWorkspace != null) {
          // If current workspace was updated or deleted
          final match = list.where((w) => w.id == _currentWorkspace!.id).firstOrNull;
          if (match != null) {
            _currentWorkspace = match;
            _listenToPeriod(match.id, match.activePeriodId);
          } else {
            _currentWorkspace = list.isNotEmpty ? list.first : null;
            if (_currentWorkspace != null) {
              _listenToPeriod(_currentWorkspace!.id, _currentWorkspace!.activePeriodId);
            }
          }
        }
        notifyListeners();
      },
      onError: (err) {
        _isLoading = false;
        _errorMessage = 'Failed to sync workspaces: $err';
        notifyListeners();
      },
    );
  }

  void selectWorkspace(Workspace workspace) {
    _currentWorkspace = workspace;
    _listenToWorkspaceUpdates(workspace.id);
    _listenToPeriod(workspace.id, workspace.activePeriodId);
    notifyListeners();
  }

  void _listenToWorkspaceUpdates(String workspaceId) {
    _currentWorkspaceSubscription?.cancel();
    _currentWorkspaceSubscription = _workspaceRepository.streamWorkspace(workspaceId).listen(
      (ws) {
        if (ws != null) {
          _currentWorkspace = ws;
          if (_currentPeriod?.id != ws.activePeriodId) {
            _listenToPeriod(ws.id, ws.activePeriodId);
          }
          notifyListeners();
        }
      },
    );
  }

  void _listenToPeriod(String workspaceId, String periodId) {
    _currentPeriodSubscription?.cancel();
    _currentPeriodSubscription = _workspaceRepository.streamActivePeriod(workspaceId, periodId).listen(
      (period) {
        _currentPeriod = period;
        notifyListeners();
      },
    );
  }

  void clearError() {
    _errorMessage = null;
    notifyListeners();
  }

  Future<Workspace?> createWorkspace({
    required String name,
    required String ownerId,
    required String ownerName,
  }) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final ws = await _workspaceRepository.createWorkspace(
        name: name,
        ownerId: ownerId,
        ownerName: ownerName,
      );
      selectWorkspace(ws);
      _isLoading = false;
      notifyListeners();
      return ws;
    } on AppException catch (e) {
      _errorMessage = e.message;
      _isLoading = false;
      notifyListeners();
      return null;
    } catch (e) {
      _errorMessage = 'Failed to create workspace: $e';
      _isLoading = false;
      notifyListeners();
      return null;
    }
  }

  Future<Workspace?> joinWorkspace({
    required String inviteCode,
    required String userId,
    required String userName,
  }) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final ws = await _workspaceRepository.joinWorkspace(
        inviteCode: inviteCode,
        userId: userId,
        userName: userName,
      );
      selectWorkspace(ws);
      _isLoading = false;
      notifyListeners();
      return ws;
    } on AppException catch (e) {
      _errorMessage = e.message;
      _isLoading = false;
      notifyListeners();
      return null;
    } catch (e) {
      _errorMessage = 'Failed to join workspace: $e';
      _isLoading = false;
      notifyListeners();
      return null;
    }
  }

  Future<bool> deleteWorkspace(String workspaceId, String userId) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      await _workspaceRepository.deleteWorkspace(workspaceId, userId);
      if (_currentWorkspace?.id == workspaceId) {
        _currentWorkspace = null;
        _currentPeriod = null;
      }
      _isLoading = false;
      notifyListeners();
      return true;
    } on AppException catch (e) {
      _errorMessage = e.message;
      _isLoading = false;
      notifyListeners();
      return false;
    } catch (e) {
      _errorMessage = 'Failed to delete workspace: $e';
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  @override
  void dispose() {
    _workspacesSubscription?.cancel();
    _currentWorkspaceSubscription?.cancel();
    _currentPeriodSubscription?.cancel();
    super.dispose();
  }
}
