import '../../../../core/constants/app_constants.dart';
import '../../expenses/domain/models/expense.dart';

class SplitEngine {
  const SplitEngine._();

  /// Validates whether a split configuration is mathematically and logically sound.
  /// Returns null if valid, or a descriptive error message if invalid.
  static String? validateSplit({
    required double totalAmount,
    required String splitType,
    required List<String> memberIds,
    Map<String, double>? splitDetails,
    String? singleMemberId,
  }) {
    if (totalAmount <= 0) {
      return 'Amount must be greater than 0.';
    }
    if (memberIds.isEmpty) {
      return 'Workspace must have at least one member.';
    }

    final totalCents = (totalAmount * 100).round();

    switch (splitType) {
      case AppConstants.splitCustom:
        if (splitDetails == null || splitDetails.isEmpty) {
          return 'Please specify custom split amounts for all members.';
        }
        int sumSharesCents = 0;
        for (final memberId in memberIds) {
          final share = splitDetails[memberId] ?? 0.0;
          if (share < 0) {
            return 'Custom share amounts cannot be negative.';
          }
          sumSharesCents += (share * 100).round();
        }

        if ((sumSharesCents - totalCents).abs() > 1) {
          final diff = (sumSharesCents - totalCents) / 100.0;
          if (diff > 0) {
            return 'Sum of custom amounts is ETB ${diff.abs().toStringAsFixed(2)} higher than total.';
          } else {
            return 'Sum of custom amounts is ETB ${diff.abs().toStringAsFixed(2)} less than total.';
          }
        }
        return null;

      case AppConstants.splitPercentage:
        if (splitDetails == null || splitDetails.isEmpty) {
          return 'Please specify split percentages for all members.';
        }
        double sumPercentages = 0.0;
        for (final memberId in memberIds) {
          final pct = splitDetails[memberId] ?? 0.0;
          if (pct < 0) {
            return 'Percentages cannot be negative.';
          }
          sumPercentages += pct;
        }

        if ((sumPercentages - 100.0).abs() > 0.05) {
          return 'Percentages must total exactly 100% (currently ${sumPercentages.toStringAsFixed(1)}%).';
        }
        return null;

      case AppConstants.splitSingle:
        if (singleMemberId == null || singleMemberId.isEmpty || !memberIds.contains(singleMemberId)) {
          return 'Please select the person this expense was paid for.';
        }
        return null;

      case AppConstants.splitEqual:
      default:
        return null;
    }
  }

  /// Calculates individual shares in currency amounts for all members.
  static Map<String, double> computeShares({
    required Expense expense,
    required List<String> memberIds,
  }) {
    if (memberIds.isEmpty) return {};
    return expense.calculateShares(memberIds);
  }

  /// Calculates net positions for all workspace members across all active expenses.
  /// Positive value: member is owed money.
  /// Negative value: member owes money.
  static Map<String, double> calculateNetPositions({
    required List<Expense> expenses,
    required List<String> memberIds,
  }) {
    final netPositionsCents = <String, int>{};
    for (final id in memberIds) {
      netPositionsCents[id] = 0;
    }

    for (final expense in expenses) {
      if (!expense.isActive) continue;

      final totalCents = (expense.amount * 100).round();
      if (totalCents <= 0) continue;

      // Payer contributed +totalAmount
      if (netPositionsCents.containsKey(expense.paidBy)) {
        netPositionsCents[expense.paidBy] = netPositionsCents[expense.paidBy]! + totalCents;
      } else {
        netPositionsCents[expense.paidBy] = totalCents;
      }

      // Compute participant shares
      final shares = expense.calculateShares(memberIds);
      shares.forEach((memberId, shareAmount) {
        final shareCents = (shareAmount * 100).round();
        netPositionsCents[memberId] = (netPositionsCents[memberId] ?? 0) - shareCents;
      });
    }

    final result = <String, double>{};
    netPositionsCents.forEach((id, cents) {
      result[id] = cents / 100.0;
    });

    return result;
  }
}
