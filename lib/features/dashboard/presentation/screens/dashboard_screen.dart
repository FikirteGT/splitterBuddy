import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:splitterbuddy/core/constants/app_colors.dart';
import 'package:splitterbuddy/core/utils/currency_formatter.dart';
import 'package:splitterbuddy/core/utils/date_formatter.dart';
import 'package:splitterbuddy/features/authentication/presentation/controllers/auth_controller.dart';
import 'package:splitterbuddy/features/balance/presentation/widgets/balance_card.dart';
import 'package:splitterbuddy/features/balance/presentation/widgets/spending_breakdown_card.dart';
import 'package:splitterbuddy/features/expenses/presentation/controllers/expense_controller.dart';
import 'package:splitterbuddy/features/expenses/presentation/screens/add_expense_screen.dart';
import 'package:splitterbuddy/features/expenses/presentation/screens/expense_details_screen.dart';
import 'package:splitterbuddy/features/settlement/presentation/screens/settle_balance_dialog.dart';
import 'package:splitterbuddy/features/settlement/presentation/screens/settlement_history_screen.dart';
import 'package:splitterbuddy/features/workspace/presentation/controllers/workspace_controller.dart';
import 'package:splitterbuddy/features/workspace/presentation/screens/create_workspace_screen.dart';
import 'package:splitterbuddy/features/workspace/presentation/screens/invite_partner_screen.dart';
import 'package:splitterbuddy/features/workspace/presentation/screens/join_workspace_screen.dart';
import 'package:splitterbuddy/features/workspace/presentation/screens/workspace_list_screen.dart';
import 'package:splitterbuddy/shared/widgets/empty_state_view.dart';

