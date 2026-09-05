import 'package:flutter_test/flutter_test.dart';
import 'package:splitterbuddy/core/constants/app_constants.dart';
import 'package:splitterbuddy/features/balance/services/split_engine.dart';
import 'package:splitterbuddy/features/balance/services/balance_engine.dart';
import 'package:splitterbuddy/features/expenses/domain/models/expense.dart';

void main() {
  group('SplitEngine Tests', () {
    const userA = 'user_a';
    const userB = 'user_b';
    const memberIds = [userA, userB];

    test('Custom amount split calculation: 1000 ETB split 700/300', () {
      final expense = Expense(
        id: '1',
        workspaceId: 'ws_1',
        periodId: 'period_1',
        description: 'Dinner',
        amount: 1000.0,
        paidBy: userA,
        createdBy: userA,
        splitType: AppConstants.splitCustom,
        splitDetails: {userA: 700.0, userB: 300.0},
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      final shares = SplitEngine.computeShares(expense: expense, memberIds: memberIds);
      expect(shares[userA], 700.0);
      expect(shares[userB], 300.0);

      final result = BalanceEngine.calculate(
        expenses: [expense],
        currentUserId: userA,
        partnerId: userB,
      );

      // User A paid 1000, share is 700 -> A is owed 300.
      expect(result.netBalance, 300.0);
      expect(result.amountOwed, 300.0);
      expect(result.payerId, userB);
      expect(result.receiverId, userA);
    });

    test('Percentage split calculation: 1000 ETB split 70% / 30%', () {
      final expense = Expense(
        id: '1',
        workspaceId: 'ws_1',
        periodId: 'period_1',
        description: 'Electric Bill',
        amount: 1000.0,
        paidBy: userA,
        createdBy: userA,
        splitType: AppConstants.splitPercentage,
        splitDetails: {userA: 70.0, userB: 30.0},
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      final shares = SplitEngine.computeShares(expense: expense, memberIds: memberIds);
      expect(shares[userA], 700.0);
      expect(shares[userB], 300.0);

      final result = BalanceEngine.calculate(
        expenses: [expense],
        currentUserId: userA,
        partnerId: userB,
      );

      expect(result.netBalance, 300.0);
      expect(result.amountOwed, 300.0);
    });

    test('Paid for one person: User A pays 1000 ETB entirely for User B', () {
      final expense = Expense(
        id: '1',
        workspaceId: 'ws_1',
        periodId: 'period_1',
        description: 'Medicine for B',
        amount: 1000.0,
        paidBy: userA,
        createdBy: userA,
        splitType: AppConstants.splitSingle,
        splitSingleMemberId: userB,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      final shares = SplitEngine.computeShares(expense: expense, memberIds: memberIds);
      expect(shares[userA], 0.0);
      expect(shares[userB], 1000.0);

      final result = BalanceEngine.calculate(
        expenses: [expense],
        currentUserId: userA,
        partnerId: userB,
      );

      // User A paid 1000, share is 0 -> User B owes User A the full 1000 ETB.
      expect(result.netBalance, 1000.0);
      expect(result.amountOwed, 1000.0);
      expect(result.payerId, userB);
      expect(result.receiverId, userA);
    });

    test('Split validation rejects mismatching custom amounts and percentages', () {
      // Custom amount mismatch
      final err1 = SplitEngine.validateSplit(
        totalAmount: 1000.0,
        splitType: AppConstants.splitCustom,
        memberIds: memberIds,
        splitDetails: {userA: 600.0, userB: 300.0}, // Sums to 900 != 1000
      );
      expect(err1, isNotNull);

      // Negative custom amount
      final err2 = SplitEngine.validateSplit(
        totalAmount: 1000.0,
        splitType: AppConstants.splitCustom,
        memberIds: memberIds,
        splitDetails: {userA: 1200.0, userB: -200.0},
      );
      expect(err2, isNotNull);

      // Percentage sum != 100%
      final err3 = SplitEngine.validateSplit(
        totalAmount: 1000.0,
        splitType: AppConstants.splitPercentage,
        memberIds: memberIds,
        splitDetails: {userA: 50.0, userB: 40.0}, // Sums to 90%
      );
      expect(err3, isNotNull);

      // Valid percentage
      final valid = SplitEngine.validateSplit(
        totalAmount: 1000.0,
        splitType: AppConstants.splitPercentage,
        memberIds: memberIds,
        splitDetails: {userA: 60.0, userB: 40.0},
      );
      expect(valid, isNull);
    });
  });
}
