import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:splitterbuddy/core/constants/app_colors.dart';
import 'package:splitterbuddy/core/utils/currency_formatter.dart';
import 'package:splitterbuddy/core/utils/date_formatter.dart';
import 'package:splitterbuddy/features/authentication/presentation/controllers/auth_controller.dart';
import 'package:splitterbuddy/features/expenses/presentation/controllers/expense_controller.dart';
import 'package:splitterbuddy/features/expenses/domain/models/expense.dart';
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

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthController>();
    final wsController = context.watch<WorkspaceController>();
    final currentWs = wsController.currentWorkspace;

    final payerName = expense.paidBy == auth.uid
        ? 'You (${auth.displayName})'
        : (currentWs?.getMemberName(expense.paidBy) ?? 'Partner');

    final fairShare = expense.amount / 2.0;

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
                  StatusBadge(status: expense.status),
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
            const SizedBox(height: 20),

            // 50/50 Breakdown Card
            Card(
              child: Padding(
                padding: const EdgeInsets.all(18),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      '50/50 Split Calculation',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 14),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Total Amount', style: TextStyle(color: AppColors.textSecondary)),
                        Text(CurrencyFormatter.format(expense.amount), style: const TextStyle(fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Fair Share Each (50%)', style: TextStyle(color: AppColors.textSecondary)),
                        Text(CurrencyFormatter.format(fairShare), style: const TextStyle(fontWeight: FontWeight.w700, color: AppColors.primaryLight)),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),

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
