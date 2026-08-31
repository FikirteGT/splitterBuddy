import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:splitterbuddy/core/constants/app_colors.dart';
import 'package:splitterbuddy/core/utils/currency_formatter.dart';
import 'package:splitterbuddy/features/authentication/presentation/controllers/auth_controller.dart';
import 'package:splitterbuddy/features/balance/domain/models/balance_result.dart';
import 'package:splitterbuddy/features/settlement/presentation/controllers/settlement_controller.dart';
import 'package:splitterbuddy/features/workspace/presentation/controllers/workspace_controller.dart';
import 'package:splitterbuddy/shared/widgets/custom_button.dart';

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

  Future<void> _handleConfirm() async {
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

  @override
  Widget build(BuildContext context) {
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
          const SizedBox(height: 20),

          // Settlement Icon
          Center(
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: const BoxDecoration(
                color: AppColors.badgeGreenBg,
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.handshake_rounded, size: 36, color: AppColors.primaryLight),
            ),
          ),
          const SizedBox(height: 18),

          const Text(
            'Settle Current Balance',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w800,
              color: AppColors.textPrimary,
              letterSpacing: -0.3,
            ),
          ),
          const SizedBox(height: 10),

          Text(
            'You are about to mark ${CurrencyFormatter.format(widget.balance.amountOwed)} as settled between you and ${widget.balance.partnerName}.',
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 14,
              color: AppColors.textSecondary,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 20),

          // Clarification Box
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AppColors.surfaceElevated.withValues(alpha: 0.4),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.cardBorder),
            ),
            child: Row(
              children: const [
                Icon(Icons.info_outline_rounded, size: 18, color: AppColors.info),
                SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'This closes the current expense period and archives it in your Settlement History. Your current balance will reset to 0 ETB.',
                    style: TextStyle(fontSize: 12, color: AppColors.textMuted, height: 1.3),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // Action Buttons
          CustomButton(
            text: 'Confirm Settlement',
            icon: Icons.check_circle_rounded,
            isLoading: _isSettling,
            onPressed: _handleConfirm,
          ),
          const SizedBox(height: 10),
          CustomButton(
            text: 'Cancel',
            isOutlined: true,
            onPressed: () => Navigator.of(context).pop(false),
          ),
        ],
      ),
    );
  }
}
