import 'package:flutter/foundation.dart';
import 'package:splitterbuddy/features/analytics/domain/models/spending_period.dart';
import 'package:splitterbuddy/features/analytics/services/financial_insights_engine.dart';
import 'package:splitterbuddy/features/analytics/services/spending_analytics_engine.dart';
import 'package:splitterbuddy/features/expenses/domain/models/expense.dart';

class AnalyticsController extends ChangeNotifier {
  SpendingPeriod _currentPeriod = SpendingPeriod.thisMonth();
  SpendingPeriod _previousPeriod = SpendingPeriod.lastMonth();

  SpendingPeriod get currentPeriod => _currentPeriod;
  SpendingPeriod get previousPeriod => _previousPeriod;

  void setPeriodType(SpendingPeriodType type) {
    final now = DateTime.now();
    switch (type) {
      case SpendingPeriodType.thisWeek:
        _currentPeriod = SpendingPeriod.thisWeek(now);
        // Previous week for comparison
        final prevWeekDate = now.subtract(const Duration(days: 7));
        _previousPeriod = SpendingPeriod.thisWeek(prevWeekDate);
        break;
      case SpendingPeriodType.thisMonth:
        _currentPeriod = SpendingPeriod.thisMonth(now);
        _previousPeriod = SpendingPeriod.lastMonth(now);
        break;
      case SpendingPeriodType.lastMonth:
        _currentPeriod = SpendingPeriod.lastMonth(now);
        // 2 months ago for comparison
        final twoMonthsAgo = DateTime(now.year, now.month - 2, 1);
        final lastDay = DateTime(twoMonthsAgo.year, twoMonthsAgo.month + 1, 0).day;
        _previousPeriod = SpendingPeriod.custom(
          startDate: twoMonthsAgo,
          endDate: DateTime(twoMonthsAgo.year, twoMonthsAgo.month, lastDay, 23, 59, 59),
        );
        break;
      case SpendingPeriodType.custom:
        break;
    }
    notifyListeners();
  }

  void setCustomPeriod(DateTime start, DateTime end) {
    _currentPeriod = SpendingPeriod.custom(
      startDate: start,
      endDate: end,
      label: 'Custom Period',
    );
    final duration = end.difference(start);
    _previousPeriod = SpendingPeriod.custom(
      startDate: start.subtract(duration),
      endDate: start.subtract(const Duration(milliseconds: 1)),
      label: 'Prior Period',
    );
    notifyListeners();
  }

  SpendingSummary getSummary({
    required List<Expense> allExpenses,
    required String currentUserId,
    required List<String> memberIds,
  }) {
    return SpendingAnalyticsEngine.calculateSummary(
      allExpenses: allExpenses,
      period: _currentPeriod,
      currentUserId: currentUserId,
      memberIds: memberIds,
      previousPeriod: _previousPeriod,
    );
  }

  List<FinancialInsight> getInsights({
    required List<Expense> allExpenses,
    required String currentUserId,
    required List<String> memberIds,
  }) {
    final currentSummary = getSummary(
      allExpenses: allExpenses,
      currentUserId: currentUserId,
      memberIds: memberIds,
    );

    final previousSummary = SpendingAnalyticsEngine.calculateSummary(
      allExpenses: allExpenses,
      period: _previousPeriod,
      currentUserId: currentUserId,
      memberIds: memberIds,
    );

    return FinancialInsightsEngine.generateInsights(
      currentSummary: currentSummary,
      previousSummary: previousSummary,
      allExpenses: allExpenses,
    );
  }

  MonthlyReport getMonthlyReport({
    required List<Expense> allExpenses,
    required int year,
    required int month,
    required String currentUserId,
    required List<String> memberIds,
  }) {
    return SpendingAnalyticsEngine.generateMonthlyReport(
      allExpenses: allExpenses,
      year: year,
      month: month,
      currentUserId: currentUserId,
      memberIds: memberIds,
    );
  }
}
