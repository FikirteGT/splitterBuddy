import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:splitterbuddy/core/constants/app_colors.dart';
import 'package:splitterbuddy/core/utils/currency_formatter.dart';
import 'package:splitterbuddy/features/analytics/domain/models/spending_period.dart';
import 'package:splitterbuddy/features/analytics/presentation/controllers/analytics_controller.dart';
import 'package:splitterbuddy/features/authentication/presentation/controllers/auth_controller.dart';
import 'package:splitterbuddy/features/budgets/presentation/screens/budgets_screen.dart';
import 'package:splitterbuddy/features/expenses/presentation/controllers/expense_controller.dart';
import 'package:splitterbuddy/features/export/presentation/screens/export_screen.dart';
import 'package:splitterbuddy/features/workspace/presentation/controllers/workspace_controller.dart';

class AnalyticsScreen extends StatelessWidget {
  const AnalyticsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final analytics = context.watch<AnalyticsController>();
    final expController = context.watch<ExpenseController>();
    final wsController = context.watch<WorkspaceController>();
    final auth = context.watch<AuthController>();

    final currentWs = wsController.currentWorkspace;
    if (currentWs == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Analytics')),
        body: const Center(child: Text('No active workspace selected')),
      );
    }

    final allExpenses = expController.activeExpenses;
    final memberIds = currentWs.members;
    final partnerName = currentWs.getPartnerName(auth.uid);

    final summary = analytics.getSummary(
      allExpenses: allExpenses,
      currentUserId: auth.uid,
      memberIds: memberIds,
    );

    final insights = analytics.getInsights(
      allExpenses: allExpenses,
      currentUserId: auth.uid,
      memberIds: memberIds,
    );

    return Scaffold(
      appBar: AppBar(
        title: const Text('Financial Analytics'),
        actions: [
          IconButton(
            icon: const Icon(Icons.account_balance_wallet_outlined),
            tooltip: 'Budgets',
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const BudgetsScreen()),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.file_download_outlined),
            tooltip: 'Export CSV',
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const ExportScreen()),
              );
            },
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        children: [
          // Period Selector Chips
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _buildPeriodChip(
                  context: context,
                  label: 'This Month',
                  type: SpendingPeriodType.thisMonth,
                  isSelected: analytics.currentPeriod.type == SpendingPeriodType.thisMonth,
                  onSelected: () => analytics.setPeriodType(SpendingPeriodType.thisMonth),
                ),
                const SizedBox(width: 8),
                _buildPeriodChip(
                  context: context,
                  label: 'This Week',
                  type: SpendingPeriodType.thisWeek,
                  isSelected: analytics.currentPeriod.type == SpendingPeriodType.thisWeek,
                  onSelected: () => analytics.setPeriodType(SpendingPeriodType.thisWeek),
                ),
                const SizedBox(width: 8),
                _buildPeriodChip(
                  context: context,
                  label: 'Last Month',
                  type: SpendingPeriodType.lastMonth,
                  isSelected: analytics.currentPeriod.type == SpendingPeriodType.lastMonth,
                  onSelected: () => analytics.setPeriodType(SpendingPeriodType.lastMonth),
                ),
                const SizedBox(width: 8),
                ActionChip(
                  label: Text(
                    analytics.currentPeriod.type == SpendingPeriodType.custom
                        ? analytics.currentPeriod.label
                        : 'Custom...',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: analytics.currentPeriod.type == SpendingPeriodType.custom
                          ? Colors.white
                          : AppColors.textSecondary,
                    ),
                  ),
                  backgroundColor: analytics.currentPeriod.type == SpendingPeriodType.custom
                      ? AppColors.primary
                      : AppColors.surface,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20),
                    side: BorderSide(
                      color: analytics.currentPeriod.type == SpendingPeriodType.custom
                          ? AppColors.primary
                          : AppColors.cardBorder,
                    ),
                  ),
                  onPressed: () async {
                    final picked = await showDateRangePicker(
                      context: context,
                      firstDate: DateTime.now().subtract(const Duration(days: 730)),
                      lastDate: DateTime.now().add(const Duration(days: 30)),
                      initialDateRange: DateTimeRange(
                        start: analytics.currentPeriod.startDate,
                        end: analytics.currentPeriod.endDate,
                      ),
                    );
                    if (picked != null) {
                      analytics.setCustomPeriod(picked.start, picked.end);
                    }
                  },
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),

          // Total Spent Banner Card
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  AppColors.surfaceElevated,
                  AppColors.surface,
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: AppColors.cardBorder),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      analytics.currentPeriod.label.toUpperCase(),
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textMuted,
                        letterSpacing: 1.1,
                      ),
                    ),
                    if (summary.comparisonWithPrevious != null &&
                        !summary.comparisonWithPrevious!.isUnchanged)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: (summary.comparisonWithPrevious!.hasIncreased
                                  ? AppColors.error
                                  : AppColors.success)
                              .withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              summary.comparisonWithPrevious!.hasIncreased
                                  ? Icons.trending_up_rounded
                                  : Icons.trending_down_rounded,
                              size: 14,
                              color: summary.comparisonWithPrevious!.hasIncreased
                                  ? AppColors.error
                                  : AppColors.success,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              '${summary.comparisonWithPrevious!.percentageChange > 0 ? '+' : ''}${summary.comparisonWithPrevious!.percentageChange.toStringAsFixed(1)}%',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                                color: summary.comparisonWithPrevious!.hasIncreased
                                    ? AppColors.error
                                    : AppColors.success,
                              ),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  CurrencyFormatter.format(summary.totalSpent),
                  style: const TextStyle(
                    fontSize: 32,
                    fontWeight: FontWeight.w900,
                    color: AppColors.textPrimary,
                    letterSpacing: -1,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '${summary.expenseCount} shared expenses in this period',
                  style: const TextStyle(fontSize: 13, color: AppColors.textMuted),
                ),
                const Divider(height: 24, color: AppColors.cardBorder),
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('You Paid', style: TextStyle(fontSize: 12, color: AppColors.textMuted)),
                          const SizedBox(height: 2),
                          Text(
                            CurrencyFormatter.format(summary.userContribution),
                            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: AppColors.primaryLight),
                          ),
                        ],
                      ),
                    ),
                    Container(height: 30, width: 1, color: AppColors.cardBorder),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('$partnerName Paid', style: const TextStyle(fontSize: 12, color: AppColors.textMuted)),
                          const SizedBox(height: 2),
                          Text(
                            CurrencyFormatter.format(summary.partnerContribution),
                            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: AppColors.secondaryLight),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // Quick Highlights (Largest & Top Category)
          if (summary.largestExpense != null || summary.topCategory != null) ...[
            Row(
              children: [
                if (summary.topCategory != null)
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: AppColors.surface,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: AppColors.cardBorder),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(summary.topCategory!.icon, size: 16, color: summary.topCategory!.color),
                              const SizedBox(width: 6),
                              const Text('Top Category', style: TextStyle(fontSize: 11, color: AppColors.textMuted)),
                            ],
                          ),
                          const SizedBox(height: 6),
                          Text(
                            summary.topCategory!.categoryName,
                            style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: AppColors.textPrimary),
                          ),
                          Text(
                            '${CurrencyFormatter.format(summary.topCategory!.totalAmount)} (${summary.topCategory!.percentage}%)',
                            style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                          ),
                        ],
                      ),
                    ),
                  ),
                if (summary.largestExpense != null && summary.topCategory != null)
                  const SizedBox(width: 12),
                if (summary.largestExpense != null)
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: AppColors.surface,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: AppColors.cardBorder),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: const [
                              Icon(Icons.star_outline_rounded, size: 16, color: Color(0xFFF59E0B)),
                              SizedBox(width: 6),
                              Text('Largest Expense', style: TextStyle(fontSize: 11, color: AppColors.textMuted)),
                            ],
                          ),
                          const SizedBox(height: 6),
                          Text(
                            summary.largestExpense!.description,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: AppColors.textPrimary),
                          ),
                          Text(
                            CurrencyFormatter.format(summary.largestExpense!.amount),
                            style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 24),
          ],

          // Category Breakdown Section
          const Text(
            'SPENDING BY CATEGORY',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: AppColors.textMuted,
              letterSpacing: 1.1,
            ),
          ),
          const SizedBox(height: 12),

          if (summary.categoryBreakdowns.isEmpty)
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppColors.cardBorder),
              ),
              child: const Center(
                child: Text('No categorized spending in this period', style: TextStyle(color: AppColors.textMuted)),
              ),
            )
          else
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppColors.cardBorder),
              ),
              child: Column(
                children: summary.categoryBreakdowns.map((breakdown) {
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 14),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(6),
                              decoration: BoxDecoration(
                                color: breakdown.color.withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Icon(breakdown.icon, size: 16, color: breakdown.color),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                breakdown.categoryName,
                                style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.textPrimary),
                              ),
                            ),
                            Text(
                              CurrencyFormatter.format(breakdown.totalAmount),
                              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: AppColors.textPrimary),
                            ),
                            const SizedBox(width: 8),
                            SizedBox(
                              width: 45,
                              child: Text(
                                '${breakdown.percentage}%',
                                textAlign: TextAlign.right,
                                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.textMuted),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(4),
                          child: LinearProgressIndicator(
                            value: breakdown.percentage / 100.0,
                            backgroundColor: AppColors.surfaceElevated,
                            valueColor: AlwaysStoppedAnimation<Color>(breakdown.color),
                            minHeight: 6,
                          ),
                        ),
                      ],
                    ),
                  );
                }).toList(),
              ),
            ),
          const SizedBox(height: 24),

          // Financial Insights Section
          if (insights.isNotEmpty) ...[
            const Text(
              'FINANCIAL INSIGHTS',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: AppColors.textMuted,
                letterSpacing: 1.1,
              ),
            ),
            const SizedBox(height: 12),
            ...insights.map((insight) {
              return Card(
                margin: const EdgeInsets.only(bottom: 10),
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: insight.color.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Icon(insight.icon, color: insight.color, size: 20),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              insight.title,
                              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: AppColors.textPrimary),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              insight.message,
                              style: const TextStyle(fontSize: 12, color: AppColors.textSecondary, height: 1.3),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }),
            const SizedBox(height: 16),
          ],

          // Monthly Summary Generator Card
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  AppColors.primaryDark.withValues(alpha: 0.3),
                  AppColors.surfaceElevated,
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: AppColors.primary.withValues(alpha: 0.3)),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.summarize_rounded, color: AppColors.primaryLight, size: 24),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: const [
                      Text('Monthly Summary Report', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
                      SizedBox(height: 2),
                      Text('View complete monthly breakdown and trends.', style: TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                    ],
                  ),
                ),
                ElevatedButton(
                  onPressed: () => _showMonthlyReportDialog(context, analytics, allExpenses, auth.uid, memberIds),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  ),
                  child: const Text('View', style: TextStyle(fontWeight: FontWeight.w700)),
                ),
              ],
            ),
          ),
          const SizedBox(height: 40),
        ],
      ),
    );
  }

  Widget _buildPeriodChip({
    required BuildContext context,
    required String label,
    required SpendingPeriodType type,
    required bool isSelected,
    required VoidCallback onSelected,
  }) {
    return ChoiceChip(
      label: Text(label),
      selected: isSelected,
      onSelected: (_) => onSelected(),
      selectedColor: AppColors.primary,
      backgroundColor: AppColors.surface,
      labelStyle: TextStyle(
        fontSize: 12,
        fontWeight: FontWeight.w600,
        color: isSelected ? Colors.white : AppColors.textSecondary,
      ),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(color: isSelected ? AppColors.primary : AppColors.cardBorder),
      ),
    );
  }

  void _showMonthlyReportDialog(
    BuildContext context,
    AnalyticsController analytics,
    List<dynamic> allExpenses,
    String currentUserId,
    List<String> memberIds,
  ) {
    final now = DateTime.now();
    final report = analytics.getMonthlyReport(
      allExpenses: allExpenses.cast(),
      year: now.year,
      month: now.month,
      currentUserId: currentUserId,
      memberIds: memberIds,
    );

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) {
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(color: AppColors.cardBorder, borderRadius: BorderRadius.circular(2)),
                ),
              ),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    '${report.monthName.toUpperCase()} ${report.year}',
                    style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: AppColors.textPrimary),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Text('Monthly Summary', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.primaryLight)),
                  ),
                ],
              ),
              const Divider(height: 24, color: AppColors.cardBorder),
              _buildReportRow('Total Spending', CurrencyFormatter.format(report.totalSpending), isBold: true),
              _buildReportRow('You Paid', CurrencyFormatter.format(report.youPaid)),
              _buildReportRow('Partner Paid', CurrencyFormatter.format(report.partnerPaid)),
              _buildReportRow(
                'Net Balance',
                report.netBalance >= 0
                    ? '+${CurrencyFormatter.format(report.netBalance)} (owed to you)'
                    : '-${CurrencyFormatter.format(report.netBalance.abs())} (you owe)',
                valueColor: report.netBalance >= 0 ? AppColors.success : AppColors.error,
              ),
              if (report.topCategory != null)
                _buildReportRow('Top Category', '${report.topCategory!.categoryName} (${CurrencyFormatter.format(report.topCategory!.totalAmount)})'),
              if (report.largestExpense != null)
                _buildReportRow('Largest Expense', '${report.largestExpense!.description} (${CurrencyFormatter.format(report.largestExpense!.amount)})'),
              if (report.comparisonWithPreviousMonth != null && !report.comparisonWithPreviousMonth!.isUnchanged)
                _buildReportRow(
                  'vs Previous Month',
                  '${report.comparisonWithPreviousMonth!.percentageChange > 0 ? '+' : ''}${report.comparisonWithPreviousMonth!.percentageChange}%',
                  valueColor: report.comparisonWithPreviousMonth!.hasIncreased ? AppColors.error : AppColors.success,
                ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () => Navigator.of(ctx).pop(),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.surfaceElevated,
                    foregroundColor: AppColors.textPrimary,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                  child: const Text('Close'),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildReportRow(String title, String value, {bool isBold = false, Color? valueColor}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(title, style: TextStyle(fontSize: 14, color: isBold ? AppColors.textPrimary : AppColors.textSecondary, fontWeight: isBold ? FontWeight.w700 : FontWeight.normal)),
          Text(
            value,
            style: TextStyle(
              fontSize: 14,
              fontWeight: isBold ? FontWeight.w800 : FontWeight.w600,
              color: valueColor ?? AppColors.textPrimary,
            ),
          ),
        ],
      ),
    );
  }
}
