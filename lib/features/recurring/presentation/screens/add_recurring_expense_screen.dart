import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:splitterbuddy/core/constants/app_colors.dart';
import 'package:splitterbuddy/core/constants/app_constants.dart';
import 'package:splitterbuddy/core/utils/currency_formatter.dart';
import 'package:splitterbuddy/core/utils/date_formatter.dart';
import 'package:splitterbuddy/features/authentication/presentation/controllers/auth_controller.dart';
import 'package:splitterbuddy/features/expenses/domain/models/expense_category.dart';
import 'package:splitterbuddy/features/expenses/presentation/widgets/category_picker_sheet.dart';
import 'package:splitterbuddy/features/expenses/presentation/widgets/split_config_sheet.dart';
import 'package:splitterbuddy/features/recurring/presentation/controllers/recurring_expense_controller.dart';
import 'package:splitterbuddy/features/workspace/presentation/controllers/workspace_controller.dart';
import 'package:splitterbuddy/shared/widgets/custom_button.dart';
import 'package:splitterbuddy/shared/widgets/custom_text_field.dart';

class AddRecurringExpenseScreen extends StatefulWidget {
  const AddRecurringExpenseScreen({super.key});

  @override
  State<AddRecurringExpenseScreen> createState() => _AddRecurringExpenseScreenState();
}

class _AddRecurringExpenseScreenState extends State<AddRecurringExpenseScreen> {
  final _formKey = GlobalKey<FormState>();
  final _descController = TextEditingController();
  final _amountController = TextEditingController();

