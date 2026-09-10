import 'package:flutter_test/flutter_test.dart';
import 'package:splitterbuddy/core/constants/app_constants.dart';
import 'package:splitterbuddy/core/utils/currency_formatter.dart';
import 'package:splitterbuddy/features/expenses/domain/models/expense.dart';
import 'package:splitterbuddy/features/expenses/domain/models/pending_change.dart';

void main() {
  group('Expense Model & Logic Tests', () {
    test('Valid expense creation and properties', () {
      final now = DateTime.now();
      final expense = Expense(
        id: 'exp_1',
        workspaceId: 'ws_1',
        periodId: 'period_1',
        description: 'Groceries',
        amount: 1000.0,
        paidBy: 'user_a',
        createdBy: 'user_a',
        createdAt: now,
        updatedAt: now,
      );

      expect(expense.isActive, isTrue);
      expect(expense.isDeleted, isFalse);
      expect(expense.amount, 1000.0);
      expect(expense.description, 'Groceries');
    });

    test('CurrencyFormatter parses and validates amounts correctly', () {
      expect(CurrencyFormatter.parseAmount('1000'), 1000.0);
      expect(CurrencyFormatter.parseAmount('1,000.50'), 1000.50);
      expect(CurrencyFormatter.parseAmount('0'), isNull);
      expect(CurrencyFormatter.parseAmount('-50'), isNull);
      expect(CurrencyFormatter.parseAmount('abc'), isNull);
      expect(CurrencyFormatter.parseAmount(''), isNull);
    });

    test('Own expense edit check vs Partner expense edit check', () {
      const currentUserId = 'user_a';

      final ownExpense = Expense(
        id: 'exp_1',
        workspaceId: 'ws_1',
        periodId: 'period_1',
        description: 'Groceries',
        amount: 1000.0,
        paidBy: 'user_a',
        createdBy: 'user_a',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      final partnerExpense = Expense(
        id: 'exp_2',
        workspaceId: 'ws_1',
        periodId: 'period_1',
        description: 'Internet',
        amount: 600.0,
        paidBy: 'user_b',
        createdBy: 'user_b',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      final isOwn = ownExpense.paidBy == currentUserId || ownExpense.createdBy == currentUserId;
      final isPartner = partnerExpense.paidBy != currentUserId && partnerExpense.createdBy != currentUserId;

      expect(isOwn, isTrue);
      expect(isPartner, isTrue);
    });

    test('PendingChange model tracks original and proposed values without affecting balance', () {
      final now = DateTime.now();
      final pendingChange = PendingChange(
        id: 'pc_1',
        expenseId: 'exp_1',
        workspaceId: 'ws_1',
        periodId: 'period_1',
        requesterId: 'user_b',
        requesterName: 'Yeabsira',
        partnerId: 'user_a',
        originalValues: {'description': 'Groceries', 'amount': 1000.0, 'paidBy': 'user_a'},
        proposedValues: {'description': 'Groceries & Household', 'amount': 1200.0, 'paidBy': 'user_a'},
        status: AppConstants.pendingChangePending,
        createdAt: now,
      );

      expect(pendingChange.isPending, isTrue);
      expect(pendingChange.isApproved, isFalse);
      expect(pendingChange.isRejected, isFalse);
      expect(pendingChange.originalAmount, 1000.0);
      expect(pendingChange.proposedAmount, 1200.0);
    });

    test('PendingChange formatDiffSummary generates human-readable what changed to what', () {
      final now = DateTime.now();
      final pendingChange = PendingChange(
        id: 'pc_1',
        expenseId: 'exp_1',
        workspaceId: 'ws_1',
        periodId: 'period_1',
        requesterId: 'user_b',
        requesterName: 'Yeabsira',
        partnerId: 'user_a',
        originalValues: {
          'description': 'Groceries',
          'amount': 1000.0,
          'paidBy': 'user_a',
          'category': 'Food',
          'splitType': 'EQUAL',
        },
        proposedValues: {
          'description': 'Groceries & Household',
          'amount': 1200.0,
          'paidBy': 'user_b',
          'category': 'Shopping',
          'splitType': 'CUSTOM',
        },
        status: AppConstants.pendingChangePending,
        createdAt: now,
      );

      final summary = pendingChange.formatDiffSummary(memberNames: {'user_a': 'User A', 'user_b': 'User B'});
      expect(summary, contains('Description: "Groceries" ➔ "Groceries & Household"'));
      expect(summary, contains('Amount: 1000.00 ETB ➔ 1200.00 ETB'));
      expect(summary, contains('Category: Food ➔ Shopping'));
      expect(summary, contains('Paid By: User A ➔ User B'));
      expect(summary, contains('Split: EQUAL ➔ CUSTOM'));

      final diffs = pendingChange.getDetailedDiffs(memberNames: {'user_a': 'User A', 'user_b': 'User B'});
      expect(diffs.length, 5);
      expect(diffs[0].label, 'Description');
      expect(diffs[0].oldValue, 'Groceries');
      expect(diffs[0].newValue, 'Groceries & Household');
      expect(diffs[1].label, 'Amount');
      expect(diffs[1].oldValue, '1000.00 ETB');
      expect(diffs[1].newValue, '1200.00 ETB');
    });

    test('Soft-deleted expense updates status and preserves history', () {
      final now = DateTime.now();
      final expense = Expense(
        id: 'exp_1',
        workspaceId: 'ws_1',
        periodId: 'period_1',
        description: 'Dinner',
        amount: 450.0,
        paidBy: 'user_a',
        createdBy: 'user_a',
        createdAt: now,
        updatedAt: now,
        status: AppConstants.expenseDeleted,
        deletedAt: now,
        deletedBy: 'user_a',
      );

      expect(expense.isActive, isFalse);
      expect(expense.isDeleted, isTrue);
      expect(expense.deletedBy, 'user_a');
      expect(expense.deletedAt, isNotNull);
    });
  });
}
