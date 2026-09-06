import 'package:splitterbuddy/core/constants/app_constants.dart';
import 'package:splitterbuddy/features/analytics/domain/models/category_breakdown.dart';
import 'package:splitterbuddy/features/analytics/domain/models/period_comparison.dart';
import 'package:splitterbuddy/features/analytics/domain/models/spending_period.dart';
import 'package:splitterbuddy/features/expenses/domain/models/expense.dart';

class SpendingSummary {
  final SpendingPeriod period;
  final double totalSpent;
  final double userContribution; // Amount paid by user
  final double partnerContribution; // Amount paid by partner / others
  final double userShare; // User's actual liability share
  final double partnerShare; // Partner's actual liability share
  final int expenseCount;
  final Expense? largestExpense;
  final CategoryBreakdown? topCategory;
  final List<CategoryBreakdown> categoryBreakdowns;
  final PeriodComparison? comparisonWithPrevious;

  const SpendingSummary({
    required this.period,
    required this.totalSpent,
    required this.userContribution,
    required this.partnerContribution,
    required this.userShare,
    required this.partnerShare,
    required this.expenseCount,
    this.largestExpense,
    this.topCategory,
    required this.categoryBreakdowns,
    this.comparisonWithPrevious,
  });
}

class MonthlyReport {
  final int year;
  final int month;
  final String monthName;
  final double totalSpending;
  final double youPaid;
  final double partnerPaid;
  final double netBalance; // positive = owed to user, negative = user owes
  final CategoryBreakdown? topCategory;
  final Expense? largestExpense;
  final PeriodComparison? comparisonWithPreviousMonth;
  final List<CategoryBreakdown> breakdowns;

  const MonthlyReport({
    required this.year,
    required this.month,
    required this.monthName,
    required this.totalSpending,
    required this.youPaid,
    required this.partnerPaid,
    required this.netBalance,
    this.topCategory,
    this.largestExpense,
    this.comparisonWithPreviousMonth,
    required this.breakdowns,
  });
}

class SpendingAnalyticsEngine {
  const SpendingAnalyticsEngine._();

  static const List<String> _monthNames = [
    'January', 'February', 'March', 'April', 'May', 'June',
    'July', 'August', 'September', 'October', 'November', 'December'
  ];

  static String getMonthName(int month) {
    if (month >= 1 && month <= 12) return _monthNames[month - 1];
    return 'Unknown';
  }

  /// Filters active (non-deleted) expenses within the specified spending period.
  static List<Expense> filterByPeriod(List<Expense> allExpenses, SpendingPeriod period) {
    return allExpenses.where((exp) => exp.isActive && period.contains(exp.createdAt)).toList();
  }

  /// Calculates the spending summary for a given period and workspace members.
  static SpendingSummary calculateSummary({
    required List<Expense> allExpenses,
    required SpendingPeriod period,
    required String currentUserId,
    required List<String> memberIds,
    SpendingPeriod? previousPeriod,
  }) {
    final periodExpenses = filterByPeriod(allExpenses, period);

    int totalCents = 0;
    int userPaidCents = 0;
    int partnerPaidCents = 0;
    int userShareCents = 0;
    int partnerShareCents = 0;

    Expense? largest;
    final Map<String, int> categoryCents = {};
    final Map<String, int> categoryCounts = {};

    for (final exp in periodExpenses) {
      final expCents = (exp.amount * 100).round();
      totalCents += expCents;

      // Track largest
      if (largest == null || exp.amount > largest.amount) {
        largest = exp;
      }

      // Track payer contributions
      if (exp.paidBy == currentUserId) {
        userPaidCents += expCents;
      } else {
        partnerPaidCents += expCents;
      }

      // Track individual liability shares
      final shares = exp.calculateShares(memberIds);
      final uShare = shares[currentUserId] ?? 0.0;
      userShareCents += (uShare * 100).round();

      for (final entry in shares.entries) {
        if (entry.key != currentUserId) {
          partnerShareCents += (entry.value * 100).round();
        }
      }

      // Track category totals
      final cat = exp.category.isNotEmpty ? exp.category : AppConstants.categoryOther;
      categoryCents[cat] = (categoryCents[cat] ?? 0) + expCents;
      categoryCounts[cat] = (categoryCounts[cat] ?? 0) + 1;
    }

    final double totalSpent = totalCents / 100.0;

    // Build category breakdowns
    final List<CategoryBreakdown> breakdowns = [];
    categoryCents.forEach((catId, cents) {
      final catTotal = cents / 100.0;
      breakdowns.add(CategoryBreakdown.fromExpenses(
        categoryId: catId,
        totalAmount: catTotal,
        overallTotal: totalSpent,
        expenseCount: categoryCounts[catId] ?? 0,
      ));
    });

    // Sort breakdowns descending by total amount
    breakdowns.sort((a, b) => b.totalAmount.compareTo(a.totalAmount));

    final topCategory = breakdowns.isNotEmpty ? breakdowns.first : null;

    // Period comparison if previous period supplied
    PeriodComparison? comparison;
    if (previousPeriod != null) {
      final prevExpenses = filterByPeriod(allExpenses, previousPeriod);
      int prevTotalCents = 0;
      for (final exp in prevExpenses) {
        prevTotalCents += (exp.amount * 100).round();
      }
      comparison = PeriodComparison.calculate(
        current: totalSpent,
        previous: prevTotalCents / 100.0,
      );
    }

    return SpendingSummary(
      period: period,
      totalSpent: totalSpent,
      userContribution: userPaidCents / 100.0,
      partnerContribution: partnerPaidCents / 100.0,
      userShare: userShareCents / 100.0,
      partnerShare: partnerShareCents / 100.0,
      expenseCount: periodExpenses.length,
      largestExpense: largest,
      topCategory: topCategory,
      categoryBreakdowns: breakdowns,
      comparisonWithPrevious: comparison,
    );
  }

  /// Generates a structured monthly report for any given year and month.
  static MonthlyReport generateMonthlyReport({
    required List<Expense> allExpenses,
    required int year,
    required int month,
    required String currentUserId,
    required List<String> memberIds,
  }) {
    final start = DateTime(year, month, 1);
    final lastDay = DateTime(year, month + 1, 0).day;
    final end = DateTime(year, month, lastDay, 23, 59, 59, 999);
    final currentPeriod = SpendingPeriod.custom(startDate: start, endDate: end, label: '${getMonthName(month)} $year');

    // Previous month period
    final prevStart = DateTime(year, month - 1, 1);
    final prevLastDay = DateTime(prevStart.year, prevStart.month + 1, 0).day;
    final prevEnd = DateTime(prevStart.year, prevStart.month, prevLastDay, 23, 59, 59, 999);
    final prevPeriod = SpendingPeriod.custom(startDate: prevStart, endDate: prevEnd);

    final summary = calculateSummary(
      allExpenses: allExpenses,
      period: currentPeriod,
      currentUserId: currentUserId,
      memberIds: memberIds,
      previousPeriod: prevPeriod,
    );

    final netBalance = summary.userContribution - summary.userShare;

    return MonthlyReport(
      year: year,
      month: month,
      monthName: getMonthName(month),
      totalSpending: summary.totalSpent,
      youPaid: summary.userContribution,
      partnerPaid: summary.partnerContribution,
      netBalance: double.parse(netBalance.toStringAsFixed(2)),
      topCategory: summary.topCategory,
      largestExpense: summary.largestExpense,
      comparisonWithPreviousMonth: summary.comparisonWithPrevious,
      breakdowns: summary.categoryBreakdowns,
    );
  }
}