  late String _selectedPaidBy;
  String _selectedCategory = AppConstants.categoryRent;
  String _selectedFrequency = AppConstants.recurrenceMonthly;
  DateTime _firstDueDate = DateTime.now();
  String _splitType = AppConstants.splitEqual;
  Map<String, double>? _splitDetails;
  String? _splitSingleMemberId;

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
        const SnackBar(content: Text('Please enter a valid amount greater than 0.'), backgroundColor: AppColors.error),
      );
      return;
    }

    final auth = context.read<AuthController>();
    final wsController = context.read<WorkspaceController>();
    final currentWs = wsController.currentWorkspace;
    final recurringController = context.read<RecurringExpenseController>();
    final desc = _descController.text.trim();
    final messenger = ScaffoldMessenger.of(context);

    if (currentWs == null) {
      messenger.showSnackBar(
        const SnackBar(content: Text('Please select or create a workspace first.'), backgroundColor: AppColors.error),
      );
      return;
    }

    final success = await recurringController.createRecurringExpense(
      workspaceId: currentWs.id,
      description: desc,
      amount: amount,
      paidBy: _selectedPaidBy,
      category: _selectedCategory,
      splitType: _splitType,
      splitDetails: _splitDetails,
      splitSingleMemberId: _splitSingleMemberId,
      frequency: _selectedFrequency,
      firstDueDate: _firstDueDate,
      createdBy: auth.uid,
      currentUserName: auth.displayName,
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
              Expanded(child: Text('Recurring expense "$desc" created!')),
            ],
          ),
          backgroundColor: AppColors.success,
          behavior: SnackBarBehavior.floating,
        ),
      );
    } else if (recurringController.errorMessage != null) {
      messenger.showSnackBar(
        SnackBar(content: Text(recurringController.errorMessage!), backgroundColor: AppColors.error),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthController>();
    final wsController = context.watch<WorkspaceController>();
    final currentWs = wsController.currentWorkspace;
    final recurringController = context.watch<RecurringExpenseController>();

    final partnerId = currentWs?.getPartnerId(auth.uid);
    final partnerName = currentWs?.getPartnerName(auth.uid) ?? 'Partner';
    final category = ExpenseCategory.find(_selectedCategory);

    return Scaffold(
      appBar: AppBar(title: const Text('Add Recurring Expense')),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                CustomTextField(
                  controller: _descController,
                  label: 'Description',
                  hintText: 'e.g. Monthly Rent, WiFi, Netflix',
                  prefixIcon: const Icon(Icons.repeat_rounded, size: 20, color: AppColors.textMuted),
                  textCapitalization: TextCapitalization.sentences,
                  autofocus: true,
                  validator: (val) => (val == null || val.trim().isEmpty) ? 'Description cannot be empty' : null,
                ),
                const SizedBox(height: 20),

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
                const SizedBox(height: 20),

                // Category & Frequency Row
                Row(
                  children: [
                    Expanded(
                      child: InkWell(
                        onTap: () async {
                          final picked = await CategoryPickerSheet.show(context, selectedCategory: _selectedCategory);
                          if (picked != null) {
                            setState(() => _selectedCategory = picked.id);
                          }
                        },
                        borderRadius: BorderRadius.circular(12),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                          decoration: BoxDecoration(
                            color: AppColors.surface,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: AppColors.cardBorder),
                          ),
                          child: Row(
                            children: [
                              Icon(category.icon, color: category.color, size: 20),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  category.name,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.textPrimary),
                                ),
                              ),
                              const Icon(Icons.arrow_drop_down_rounded, color: AppColors.textSecondary),
                            ],
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        decoration: BoxDecoration(
                          color: AppColors.surface,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: AppColors.cardBorder),
                        ),
                        child: DropdownButtonHideUnderline(
                          child: DropdownButton<String>(
                            value: _selectedFrequency,
                            isExpanded: true,
                            dropdownColor: AppColors.surface,
                            items: const [
                              DropdownMenuItem(value: AppConstants.recurrenceDaily, child: Text('Daily', style: TextStyle(fontSize: 13))),
                              DropdownMenuItem(value: AppConstants.recurrenceWeekly, child: Text('Weekly', style: TextStyle(fontSize: 13))),
                              DropdownMenuItem(value: AppConstants.recurrenceMonthly, child: Text('Monthly', style: TextStyle(fontSize: 13))),
                              DropdownMenuItem(value: AppConstants.recurrenceYearly, child: Text('Yearly', style: TextStyle(fontSize: 13))),
                            ],
                            onChanged: (val) {
                              if (val != null) setState(() => _selectedFrequency = val);
                            },
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),

                // First Due Date
                InkWell(
                  onTap: () async {
                    final picked = await showDatePicker(
                      context: context,
                      initialDate: _firstDueDate,
                      firstDate: DateTime.now().subtract(const Duration(days: 30)),
                      lastDate: DateTime.now().add(const Duration(days: 365)),
                    );
                    if (picked != null) setState(() => _firstDueDate = picked);
                  },
                  borderRadius: BorderRadius.circular(12),
                  child: Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: AppColors.surface,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppColors.cardBorder),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.calendar_today_outlined, size: 18, color: AppColors.primaryLight),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('First Occurrence Date', style: TextStyle(fontSize: 11, color: AppColors.textMuted)),
                              Text(
                                DateFormatter.formatDateOnly(_firstDueDate),
                                style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.textPrimary),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 20),

                // Paid By
                const Text('Paid By', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.textSecondary)),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: ChoiceChip(
                        label: Text('You (${auth.displayName})', overflow: TextOverflow.ellipsis),
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
                      ),
                    ),
                    if (partnerId != null) ...[
                      const SizedBox(width: 10),
                      Expanded(
                        child: ChoiceChip(
                          label: Text(partnerName, overflow: TextOverflow.ellipsis),
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
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 20),

                // Split Configuration
                const Text('Split Method', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.textSecondary)),
                const SizedBox(height: 8),
                InkWell(
                  onTap: () async {
                    final amount = CurrencyFormatter.parseAmount(_amountController.text) ?? 0.0;
                    final memberIds = [
                      auth.uid,
                      ?partnerId,
                    ];
                    final memberNames = <String, String>{
                      auth.uid: 'You (${auth.displayName})',
                      ?partnerId: partnerName,
                    };
                    final result = await SplitConfigSheet.show(
                      context,
                      totalAmount: amount,
                      memberIds: memberIds,
                      memberNames: memberNames,
                      initialSplitType: _splitType,
                      initialSplitDetails: _splitDetails,
                      initialSingleMemberId: _splitSingleMemberId,
                    );
                    if (result != null) {
                      setState(() {
                        _splitType = result.splitType;
                        _splitDetails = result.splitDetails;
                        _splitSingleMemberId = result.splitSingleMemberId;
                      });
                    }
                  },
                  borderRadius: BorderRadius.circular(12),
                  child: Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: AppColors.surface,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppColors.cardBorder),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.call_split_rounded, size: 20, color: AppColors.primaryLight),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                _splitType == AppConstants.splitEqual
                                    ? '50/50 Equal Split'
                                    : _splitType == AppConstants.splitCustom
                                        ? 'Custom Amount Split'
                                        : _splitType == AppConstants.splitPercentage
                                            ? 'Percentage Split'
                                            : 'Paid Entirely for One Person',
                                style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.textPrimary),
                              ),
                              const SizedBox(height: 2),
                              const Text(
                                'Tap to change split method or customize shares',
                                style: TextStyle(fontSize: 11, color: AppColors.textMuted),
                              ),
                            ],
                          ),
                        ),
                        const Icon(Icons.chevron_right_rounded, color: AppColors.textSecondary),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 32),

                CustomButton(
                  text: 'Save Recurring Expense',
                  icon: Icons.check_rounded,
                  isLoading: recurringController.isLoading,
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