class DashboardScreen extends StatelessWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthController>();
    final wsController = context.watch<WorkspaceController>();
    final expController = context.watch<ExpenseController>();

    final currentWs = wsController.currentWorkspace;

    if (wsController.isLoading && currentWs == null) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    if (currentWs == null) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('SplitterBud'),
          actions: [
            IconButton(
              icon: const Icon(Icons.group_add_rounded),
              tooltip: 'Join Workspace',
              onPressed: () {
                Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const JoinWorkspaceScreen()),
                );
              },
            ),
          ],
        ),
        body: EmptyStateView(
          icon: Icons.home_work_outlined,
          title: "You don't have a workspace yet",
          subtitle: 'Create your own workspace to split shared expenses, or join a friend using their invitation code.',
          buttonText: 'Create Workspace',
          buttonIcon: Icons.add_rounded,
          onButtonPressed: () {
            Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const CreateWorkspaceScreen()),
            );
          },
          secondaryButtonText: 'Join with Invite Code',
          secondaryButtonIcon: Icons.login_rounded,
          onSecondaryButtonPressed: () {
            Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const JoinWorkspaceScreen()),
            );
          },
        ),
      );
    }

    final partnerName = currentWs.getPartnerName(auth.uid);
    final hasPartner = currentWs.hasPartner;
    final balance = expController.balance;
    final recentExpenses = expController.recentExpenses;

    return Scaffold(
      appBar: AppBar(
        title: InkWell(
          onTap: () {
            Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const WorkspaceListScreen()),
            );
          },
          borderRadius: BorderRadius.circular(8),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Flexible(
                  child: Text(
                    currentWs.name,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.5,
                    ),
                  ),
                ),
                const SizedBox(width: 6),
                const Icon(Icons.keyboard_arrow_down_rounded, size: 20, color: AppColors.textSecondary),
              ],
            ),
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.history_edu_rounded),
            tooltip: 'Settlement History',
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const SettlementHistoryScreen()),
              );
            },
          ),
          if (!hasPartner)
            IconButton(
              icon: const Icon(Icons.person_add_outlined, color: AppColors.primaryLight),
              tooltip: 'Invite Partner',
              onPressed: () {
                Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => InvitePartnerScreen(workspace: currentWs)),
                );
              },
            ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => const AddExpenseScreen()),
          );
        },
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add_rounded),
        label: const Text('Add Expense', style: TextStyle(fontWeight: FontWeight.w700)),
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          // Streams update in real-time, but refresh gives immediate tactile response
          await Future.delayed(const Duration(milliseconds: 300));
        },
        child: ListView(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          children: [
            // Invite Partner Banner if only 1 member
            if (!hasPartner) ...[
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      AppColors.primaryDark.withValues(alpha: 0.4),
                      AppColors.surfaceElevated,
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: AppColors.primary.withValues(alpha: 0.4)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: const [
                        Icon(Icons.people_outline_rounded, color: AppColors.primaryLight, size: 22),
                        SizedBox(width: 8),
                        Text(
                          'Invite your partner',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            color: AppColors.textPrimary,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Give your partner code ${currentWs.inviteCode} to start splitting expenses together.',
                      style: const TextStyle(fontSize: 13, color: AppColors.textSecondary),
                    ),
                    const SizedBox(height: 12),
                    OutlinedButton.icon(
                      onPressed: () {
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => InvitePartnerScreen(workspace: currentWs),
                          ),
                        );
                      },
                      icon: const Icon(Icons.share_rounded, size: 16, color: AppColors.primaryLight),
                      label: Text(
                        'Share Code: ${currentWs.inviteCode}',
                        style: const TextStyle(fontWeight: FontWeight.w700, color: AppColors.primaryLight),
                      ),
                      style: OutlinedButton.styleFrom(
                        side: const BorderSide(color: AppColors.primary),
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 18),
            ],

            // Spending Breakdown Card
            SpendingBreakdownCard(
              balance: balance,
              partnerName: partnerName,
            ),
            const SizedBox(height: 18),

            // Dominant Balance Card
            BalanceCard(
              balance: balance,
              onSettlePressed: () {
                SettleBalanceDialog.show(context, balance);
              },
            ),
            const SizedBox(height: 24),

            // Recent Expenses Section Header
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'RECENT EXPENSES',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textMuted,
                    letterSpacing: 1.1,
                  ),
                ),
                if (recentExpenses.isNotEmpty)
                  Text(
                    '${expController.activeExpenses.length} total',
                    style: const TextStyle(fontSize: 12, color: AppColors.textMuted),
                  ),
              ],
            ),
            const SizedBox(height: 12),

            // Recent Expenses List
            if (recentExpenses.isEmpty)
              Container(
                padding: const EdgeInsets.symmetric(vertical: 36, horizontal: 16),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppColors.cardBorder),
                ),
                child: Column(
                  children: [
                    const Icon(Icons.receipt_outlined, size: 40, color: AppColors.textMuted),
                    const SizedBox(height: 12),
                    const Text(
                      'No expenses yet',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      'Add your first shared expense to get started.',
                      style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
                    ),
                    const SizedBox(height: 16),
                    ElevatedButton.icon(
                      onPressed: () {
                        Navigator.of(context).push(
                          MaterialPageRoute(builder: (_) => const AddExpenseScreen()),
                        );
                      },
                      icon: const Icon(Icons.add_rounded, size: 18),
                      label: const Text('Add Expense'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.surfaceElevated,
                        foregroundColor: AppColors.textPrimary,
                      ),
                    ),
                  ],
                ),
              )
            else
              ...recentExpenses.map((expense) {
                final payerName = expense.paidBy == auth.uid
                    ? 'You'
                    : currentWs.getMemberName(expense.paidBy);

                return Card(
                  margin: const EdgeInsets.only(bottom: 10),
                  child: ListTile(
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                    onTap: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => ExpenseDetailsScreen(expense: expense),
                        ),
                      );
                    },
                    leading: Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: AppColors.surfaceElevated,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(
                        Icons.shopping_bag_outlined,
                        color: AppColors.primaryLight,
                        size: 20,
                      ),
                    ),
                    title: Text(
                      expense.description,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    subtitle: Text(
                      'Paid by $payerName • ${DateFormatter.formatRelative(expense.createdAt)}',
                      style: const TextStyle(fontSize: 12, color: AppColors.textMuted),
                    ),
                    trailing: Text(
                      CurrencyFormatter.format(expense.amount),
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary,
                      ),
                    ),
                  ),
                );
              }),
            const SizedBox(height: 80), // Padding for FloatingActionButton
          ],
        ),
      ),
    );
  }
}
