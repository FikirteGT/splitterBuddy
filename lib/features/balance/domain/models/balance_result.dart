class BalanceResult {
  final double totalSpent;
  final double fairSharePerPerson;
  final double userPaid;
  final double partnerPaid;
  final double netBalance; // > 0: partner owes user; < 0: user owes partner; 0: settled
  final double amountOwed; // Absolute magnitude of the balance to be settled
  final String? payerId; // User who owes money
  final String? receiverId; // User who is owed money
  final bool isSettled;
  final String statusText;
  final String partnerName;

  const BalanceResult({
    required this.totalSpent,
    required this.fairSharePerPerson,
    required this.userPaid,
    required this.partnerPaid,
    required this.netBalance,
    required this.amountOwed,
    this.payerId,
    this.receiverId,
    required this.isSettled,
    required this.statusText,
    required this.partnerName,
  });

  /// Factory for a fresh zero-balance state.
  factory BalanceResult.zero({String partnerName = 'Partner'}) {
    return BalanceResult(
      totalSpent: 0.0,
      fairSharePerPerson: 0.0,
      userPaid: 0.0,
      partnerPaid: 0.0,
      netBalance: 0.0,
      amountOwed: 0.0,
      isSettled: true,
      statusText: 'All settled up',
      partnerName: partnerName,
    );
  }

  bool get doesPartnerOweUser => netBalance > 0.009;
  bool get doesUserOwePartner => netBalance < -0.009;
}
