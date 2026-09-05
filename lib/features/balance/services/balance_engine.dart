import '../../../../core/constants/app_constants.dart';
import '../../expenses/domain/models/expense.dart';
import '../domain/models/balance_result.dart';
import 'split_engine.dart';

/// Pure, deterministic balance engine for flexible shared expense calculations.
/// Fully backward compatible with V1 50/50 expenses and generalized for V2 splitting.
class BalanceEngine {
  const BalanceEngine._();

  /// Calculates the authoritative balance between two workspace members (or multiple members)
  /// for a given list of expenses.
  ///
  /// Safe integer cents arithmetic is used internally to eliminate floating-point drift.
  static BalanceResult calculate({
    required List<Expense> expenses,
    required String currentUserId,
    required String partnerId,
    String partnerName = 'Partner',
    List<String>? allMemberIds,
  }) {
    if (currentUserId.isEmpty) {
      return BalanceResult.zero(partnerName: partnerName);
    }

    final members = (allMemberIds != null && allMemberIds.isNotEmpty)
        ? allMemberIds
        : (partnerId.isNotEmpty ? [currentUserId, partnerId] : [currentUserId]);

    double totalSpentCents = 0.0;
    double userPaidCents = 0.0;
    double partnerPaidCents = 0.0;
    double userShareCents = 0.0;
    double partnerShareCents = 0.0;

    final memberPaidCents = <String, double>{};
    final memberShareCents = <String, double>{};
    final categorySpendingCents = <String, double>{};

    for (final id in members) {
      memberPaidCents[id] = 0.0;
      memberShareCents[id] = 0.0;
    }

    for (final expense in expenses) {
      if (expense.status != AppConstants.expenseActive) {
        continue;
      }

      final amountInCents = expense.amount * 100.0;
      if (amountInCents <= 0) continue;

      totalSpentCents += amountInCents;

      // Track by category
      final cat = expense.category.isNotEmpty ? expense.category : AppConstants.categoryOther;
      categorySpendingCents[cat] = (categorySpendingCents[cat] ?? 0.0) + amountInCents;

      // Track payments
      final payer = expense.paidBy;
      memberPaidCents[payer] = (memberPaidCents[payer] ?? 0.0) + amountInCents;

      if (payer == currentUserId) {
        userPaidCents += amountInCents;
      } else if (payer == partnerId || members.length <= 2) {
        partnerPaidCents += amountInCents;
      }

      // Compute participant shares for this expense
      final shares = expense.calculateShares(members);
      shares.forEach((memberId, shareAmount) {
        final shareInCents = shareAmount * 100.0;
        memberShareCents[memberId] = (memberShareCents[memberId] ?? 0.0) + shareInCents;

        if (memberId == currentUserId) {
          userShareCents += shareInCents;
        } else if (memberId == partnerId || members.length <= 2) {
          partnerShareCents += shareInCents;
        }
      });
    }

    final totalSpent = ((totalSpentCents.round()) / 100.0);
    final fairSharePerPerson = members.isNotEmpty
        ? ((totalSpentCents / members.length).round() / 100.0)
        : ((totalSpentCents / 2.0).round() / 100.0);

    final userPaid = ((userPaidCents.round()) / 100.0);
    final partnerPaid = ((partnerPaidCents.round()) / 100.0);
    final userShare = ((userShareCents.round()) / 100.0);
    final partnerShare = ((partnerShareCents.round()) / 100.0);

    // Net balance calculation:
    // Net Position = Amount Paid - Assigned Share
    // If netCents > 0, the member is owed money.
    // If netCents < 0, the member owes money.
    final netCents = userPaidCents - userShareCents;
    final netBalance = (netCents / 100.0);
    final roundedNetBalance = (netBalance * 100).round() / 100.0;
    final amountOwed = (roundedNetBalance.abs());

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
      payerId = partnerId.isNotEmpty ? partnerId : null;
      receiverId = currentUserId;
    } else {
      statusText = 'You owe $partnerName';
      payerId = currentUserId;
      receiverId = partnerId.isNotEmpty ? partnerId : null;
    }

    final memberNetBalances = <String, double>{};
    final memberTotalPaid = <String, double>{};
    final memberTotalShare = <String, double>{};
    final categorySpending = <String, double>{};

    for (final id in members) {
      final paid = (memberPaidCents[id] ?? 0) / 100.0;
      final share = (memberShareCents[id] ?? 0) / 100.0;
      memberTotalPaid[id] = paid;
      memberTotalShare[id] = share;
      memberNetBalances[id] = (paid - share);
    }

    categorySpendingCents.forEach((cat, cents) {
      categorySpending[cat] = cents / 100.0;
    });

    return BalanceResult(
      totalSpent: totalSpent,
      fairSharePerPerson: fairSharePerPerson,
      userPaid: userPaid,
      partnerPaid: partnerPaid,
      userShare: userShare,
      partnerShare: partnerShare,
      netBalance: roundedNetBalance,
      amountOwed: amountOwed,
      payerId: payerId,
      receiverId: receiverId,
      isSettled: isSettled,
      statusText: statusText,
      partnerName: partnerName,
      memberNetBalances: memberNetBalances,
      memberTotalPaid: memberTotalPaid,
      memberTotalShare: memberTotalShare,
      categorySpending: categorySpending,
    );
  }
}
