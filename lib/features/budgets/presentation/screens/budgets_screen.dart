import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:splitterbuddy/core/constants/app_colors.dart';
import 'package:splitterbuddy/core/constants/app_constants.dart';
import 'package:splitterbuddy/core/utils/currency_formatter.dart';
import 'package:splitterbuddy/features/authentication/presentation/controllers/auth_controller.dart';
import 'package:splitterbuddy/features/budgets/domain/models/budget.dart';
import 'package:splitterbuddy/features/budgets/presentation/controllers/budget_controller.dart';
import 'package:splitterbuddy/features/expenses/domain/models/expense_category.dart';
import 'package:splitterbuddy/features/expenses/presentation/controllers/expense_controller.dart';
import 'package:splitterbuddy/features/expenses/presentation/widgets/category_picker_sheet.dart';
import 'package:splitterbuddy/features/workspace/presentation/controllers/workspace_controller.dart';
import 'package:splitterbuddy/shared/widgets/confirm_dialog.dart';
import 'package:splitterbuddy/shared/widgets/custom_button.dart';
import 'package:splitterbuddy/shared/widgets/custom_text_field.dart';
import 'package:splitterbuddy/shared/widgets/empty_state_view.dart';

class BudgetsScreen extends StatelessWidget {
  const BudgetsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final budgetController = context.watch<BudgetController>();
    final expController = context.watch<ExpenseController>();
    final wsController = context.watch<WorkspaceController>();
    final auth = context.watch<AuthController>();
    final currentWs = wsController.currentWorkspace;

    final calculations = budgetController.getBudgetCalculations(expController.activeExpenses);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Budgets & Limits'),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showAddBudgetDialog(context, auth.uid, currentWs?.id),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add_rounded),
        label: const Text('New Budget', style: TextStyle(fontWeight: FontWeight.w700)),
      ),
      body: calculations.isEmpty
          ? EmptyStateView(
              icon: Icons.account_balance_wallet_outlined,
              title: 'No budgets set',
              subtitle: 'Create monthly spending targets for categories or overall expenses to receive threshold alerts.',
              buttonText: 'Set a Budget',
              buttonIcon: Icons.add_rounded,
              onButtonPressed: () => _showAddBudgetDialog(context, auth.uid, currentWs?.id),
            )
          : ListView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              itemCount: calculations.length,
              itemBuilder: (context, index) {
                final calc = calculations[index];
                final budget = calc.budget;
                final isOverall = budget.isOverall;
                final cat = isOverall ? null : ExpenseCategory.find(budget.category);

                Color statusColor = AppColors.success;
                switch (calc.status) {
                  case BudgetStatus.onTrack:
                    statusColor = AppColors.success;
                    break;
                  case BudgetStatus.approachingLimit:
                    statusColor = const Color(0xFFF59E0B); // Amber
                    break;
                  case BudgetStatus.exceeded:
                    statusColor = AppColors.error;
                    break;
                }

                return Card(
                  margin: const EdgeInsets.only(bottom: 14),
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
                                color: (isOverall ? AppColors.primaryLight : cat!.color).withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Icon(
                                isOverall ? Icons.all_inclusive_rounded : cat!.icon,
                                color: isOverall ? AppColors.primaryLight : cat!.color,
                                size: 20,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    isOverall ? 'Overall Monthly Budget' : '${cat!.name} Budget',
                                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: AppColors.textPrimary),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    '${calc.percentage}% used • ${budget.period.toUpperCase()}',
                                    style: const TextStyle(fontSize: 12, color: AppColors.textMuted),
                                  ),
                                ],
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                              decoration: BoxDecoration(
                                color: statusColor.withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Text(
                                calc.statusLabel,
                                style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: statusColor),
                              ),
                            ),
                            IconButton(
                              icon: const Icon(Icons.delete_outline_rounded, color: AppColors.textMuted, size: 20),
                              onPressed: () async {
                                final confirmed = await ConfirmDialog.show(
                                  context,
                                  title: 'Delete Budget',
                                  message: 'Are you sure you want to remove this budget target?',
                                  confirmText: 'Delete',
                                  isDestructive: true,
                                );
                                if (confirmed == true) {
                                  await budgetController.deleteBudget(budget.id, workspaceId: currentWs?.id);
                                }
                              },
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(4),
                          child: LinearProgressIndicator(
                            value: (calc.percentage / 100.0).clamp(0.0, 1.0),
                            backgroundColor: AppColors.surfaceElevated,
                            valueColor: AlwaysStoppedAnimation<Color>(statusColor),
                            minHeight: 8,
                          ),
                        ),
                        const SizedBox(height: 12),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'Spent: ${CurrencyFormatter.format(calc.spentAmount)}',
                              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.textPrimary),
                            ),
                            Text(
                              'Limit: ${CurrencyFormatter.format(calc.limitAmount)}',
                              style: const TextStyle(fontSize: 13, color: AppColors.textSecondary),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          calc.status == BudgetStatus.exceeded
                              ? 'Exceeded by ${CurrencyFormatter.format(calc.overAmount)}'
                              : 'Remaining: ${CurrencyFormatter.format(calc.remainingAmount)}',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: calc.status == BudgetStatus.exceeded ? AppColors.error : AppColors.textMuted,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
    );
  }

  void _showAddBudgetDialog(BuildContext context, String currentUserId, String? workspaceId) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) => _AddBudgetBottomSheet(currentUserId: currentUserId, workspaceId: workspaceId),
    );
  }
}

