import 'package:flutter_test/flutter_test.dart';
import 'package:splitterbuddy/core/constants/app_constants.dart';
import 'package:splitterbuddy/features/recurring/domain/models/recurring_expense.dart';

void main() {
  group('RecurringExpense Domain & Schedule Tests', () {
    test('Daily schedule advances by 1 day', () {
      final initial = DateTime(2026, 9, 1, 10, 0);
      final next = RecurringExpense.calculateNextDueDate(initial, AppConstants.recurrenceDaily);
      expect(next, DateTime(2026, 9, 2, 10, 0));
    });

    test('Weekly schedule advances by 7 days', () {
      final initial = DateTime(2026, 9, 1, 10, 0);
      final next = RecurringExpense.calculateNextDueDate(initial, AppConstants.recurrenceWeekly);
      expect(next, DateTime(2026, 9, 8, 10, 0));
    });

    test('Monthly schedule advances by 1 month preserving day', () {
      final initial = DateTime(2026, 9, 15, 10, 0);
      final next = RecurringExpense.calculateNextDueDate(initial, AppConstants.recurrenceMonthly);
      expect(next, DateTime(2026, 10, 15, 10, 0));
    });

    test('Monthly schedule at end of year rolls over to next year', () {
      final initial = DateTime(2026, 12, 5, 10, 0);
      final next = RecurringExpense.calculateNextDueDate(initial, AppConstants.recurrenceMonthly);
      expect(next, DateTime(2027, 1, 5, 10, 0));
    });

    test('Yearly schedule advances by 1 year', () {
      final initial = DateTime(2026, 9, 1, 10, 0);
      final next = RecurringExpense.calculateNextDueDate(initial, AppConstants.recurrenceYearly);
      expect(next, DateTime(2027, 9, 1, 10, 0));
    });

    test('Serialization and deserialization roundtrip', () {
      final now = DateTime(2026, 9, 1, 12, 0);
      final recurring = RecurringExpense(
        id: 'rec_1',
        workspaceId: 'ws_1',
        description: 'Netflix Subscription',
        amount: 350.0,
        paidBy: 'user_1',
        category: AppConstants.categorySubscription,
        splitType: AppConstants.splitEqual,
        frequency: AppConstants.recurrenceMonthly,
        isActive: true,
        nextDueDate: now.add(const Duration(days: 30)),
        createdBy: 'user_1',
        createdAt: now,
        updatedAt: now,
      );

      final map = recurring.toMap();
      final parsed = RecurringExpense.fromMap(map, recurring.id);

      expect(parsed.id, recurring.id);
      expect(parsed.description, 'Netflix Subscription');
      expect(parsed.amount, 350.0);
      expect(parsed.category, AppConstants.categorySubscription);
      expect(parsed.frequency, AppConstants.recurrenceMonthly);
      expect(parsed.isActive, true);
    });
  });
}
