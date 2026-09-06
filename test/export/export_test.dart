import 'package:flutter_test/flutter_test.dart';
import 'package:splitterbuddy/core/constants/app_constants.dart';
import 'package:splitterbuddy/features/expenses/domain/models/expense.dart';
import 'package:splitterbuddy/features/export/services/export_service.dart';
import 'package:splitterbuddy/features/workspace/domain/models/workspace.dart';

void main() {
  group('ExportService Tests', () {
    final workspace = Workspace(
      id: 'ws1',
      name: 'Test Apartment',
      inviteCode: 'ABC123',
      ownerId: 'userA',
      memberIds: ['userA', 'userB'],
      memberNames: {'userA': 'Fikrte', 'userB': 'Yeabsira'},
      activePeriodId: 'period1',
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );

    final expenses = [
      Expense(
        id: 'exp1',
        workspaceId: 'ws1',
        periodId: 'period1',
        description: 'Groceries Dinner',
        amount: 1000.0,
        paidBy: 'userA',
        createdBy: 'userA',
        category: AppConstants.categoryFood,
        createdAt: DateTime(2026, 9, 1),
        updatedAt: DateTime(2026, 9, 1),
      ),
    ];

    test('generateExpensesCsv generates valid CSV header and rows', () {
      final csv = ExportService.generateExpensesCsv(
        workspace: workspace,
        currentUserId: 'userA',
        expenses: expenses,
        memberNames: {'userA': 'Fikrte', 'userB': 'Yeabsira'},
      );

      expect(csv.contains('Date,Description,Category,Amount (ETB)'), isTrue);
      expect(csv.contains('Groceries Dinner'), isTrue);
      expect(csv.contains('1000.00'), isTrue);
      expect(csv.contains('Fikrte'), isTrue);
    });

    test('generateExpensesCsv rejects unauthorized non-members', () {
      expect(
        () => ExportService.generateExpensesCsv(
          workspace: workspace,
          currentUserId: 'unauthorized_stranger',
          expenses: expenses,
          memberNames: {},
        ),
        throwsA(isA<Exception>()),
      );
    });

    test('generateTextSummary formats report summary correctly', () {
      final text = ExportService.generateTextSummary(
        workspace: workspace,
        periodLabel: 'September 2026',
        totalSpending: 1000.0,
        userPaid: 1000.0,
        partnerPaid: 0.0,
        balance: 500.0,
        partnerName: 'Yeabsira',
      );

      expect(text.contains('SPLITTERBUD FINANCIAL REPORT'), isTrue);
      expect(text.contains('Total Spending: 1,000 ETB'), isTrue);
      expect(text.contains('Yeabsira owes you 500 ETB'), isTrue);
    });
  });
}
