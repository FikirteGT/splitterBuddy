import 'package:flutter/material.dart';
import '../../../core/utils/currency_formatter.dart';
import '../../expenses/domain/models/expense.dart';
import 'spending_analytics_engine.dart';

class FinancialInsight {
  final String title;
  final String message;
  final IconData icon;
  final Color color;

  const FinancialInsight({
    required this.title,
    required this.message,
    required this.icon,
    required this.color,
  });
}

class FinancialInsightsEngine {
  const FinancialInsightsEngine._();

  /// Generates pure, deterministic rule-based insights based on stored data.
  /// Never fabricates insights when data is insufficient.
  static List<FinancialInsight> generateInsights({
    required SpendingSummary currentSummary,
    SpendingSummary? previousSummary,
    List<Expense>? allExpenses,
  }) {
    final List<FinancialInsight> insights = [];

    // Rule 1: No expenses in period
    if (currentSummary.expenseCount == 0) {
      return insights;
    }

    // Rule 2: Top category dominance (> 30% of spending)
    final topCat = currentSummary.topCategory;
    if (topCat != null && currentSummary.totalSpent > 0) {
      if (topCat.percentage >= 30.0) {
        insights.add(FinancialInsight(
          title: 'Top Category Dominance',
          message: '${topCat.categoryName} is your largest shared expense category, accounting for ${topCat.percentage.toStringAsFixed(1)}% of your spending.',
          icon: topCat.icon,
          color: topCat.color,
        ));
      } else {
        insights.add(FinancialInsight(
          title: 'Highest Spending Area',
          message: '${topCat.categoryName} is your top expense category (${CurrencyFormatter.format(topCat.totalAmount)}).',
          icon: topCat.icon,
          color: topCat.color,
        ));
      }
    }

    // Rule 3: Month-over-month overall spending comparison
    if (previousSummary != null && previousSummary.totalSpent > 0 && currentSummary.totalSpent > 0) {
      final diff = currentSummary.totalSpent - previousSummary.totalSpent;
      final absDiff = diff.abs();
      final pct = ((diff) / previousSummary.totalSpent) * 100.0;
      final formattedDiff = CurrencyFormatter.format(absDiff);

      if (diff > 0.01) {
        insights.add(FinancialInsight(
          title: 'Spending Increased',
          message: 'You have spent $formattedDiff (${pct.toStringAsFixed(1)}%) more than last month.',
          icon: Icons.trending_up_rounded,
          color: const Color(0xFFEF4444),
        ));
      } else if (diff < -0.01) {
        insights.add(FinancialInsight(
          title: 'Spending Decreased',
          message: 'You have spent $formattedDiff (${pct.abs().toStringAsFixed(1)}%) less than last month.',
          icon: Icons.trending_down_rounded,
          color: const Color(0xFF10B981),
        ));
      }
    }

    // Rule 4: Largest single expense proportion (> 40% of total)
    final largest = currentSummary.largestExpense;
    if (largest != null && currentSummary.totalSpent > 0) {
      final largestPct = (largest.amount / currentSummary.totalSpent) * 100.0;
      if (largestPct >= 40.0 && currentSummary.expenseCount > 1) {
        insights.add(FinancialInsight(
          title: 'Major Single Expense',
          message: '"${largest.description}" (${CurrencyFormatter.format(largest.amount)}) represents ${largestPct.toStringAsFixed(0)}% of your total period spending.',
          icon: Icons.priority_high_rounded,
          color: const Color(0xFFF59E0B),
        ));
      }
    }

    // Rule 5: Specific category increase comparison (if category exists in both periods)
    if (previousSummary != null && topCat != null) {
      final prevCat = previousSummary.categoryBreakdowns
          .where((b) => b.categoryId == topCat.categoryId)
          .firstOrNull;
      if (prevCat != null && prevCat.totalAmount > 0) {
        final catDiff = topCat.totalAmount - prevCat.totalAmount;
        final catPct = (catDiff / prevCat.totalAmount) * 100.0;
        if (catPct >= 15.0) {
          insights.add(FinancialInsight(
            title: '${topCat.categoryName} Growth',
            message: 'You spent ${catPct.toStringAsFixed(0)}% more on ${topCat.categoryName} compared to last period.',
            icon: Icons.arrow_upward_rounded,
            color: const Color(0xFFEC4899),
          ));
        }
      }
    }

    // Rule 6: Contribution balance
    if (currentSummary.totalSpent > 0 && currentSummary.expenseCount >= 2) {
      final userPct = (currentSummary.userContribution / currentSummary.totalSpent) * 100.0;
      if (userPct >= 70.0) {
        insights.add(FinancialInsight(
          title: 'High Upfront Contribution',
          message: 'You paid ${userPct.toStringAsFixed(0)}% of upfront expenses this period.',
          icon: Icons.account_balance_wallet_outlined,
          color: const Color(0xFF6366F1),
        ));
      }
    }

    return insights;
  }
}
