import 'package:flutter_test/flutter_test.dart';
import 'package:splitterbuddy/features/settlement/domain/models/settlement.dart';
import 'package:splitterbuddy/features/workspace/domain/models/expense_period.dart';

void main() {
  group('Settlement and Expense Period Tests', () {
    test('ExpensePeriod active vs settled status', () {
      final period = ExpensePeriod(
        id: 'p_1',
        workspaceId: 'ws_1',
        periodNumber: 1,
        isSettled: false,
        createdAt: DateTime.now(),
      );

      expect(period.isSettled, isFalse);
      expect(period.periodNumber, 1);

      final settledPeriod = period.copyWith(
        isSettled: true,
        settledAt: DateTime.now(),
        settledBy: 'user_a',
        settledAmount: 500.0,
      );

      expect(settledPeriod.isSettled, isTrue);
      expect(settledPeriod.settledAmount, 500.0);
      expect(settledPeriod.settledBy, 'user_a');
    });

    test('Settlement record preserves payer, receiver and amount data', () {
      final now = DateTime.now();
      final settlement = Settlement(
        id: 'set_1',
        workspaceId: 'ws_1',
        periodId: 'p_1',
        amount: 500.0,
        payerId: 'user_b',
        receiverId: 'user_a',
        payerName: 'Yeabsira',
        receiverName: 'Fikrte',
        initiatedBy: 'user_a',
        initiatedByName: 'Fikrte',
        timestamp: now,
      );

      expect(settlement.amount, 500.0);
      expect(settlement.payerId, 'user_b');
      expect(settlement.receiverId, 'user_a');
      expect(settlement.initiatedBy, 'user_a');
    });
  });
}
