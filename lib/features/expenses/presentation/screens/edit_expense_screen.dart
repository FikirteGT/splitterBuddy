import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:splitterbuddy/core/constants/app_colors.dart';
import 'package:splitterbuddy/core/utils/currency_formatter.dart';
import 'package:splitterbuddy/features/authentication/presentation/controllers/auth_controller.dart';
import 'package:splitterbuddy/features/expenses/presentation/controllers/expense_controller.dart';
import 'package:splitterbuddy/features/expenses/domain/models/expense.dart';
import 'package:splitterbuddy/features/workspace/presentation/controllers/workspace_controller.dart';
import 'package:splitterbuddy/shared/widgets/custom_button.dart';
import 'package:splitterbuddy/shared/widgets/custom_text_field.dart';

class EditExpenseScreen extends StatefulWidget {
  final Expense expense;

  const EditExpenseScreen({super.key, required this.expense});

  @override
  State<EditExpenseScreen> createState() => _EditExpenseScreenState();
}

class _EditExpenseScreenState extends State<EditExpenseScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _descController;
  late final TextEditingController _amountController;
  late String _selectedPaidBy;

  @override
  void initState() {
    super.initState();
    _descController = TextEditingController(text: widget.expense.description);
    _amountController = TextEditingController(
      text: widget.expense.amount.toStringAsFixed(
        (widget.expense.amount % 1 == 0) ? 0 : 2,
      ),
    );
    _selectedPaidBy = widget.expense.paidBy;
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

    final auth = context.read<AuthController>();
    final ws = context.read<WorkspaceController>().currentWorkspace;
    final expController = context.read<ExpenseController>();

    final partnerId = ws?.getPartnerId(auth.uid);
    final isOwnExpense = widget.expense.paidBy == auth.uid || widget.expense.createdBy == auth.uid;

    final success = await expController.editExpense(
      expense: widget.expense,
      newDescription: _descController.text.trim(),
      newAmount: amount,
      newPaidBy: _selectedPaidBy,
      currentUserId: auth.uid,
      currentUserName: auth.displayName,
      partnerId: partnerId,
    );

    if (!mounted) return;
    if (success) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            isOwnExpense
                ? 'Expense updated successfully!'
                : 'Edit proposal submitted for partner review!',
          ),
          backgroundColor: isOwnExpense ? AppColors.success : AppColors.warning,
          duration: const Duration(seconds: 2),
        ),
      );
      Navigator.of(context).pop();
    } else if (expController.errorMessage != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(expController.errorMessage!),
          backgroundColor: AppColors.error,
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
    final isOwnExpense = widget.expense.paidBy == auth.uid || widget.expense.createdBy == auth.uid;

    return Scaffold(
      appBar: AppBar(
        title: Text(isOwnExpense ? 'Edit Expense' : 'Propose Expense Edit'),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Partner Edit Notice Banner if not own expense
                if (!isOwnExpense) ...[
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: AppColors.badgeAmberBg,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: AppColors.warning.withValues(alpha: 0.4)),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(Icons.shield_outlined, color: AppColors.warning, size: 22),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Partner Approval Required',
                                style: TextStyle(
                                  color: AppColors.warning,
                                  fontWeight: FontWeight.w700,
                                  fontSize: 14,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'This expense was paid by $partnerName. Your changes will be submitted as a proposed edit and will NOT modify the official balance until $partnerName approves.',
                                style: const TextStyle(
                                  color: AppColors.textSecondary,
                                  fontSize: 13,
                                  height: 1.35,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),
                ],

                // Description Field
                CustomTextField(
                  controller: _descController,
                  label: 'Description',
                  hintText: 'e.g. Groceries',
                  prefixIcon: const Icon(Icons.receipt_long_outlined, size: 20, color: AppColors.textMuted),
                  textCapitalization: TextCapitalization.sentences,
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
                const SizedBox(height: 32),

                // Submit Button
                CustomButton(
                  text: isOwnExpense ? 'Save Changes' : 'Submit for Review',
                  icon: isOwnExpense ? Icons.check_rounded : Icons.send_rounded,
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
