import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:splitterbuddy/core/constants/app_colors.dart';
import 'package:splitterbuddy/core/utils/currency_formatter.dart';
import 'package:splitterbuddy/features/authentication/presentation/controllers/auth_controller.dart';
import 'package:splitterbuddy/features/balance/domain/models/balance_result.dart';
import 'package:splitterbuddy/features/settlement/domain/models/settlement_obligation.dart';
import 'package:splitterbuddy/features/settlement/presentation/controllers/settlement_controller.dart';
import 'package:splitterbuddy/features/settlement/services/settlement_minimizer.dart';
import 'package:splitterbuddy/features/workspace/presentation/controllers/workspace_controller.dart';
import 'package:splitterbuddy/shared/widgets/custom_button.dart';
import 'package:splitterbuddy/shared/widgets/custom_text_field.dart';

class SettleBalanceDialog extends StatefulWidget {
  final BalanceResult balance;

  const SettleBalanceDialog({super.key, required this.balance});

  static Future<bool?> show(BuildContext context, BalanceResult balance) {
    return showModalBottomSheet<bool>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => SettleBalanceDialog(balance: balance),
    );
  }

  @override
  State<SettleBalanceDialog> createState() => _SettleBalanceDialogState();
}

class _SettleBalanceDialogState extends State<SettleBalanceDialog> {
  bool _isSettling = false;
  final TextEditingController _partialAmountController = TextEditingController();
  SettlementObligation? _selectedObligation;

  @override
  void dispose() {
    _partialAmountController.dispose();
    super.dispose();
  }

