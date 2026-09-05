import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:splitterbuddy/core/constants/app_colors.dart';
import 'package:splitterbuddy/core/constants/app_constants.dart';
import 'package:splitterbuddy/core/utils/currency_formatter.dart';
import 'package:splitterbuddy/core/utils/date_formatter.dart';
import 'package:splitterbuddy/features/authentication/presentation/controllers/auth_controller.dart';
import 'package:splitterbuddy/features/expenses/domain/models/expense_category.dart';
import 'package:splitterbuddy/features/expenses/presentation/controllers/expense_controller.dart';
import 'package:splitterbuddy/features/workspace/presentation/controllers/workspace_controller.dart';
import 'expense_details_screen.dart';

class AllExpensesScreen extends StatelessWidget {
  const AllExpensesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final expController = context.watch<ExpenseController>();
    final wsController = context.watch<WorkspaceController>();
    final auth = context.watch<AuthController>();
    final currentWs = wsController.currentWorkspace;
    final expenses = expController.filteredExpenses;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Search & Filter Expenses'),
        actions: [
          if (expController.hasActiveFilters)
            TextButton.icon(
              onPressed: () => expController.resetFilters(),
              icon: const Icon(Icons.refresh_rounded, size: 16, color: AppColors.primaryLight),
              label: const Text('Reset', style: TextStyle(color: AppColors.primaryLight)),
            ),
        ],
      ),
      body: Column(
        children: [
          // Search Box & Filter trigger
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    onChanged: (val) => expController.setSearchQuery(val),
                    decoration: InputDecoration(
                      hintText: 'Search by description or category...',
                      prefixIcon: const Icon(Icons.search_rounded, color: AppColors.textMuted),
                      suffixIcon: expController.searchQuery.isNotEmpty
                          ? IconButton(
                              icon: const Icon(Icons.clear_rounded, size: 18),
                              onPressed: () => expController.setSearchQuery(''),
                            )
                          : null,
                      filled: true,
                      fillColor: AppColors.surface,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(color: AppColors.cardBorder),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(color: AppColors.cardBorder),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton.filledTonal(
                  onPressed: () => _showFilterDialog(context, expController, currentWs?.memberNames ?? {}),
                  icon: Badge(
                    isLabelVisible: expController.hasActiveFilters,
                    child: const Icon(Icons.tune_rounded, color: AppColors.primaryLight),
                  ),
                  style: IconButton.styleFrom(
                    backgroundColor: AppColors.surface,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              ],
            ),
          ),

          // Category Quick Filter Bar
          SizedBox(
            height: 38,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              children: [
                Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: ChoiceChip(
                    selected: expController.selectedCategory == null,
                    label: const Text('All Categories'),
                    selectedColor: AppColors.primary,
                    backgroundColor: AppColors.surface,
                    labelStyle: TextStyle(
                      color: expController.selectedCategory == null ? Colors.white : AppColors.textSecondary,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                    onSelected: (selected) {
                      if (selected) expController.setCategoryFilter(null);
                    },
                  ),
                ),
                ...ExpenseCategory.all.map((cat) {
                  final isSelected = expController.selectedCategory == cat.id;
                  return Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: ChoiceChip(
                      selected: isSelected,
                      avatar: Icon(cat.icon, size: 14, color: isSelected ? Colors.white : cat.color),
                      label: Text(cat.name),
                      selectedColor: cat.color,
                      backgroundColor: AppColors.surface,
                      labelStyle: TextStyle(
                        color: isSelected ? Colors.white : AppColors.textSecondary,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                      onSelected: (selected) {
                        expController.setCategoryFilter(selected ? cat.id : null);
                      },
                    ),
                  );
                }),
              ],
            ),
          ),
          const SizedBox(height: 10),

          // Results count
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '${expenses.length} ${expenses.length == 1 ? 'expense' : 'expenses'} found',
                  style: const TextStyle(fontSize: 12, color: AppColors.textMuted, fontWeight: FontWeight.w600),
                ),
                Text(
                  'Sort: ${_getSortLabel(expController.sortOption)}',
                  style: const TextStyle(fontSize: 12, color: AppColors.primaryLight, fontWeight: FontWeight.w500),
                ),
              ],
            ),
          ),
          const Divider(height: 16),

          // Expense List
          Expanded(
            child: expenses.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.search_off_rounded, size: 48, color: AppColors.textMuted),
                        const SizedBox(height: 12),
                        const Text(
                          'No matching expenses found',
                          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: AppColors.textPrimary),
                        ),
                        const SizedBox(height: 4),
                        const Text(
                          'Try clearing your search terms or filters.',
                          style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
                        ),
                        if (expController.hasActiveFilters) ...[
                          const SizedBox(height: 16),
                          OutlinedButton.icon(
                            onPressed: () => expController.resetFilters(),
                            icon: const Icon(Icons.refresh_rounded, size: 16),
                            label: const Text('Reset All Filters'),
                          ),
                        ],
                      ],
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    itemCount: expenses.length,
                    itemBuilder: (ctx, index) {
                      final exp = expenses[index];
                      final cat = ExpenseCategory.find(exp.category);
                      final payerName = exp.paidBy == auth.uid
                          ? 'You'
                          : (currentWs?.getMemberName(exp.paidBy) ?? 'Partner');

                      return Card(
                        margin: const EdgeInsets.only(bottom: 10),
                        child: ListTile(
                          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                          onTap: () {
                            Navigator.of(context).push(
                              MaterialPageRoute(builder: (_) => ExpenseDetailsScreen(expense: exp)),
                            );
                          },
                          leading: Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: cat.color.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Icon(cat.icon, color: cat.color, size: 20),
                          ),
                          title: Text(
                            exp.description,
                            style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: AppColors.textPrimary),
                          ),
                          subtitle: Text(
                            '${cat.name} • Paid by $payerName • ${DateFormatter.formatRelative(exp.createdAt)}',
                            style: const TextStyle(fontSize: 12, color: AppColors.textMuted),
                          ),
                          trailing: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Text(
                                CurrencyFormatter.format(exp.amount),
                                style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: AppColors.textPrimary),
                              ),
                              if (exp.splitType != AppConstants.splitEqual)
                                Container(
                                  margin: const EdgeInsets.only(top: 2),
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: AppColors.surfaceElevated,
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: Text(
                                    exp.splitType,
                                    style: const TextStyle(fontSize: 9, fontWeight: FontWeight.w700, color: AppColors.primaryLight),
                                  ),
                                ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  String _getSortLabel(ExpenseSortOption option) {
    switch (option) {
      case ExpenseSortOption.oldest:
        return 'Oldest First';
      case ExpenseSortOption.highestAmount:
        return 'Highest Amount';
      case ExpenseSortOption.lowestAmount:
        return 'Lowest Amount';
      case ExpenseSortOption.newest:
        return 'Newest First';
    }
  }

  void _showFilterDialog(BuildContext context, ExpenseController controller, Map<String, String> memberNames) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (_) {
        return StatefulBuilder(
          builder: (ctx, setModalState) {
            return Padding(
              padding: const EdgeInsets.all(20),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Filter & Sort Options', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
                        IconButton(icon: const Icon(Icons.close_rounded), onPressed: () => Navigator.of(ctx).pop()),
                      ],
                    ),
                    const SizedBox(height: 14),

                    // Sort By
                    const Text('SORT BY', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: AppColors.textMuted, letterSpacing: 1.1)),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      children: [
                        _buildSortChip(controller, ExpenseSortOption.newest, 'Newest First', setModalState),
                        _buildSortChip(controller, ExpenseSortOption.oldest, 'Oldest First', setModalState),
                        _buildSortChip(controller, ExpenseSortOption.highestAmount, 'Highest Amount', setModalState),
                        _buildSortChip(controller, ExpenseSortOption.lowestAmount, 'Lowest Amount', setModalState),
                      ],
                    ),
                    const SizedBox(height: 18),

                    // Split Type Filter
                    const Text('SPLIT TYPE', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: AppColors.textMuted, letterSpacing: 1.1)),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      children: [
                        _buildSplitChip(controller, null, 'All', setModalState),
                        _buildSplitChip(controller, AppConstants.splitEqual, 'Equal (50/50)', setModalState),
                        _buildSplitChip(controller, AppConstants.splitCustom, 'Custom', setModalState),
                        _buildSplitChip(controller, AppConstants.splitPercentage, 'Percentage', setModalState),
                        _buildSplitChip(controller, AppConstants.splitSingle, 'Paid for One', setModalState),
                      ],
                    ),
                    const SizedBox(height: 24),

                    ElevatedButton(
                      onPressed: () => Navigator.of(ctx).pop(),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      child: const Text('Apply Filters', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildSortChip(ExpenseController controller, ExpenseSortOption option, String label, StateSetter setModalState) {
    final isSelected = controller.sortOption == option;
    return ChoiceChip(
      selected: isSelected,
      label: Text(label),
      selectedColor: AppColors.primary,
      backgroundColor: AppColors.surfaceElevated,
      labelStyle: TextStyle(color: isSelected ? Colors.white : AppColors.textSecondary, fontSize: 12, fontWeight: FontWeight.w600),
      onSelected: (selected) {
        if (selected) {
          controller.setSortOption(option);
          setModalState(() {});
        }
      },
    );
  }

  Widget _buildSplitChip(ExpenseController controller, String? type, String label, StateSetter setModalState) {
    final isSelected = controller.selectedSplitType == type;
    return ChoiceChip(
      selected: isSelected,
      label: Text(label),
      selectedColor: AppColors.primary,
      backgroundColor: AppColors.surfaceElevated,
      labelStyle: TextStyle(color: isSelected ? Colors.white : AppColors.textSecondary, fontSize: 12, fontWeight: FontWeight.w600),
      onSelected: (selected) {
        if (selected) {
          controller.setSplitTypeFilter(type);
          setModalState(() {});
        }
      },
    );
  }
}
