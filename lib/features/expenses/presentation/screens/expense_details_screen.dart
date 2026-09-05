import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:splitterbuddy/core/constants/app_colors.dart';
import 'package:splitterbuddy/core/utils/currency_formatter.dart';
import 'package:splitterbuddy/core/utils/date_formatter.dart';
import 'package:splitterbuddy/features/authentication/presentation/controllers/auth_controller.dart';
import 'package:splitterbuddy/features/expenses/domain/models/expense.dart';
import 'package:splitterbuddy/features/expenses/domain/models/expense_category.dart';
import 'package:splitterbuddy/features/expenses/presentation/controllers/expense_controller.dart';
import 'package:splitterbuddy/features/expenses/presentation/screens/edit_expense_screen.dart';
import 'package:splitterbuddy/features/workspace/presentation/controllers/workspace_controller.dart';
import 'package:splitterbuddy/shared/widgets/confirm_dialog.dart';
import 'package:splitterbuddy/shared/widgets/custom_button.dart';
import 'package:splitterbuddy/shared/widgets/status_badge.dart';

class ExpenseDetailsScreen extends StatelessWidget {
  final Expense expense;

  const ExpenseDetailsScreen({super.key, required this.expense});

  Future<void> _handleDelete(BuildContext context) async {
    final confirmed = await ConfirmDialog.show(
      context,
      title: 'Delete Expense',
      message: 'Are you sure you want to delete "${expense.description}" (${CurrencyFormatter.format(expense.amount)})? This will adjust your shared balance accordingly.',
      confirmText: 'Delete',
      isDestructive: true,
    );

    if (confirmed == true && context.mounted) {
      final auth = context.read<AuthController>();
      final ws = context.read<WorkspaceController>().currentWorkspace;
      final partnerId = ws?.getPartnerId(auth.uid);

      final success = await context.read<ExpenseController>().deleteExpense(
        expense: expense,
        currentUserId: auth.uid,
        currentUserName: auth.displayName,
        partnerId: partnerId,
      );

      if (context.mounted) {
        if (success) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Expense deleted.'),
              backgroundColor: AppColors.error,
            ),
          );
          Navigator.of(context).pop();
        } else {
          final err = context.read<ExpenseController>().errorMessage ?? 'Failed to delete expense';
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(err), backgroundColor: AppColors.error),
          );
        }
      }
    }
  }

  void _showReceiptDialog(BuildContext context, String receiptUrl) {
    showDialog(
      context: context,
      builder: (_) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                IconButton.filled(
                  icon: const Icon(Icons.close_rounded, color: Colors.white),
                  onPressed: () => Navigator.of(context).pop(),
                  style: IconButton.styleFrom(backgroundColor: Colors.black54),
                ),
              ],
            ),
            const SizedBox(height: 8),
            ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: Image.network(
                receiptUrl,
                fit: BoxFit.contain,
                loadingBuilder: (ctx, child, progress) {
                  if (progress == null) return child;
                  return const Padding(
                    padding: EdgeInsets.all(32),
                    child: CircularProgressIndicator(),
                  );
                },
                errorBuilder: (ctx, error, stackTrace) => Container(
                  padding: const EdgeInsets.all(24),
                  color: AppColors.surface,
                  child: const Text('Failed to load image', style: TextStyle(color: AppColors.error)),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthController>();
    final wsController = context.watch<WorkspaceController>();
    final currentWs = wsController.currentWorkspace;

    final payerName = expense.paidBy == auth.uid
        ? 'You (${auth.displayName})'
        : (currentWs?.getMemberName(expense.paidBy) ?? 'Partner');

    final category = ExpenseCategory.find(expense.category);
    final members = currentWs?.memberIds ?? [auth.uid];
    final memberNames = currentWs?.memberNames ?? {auth.uid: auth.displayName};
    final shares = expense.calculateShares(members);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Expense Details'),
        actions: [
          if (expense.isActive) ...[
            IconButton(
              icon: const Icon(Icons.edit_outlined),
              onPressed: () {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => EditExpenseScreen(expense: expense),
                  ),
                );
              },
            ),
            IconButton(
              icon: const Icon(Icons.delete_outline_rounded, color: AppColors.error),
              onPressed: () => _handleDelete(context),
            ),
          ],
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Header Amount Card
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: AppColors.cardBorder),
              ),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      StatusBadge(status: expense.status),
                      if (expense.isRecurring) ...[
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: AppColors.secondary.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.repeat_rounded, size: 12, color: AppColors.secondaryLight),
                              SizedBox(width: 4),
                              Text('Recurring', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: AppColors.secondaryLight)),
                            ],
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 14),
                  Text(
                    expense.description,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    CurrencyFormatter.format(expense.amount),
                    style: const TextStyle(
                      fontSize: 34,
                      fontWeight: FontWeight.w900,
                      color: AppColors.primaryLight,
                      letterSpacing: -0.5,
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Category Chip
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: category.color.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: category.color.withValues(alpha: 0.3)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(category.icon, color: category.color, size: 16),
                        const SizedBox(width: 6),
                        Text(
                          category.name,
                          style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: category.color),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Paid by $payerName',
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 18),

            // Split Breakdown Card
            Card(
              child: Padding(
                padding: const EdgeInsets.all(18),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Split Breakdown',
                          style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: AppColors.textPrimary),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: AppColors.surfaceElevated,
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            expense.splitType,
                            style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: AppColors.primaryLight),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    ...members.map((id) {
                      final name = (id == auth.uid) ? 'You (${auth.displayName})' : (memberNames[id] ?? 'Partner');
                      final share = shares[id] ?? 0.0;
                      final pct = expense.amount > 0 ? (share / expense.amount * 100) : 0.0;

                      return Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(name, style: const TextStyle(color: AppColors.textSecondary, fontSize: 14)),
                            Text(
                              '${CurrencyFormatter.format(share)} (${pct.toStringAsFixed(0)}%)',
                              style: const TextStyle(fontWeight: FontWeight.w700, color: AppColors.textPrimary, fontSize: 14),
                            ),
                          ],
                        ),
                      );
                    }),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 18),

            // Receipt Evidence Card
            if (expense.hasReceipt) ...[
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(18),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Receipt Attachment',
                        style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: AppColors.textPrimary),
                      ),
                      const SizedBox(height: 12),
                      InkWell(
                        onTap: () => _showReceiptDialog(context, expense.receiptUrl!),
                        borderRadius: BorderRadius.circular(12),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(12),
                          child: Stack(
                            alignment: Alignment.bottomRight,
                            children: [
                              Image.network(
                                expense.receiptUrl!,
                                height: 160,
                                width: double.infinity,
                                fit: BoxFit.cover,
                                loadingBuilder: (ctx, child, progress) {
                                  if (progress == null) return child;
                                  return Container(
                                    height: 160,
                                    color: AppColors.surfaceElevated,
                                    child: const Center(child: CircularProgressIndicator()),
                                  );
                                },
                              ),
                              Container(
                                margin: const EdgeInsets.all(8),
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                decoration: BoxDecoration(
                                  color: Colors.black87,
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: const Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(Icons.fullscreen_rounded, color: Colors.white, size: 16),
                                    SizedBox(width: 4),
                                    Text('Tap to View', style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w600)),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 18),
            ],

            // Metadata Card
            Card(
              child: Padding(
                padding: const EdgeInsets.all(18),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Date Created', style: TextStyle(color: AppColors.textSecondary, fontSize: 13)),
                        Text(DateFormatter.formatFull(expense.createdAt), style: const TextStyle(color: AppColors.textPrimary, fontSize: 13, fontWeight: FontWeight.w500)),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Last Updated', style: TextStyle(color: AppColors.textSecondary, fontSize: 13)),
                        Text(DateFormatter.formatRelative(expense.updatedAt), style: const TextStyle(color: AppColors.textPrimary, fontSize: 13, fontWeight: FontWeight.w500)),
                      ],
                    ),
                    if (expense.isDeleted) ...[
                      const SizedBox(height: 12),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text('Deleted At', style: TextStyle(color: AppColors.error, fontSize: 13)),
                          Text(
                            expense.deletedAt != null ? DateFormatter.formatFull(expense.deletedAt!) : 'Archived',
                            style: const TextStyle(color: AppColors.error, fontSize: 13, fontWeight: FontWeight.w600),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
            ),
            const SizedBox(height: 28),

            if (expense.isActive) ...[
              CustomButton(
                text: 'Edit Expense',
                icon: Icons.edit_outlined,
                onPressed: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => EditExpenseScreen(expense: expense),
                    ),
                  );
                },
              ),
            ],
          ],
        ),
      ),
    );
  }
}
