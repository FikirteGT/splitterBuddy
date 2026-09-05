import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import 'package:splitterbuddy/core/constants/app_colors.dart';
import 'package:splitterbuddy/core/constants/app_constants.dart';
import 'package:splitterbuddy/core/utils/currency_formatter.dart';
import 'package:splitterbuddy/features/authentication/presentation/controllers/auth_controller.dart';
import 'package:splitterbuddy/features/expenses/domain/models/expense_category.dart';
import 'package:splitterbuddy/features/expenses/presentation/controllers/expense_controller.dart';
import 'package:splitterbuddy/features/expenses/presentation/widgets/category_picker_sheet.dart';
import 'package:splitterbuddy/features/expenses/presentation/widgets/split_config_sheet.dart';
import 'package:splitterbuddy/features/expenses/services/receipt_service.dart';
import 'package:splitterbuddy/features/recurring/presentation/controllers/recurring_expense_controller.dart';
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
  String _selectedCategory = AppConstants.categoryOther;
  String _splitType = AppConstants.splitEqual;
  Map<String, double>? _splitDetails;
  String? _splitSingleMemberId;

  XFile? _receiptImage;
  bool _isUploadingReceipt = false;
  bool _makeRecurring = false;
  String _recurringFrequency = AppConstants.recurrenceMonthly;

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

  Future<void> _pickReceipt(ImageSource source) async {
    final receiptService = context.read<ReceiptService>();
    final file = await receiptService.pickReceiptImage(source: source);
    if (file != null) {
      setState(() => _receiptImage = file);
    }
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
    final wsController = context.read<WorkspaceController>();
    final ws = wsController.currentWorkspace;
    final expController = context.read<ExpenseController>();
    final receiptService = context.read<ReceiptService>();

    if (ws == null) return;

    final partnerId = ws.getPartnerId(auth.uid);
    final partnerName = ws.getPartnerName(auth.uid);
    final paidByName = _selectedPaidBy == auth.uid ? auth.displayName : partnerName;
    final desc = _descController.text.trim();

    String? receiptUrl;
    String? receiptPath;

    if (_receiptImage != null) {
      setState(() => _isUploadingReceipt = true);
      try {
        final uploadRes = await receiptService.uploadReceipt(
          workspaceId: ws.id,
          file: _receiptImage!,
        );
        receiptUrl = uploadRes.downloadUrl;
        receiptPath = uploadRes.storagePath;
      } catch (e) {
        debugPrint('Receipt upload failed: $e');
      } finally {
        if (mounted) setState(() => _isUploadingReceipt = false);
      }
    }

    final success = await expController.addExpense(
      description: desc,
      amount: amount,
      paidBy: _selectedPaidBy,
      paidByName: paidByName,
      category: _selectedCategory,
      splitType: _splitType,
      splitDetails: _splitDetails,
      splitSingleMemberId: _splitSingleMemberId,
      receiptUrl: receiptUrl,
      receiptPath: receiptPath,
      currentUserId: auth.uid,
      currentUserName: auth.displayName,
      partnerId: partnerId,
    );

    if (_makeRecurring && success && mounted) {
      final recurringController = context.read<RecurringExpenseController>();
      await recurringController.createRecurringExpense(
        description: desc,
        amount: amount,
        paidBy: _selectedPaidBy,
        category: _selectedCategory,
        splitType: _splitType,
        splitDetails: _splitDetails,
        splitSingleMemberId: _splitSingleMemberId,
        frequency: _recurringFrequency,
        firstDueDate: DateTime.now().add(const Duration(days: 30)),
        createdBy: auth.uid,
        currentUserName: auth.displayName,
      );
    }

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
    final category = ExpenseCategory.find(_selectedCategory);

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
                const SizedBox(height: 20),

                // Category Selector
                const Text(
                  'Category',
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.textSecondary),
                ),
                const SizedBox(height: 8),
                InkWell(
                  onTap: () async {
                    final picked = await CategoryPickerSheet.show(context, selectedCategory: _selectedCategory);
                    if (picked != null) {
                      setState(() => _selectedCategory = picked.id);
                    }
                  },
                  borderRadius: BorderRadius.circular(12),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    decoration: BoxDecoration(
                      color: AppColors.surface,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppColors.cardBorder),
                    ),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: category.color.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Icon(category.icon, color: category.color, size: 20),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            category.name,
                            style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: AppColors.textPrimary),
                          ),
                        ),
                        const Icon(Icons.keyboard_arrow_down_rounded, color: AppColors.textSecondary),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 20),

                // Paid By Selector
                const Text(
                  'Paid By',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textSecondary,
                  ),
                ),
                const SizedBox(height: 8),
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
                const SizedBox(height: 20),

                // Split Configuration Card
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: AppColors.cardBorder),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.pie_chart_outline_rounded, color: AppColors.primaryLight, size: 22),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _getSplitTypeTitle(_splitType),
                              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: AppColors.textPrimary),
                            ),
                            Text(
                              _getSplitTypeSubtitle(_splitType),
                              style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                            ),
                          ],
                        ),
                      ),
                      TextButton(
                        onPressed: () async {
                          final currentAmount = CurrencyFormatter.parseAmount(_amountController.text) ?? 100.0;
                          final members = currentWs?.memberIds ?? [auth.uid];
                          final names = currentWs?.memberNames ?? {auth.uid: auth.displayName};

                          final result = await SplitConfigSheet.show(
                            context,
                            totalAmount: currentAmount,
                            memberIds: members,
                            memberNames: names,
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
                        child: const Text('Change', style: TextStyle(fontWeight: FontWeight.w700)),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),

                // Receipt Attachment Section
                const Text('Receipt / Bill Evidence', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.textSecondary)),
                const SizedBox(height: 8),
                if (_receiptImage != null) ...[
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: AppColors.surface,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppColors.cardBorder),
                    ),
                    child: Row(
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: kIsWeb
                              ? Container(
                                  width: 48,
                                  height: 48,
                                  color: AppColors.surfaceElevated,
                                  child: const Icon(Icons.image_rounded, color: AppColors.primaryLight),
                                )
                              : Image.file(
                                  File(_receiptImage!.path),
                                  width: 48,
                                  height: 48,
                                  fit: BoxFit.cover,
                                ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            _receiptImage!.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.textPrimary),
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.close_rounded, color: AppColors.error, size: 20),
                          onPressed: () => setState(() => _receiptImage = null),
                        ),
                      ],
                    ),
                  ),
                ] else ...[
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () => _pickReceipt(ImageSource.camera),
                          icon: const Icon(Icons.camera_alt_outlined, size: 18),
                          label: const Text('Camera'),
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            side: const BorderSide(color: AppColors.cardBorder),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () => _pickReceipt(ImageSource.gallery),
                          icon: const Icon(Icons.photo_library_outlined, size: 18),
                          label: const Text('Gallery'),
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            side: const BorderSide(color: AppColors.cardBorder),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
                const SizedBox(height: 20),

                // Make Recurring Switch
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  value: _makeRecurring,
                  activeTrackColor: AppColors.primary,
                  activeThumbColor: Colors.white,
                  title: const Text('Make this a recurring expense', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
                  subtitle: const Text('Automatically generate this on a schedule', style: TextStyle(fontSize: 12, color: AppColors.textMuted)),
                  onChanged: (val) => setState(() => _makeRecurring = val),
                ),
                if (_makeRecurring) ...[
                  const SizedBox(height: 8),
                  DropdownButtonFormField<String>(
                    initialValue: _recurringFrequency,
                    decoration: InputDecoration(
                      labelText: 'Repeat Frequency',
                      filled: true,
                      fillColor: AppColors.surface,
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    dropdownColor: AppColors.surface,
                    items: const [
                      DropdownMenuItem(value: AppConstants.recurrenceDaily, child: Text('Daily')),
                      DropdownMenuItem(value: AppConstants.recurrenceWeekly, child: Text('Weekly')),
                      DropdownMenuItem(value: AppConstants.recurrenceMonthly, child: Text('Monthly')),
                      DropdownMenuItem(value: AppConstants.recurrenceYearly, child: Text('Yearly')),
                    ],
                    onChanged: (val) {
                      if (val != null) setState(() => _recurringFrequency = val);
                    },
                  ),
                ],
                const SizedBox(height: 32),

                // Save Expense Button
                CustomButton(
                  text: 'Save Expense',
                  icon: Icons.check_rounded,
                  isLoading: expController.isLoading || _isUploadingReceipt,
                  onPressed: _handleSubmit,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  String _getSplitTypeTitle(String type) {
    switch (type) {
      case AppConstants.splitCustom:
        return 'Custom Amount Split';
      case AppConstants.splitPercentage:
        return 'Percentage Split';
      case AppConstants.splitSingle:
        return 'Paid Entirely for One Person';
      case AppConstants.splitEqual:
      default:
        return 'Split 50/50 Equally';
    }
  }

  String _getSplitTypeSubtitle(String type) {
    switch (type) {
      case AppConstants.splitCustom:
        return 'Each person pays a designated custom amount';
      case AppConstants.splitPercentage:
        return 'Shares allocated by customized percentage';
      case AppConstants.splitSingle:
        return 'Allocated 100% to selected recipient';
      case AppConstants.splitEqual:
      default:
        return 'Divided equally between both members';
    }
  }
}
