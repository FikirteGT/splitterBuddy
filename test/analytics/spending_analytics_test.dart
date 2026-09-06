import 'package:flutter_test/flutter_test.dart';
import 'package:splitterbuddy/core/constants/app_constants.dart';
import 'package:splitterbuddy/features/analytics/domain/models/period_comparison.dart';
import 'package:splitterbuddy/features/analytics/domain/models/spending_period.dart';
import 'package:splitterbuddy/features/analytics/services/financial_insights_engine.dart';
import 'package:splitterbuddy/features/analytics/services/spending_analytics_engine.dart';
import 'package:splitterbuddy/features/expenses/domain/models/expense.dart';

void main() {
  group('SpendingPeriod Tests', () {
    test('SpendingPeriod thisMonth creates correct bounds for September 2026', () {
      final septDate = DateTime(2026, 9, 15, 14, 30);
      final period = SpendingPeriod.thisMonth(septDate);

      expect(period.type, SpendingPeriodType.thisMonth);
      expect(period.startDate, DateTime(2026, 9, 1));
      expect(period.endDate, DateTime(2026, 9, 30, 23, 59, 59, 999));
      expect(period.contains(DateTime(2026, 9, 15)), isTrue);
      expect(period.contains(DateTime(2026, 10, 1)), isFalse);
    });

    test('SpendingPeriod lastMonth bounds from September 2026 produces August 2026', () {
      final septDate = DateTime(2026, 9, 15);
      final period = SpendingPeriod.lastMonth(septDate);

      expect(period.type, SpendingPeriodType.lastMonth);
      expect(period.startDate, DateTime(2026, 8, 1));
      expect(period.endDate, DateTime(2026, 8, 31, 23, 59, 59, 999));
    });

    test('PeriodComparison calculates increase and decrease percentages accurately', () {
      // August 4500 -> September 5200 (+15.6%)
      final comp1 = PeriodComparison.calculate(current: 5200.0, previous: 4500.0);
      expect(comp1.hasIncreased, isTrue);
      expect(comp1.percentageChange, 15.6);
      expect(comp1.absoluteDifference, 700.0);

      // Current 3000 -> Previous 4000 (-25.0%)
      final comp2 = PeriodComparison.calculate(current: 3000.0, previous: 4000.0);
      expect(comp2.hasIncreased, isFalse);
      expect(comp2.percentageChange, -25.0);
      expect(comp2.absoluteDifference, 1000.0);
    });
  });

  group('SpendingAnalyticsEngine Tests', () {
    final now = DateTime(2026, 9, 15);
    final period = SpendingPeriod.thisMonth(now);

    final expenses = [
      Expense(
        id: 'exp1',
        workspaceId: 'ws1',
        periodId: 'p1',
        description: 'Groceries',
        amount: 1200.0,
        paidBy: 'userA',
        createdBy: 'userA',
        category: AppConstants.categoryFood,
        createdAt: DateTime(2026, 9, 5),
        updatedAt: DateTime(2026, 9, 5),
      ),
      Expense(
        id: 'exp2',
        workspaceId: 'ws1',
        periodId: 'p1',
        description: 'House Rent',
        amount: 1500.0,
        paidBy: 'userB',
        createdBy: 'userB',
        category: AppConstants.categoryRent,
        createdAt: DateTime(2026, 9, 8),
        updatedAt: DateTime(2026, 9, 8),
      ),
      Expense(
        id: 'exp3',
        workspaceId: 'ws1',
        periodId: 'p1',
        description: 'Taxi Ride',
        amount: 300.0,
        paidBy: 'userA',
        createdBy: 'userA',
        category: AppConstants.categoryTransportation,
        createdAt: DateTime(2026, 9, 10),
        updatedAt: DateTime(2026, 9, 10),
      ),
    ];

    test('calculateSummary computes totals, contributions, and top category', () {
      final summary = SpendingAnalyticsEngine.calculateSummary(
        allExpenses: expenses,
        period: period,
        currentUserId: 'userA',
        memberIds: ['userA', 'userB'],
      );

      expect(summary.totalSpent, 3000.0);
      expect(summary.userContribution, 1500.0); // 1200 + 300
      expect(summary.partnerContribution, 1500.0); // 1500
      expect(summary.expenseCount, 3);
      expect(summary.largestExpense?.id, 'exp2'); // Rent (1500)
      expect(summary.topCategory?.categoryId, AppConstants.categoryRent);
      expect(summary.topCategory?.totalAmount, 1500.0);
      expect(summary.topCategory?.percentage, 50.0); // 1500 / 3000 = 50%
    });

    test('generateMonthlyReport produces deterministic report', () {
      final report = SpendingAnalyticsEngine.generateMonthlyReport(
        allExpenses: expenses,
        year: 2026,
        month: 9,
        currentUserId: 'userA',
        memberIds: ['userA', 'userB'],
      );

      expect(report.monthName, 'September');
      expect(report.year, 2026);
      expect(report.totalSpending, 3000.0);
      expect(report.youPaid, 1500.0);
      expect(report.partnerPaid, 1500.0);
      expect(report.netBalance, 0.0);
    });

    test('FinancialInsightsEngine generates rule-based insights without fabricating data', () {
      final summary = SpendingAnalyticsEngine.calculateSummary(
        allExpenses: expenses,
        period: period,
        currentUserId: 'userA',
        memberIds: ['userA', 'userB'],
      );

      final insights = FinancialInsightsEngine.generateInsights(currentSummary: summary);
      expect(insights.isNotEmpty, isTrue);
      expect(insights.any((i) => i.title.contains('Top Category Dominance') || i.title.contains('Major Single Expense')), isTrue);
    });
  });
}
