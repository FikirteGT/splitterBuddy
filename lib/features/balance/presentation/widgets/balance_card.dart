import 'package:flutter/material.dart';
import 'package:splitterbuddy/core/constants/app_colors.dart';
import 'package:splitterbuddy/core/utils/currency_formatter.dart';
import 'package:splitterbuddy/features/balance/domain/models/balance_result.dart';

class BalanceCard extends StatelessWidget {
  final BalanceResult balance;
  final VoidCallback? onSettlePressed;

  const BalanceCard({
    super.key,
    required this.balance,
    this.onSettlePressed,
  });

  @override
  Widget build(BuildContext context) {
    Color cardBorderColor;
    Color accentColor;
    IconData statusIcon;

    if (balance.isSettled) {
      cardBorderColor = AppColors.cardBorder;
      accentColor = AppColors.textSecondary;
      statusIcon = Icons.check_circle_outline_rounded;
    } else if (balance.doesPartnerOweUser) {
      cardBorderColor = AppColors.owesYou.withValues(alpha: 0.5);
      accentColor = AppColors.owesYou;
      statusIcon = Icons.arrow_downward_rounded; // Incoming money
    } else {
      cardBorderColor = AppColors.youOwe.withValues(alpha: 0.5);
      accentColor = AppColors.youOwe;
      statusIcon = Icons.arrow_upward_rounded; // Outgoing money
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: cardBorderColor, width: 1.5),
        boxShadow: [
          BoxShadow(
            color: accentColor.withValues(alpha: 0.12),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(statusIcon, size: 18, color: accentColor),
              const SizedBox(width: 6),
              Text(
                'CURRENT BALANCE',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: accentColor,
                  letterSpacing: 1.2,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Who owes whom description
          Text(
            balance.statusText,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 8),

          // Exact Amount Dominant Display
          Text(
            balance.isSettled ? '0 ETB' : CurrencyFormatter.format(balance.amountOwed),
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 38,
              fontWeight: FontWeight.w900,
              color: accentColor,
              letterSpacing: -1,
            ),
          ),
          const SizedBox(height: 20),

          // Settle Balance Button
          if (!balance.isSettled && onSettlePressed != null) ...[
            SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton.icon(
                onPressed: onSettlePressed,
                icon: const Icon(Icons.handshake_outlined, size: 20, color: Colors.white),
                label: const Text(
                  'SETTLE BALANCE',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.8,
                    color: Colors.white,
                  ),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  elevation: 0,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
