import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:splitterbuddy/core/constants/app_colors.dart';
import 'package:splitterbuddy/features/authentication/presentation/controllers/auth_controller.dart';
import 'package:splitterbuddy/features/expenses/presentation/controllers/expense_controller.dart';
import 'package:splitterbuddy/features/export/services/export_service.dart';
import 'package:splitterbuddy/features/workspace/presentation/controllers/workspace_controller.dart';
import 'package:splitterbuddy/shared/widgets/custom_button.dart';

class ExportScreen extends StatefulWidget {
  const ExportScreen({super.key});

  @override
  State<ExportScreen> createState() => _ExportScreenState();
}

class _ExportScreenState extends State<ExportScreen> {
  int _selectedTabIndex = 0; // 0: CSV, 1: Text Summary

  @override
  Widget build(BuildContext context) {
    final expController = context.watch<ExpenseController>();
    final wsController = context.watch<WorkspaceController>();
    final auth = context.watch<AuthController>();

    final currentWs = wsController.currentWorkspace;
    if (currentWs == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Export Data')),
        body: const Center(child: Text('No active workspace')),
      );
    }

    final expenses = expController.activeExpenses;
    final partnerName = currentWs.getPartnerName(auth.uid);
    final memberNames = {
      auth.uid: 'You (${auth.displayName})',
      if (currentWs.hasPartner) currentWs.getPartnerId(auth.uid)!: partnerName,
    };

    String csvContent = '';
    String textContent = '';

    try {
      csvContent = ExportService.generateExpensesCsv(
        workspace: currentWs,
        currentUserId: auth.uid,
        expenses: expenses,
        memberNames: memberNames,
      );

      final balance = expController.balance;
      textContent = ExportService.generateTextSummary(
        workspace: currentWs,
        periodLabel: 'All Active Expenses',
        totalSpending: balance.totalSpent,
        userPaid: balance.userPaid,
        partnerPaid: balance.partnerPaid,
        balance: balance.netBalance,
        partnerName: partnerName,
      );
    } catch (e) {
      return Scaffold(
        appBar: AppBar(title: const Text('Export Data')),
        body: Center(child: Text('Error preparing export: $e', style: const TextStyle(color: AppColors.error))),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Export Expenses'),
      ),
      body: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Export Format Toggle
            Row(
              children: [
                Expanded(
                  child: ChoiceChip(
                    label: const Text('CSV Format'),
                    selected: _selectedTabIndex == 0,
                    onSelected: (selected) {
                      if (selected) setState(() => _selectedTabIndex = 0);
                    },
                    selectedColor: AppColors.primary,
                    backgroundColor: AppColors.surface,
                    labelStyle: TextStyle(
                      color: _selectedTabIndex == 0 ? Colors.white : AppColors.textSecondary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: ChoiceChip(
                    label: const Text('Text Summary'),
                    selected: _selectedTabIndex == 1,
                    onSelected: (selected) {
                      if (selected) setState(() => _selectedTabIndex = 1);
                    },
                    selectedColor: AppColors.primary,
                    backgroundColor: AppColors.surface,
                    labelStyle: TextStyle(
                      color: _selectedTabIndex == 1 ? Colors.white : AppColors.textSecondary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Preview Title
            Text(
              _selectedTabIndex == 0 ? 'CSV PREVIEW (${expenses.length} records)' : 'TEXT SUMMARY PREVIEW',
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: AppColors.textMuted,
                letterSpacing: 1.1,
              ),
            ),
            const SizedBox(height: 10),

            // Content Preview Box
            Expanded(
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppColors.cardBorder),
                ),
                child: SingleChildScrollView(
                  child: SelectableText(
                    _selectedTabIndex == 0 ? csvContent : textContent,
                    style: TextStyle(
                      fontFamily: _selectedTabIndex == 0 ? 'monospace' : null,
                      fontSize: 12,
                      color: AppColors.textPrimary,
                      height: 1.4,
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Action Buttons
            CustomButton(
              text: _selectedTabIndex == 0 ? 'Copy CSV to Clipboard' : 'Copy Summary to Clipboard',
              icon: Icons.copy_rounded,
              onPressed: () async {
                final textToCopy = _selectedTabIndex == 0 ? csvContent : textContent;
                await Clipboard.setData(ClipboardData(text: textToCopy));
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Row(
                        children: const [
                          Icon(Icons.check_circle_rounded, color: Colors.white, size: 20),
                          SizedBox(width: 10),
                          Text('Copied to clipboard!'),
                        ],
                      ),
                      backgroundColor: AppColors.success,
                      behavior: SnackBarBehavior.floating,
                    ),
                  );
                }
              },
            ),
            const SizedBox(height: 10),
          ],
        ),
      ),
    );
  }
}
