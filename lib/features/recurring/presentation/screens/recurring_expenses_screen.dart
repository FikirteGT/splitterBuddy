import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:splitterbuddy/core/constants/app_colors.dart';
import 'package:splitterbuddy/core/utils/currency_formatter.dart';
import 'package:splitterbuddy/core/utils/date_formatter.dart';
import 'package:splitterbuddy/features/authentication/presentation/controllers/auth_controller.dart';
import 'package:splitterbuddy/features/expenses/domain/models/expense_category.dart';
import 'package:splitterbuddy/features/recurring/presentation/controllers/recurring_expense_controller.dart';
import 'package:splitterbuddy/shared/widgets/confirm_dialog.dart';
import 'package:splitterbuddy/shared/widgets/empty_state_view.dart';
import 'add_recurring_expense_screen.dart';

class RecurringExpensesScreen extends StatelessWidget {
  const RecurringExpensesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final recurringController = context.watch<RecurringExpenseController>();
    final auth = context.watch<AuthController>();
    final list = recurringController.recurringExpenses;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Recurring Expenses'),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => const AddRecurringExpenseScreen()),
          );
        },
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add_rounded),
        label: const Text('New Recurring', style: TextStyle(fontWeight: FontWeight.w700)),
      ),
      body: list.isEmpty
          ? EmptyStateView(
              icon: Icons.repeat_rounded,
              title: 'No recurring expenses',
              subtitle: 'Automate monthly rent, subscription fees, or regular bills so they split automatically.',
              buttonText: 'Add Recurring Expense',
              buttonIcon: Icons.add_rounded,
              onButtonPressed: () {
                Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const AddRecurringExpenseScreen()),
                );
              },
            )
          : ListView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              itemCount: list.length,
              itemBuilder: (context, index) {
                final item = list[index];
                final cat = ExpenseCategory.find(item.category);

                return Card(
                  margin: const EdgeInsets.only(bottom: 12),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: cat.color.withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Icon(cat.icon, color: cat.color, size: 20),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    item.description,
                                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: AppColors.textPrimary),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    '${item.frequency.toUpperCase()} • ${cat.name}',
                                    style: const TextStyle(fontSize: 12, color: AppColors.textMuted),
                                  ),
                                ],
                              ),
                            ),
                            Text(
                              CurrencyFormatter.format(item.amount),
                              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: AppColors.textPrimary),
                            ),
                          ],
                        ),
                        const Divider(height: 24, color: AppColors.cardBorder),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text('Next Occurrence', style: TextStyle(fontSize: 11, color: AppColors.textMuted)),
                                Text(
                                  DateFormatter.formatDateOnly(item.nextDueDate),
                                  style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.primaryLight),
                                ),
                              ],
                            ),
                            Row(
                              children: [
                                Switch(
                                  value: item.isActive,
                                  activeTrackColor: AppColors.primary,
                                  activeThumbColor: Colors.white,
                                  onChanged: (val) {
                                    recurringController.toggleActive(
                                      recurring: item,
                                      currentUserId: auth.uid,
                                      currentUserName: auth.displayName,
                                    );
                                  },
                                ),
                                IconButton(
                                  icon: const Icon(Icons.delete_outline_rounded, color: AppColors.error, size: 20),
                                  onPressed: () async {
                                    final confirmed = await ConfirmDialog.show(
                                      context,
                                      title: 'Delete Recurring Expense',
                                      message: 'Are you sure you want to stop and delete "${item.description}"? Past generated expenses will remain preserved.',
                                      confirmText: 'Delete',
                                      isDestructive: true,
                                    );
                                    if (confirmed == true) {
                                      recurringController.deleteRecurring(item.id);
                                    }
                                  },
                                ),
                              ],
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
    );
  }
}
