import 'package:flutter_test/flutter_test.dart';
import 'package:splitterbuddy/core/constants/app_constants.dart';
import 'package:splitterbuddy/features/budgets/domain/models/budget.dart';

void main() {
  group('Budget Domain Tests', () {
    test('calculateProgress calculates onTrack status correctly when < 75%', () {
      final budget = Budget(
        id: 'b1',
        workspaceId: 'ws1',
        category: AppConstants.categoryFood,
        limitAmount: 2000.0,
        createdBy: 'userA',
        createdAt: DateTime.now(),
      );

      final calc = budget.calculateProgress(1000.0); // 50%
      expect(calc.percentage, 50.0);
      expect(calc.spentAmount, 1000.0);
      expect(calc.remainingAmount, 1000.0);
      expect(calc.overAmount, 0.0);
      expect(calc.status, BudgetStatus.onTrack);
      expect(calc.statusLabel, 'On Track');
    });

    test('calculateProgress calculates approachingLimit when between 75% and 99%', () {
      final budget = Budget(
        id: 'b1',
        workspaceId: 'ws1',
        category: AppConstants.categoryFood,
        limitAmount: 2000.0,
        createdBy: 'userA',
        createdAt: DateTime.now(),
      );

      final calc = budget.calculateProgress(1700.0); // 85%
      expect(calc.percentage, 85.0);
      expect(calc.spentAmount, 1700.0);
      expect(calc.remainingAmount, 300.0);
      expect(calc.status, BudgetStatus.approachingLimit);
      expect(calc.statusLabel, 'Approaching Limit');
    });

    test('calculateProgress calculates exceeded status when >= 100%', () {
      final budget = Budget(
        id: 'b1',
        workspaceId: 'ws1',
        category: 'overall',
        limitAmount: 5000.0,
        createdBy: 'userA',
        createdAt: DateTime.now(),
      );

      final calc = budget.calculateProgress(5500.0); // 110%
      expect(calc.percentage, 110.0);
      expect(calc.spentAmount, 5500.0);
      expect(calc.remainingAmount, 0.0);
      expect(calc.overAmount, 500.0);
      expect(calc.status, BudgetStatus.exceeded);
      expect(calc.statusLabel, 'Exceeded Limit');
    });
  });
}
