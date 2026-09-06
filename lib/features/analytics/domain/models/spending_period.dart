enum SpendingPeriodType {
  thisWeek,
  thisMonth,
  lastMonth,
  custom,
}

class SpendingPeriod {
  final SpendingPeriodType type;
  final DateTime startDate;
  final DateTime endDate;
  final String label;

  const SpendingPeriod({
    required this.type,
    required this.startDate,
    required this.endDate,
    required this.label,
  });

  static SpendingPeriod thisWeek([DateTime? now]) {
    final current = now ?? DateTime.now();
    // Monday as start of week
    final daysFromMonday = (current.weekday - 1) % 7;
    final start = DateTime(current.year, current.month, current.day - daysFromMonday);
    final end = DateTime(start.year, start.month, start.day + 6, 23, 59, 59, 999);
    return SpendingPeriod(
      type: SpendingPeriodType.thisWeek,
      startDate: start,
      endDate: end,
      label: 'This Week',
    );
  }

  static SpendingPeriod thisMonth([DateTime? now]) {
    final current = now ?? DateTime.now();
    final start = DateTime(current.year, current.month, 1);
    final lastDay = DateTime(current.year, current.month + 1, 0).day;
    final end = DateTime(current.year, current.month, lastDay, 23, 59, 59, 999);
    return SpendingPeriod(
      type: SpendingPeriodType.thisMonth,
      startDate: start,
      endDate: end,
      label: 'This Month',
    );
  }

  static SpendingPeriod lastMonth([DateTime? now]) {
    final current = now ?? DateTime.now();
    final start = DateTime(current.year, current.month - 1, 1);
    final lastDay = DateTime(start.year, start.month + 1, 0).day;
    final end = DateTime(start.year, start.month, lastDay, 23, 59, 59, 999);
    return SpendingPeriod(
      type: SpendingPeriodType.lastMonth,
      startDate: start,
      endDate: end,
      label: 'Last Month',
    );
  }

  static SpendingPeriod custom({
    required DateTime startDate,
    required DateTime endDate,
    String? label,
  }) {
    final start = DateTime(startDate.year, startDate.month, startDate.day);
    final end = DateTime(endDate.year, endDate.month, endDate.day, 23, 59, 59, 999);
    return SpendingPeriod(
      type: SpendingPeriodType.custom,
      startDate: start,
      endDate: end,
      label: label ?? 'Custom Period',
    );
  }

  bool contains(DateTime date) {
    return date.isAfter(startDate.subtract(const Duration(milliseconds: 1))) &&
        date.isBefore(endDate.add(const Duration(milliseconds: 1)));
  }
}