  Future<void> _handleFullPeriodSettlement() async {
    final auth = context.read<AuthController>();
    final wsController = context.read<WorkspaceController>();
    final currentWs = wsController.currentWorkspace;
    final currentPeriod = wsController.currentPeriod;

    if (currentWs == null || currentPeriod == null) return;

    setState(() => _isSettling = true);

    final payerId = widget.balance.payerId ?? auth.uid;
    final receiverId = widget.balance.receiverId ?? (currentWs.getPartnerId(auth.uid) ?? '');

    final payerName = currentWs.getMemberName(payerId);
    final receiverName = currentWs.getMemberName(receiverId);

    final success = await context.read<SettlementController>().settleBalance(
      currentPeriod: currentPeriod,
      amount: widget.balance.amountOwed,
      payerId: payerId,
      receiverId: receiverId,
      payerName: payerName,
      receiverName: receiverName,
      initiatedBy: auth.uid,
      initiatedByName: auth.displayName,
      partnerId: currentWs.getPartnerId(auth.uid),
      allMemberIds: currentWs.memberIds,
    );

    if (!mounted) return;
    setState(() => _isSettling = false);

    if (success) {
      Navigator.of(context).pop(true);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Balance of ${CurrencyFormatter.format(widget.balance.amountOwed)} settled! A new expense period has started.',
          ),
          backgroundColor: AppColors.success,
          duration: const Duration(seconds: 3),
        ),
      );
    } else {
      final err = context.read<SettlementController>().errorMessage ?? 'Failed to settle balance';
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(err), backgroundColor: AppColors.error),
      );
    }
  }

  Future<void> _handlePartialObligationPayment(SettlementObligation obligation) async {
    final auth = context.read<AuthController>();
    final wsController = context.read<WorkspaceController>();
    final currentWs = wsController.currentWorkspace;
    final currentPeriod = wsController.currentPeriod;

    if (currentWs == null || currentPeriod == null) return;

    final inputAmount = double.tryParse(_partialAmountController.text.trim()) ?? obligation.remainingAmount;
    if (inputAmount <= 0 || inputAmount > obligation.remainingAmount + 0.005) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Please enter a valid amount up to ${CurrencyFormatter.format(obligation.remainingAmount)}'),
          backgroundColor: AppColors.error,
        ),
      );
      return;
    }

    setState(() => _isSettling = true);

    final success = await context.read<SettlementController>().recordPartialSettlement(
      currentPeriod: currentPeriod,
      obligationId: obligation.id,
      paymentAmount: inputAmount,
      totalOriginalAmount: obligation.originalAmount,
      previousSettledAmount: obligation.settledAmount,
      payerId: obligation.fromUserId,
      receiverId: obligation.toUserId,
      payerName: obligation.fromUserName,
      receiverName: obligation.toUserName,
      initiatedBy: auth.uid,
      initiatedByName: auth.displayName,
    );

    if (!mounted) return;
    setState(() => _isSettling = false);

    if (success) {
      Navigator.of(context).pop(true);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Recorded payment of ${CurrencyFormatter.format(inputAmount)} from ${obligation.fromUserName} to ${obligation.toUserName}.',
          ),
          backgroundColor: AppColors.success,
        ),
      );
    } else {
      final err = context.read<SettlementController>().errorMessage ?? 'Failed to record payment';
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(err), backgroundColor: AppColors.error),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final ws = context.watch<WorkspaceController>().currentWorkspace;
    final period = context.watch<WorkspaceController>().currentPeriod;
    final isMultiMember = ws != null && ws.memberCount > 2;

    List<SettlementObligation> obligations = [];
    if (ws != null && period != null) {
      obligations = SettlementMinimizer.minimizeDebts(
        memberNetBalances: widget.balance.memberNetBalances,
        memberNames: ws.memberNames,
        workspaceId: ws.id,
        periodId: period.id,
      );
    }

    return Container(
      padding: EdgeInsets.only(
        left: 24,
        right: 24,
        top: 24,
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      decoration: const BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        border: Border(top: BorderSide(color: AppColors.cardBorder, width: 1)),
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: AppColors.cardBorder,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 18),

            // Settlement Icon
            Center(
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: const BoxDecoration(
                  color: AppColors.badgeGreenBg,
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.handshake_rounded, size: 34, color: AppColors.primaryLight),
              ),
            ),
            const SizedBox(height: 14),

            Text(
              isMultiMember ? 'Group Settlement & Obligations' : 'Settle Current Balance',
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w800,
                color: AppColors.textPrimary,
                letterSpacing: -0.3,
              ),
            ),
            const SizedBox(height: 8),

            Text(
              isMultiMember
                  ? 'Optimized minimal payment plan across ${ws.memberCount} members.'
                  : 'You are about to mark ${CurrencyFormatter.format(widget.balance.amountOwed)} as settled between you and ${widget.balance.partnerName}.',
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 13,
                color: AppColors.textSecondary,
                height: 1.4,
              ),
            ),
            const SizedBox(height: 18),

            // Multi-member Obligations List
            if (isMultiMember && obligations.isNotEmpty) ...[
              const Text(
                'Calculated Debt Transfers',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
              ),
              const SizedBox(height: 8),
              ...obligations.map((obl) {
                final isSelected = _selectedObligation?.id == obl.id;
                return InkWell(
                  onTap: () {
                    setState(() {
                      _selectedObligation = isSelected ? null : obl;
                      if (!isSelected) {
                        _partialAmountController.text = obl.remainingAmount.toStringAsFixed(2);
                      }
                    });
                  },
                  borderRadius: BorderRadius.circular(12),
                  child: Container(
                    margin: const EdgeInsets.only(bottom: 8),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: isSelected ? AppColors.primary.withValues(alpha: 0.15) : AppColors.surfaceElevated,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: isSelected ? AppColors.primaryLight : AppColors.cardBorder,
                      ),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.arrow_circle_right_outlined, color: AppColors.primaryLight, size: 20),
                        const SizedBox(width: 10),
                        Expanded(
                          child: RichText(
                            text: TextSpan(
                              style: const TextStyle(fontSize: 13, color: AppColors.textSecondary),
                              children: [
                                TextSpan(
                                  text: obl.fromUserName,
                                  style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.textPrimary),
                                ),
                                const TextSpan(text: ' pays '),
                                TextSpan(
                                  text: obl.toUserName,
                                  style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.textPrimary),
                                ),
                              ],
                            ),
                          ),
                        ),
                        Text(
                          CurrencyFormatter.format(obl.originalAmount),
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                            color: AppColors.primaryLight,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }),

              if (_selectedObligation != null) ...[
                const SizedBox(height: 12),
                CustomTextField(
                  label: 'Payment Amount (ETB)',
                  controller: _partialAmountController,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  prefixIcon: const Icon(Icons.payments_rounded, color: AppColors.textMuted),
                ),
                const SizedBox(height: 10),
                CustomButton(
                  text: 'Record Selected Payment',
                  icon: Icons.check,
                  isLoading: _isSettling,
                  onPressed: () => _handlePartialObligationPayment(_selectedObligation!),
                ),
                const SizedBox(height: 14),
              ],
            ],

            // Clarification Box
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.surfaceElevated.withValues(alpha: 0.4),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.cardBorder),
              ),
              child: Row(
                children: const [
                  Icon(Icons.info_outline_rounded, size: 16, color: AppColors.info),
                  SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Closing the period will archive current expenses and reset all member balances for the new period.',
                      style: TextStyle(fontSize: 11, color: AppColors.textMuted, height: 1.3),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 18),

            // Action Buttons
            CustomButton(
              text: isMultiMember ? 'Close Period & Reset All' : 'Confirm Settlement',
              icon: Icons.check_circle_rounded,
              isLoading: _isSettling,
              onPressed: _handleFullPeriodSettlement,
            ),
            const SizedBox(height: 8),
            CustomButton(
              text: 'Cancel',
              isOutlined: true,
              onPressed: () => Navigator.of(context).pop(false),
            ),
          ],
        ),
      ),
    );
  }
}
