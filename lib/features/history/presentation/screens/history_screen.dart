import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:splitterbuddy/core/constants/app_colors.dart';
import 'package:splitterbuddy/core/constants/app_constants.dart';
import 'package:splitterbuddy/core/utils/currency_formatter.dart';
import 'package:splitterbuddy/core/utils/date_formatter.dart';
import 'package:splitterbuddy/features/history/presentation/controllers/history_controller.dart';
import 'package:splitterbuddy/features/history/domain/models/activity_log.dart';
import 'package:splitterbuddy/shared/widgets/empty_state_view.dart';

class HistoryScreen extends StatelessWidget {
  const HistoryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final historyController = context.watch<HistoryController>();
    final logs = historyController.activityLogs;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Activity History'),
      ),
      body: logs.isEmpty
          ? const EmptyStateView(
              icon: Icons.history_rounded,
              title: 'Your activity will appear here',
              subtitle: 'Every expense added, edited, or settled in this workspace will be recorded in this chronological log.',
            )
          : ListView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              itemCount: logs.length,
              itemBuilder: (ctx, index) {
                final log = logs[index];
                return _buildActivityItem(log);
              },
            ),
    );
  }

  Widget _buildActivityItem(ActivityLog log) {
    IconData icon;
    Color iconColor;
    Color iconBg;
    String actionTitle;
    String? subDetails;

    final amountStr = log.amount != null ? CurrencyFormatter.format(log.amount!) : null;
    final prevAmountStr = log.previousAmount != null ? CurrencyFormatter.format(log.previousAmount!) : null;
    final paidByStr = log.paidByName != null && log.paidByName!.isNotEmpty
        ? 'Paid by ${log.paidByName}'
        : null;

    switch (log.action) {
      case AppConstants.actionAdded:
        icon = Icons.add_circle_outline_rounded;
        iconColor = AppColors.primary;
        iconBg = AppColors.badgeGreenBg;
        actionTitle = '${log.actorName} added "${log.expenseDescription ?? 'Expense'}"';
        final details = <String>[];
        if (amountStr != null) details.add(amountStr);
        if (paidByStr != null) details.add(paidByStr);
        subDetails = details.isNotEmpty ? details.join(' • ') : null;
        break;

      case AppConstants.actionEdited:
        icon = Icons.edit_outlined;
        iconColor = AppColors.info;
        iconBg = AppColors.badgeBlueBg;
        actionTitle = '${log.actorName} updated "${log.expenseDescription ?? 'Expense'}"';
        final details = <String>[];
        if (prevAmountStr != null && amountStr != null && prevAmountStr != amountStr) {
          details.add('$prevAmountStr → $amountStr');
        } else if (amountStr != null) {
          details.add(amountStr);
        }
        if (paidByStr != null) details.add(paidByStr);
        subDetails = details.isNotEmpty ? details.join(' • ') : null;
        break;

      case AppConstants.actionProposedEdit:
        icon = Icons.rule_folder_outlined;
        iconColor = AppColors.warning;
        iconBg = AppColors.badgeAmberBg;
        actionTitle = '${log.actorName} requested edit on "${log.expenseDescription ?? 'Expense'}"';
        final details = <String>[];
        if (prevAmountStr != null && amountStr != null && prevAmountStr != amountStr) {
          details.add('Proposed: $prevAmountStr → $amountStr');
        } else if (amountStr != null) {
          details.add('Proposed: $amountStr');
        }
        if (paidByStr != null) details.add(paidByStr);
        subDetails = details.isNotEmpty ? details.join(' • ') : null;
        break;

      case AppConstants.actionApprovedEdit:
        icon = Icons.check_circle_outline_rounded;
        iconColor = AppColors.success;
        iconBg = AppColors.badgeGreenBg;
        actionTitle = '${log.actorName} approved edit on "${log.expenseDescription ?? 'Expense'}"';
        final details = <String>[];
        if (amountStr != null) details.add(amountStr);
        if (paidByStr != null) details.add(paidByStr);
        subDetails = details.isNotEmpty ? details.join(' • ') : null;
        break;

      case AppConstants.actionRejectedEdit:
        icon = Icons.cancel_outlined;
        iconColor = AppColors.error;
        iconBg = AppColors.badgeRedBg;
        actionTitle = '${log.actorName} declined proposed edit on "${log.expenseDescription ?? 'Expense'}"';
        if (amountStr != null) subDetails = amountStr;
        break;

      case AppConstants.actionDeleted:
        icon = Icons.delete_outline_rounded;
        iconColor = AppColors.error;
        iconBg = AppColors.badgeRedBg;
        actionTitle = '${log.actorName} deleted "${log.expenseDescription ?? 'Expense'}"';
        if (amountStr != null) subDetails = amountStr;
        break;

      case AppConstants.actionSettled:
        icon = Icons.handshake_rounded;
        iconColor = AppColors.primaryLight;
        iconBg = AppColors.badgeGreenBg;
        actionTitle = '${log.actorName} settled the balance';
        if (amountStr != null) subDetails = 'Settled amount: $amountStr';
        break;

      default:
        icon = Icons.info_outline_rounded;
        iconColor = AppColors.textSecondary;
        iconBg = AppColors.surfaceElevated;
        actionTitle = '${log.actorName} updated "${log.expenseDescription ?? 'workspace'}"';
        break;
    }

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: iconBg,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: iconColor, size: 20),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    actionTitle,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textPrimary,
                      height: 1.3,
                    ),
                  ),
                  if (subDetails != null) ...[
                    const SizedBox(height: 4),
                    Text(
                      subDetails,
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                        color: AppColors.primaryLight,
                      ),
                    ),
                  ],
                  const SizedBox(height: 4),
                  Text(
                    DateFormatter.formatRelative(log.timestamp),
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppColors.textMuted,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
