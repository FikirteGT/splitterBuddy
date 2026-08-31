import 'package:flutter_test/flutter_test.dart';
import 'package:splitterbuddy/core/constants/app_constants.dart';
import 'package:splitterbuddy/features/balance/services/balance_engine.dart';
import 'package:splitterbuddy/features/expenses/domain/models/expense.dart';

void main() {
  const userA = 'user_a';
  const userB = 'user_b';
  const partnerName = 'Yeabsira';

  Expense createExpense({
    required String id,
    required double amount,
    required String paidBy,
    String description = 'Test Expense',
    String status = AppConstants.expenseActive,
  }) {
    return Expense(
      id: id,
      workspaceId: 'ws_1',
      periodId: 'period_1',
      description: description,
      amount: amount,
      paidBy: paidBy,
      createdBy: paidBy,
      createdAt: DateTime(2026, 1, 1),
      updatedAt: DateTime(2026, 1, 1),
      status: status,
    );
  }

  group('BalanceEngine 50/50 Calculations', () {
    test('Empty expenses yields zero balance and settled state', () {
      final result = BalanceEngine.calculate(
        expenses: [],
        currentUserId: userA,
        partnerId: userB,
        partnerName: partnerName,
      );

      expect(result.totalSpent, 0.0);
      expect(result.fairSharePerPerson, 0.0);
      expect(result.userPaid, 0.0);
      expect(result.partnerPaid, 0.0);
      expect(result.netBalance, 0.0);
      expect(result.amountOwed, 0.0);
      expect(result.isSettled, isTrue);
      expect(result.statusText, 'All settled up');
    });

    test('Single expense: User A pays 1,000 ETB -> User B owes A 500 ETB', () {
      final expenses = [
        createExpense(id: '1', amount: 1000.0, paidBy: userA, description: 'Groceries'),
      ];

      // Perspective of User A
      final resultA = BalanceEngine.calculate(
        expenses: expenses,
        currentUserId: userA,
        partnerId: userB,
        partnerName: partnerName,
      );

      expect(resultA.totalSpent, 1000.0);
      expect(resultA.fairSharePerPerson, 500.0);
      expect(resultA.userPaid, 1000.0);
      expect(resultA.partnerPaid, 0.0);
      expect(resultA.netBalance, 500.0);
      expect(resultA.amountOwed, 500.0);
      expect(resultA.payerId, userB);
      expect(resultA.receiverId, userA);
      expect(resultA.isSettled, isFalse);
      expect(resultA.statusText, 'Yeabsira owes you');

      // Perspective of User B
      final resultB = BalanceEngine.calculate(
        expenses: expenses,
        currentUserId: userB,
        partnerId: userA,
        partnerName: 'Fikrte',
      );

      expect(resultB.totalSpent, 1000.0);
      expect(resultB.fairSharePerPerson, 500.0);
      expect(resultB.userPaid, 0.0);
      expect(resultB.partnerPaid, 1000.0);
      expect(resultB.netBalance, -500.0);
      expect(resultB.amountOwed, 500.0);
      expect(resultB.payerId, userB);
      expect(resultB.receiverId, userA);
      expect(resultB.isSettled, isFalse);
      expect(resultB.statusText, 'You owe Fikrte');
    });

    test('Multiple expenses: A pays 1,000 ETB, B pays 600 ETB -> B owes A 200 ETB', () {
      final expenses = [
        createExpense(id: '1', amount: 1000.0, paidBy: userA, description: 'Groceries'),
        createExpense(id: '2', amount: 600.0, paidBy: userB, description: 'Internet'),
      ];

      final result = BalanceEngine.calculate(
        expenses: expenses,
        currentUserId: userA,
        partnerId: userB,
        partnerName: partnerName,
      );

      expect(result.totalSpent, 1600.0);
      expect(result.fairSharePerPerson, 800.0);
      expect(result.userPaid, 1000.0);
      expect(result.partnerPaid, 600.0);
      expect(result.netBalance, 200.0);
      expect(result.amountOwed, 200.0);
      expect(result.payerId, userB);
      expect(result.receiverId, userA);
      expect(result.statusText, 'Yeabsira owes you');
    });

    test('Equal payments: A pays 500 ETB, B pays 500 ETB -> All settled up', () {
      final expenses = [
        createExpense(id: '1', amount: 500.0, paidBy: userA),
        createExpense(id: '2', amount: 500.0, paidBy: userB),
      ];

      final result = BalanceEngine.calculate(
        expenses: expenses,
        currentUserId: userA,
        partnerId: userB,
        partnerName: partnerName,
      );

      expect(result.totalSpent, 1000.0);
      expect(result.fairSharePerPerson, 500.0);
      expect(result.userPaid, 500.0);
      expect(result.partnerPaid, 500.0);
      expect(result.netBalance, 0.0);
      expect(result.amountOwed, 0.0);
      expect(result.isSettled, isTrue);
      expect(result.statusText, 'All settled up');
    });

    test('Deleted expense is excluded from balance calculations', () {
      final expenses = [
        createExpense(id: '1', amount: 1000.0, paidBy: userA, status: AppConstants.expenseActive),
        createExpense(id: '2', amount: 400.0, paidBy: userB, status: AppConstants.expenseDeleted), // Should be ignored
      ];

      final result = BalanceEngine.calculate(
        expenses: expenses,
        currentUserId: userA,
        partnerId: userB,
        partnerName: partnerName,
      );

      expect(result.totalSpent, 1000.0);
      expect(result.partnerPaid, 0.0);
      expect(result.netBalance, 500.0);
      expect(result.amountOwed, 500.0);
    });

    test('Safe floating point arithmetic with cents', () {
      final expenses = [
        createExpense(id: '1', amount: 99.99, paidBy: userA),
        createExpense(id: '2', amount: 33.33, paidBy: userB),
      ];

      final result = BalanceEngine.calculate(
        expenses: expenses,
        currentUserId: userA,
        partnerId: userB,
        partnerName: partnerName,
      );

      expect(result.totalSpent, 133.32);
      expect(result.fairSharePerPerson, 66.66);
      expect(result.userPaid, 99.99);
      expect(result.partnerPaid, 33.33);
      expect(result.netBalance, 33.33);
      expect(result.amountOwed, 33.33);
    });
  });
}
