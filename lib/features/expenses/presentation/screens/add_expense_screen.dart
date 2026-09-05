import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:splitterbuddy/core/constants/app_colors.dart';
import 'package:splitterbuddy/core/utils/currency_formatter.dart';
import 'package:splitterbuddy/features/authentication/presentation/controllers/auth_controller.dart';
import 'package:splitterbuddy/features/expenses/presentation/controllers/expense_controller.dart';
import 'package:splitterbuddy/features/workspace/presentation/controllers/workspace_controller.dart';
import 'package:splitterbuddy/shared/widgets/custom_button.dart';
import 'package:splitterbuddy/shared/widgets/custom_text_field.dart';

class AddExpenseScreen extends StatefulWidget {
  const AddExpenseScreen({super.key});

  @override
  State<AddExpenseScreen> createState() => _AddExpenseScreenState();
}

class _AddExpenseScreenState extends State<AddExpenseScreen> {
  final _formKey = GlobalKey<FormState>();
  final _descController = TextEditingController();
  final _amountController = TextEditingController();
  late String _selectedPaidBy;

  @override
  void initState() {
    super.initState();
    final auth = context.read<AuthController>();
    _selectedPaidBy = auth.uid;
  }

  @override
  void dispose() {
    _descController.dispose();
    _amountController.dispose();
    super.dispose();
  }

  Future<void> _handleSubmit() async {
    if (!_formKey.currentState!.validate()) return;
    FocusScope.of(context).unfocus();

    final amount = CurrencyFormatter.parseAmount(_amountController.text);
    if (amount == null || amount <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter a valid amount greater than 0.'),
          backgroundColor: AppColors.error,
        ),
      );
      return;
    }

    final messenger = ScaffoldMessenger.of(context);
    final auth = context.read<AuthController>();
    final ws = context.read<WorkspaceController>().currentWorkspace;
    final expController = context.read<ExpenseController>();

    final partnerId = ws?.getPartnerId(auth.uid);
    final partnerName = ws?.getPartnerName(auth.uid) ?? 'Partner';
    final paidByName = _selectedPaidBy == auth.uid ? auth.displayName : partnerName;
    final desc = _descController.text.trim();

    final success = await expController.addExpense(
      description: desc,
      amount: amount,
      paidBy: _selectedPaidBy,
      paidByName: paidByName,
      currentUserId: auth.uid,
      currentUserName: auth.displayName,
      partnerId: partnerId,
    );

    if (!mounted) return;
    if (success) {
      Navigator.of(context).pop();
      messenger.showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.check_circle_rounded, color: Colors.white, size: 20),
              const SizedBox(width: 10),
              Expanded(
                child: Text('Expense "$desc" added successfully!'),
              ),
            ],
          ),
          backgroundColor: AppColors.success,
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 3),
        ),
      );
    } else if (expController.errorMessage != null) {
      messenger.showSnackBar(
        SnackBar(
          content: Text(expController.errorMessage!),
          backgroundColor: AppColors.error,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthController>();
    final wsController = context.watch<WorkspaceController>();
    final expController = context.watch<ExpenseController>();
    final currentWs = wsController.currentWorkspace;

    final partnerId = currentWs?.getPartnerId(auth.uid);
    final partnerName = currentWs?.getPartnerName(auth.uid) ?? 'Partner';

    return Scaffold(
      appBar: AppBar(
        title: const Text('Add Expense'),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Description Field
                CustomTextField(
                  controller: _descController,
                  label: 'Description',
                  hintText: 'e.g. Groceries, Electricity, Dinner',
                  prefixIcon: const Icon(Icons.receipt_long_outlined, size: 20, color: AppColors.textMuted),
                  textCapitalization: TextCapitalization.sentences,
                  autofocus: true,
                  validator: (val) {
                    if (val == null || val.trim().isEmpty) return 'Description cannot be empty';
                    return null;
                  },
                ),
                const SizedBox(height: 20),

                // Amount Field
                CustomTextField(
                  controller: _amountController,
                  label: 'Amount (ETB)',
                  hintText: '0.00',
                  prefixText: 'ETB ',
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  prefixIcon: const Icon(Icons.payments_outlined, size: 20, color: AppColors.textMuted),
                  inputFormatters: [
                    FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d{0,2}')),
                  ],
                  validator: (val) {
                    if (val == null || val.trim().isEmpty) return 'Amount is required';
                    final parsed = CurrencyFormatter.parseAmount(val);
                    if (parsed == null || parsed <= 0) return 'Enter a valid amount > 0';
                    return null;
                  },
                ),
                const SizedBox(height: 24),

                // Paid By Selector
                const Text(
                  'Paid By',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textSecondary,
                  ),
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: ChoiceChip(
                        label: Text('You (${auth.displayName})'),
                        selected: _selectedPaidBy == auth.uid,
                        onSelected: (selected) {
                          if (selected) setState(() => _selectedPaidBy = auth.uid);
                        },
                        selectedColor: AppColors.primary,
                        backgroundColor: AppColors.surface,
                        labelStyle: TextStyle(
                          color: _selectedPaidBy == auth.uid ? Colors.white : AppColors.textSecondary,
                          fontWeight: FontWeight.w600,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                          side: BorderSide(
                            color: _selectedPaidBy == auth.uid ? AppColors.primary : AppColors.cardBorder,
                          ),
                        ),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                    ),
                    if (partnerId != null) ...[
                      const SizedBox(width: 12),
                      Expanded(
                        child: ChoiceChip(
                          label: Text(partnerName),
                          selected: _selectedPaidBy == partnerId,
                          onSelected: (selected) {
                            if (selected) setState(() => _selectedPaidBy = partnerId);
                          },
                          selectedColor: AppColors.primary,
                          backgroundColor: AppColors.surface,
                          labelStyle: TextStyle(
                            color: _selectedPaidBy == partnerId ? Colors.white : AppColors.textSecondary,
                            fontWeight: FontWeight.w600,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                            side: BorderSide(
                              color: _selectedPaidBy == partnerId ? AppColors.primary : AppColors.cardBorder,
                            ),
                          ),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 24),

                // 50/50 Split Indicator Card
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: AppColors.cardBorder),
                  ),
                  child: Row(
                    children: const [
                      Icon(Icons.pie_chart_outline_rounded, color: AppColors.primaryLight, size: 22),
                      SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          'Split 50/50 equally between both members',
                          style: TextStyle(
                            fontSize: 13,
                            color: AppColors.textSecondary,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 32),

                // Save Expense Button
                CustomButton(
                  text: 'Save Expense',
                  icon: Icons.check_rounded,
                  isLoading: expController.isLoading,
                  onPressed: _handleSubmit,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
