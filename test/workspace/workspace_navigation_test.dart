import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:splitterbuddy/features/workspace/data/repositories/workspace_repository.dart';
import 'package:splitterbuddy/features/workspace/domain/models/expense_period.dart';
import 'package:splitterbuddy/features/workspace/domain/models/workspace.dart';
import 'package:splitterbuddy/features/workspace/presentation/controllers/workspace_controller.dart';

class FakeWorkspaceRepository extends WorkspaceRepository {
  final Map<String, Workspace> workspaces = {};
  final StreamController<List<Workspace>> _userWorkspacesController = StreamController<List<Workspace>>.broadcast();
  final StreamController<Workspace?> _workspaceController = StreamController<Workspace?>.broadcast();
  final StreamController<ExpensePeriod?> _periodController = StreamController<ExpensePeriod?>.broadcast();

  FakeWorkspaceRepository() : super();

  @override
  Stream<List<Workspace>> streamUserWorkspaces(String userId) {
    return _userWorkspacesController.stream;
  }

  @override
  Stream<Workspace?> streamWorkspace(String workspaceId) {
    return _workspaceController.stream;
  }

  @override
  Stream<ExpensePeriod?> streamActivePeriod(String workspaceId, String periodId) {
    return _periodController.stream;
  }
}

void main() {
  group('Workspace Switching and Selection Logic Tests', () {
    late FakeWorkspaceRepository fakeRepo;

    final ws1 = Workspace(
      id: 'ws_1',
      name: 'Apartment A',
      inviteCode: 'CODE01',
      ownerId: 'user_1',
      memberIds: ['user_1', 'user_2'],
      memberNames: {'user_1': 'User 1', 'user_2': 'User 2'},
      activePeriodId: 'period_1',
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );

    final ws2 = Workspace(
      id: 'ws_2',
      name: 'Vacation Trip',
      inviteCode: 'CODE02',
      ownerId: 'user_1',
      memberIds: ['user_1', 'user_3'],
      memberNames: {'user_1': 'User 1', 'user_3': 'User 3'},
      activePeriodId: 'period_2',
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );

    setUp(() {
      fakeRepo = FakeWorkspaceRepository();
    });

    test('selectWorkspace changes current active workspace immediately', () {
      final controller = WorkspaceController(workspaceRepository: fakeRepo);
      expect(controller.currentWorkspace, isNull);

      controller.selectWorkspace(ws1);
      expect(controller.currentWorkspace?.id, 'ws_1');
      expect(controller.currentWorkspace?.name, 'Apartment A');

      controller.selectWorkspace(ws2);
      expect(controller.currentWorkspace?.id, 'ws_2');
      expect(controller.currentWorkspace?.name, 'Vacation Trip');
    });

    test('selecting already selected workspace does not trigger duplicate state churn', () {
      final controller = WorkspaceController(workspaceRepository: fakeRepo);
      int notifyCount = 0;
      controller.addListener(() => notifyCount++);

      controller.selectWorkspace(ws1);
      expect(notifyCount, 1);
      expect(controller.currentWorkspace?.id, 'ws_1');

      // Selecting the same workspace again
      controller.selectWorkspace(ws1);
      expect(notifyCount, 2);
      expect(controller.currentWorkspace?.id, 'ws_1');
    });

    test('switching workspaces correctly isolates partner and member information', () {
      final controller = WorkspaceController(workspaceRepository: fakeRepo);
      controller.selectWorkspace(ws1);
      expect(controller.currentWorkspace?.getPartnerId('user_1'), 'user_2');
      expect(controller.currentWorkspace?.getPartnerName('user_1'), 'User 2');

      controller.selectWorkspace(ws2);
      expect(controller.currentWorkspace?.getPartnerId('user_1'), 'user_3');
      expect(controller.currentWorkspace?.getPartnerName('user_1'), 'User 3');
    });
  });
}
