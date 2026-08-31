import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:splitterbuddy/features/history/data/repositories/activity_repository.dart';
import 'package:splitterbuddy/features/history/domain/models/activity_log.dart';

class HistoryController extends ChangeNotifier {
  final ActivityRepository _activityRepository;

  List<ActivityLog> _activityLogs = [];
  bool _isLoading = false;
  String? _errorMessage;
  StreamSubscription<List<ActivityLog>>? _subscription;
  String? _currentWorkspaceId;

  HistoryController({ActivityRepository? activityRepository})
      : _activityRepository = activityRepository ?? ActivityRepository();

  List<ActivityLog> get activityLogs => _activityLogs;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;

  void updateWorkspace(String? workspaceId) {
    if (_currentWorkspaceId == workspaceId) return;
    _currentWorkspaceId = workspaceId;

    _subscription?.cancel();
    _activityLogs = [];

    if (workspaceId != null && workspaceId.isNotEmpty) {
      _listenToLogs(workspaceId);
    } else {
      notifyListeners();
    }
  }

  void _listenToLogs(String workspaceId) {
    _isLoading = true;
    notifyListeners();

    _subscription = _activityRepository.streamActivityLogs(workspaceId).listen(
      (logs) {
        _activityLogs = logs;
        _isLoading = false;
        notifyListeners();
      },
      onError: (err) {
        _isLoading = false;
        _errorMessage = 'Failed to load activity: $err';
        notifyListeners();
      },
    );
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }
}
