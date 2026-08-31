import 'dart:math';
import '../../../core/constants/app_constants.dart';
import '../../expenses/domain/models/expense.dart';
import '../domain/models/balance_result.dart';

/// Pure, deterministic balance engine for two-person 50/50 expense sharing.
/// No Flutter UI dependencies, completely decoupled and testable.
class BalanceEngine {
  const BalanceEngine._();

  /// Calculates the authoritative balance between two workspace members
  /// for a given list of expenses.
  ///
  /// Safe integer cents arithmetic is used internally to eliminate
  /// floating-point drift and inaccuracies.
  static BalanceResult calculate({
    required List<Expense> expenses,
    required String currentUserId,
    required String partnerId,
    String partnerName = 'Partner',
  }) {
    if (currentUserId.isEmpty) {
      return BalanceResult.zero(partnerName: partnerName);
    }

    int userPaidCents = 0;
    int partnerPaidCents = 0;

    for (final expense in expenses) {
      // Deleted expenses must never affect the active balance
      if (expense.status != AppConstants.expenseActive) {
        continue;
      }

      // Convert to integer cents (e.g. 450.50 -> 45050)
      final amountInCents = (expense.amount * 100).round();
      if (amountInCents <= 0) continue;

      if (expense.paidBy == currentUserId) {
        userPaidCents += amountInCents;
      } else if (expense.paidBy == partnerId) {
        partnerPaidCents += amountInCents;
      } else {
        // Fallback: if paidBy is not explicitly partnerId (e.g., initial setup or guest alias),
        // attribute to partner
        partnerPaidCents += amountInCents;
      }
    }

    final totalSpentCents = userPaidCents + partnerPaidCents;
    final totalSpent = totalSpentCents / 100.0;
    final fairSharePerPerson = (totalSpentCents / 2.0) / 100.0;
    final userPaid = userPaidCents / 100.0;
    final partnerPaid = partnerPaidCents / 100.0;

    // Mathematical formula for 50/50:
    // Net Position = (User Paid - Partner Paid) / 2
    final netCents = (userPaidCents - partnerPaidCents) / 2.0;
    final netBalance = (netCents / 100.0);
    final roundedNetBalance = (netBalance * 100).round() / 100.0;
    final amountOwed = (roundedNetBalance.abs());

    // Threshold for floating point settlement: less than 1 cent (0.009 ETB)
    final bool isSettled = amountOwed < 0.01;

    String statusText;
    String? payerId;
    String? receiverId;

    if (isSettled) {
      statusText = 'All settled up';
      payerId = null;
      receiverId = null;
    } else if (roundedNetBalance > 0) {
      statusText = '$partnerName owes you';
      payerId = partnerId;
      receiverId = currentUserId;
    } else {
      statusText = 'You owe $partnerName';
      payerId = currentUserId;
      receiverId = partnerId;
    }

    return BalanceResult(
      totalSpent: totalSpent,
      fairSharePerPerson: fairSharePerPerson,
      userPaid: userPaid,
      partnerPaid: partnerPaid,
      netBalance: roundedNetBalance,
      amountOwed: amountOwed,
      payerId: payerId,
      receiverId: receiverId,
      isSettled: isSettled,
      statusText: statusText,
      partnerName: partnerName,
    );
  }
}
