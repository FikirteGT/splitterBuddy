import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:splitterbuddy/core/constants/app_colors.dart';
import 'package:splitterbuddy/core/utils/date_formatter.dart';
import 'package:splitterbuddy/features/authentication/presentation/controllers/auth_controller.dart';
import 'package:splitterbuddy/features/expenses/presentation/controllers/expense_controller.dart';
import 'package:splitterbuddy/features/notifications/domain/models/app_notification.dart';
import 'package:splitterbuddy/features/workspace/presentation/controllers/workspace_controller.dart';
import 'package:splitterbuddy/shared/widgets/custom_button.dart';
import 'package:splitterbuddy/shared/widgets/empty_state_view.dart';

class NotificationsScreen extends StatelessWidget {
  const NotificationsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final notifController = context.watch<NotificationController>();
    final notifications = notifController.notifications;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Notifications'),
        actions: [
          if (notifController.hasUnread)
            TextButton(
              onPressed: () => notifController.markAllAsRead(),
              child: const Text('Mark all read'),
            ),
        ],
      ),
      body: notifications.isEmpty
          ? const EmptyStateView(
              icon: Icons.notifications_none_rounded,
              title: "You're all caught up",
              subtitle: 'New shared expenses, edit requests, and settlement updates will appear here.',
            )
          : ListView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              itemCount: notifications.length,
              itemBuilder: (ctx, index) {
                final notif = notifications[index];
                return _NotificationCard(notification: notif);
              },
            ),
    );
  }
}

class _NotificationCard extends StatefulWidget {
  final AppNotification notification;

  const _NotificationCard({required this.notification});

  @override
  State<_NotificationCard> createState() => _NotificationCardState();
}

class _NotificationCardState extends State<_NotificationCard> {
  bool _isProcessing = false;

  Future<void> _handleApprove() async {
    final notif = widget.notification;
    final expController = context.read<ExpenseController>();
    final wsController = context.read<WorkspaceController>();
    final auth = context.read<AuthController>();
    final notifController = context.read<NotificationController>();
    final currentWs = wsController.currentWorkspace;

    final pendingChange = expController.pendingChanges.where((p) => p.id == notif.pendingChangeId).firstOrNull;
    if (pendingChange == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('This edit request has already been reviewed or resolved.'), backgroundColor: AppColors.warning),
      );
      await notifController.markAsRead(notif.id);
      return;
    }

    setState(() => _isProcessing = true);
    final success = await expController.approvePendingChange(
      pendingChange: pendingChange,
      reviewerId: auth.uid,
      reviewerName: auth.displayName,
      allMemberIds: currentWs?.memberIds,
      memberNames: currentWs?.memberNames,
    );
    if (!mounted) return;
    setState(() => _isProcessing = false);

    if (success) {
      await notifController.markAsRead(notif.id);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Edit accepted! Shared balance updated.'), backgroundColor: AppColors.success),
        );
      }
    }
  }

  Future<void> _handleReject() async {
    final notif = widget.notification;
    final expController = context.read<ExpenseController>();
    final wsController = context.read<WorkspaceController>();
    final auth = context.read<AuthController>();
    final notifController = context.read<NotificationController>();
    final currentWs = wsController.currentWorkspace;

    final pendingChange = expController.pendingChanges.where((p) => p.id == notif.pendingChangeId).firstOrNull;
    if (pendingChange == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('This edit request has already been reviewed or resolved.'), backgroundColor: AppColors.warning),
      );
      await notifController.markAsRead(notif.id);
      return;
    }

    setState(() => _isProcessing = true);
    final success = await expController.rejectPendingChange(
      pendingChange: pendingChange,
      reviewerId: auth.uid,
      reviewerName: auth.displayName,
      allMemberIds: currentWs?.memberIds,
      memberNames: currentWs?.memberNames,
    );
    if (!mounted) return;
    setState(() => _isProcessing = false);

    if (success) {
      await notifController.markAsRead(notif.id);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Edit declined. Official balance remains unchanged.'), backgroundColor: AppColors.error),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final notif = widget.notification;
    final notifController = context.read<NotificationController>();
    final expController = context.watch<ExpenseController>();
    final wsController = context.watch<WorkspaceController>();
    final currentWs = wsController.currentWorkspace;

    final pendingChange = notif.pendingChangeId != null
        ? expController.pendingChanges.where((p) => p.id == notif.pendingChangeId).firstOrNull
        : null;

    final hasPendingAction = notif.isPendingEdit && pendingChange != null && pendingChange.isPending;
    final diffItems = pendingChange?.getDetailedDiffs(memberNames: currentWs?.memberNames) ?? [];

    return Card(
      color: notif.isRead ? AppColors.surface : AppColors.surfaceElevated.withValues(alpha: 0.7),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: notif.isRead ? AppColors.cardBorder : AppColors.primary.withValues(alpha: 0.5),
          width: notif.isRead ? 1 : 1.5,
        ),
      ),
      margin: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () {
          if (!notif.isRead) {
            notifController.markAsRead(notif.id);
          }
        },
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: notif.isPendingEdit ? AppColors.badgeAmberBg : AppColors.badgeGreenBg,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      notif.isPendingEdit ? Icons.rule_folder_outlined : Icons.notifications_active_outlined,
                      color: notif.isPendingEdit ? AppColors.warning : AppColors.primaryLight,
                      size: 18,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Expanded(
                              child: Text(
                                notif.title,
                                style: const TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.textPrimary,
                                ),
                              ),
                            ),
                            Text(
                              DateFormatter.formatRelative(notif.createdAt),
                              style: const TextStyle(
                                fontSize: 11,
                                color: AppColors.textMuted,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Text(
                          notif.message,
                          style: const TextStyle(
                            fontSize: 13,
                            color: AppColors.textSecondary,
                            height: 1.35,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              if (hasPendingAction && diffItems.isNotEmpty) ...[
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColors.surfaceElevated,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppColors.cardBorder),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: const [
                          Icon(Icons.compare_arrows_rounded, size: 16, color: AppColors.primaryLight),
                          SizedBox(width: 6),
                          Text(
                            'What Changed:',
                            style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.textPrimary),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      ...diffItems.map((diff) {
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 6),
                          child: Row(
                            children: [
                              Text('${diff.label}: ', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.textSecondary)),
                              Flexible(
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: AppColors.error.withValues(alpha: 0.15),
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: Text(
                                    diff.oldValue,
                                    style: const TextStyle(fontSize: 11, color: AppColors.error, decoration: TextDecoration.lineThrough),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ),
                              const Padding(
                                padding: EdgeInsets.symmetric(horizontal: 6),
                                child: Icon(Icons.arrow_forward_rounded, size: 12, color: AppColors.textMuted),
                              ),
                              Flexible(
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: AppColors.success.withValues(alpha: 0.15),
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: Text(
                                    diff.newValue,
                                    style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: AppColors.success),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        );
                      }),
                    ],
                  ),
                ),
              ],
              if (hasPendingAction) ...[
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: CustomButton(
                        text: 'Accept Edit',
                        icon: Icons.check_circle_outline_rounded,
                        height: 40,
                        backgroundColor: AppColors.primary,
                        isLoading: _isProcessing,
                        onPressed: _handleApprove,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: CustomButton(
                        text: 'Decline',
                        icon: Icons.close_rounded,
                        height: 40,
                        isOutlined: true,
                        backgroundColor: AppColors.error,
                        textColor: AppColors.error,
                        isLoading: _isProcessing,
                        onPressed: _handleReject,
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
