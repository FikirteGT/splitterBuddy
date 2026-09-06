import 'package:flutter_test/flutter_test.dart';
import 'package:splitterbuddy/core/constants/app_constants.dart';
import 'package:splitterbuddy/features/settlement/domain/models/settlement_obligation.dart';
import 'package:splitterbuddy/features/settlement/services/settlement_minimizer.dart';

void main() {
  group('SettlementMinimizer Tests', () {
    final names = {
      'user_a': 'Alice',
      'user_b': 'Bob',
      'user_c': 'Charlie',
      'user_d': 'David',
    };

    test('Zero balances produce no obligations', () {
      final balances = {
        'user_a': 0.0,
        'user_b': 0.0,
      };

      final obligations = SettlementMinimizer.minimizeDebts(
        memberNetBalances: balances,
        memberNames: names,
        workspaceId: 'ws_1',
        periodId: 'p_1',
      );

      expect(obligations, isEmpty);
    });

    test('Two-member balanced debt minimizes to exactly 1 obligation', () {
      final balances = {
        'user_a': -50.0, // Alice owes 50
        'user_b': 50.0,  // Bob is owed 50
      };

      final obligations = SettlementMinimizer.minimizeDebts(
        memberNetBalances: balances,
        memberNames: names,
        workspaceId: 'ws_1',
        periodId: 'p_1',
      );

      expect(obligations.length, 1);
      final obl = obligations.first;
      expect(obl.fromUserId, 'user_a');
      expect(obl.toUserId, 'user_b');
      expect(obl.fromUserName, 'Alice');
      expect(obl.toUserName, 'Bob');
      expect(obl.originalAmount, 50.0);
      expect(obl.remainingAmount, 50.0);
      expect(obl.status, AppConstants.obligationOpen);
    });

    test('Three-member cyclic debt is simplified to minimal payments', () {
      // Net balances: Alice owes 30, Bob is neutral (0), Charlie is owed 30
      final balances = {
        'user_a': -30.0,
        'user_b': 0.0,
        'user_c': 30.0,
      };

      final obligations = SettlementMinimizer.minimizeDebts(
        memberNetBalances: balances,
        memberNames: names,
        workspaceId: 'ws_1',
        periodId: 'p_1',
      );

      expect(obligations.length, 1);
      expect(obligations.first.fromUserId, 'user_a');
      expect(obligations.first.toUserId, 'user_c');
      expect(obligations.first.originalAmount, 30.0);
    });

    test('Four-member complex multi-party debt minimizes to <= 3 obligations', () {
      // Alice owes 60, Bob owes 40, Charlie is owed 70, David is owed 30
      // Sum debts = 100, Sum credits = 100
      final balances = {
        'user_a': -60.0,
        'user_b': -40.0,
        'user_c': 70.0,
        'user_d': 30.0,
      };

      final obligations = SettlementMinimizer.minimizeDebts(
        memberNetBalances: balances,
        memberNames: names,
        workspaceId: 'ws_1',
        periodId: 'p_1',
      );

      expect(obligations.length, lessThanOrEqualTo(3));

      // Check total amounts paid match total amounts received
      final totalSettled = obligations.fold<double>(0.0, (sum, o) => sum + o.originalAmount);
      expect(totalSettled, 100.0);
    });
  });

  group('SettlementObligation Model Tests', () {
    test('Calculates remaining amounts and partial settlement statuses accurately', () {
      final obl = SettlementObligation(
        id: 'obl_1',
        workspaceId: 'ws_1',
        periodId: 'p_1',
        fromUserId: 'user_a',
        toUserId: 'user_b',
        fromUserName: 'Alice',
        toUserName: 'Bob',
        originalAmount: 100.0,
        settledAmount: 40.0,
        status: AppConstants.obligationPartiallySettled,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      expect(obl.remainingAmount, 60.0);
      expect(obl.isPartiallySettled, isTrue);
      expect(obl.isSettled, isFalse);
      expect(obl.isOpen, isFalse);

      final fullySettled = obl.copyWith(
        settledAmount: 100.0,
        status: AppConstants.obligationSettled,
      );

      expect(fullySettled.remainingAmount, 0.0);
      expect(fullySettled.isSettled, isTrue);
    });
  });
}
