import 'package:flutter_test/flutter_test.dart';
import 'package:splitterbuddy/features/workspace/domain/models/workspace.dart';

void main() {
  group('Multi-Member Workspace Model Tests', () {
    test('Default permissions and roles work as expected', () {
      final ws = Workspace(
        id: 'ws_1',
        name: 'Apartment Buddies',
        inviteCode: 'APT123',
        ownerId: 'user_1',
        memberIds: ['user_1', 'user_2', 'user_3'],
        memberNames: {'user_1': 'Owner Alice', 'user_2': 'Admin Bob', 'user_3': 'Member Charlie'},
        memberRoles: {
          'user_1': WorkspaceRole.owner,
          'user_2': WorkspaceRole.admin,
          'user_3': WorkspaceRole.member,
        },
        maxMembers: 10,
        activePeriodId: 'period_1',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      expect(ws.isOwner('user_1'), isTrue);
      expect(ws.isOwner('user_2'), isFalse);
      expect(ws.isAdmin('user_1'), isTrue); // Owner is also admin
      expect(ws.isAdmin('user_2'), isTrue);
      expect(ws.isAdmin('user_3'), isFalse);

      expect(ws.canManageMembers('user_1'), isTrue);
      expect(ws.canManageMembers('user_2'), isTrue);
      expect(ws.canManageMembers('user_3'), isFalse);

      expect(ws.canDeleteWorkspace('user_1'), isTrue);
      expect(ws.canDeleteWorkspace('user_2'), isFalse);

      expect(ws.memberCount, 3);
      expect(ws.isFull, isFalse);
    });

    test('Backward-compatible deserialization assigns owner role to ownerId and member to others', () {
      final v1Map = {
        'id': 'ws_legacy',
        'name': 'Legacy Workspace',
        'inviteCode': 'LEG123',
        'ownerId': 'user_1',
        'memberIds': ['user_1', 'user_2'],
        'memberNames': {'user_1': 'Alice', 'user_2': 'Bob'},
        'activePeriodId': 'period_0',
        'createdAt': '2026-01-01T00:00:00.000Z',
        'updatedAt': '2026-01-01T00:00:00.000Z',
      };

      final ws = Workspace.fromMap(v1Map, 'ws_legacy');

      expect(ws.maxMembers, 10);
      expect(ws.getRole('user_1'), WorkspaceRole.owner);
      expect(ws.getRole('user_2'), WorkspaceRole.member);
      expect(ws.isOwner('user_1'), isTrue);
      expect(ws.isOwner('user_2'), isFalse);
    });

    test('Serialization toMap preserves memberRoles and maxMembers', () {
      final ws = Workspace(
        id: 'ws_serialize',
        name: 'Test WS',
        inviteCode: 'SER123',
        ownerId: 'user_1',
        memberIds: ['user_1', 'user_2'],
        memberNames: {'user_1': 'Alice', 'user_2': 'Bob'},
        memberRoles: {'user_1': WorkspaceRole.owner, 'user_2': WorkspaceRole.admin},
        maxMembers: 10,
        activePeriodId: 'period_1',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      final map = ws.toMap();
      expect(map['memberRoles']['user_1'], WorkspaceRole.owner);
      expect(map['memberRoles']['user_2'], WorkspaceRole.admin);
      expect(map['maxMembers'], 10);
    });
  });
}
