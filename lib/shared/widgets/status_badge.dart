import 'package:flutter/material.dart';
import 'package:splitterbuddy/core/constants/app_colors.dart';
import 'package:splitterbuddy/core/constants/app_constants.dart';

class StatusBadge extends StatelessWidget {
  final String status;

  const StatusBadge({super.key, required this.status});

  @override
  Widget build(BuildContext context) {
    Color bg;
    Color text;
    String label = status;

    switch (status) {
      case AppConstants.pendingChangePending:
        bg = AppColors.badgeAmberBg;
        text = AppColors.warning;
        label = 'Pending Review';
        break;
      case AppConstants.pendingChangeApproved:
        bg = AppColors.badgeGreenBg;
        text = AppColors.success;
        label = 'Approved';
        break;
      case AppConstants.pendingChangeRejected:
        bg = AppColors.badgeRedBg;
        text = AppColors.error;
        label = 'Rejected';
        break;
      case AppConstants.expenseDeleted:
        bg = AppColors.badgeRedBg;
        text = AppColors.error;
        label = 'Deleted';
        break;
      case AppConstants.expenseActive:
      default:
        bg = AppColors.badgeGreenBg;
        text = AppColors.success;
        label = 'Active';
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: text.withValues(alpha: 0.3)),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: text,
          fontSize: 12,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}