class _AddBudgetBottomSheet extends StatefulWidget {
  final String currentUserId;
  final String? workspaceId;

  const _AddBudgetBottomSheet({required this.currentUserId, this.workspaceId});

  @override
  State<_AddBudgetBottomSheet> createState() => _AddBudgetBottomSheetState();
}

class _AddBudgetBottomSheetState extends State<_AddBudgetBottomSheet> {
  final _amountController = TextEditingController();
  String _selectedType = 'overall'; // 'overall' or 'category'
  String _selectedCategory = AppConstants.categoryFood;

  @override
  void dispose() {
    _amountController.dispose();
    super.dispose();
  }

  Future<void> _handleSave() async {
    final amount = CurrencyFormatter.parseAmount(_amountController.text);
    if (amount == null || amount <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a valid budget amount.'), backgroundColor: AppColors.error),
      );
      return;
    }

    final budgetController = context.read<BudgetController>();
    final messenger = ScaffoldMessenger.of(context);
    final categoryToSave = _selectedType == 'overall' ? 'overall' : _selectedCategory;

    final success = await budgetController.createBudget(
      workspaceId: widget.workspaceId,
      category: categoryToSave,
      limitAmount: amount,
      createdBy: widget.currentUserId,
    );

    if (!mounted) return;
    if (success) {
      Navigator.of(context).pop();
      messenger.showSnackBar(
        const SnackBar(content: Text('Budget created successfully!'), backgroundColor: AppColors.success),
      );
    } else {
      messenger.showSnackBar(
        SnackBar(
          content: Text(budgetController.errorMessage ?? 'Failed to create budget.'),
          backgroundColor: AppColors.error,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final cat = ExpenseCategory.find(_selectedCategory);

    return Padding(
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 24,
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Create Budget', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: AppColors.textPrimary)),
              IconButton(icon: const Icon(Icons.close_rounded), onPressed: () => Navigator.of(context).pop()),
            ],
          ),
          const SizedBox(height: 16),
          // Type Selector
          Row(
            children: [
              Expanded(
                child: ChoiceChip(
                  label: const Text('Overall Budget'),
                  selected: _selectedType == 'overall',
                  onSelected: (selected) {
                    if (selected) setState(() => _selectedType = 'overall');
                  },
                  selectedColor: AppColors.primary,
                  backgroundColor: AppColors.surfaceElevated,
                  labelStyle: TextStyle(
                    color: _selectedType == 'overall' ? Colors.white : AppColors.textSecondary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: ChoiceChip(
                  label: const Text('By Category'),
                  selected: _selectedType == 'category',
                  onSelected: (selected) {
                    if (selected) setState(() => _selectedType = 'category');
                  },
                  selectedColor: AppColors.primary,
                  backgroundColor: AppColors.surfaceElevated,
                  labelStyle: TextStyle(
                    color: _selectedType == 'category' ? Colors.white : AppColors.textSecondary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          if (_selectedType == 'category') ...[
            const SizedBox(height: 16),
            InkWell(
              onTap: () async {
                final picked = await CategoryPickerSheet.show(context, selectedCategory: _selectedCategory);
                if (picked != null) setState(() => _selectedCategory = picked.id);
              },
              borderRadius: BorderRadius.circular(12),
              child: Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: AppColors.surfaceElevated,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.cardBorder),
                ),
                child: Row(
                  children: [
                    Icon(cat.icon, color: cat.color, size: 20),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(cat.name, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
                    ),
                    const Icon(Icons.arrow_drop_down_rounded, color: AppColors.textSecondary),
                  ],
                ),
              ),
            ),
          ],
          const SizedBox(height: 16),
          CustomTextField(
            label: 'Monthly Limit Amount (ETB)',
            controller: _amountController,
            hintText: 'e.g. 5,000.00',
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            prefixIcon: const Icon(Icons.attach_money_rounded),
          ),
          const SizedBox(height: 24),
          CustomButton(
            text: 'Save Budget Target',
            icon: Icons.check_rounded,
            isLoading: context.watch<BudgetController>().isLoading,
            onPressed: _handleSave,
          ),
        ],
      ),
    );
  }
}
