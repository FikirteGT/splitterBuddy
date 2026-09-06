import '../../../../core/constants/app_constants.dart';
import '../domain/models/settlement_obligation.dart';

class _MemberDebtEntry {
  final String userId;
  final String name;
  int cents;

  _MemberDebtEntry({
    required this.userId,
    required this.name,
    required this.cents,
  });
}

/// Pure, deterministic settlement debt minimization engine.
/// Reduces N-party circular and fragmented debts to the minimal transaction set (at most N-1 transactions).
class SettlementMinimizer {
  const SettlementMinimizer._();

  /// Calculates the minimal set of settlement obligations needed to resolve all balances.
  /// Uses integer-cents arithmetic to prevent rounding errors and financial discrepancies.
  static List<SettlementObligation> minimizeDebts({
    required Map<String, double> memberNetBalances,
    required Map<String, String> memberNames,
    required String workspaceId,
    required String periodId,
  }) {
    final List<_MemberDebtEntry> debtors = [];
    final List<_MemberDebtEntry> creditors = [];

    // Separate net debtors (< 0) and net creditors (> 0)
    memberNetBalances.forEach((userId, balance) {
      final cents = (balance * 100.0).round();
      final name = memberNames[userId] ?? 'Member';

      if (cents < 0) {
        debtors.add(_MemberDebtEntry(userId: userId, name: name, cents: -cents));
      } else if (cents > 0) {
        creditors.add(_MemberDebtEntry(userId: userId, name: name, cents: cents));
      }
    });

    // Deterministic sorting: largest amounts first, ties broken by userId
    debtors.sort((a, b) {
      final cmp = b.cents.compareTo(a.cents);
      return cmp != 0 ? cmp : a.userId.compareTo(b.userId);
    });

    creditors.sort((a, b) {
      final cmp = b.cents.compareTo(a.cents);
      return cmp != 0 ? cmp : a.userId.compareTo(b.userId);
    });

    final List<SettlementObligation> obligations = [];
    int debtorIdx = 0;
    int creditorIdx = 0;
    final now = DateTime.now();

    while (debtorIdx < debtors.length && creditorIdx < creditors.length) {
      final debtor = debtors[debtorIdx];
      final creditor = creditors[creditorIdx];

      final settleCents = debtor.cents < creditor.cents ? debtor.cents : creditor.cents;

      if (settleCents > 0) {
        final amount = (settleCents / 100.0);
        final obligationId = 'obl_${workspaceId}_${periodId}_${debtor.userId}_${creditor.userId}';

        obligations.add(SettlementObligation(
          id: obligationId,
          workspaceId: workspaceId,
          periodId: periodId,
          fromUserId: debtor.userId,
          toUserId: creditor.userId,
          fromUserName: debtor.name,
          toUserName: creditor.name,
          originalAmount: (amount * 100).round() / 100.0,
          settledAmount: 0.0,
          status: AppConstants.obligationOpen,
          createdAt: now,
          updatedAt: now,
        ));

        debtor.cents -= settleCents;
        creditor.cents -= settleCents;
      }

      if (debtor.cents <= 0) {
        debtorIdx++;
      }
      if (creditor.cents <= 0) {
        creditorIdx++;
      }
    }

    return obligations;
  }
}
