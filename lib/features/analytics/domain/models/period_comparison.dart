class PeriodComparison {
  final double currentSpending;
  final double previousSpending;
  final double absoluteDifference;
  final double percentageChange; // Positive indicates increase, negative indicates decrease
  final bool hasIncreased;
  final bool isUnchanged;

  const PeriodComparison({
    required this.currentSpending,
    required this.previousSpending,
    required this.absoluteDifference,
    required this.percentageChange,
    required this.hasIncreased,
    required this.isUnchanged,
  });

  factory PeriodComparison.calculate({
    required double current,
    required double previous,
  }) {
    final diff = current - previous;
    final isZero = diff.abs() < 0.01;
    final percentage = previous > 0
        ? ((current - previous) / previous) * 100.0
        : (current > 0 ? 100.0 : 0.0);

    return PeriodComparison(
      currentSpending: current,
      previousSpending: previous,
      absoluteDifference: diff.abs(),
      percentageChange: double.parse(percentage.toStringAsFixed(1)),
      hasIncreased: diff > 0.009,
      isUnchanged: isZero,
    );
  }

  String get trendText {
    if (isUnchanged) return 'Same as last period';
    final sign = percentageChange > 0 ? '+' : '';
    return '$sign${percentageChange.toStringAsFixed(1)}% vs previous';
  }
}
