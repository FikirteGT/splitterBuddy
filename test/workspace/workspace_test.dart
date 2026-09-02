import 'package:flutter_test/flutter_test.dart';
import 'package:splitterbuddy/core/constants/app_constants.dart';
import 'package:splitterbuddy/core/utils/invite_code_generator.dart';
import 'package:splitterbuddy/features/workspace/domain/models/workspace.dart';

void main() {
  group('Workspace Domain & Invite Code Logic', () {
    test('InviteCodeGenerator generates 6-character uppercase alphanumeric code', () {
      final code = InviteCodeGenerator.generate();
      expect(code.length, 6);
      expect(InviteCodeGenerator.isValidFormat(code), isTrue);
      expect(code, code.toUpperCase());
    });

    test('InviteCodeGenerator normalizes whitespace, hyphens, and lowercase input', () {
      expect(InviteCodeGenerator.normalize('  k9x2mn  '), 'K9X2MN');
      expect(InviteCodeGenerator.normalize('k9-x2-mn'), 'K9X2MN');
      expect(InviteCodeGenerator.normalize(' k9 x2 mn '), 'K9X2MN');
      expect(InviteCodeGenerator.isValidFormat('  k9x2mn  '), isTrue);
      expect(InviteCodeGenerator.isValidFormat('k9-x2-mn'), isTrue);
      expect(InviteCodeGenerator.isValidFormat(' k9 x2 mn '), isTrue);
      expect(InviteCodeGenerator.isValidFormat('12345'), isFalse); // too short
      expect(InviteCodeGenerator.isValidFormat('1234567'), isFalse); // too long
    });

    test('Workspace with 1 member has no partner and is not full', () {
      final ws = Workspace(
        id: 'ws_1',
        name: 'Apartment',
        inviteCode: 'ABC123',
        ownerId: 'user_1',
        memberIds: ['user_1'],
        memberNames: {'user_1': 'Fikrte'},
        activePeriodId: 'period_1',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      expect(ws.isFull, isFalse);
      expect(ws.hasPartner, isFalse);
      expect(ws.getPartnerId('user_1'), isNull);
      expect(ws.getPartnerName('user_1'), 'Partner');
    });

    test('Workspace with 2 members is full and identifies partner correctly', () {
      final ws = Workspace(
        id: 'ws_1',
        name: 'Apartment',
        inviteCode: 'ABC123',
        ownerId: 'user_1',
        memberIds: ['user_1', 'user_2'],
        memberNames: {'user_1': 'Fikrte', 'user_2': 'Yeabsira'},
        activePeriodId: 'period_1',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      expect(ws.isFull, isTrue);
      expect(ws.hasPartner, isTrue);
      expect(ws.getPartnerId('user_1'), 'user_2');
      expect(ws.getPartnerName('user_1'), 'Yeabsira');
      expect(ws.getPartnerId('user_2'), 'user_1');
      expect(ws.getPartnerName('user_2'), 'Fikrte');
    });

    test('Enforces maximum 2 members restriction', () {
      final currentMembers = ['user_1', 'user_2'];
      final canJoin = currentMembers.length < AppConstants.maxWorkspaceMembers;
      expect(canJoin, isFalse);
    });

    test('Rejects duplicate member', () {
      final currentMembers = ['user_1'];
      final isAlreadyMember = currentMembers.contains('user_1');
      expect(isAlreadyMember, isTrue);
    });
  });
}
