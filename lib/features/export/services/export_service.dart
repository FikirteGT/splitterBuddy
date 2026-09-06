import 'package:csv/csv.dart';
import 'package:splitterbuddy/core/constants/app_constants.dart';
import 'package:splitterbuddy/core/utils/currency_formatter.dart';
import 'package:splitterbuddy/core/utils/date_formatter.dart';
import 'package:splitterbuddy/features/expenses/domain/models/expense.dart';
import 'package:splitterbuddy/features/expenses/domain/models/expense_category.dart';
import 'package:splitterbuddy/features/workspace/domain/models/workspace.dart';

class ExportService {
  const ExportService._();

  /// Generates a standardized CSV string for workspace expenses.
  /// Enforces workspace authorization by ensuring currentUserId is in workspace.members.
  static String generateExpensesCsv({
    required Workspace workspace,
    required String currentUserId,
    required List<Expense> expenses,
    required Map<String, String> memberNames,
  }) {
    // Authorization check
    if (!workspace.members.contains(currentUserId)) {
      throw Exception('Unauthorized: You are not a member of this workspace.');
    }

    final List<List<dynamic>> rows = [];

    // Header Row
    rows.add([
      'Date',
      'Description',
      'Category',
      'Amount (ETB)',
      'Paid By',
      'Split Method',
      'Member Shares',
      'Receipt Attached',
      'Recurring',
      'Status',
    ]);

    for (final exp in expenses) {
      if (exp.isDeleted) continue;

      final cat = ExpenseCategory.find(exp.category).name;
      final payerName = memberNames[exp.paidBy] ?? exp.paidBy;
      final splitMethod = exp.splitType == AppConstants.splitEqual
          ? '50/50 Equal'
          : exp.splitType == AppConstants.splitCustom
              ? 'Custom Amount'
              : exp.splitType == AppConstants.splitPercentage
                  ? 'Percentage'
                  : 'Paid for One';

      final shares = exp.calculateShares(workspace.members);
      final shareString = shares.entries
          .map((e) => '${memberNames[e.key] ?? e.key}: ${CurrencyFormatter.format(e.value)}')
          .join(' | ');

      rows.add([
        DateFormatter.formatDateOnly(exp.createdAt),
        exp.description,
        cat,
        exp.amount.toStringAsFixed(2),
        payerName,
        splitMethod,
        shareString,
        exp.hasReceipt ? 'Yes' : 'No',
        exp.isRecurring ? 'Yes' : 'No',
        exp.status,
      ]);
    }

    return const ListToCsvConverter().convert(rows);
  }

  /// Generates a clean text summary of monthly finances for sharing or quick export.
  static String generateTextSummary({
    required Workspace workspace,
    required String periodLabel,
    required double totalSpending,
    required double userPaid,
    required double partnerPaid,
    required double balance,
    required String partnerName,
  }) {
    final buffer = StringBuffer();
    buffer.writeln('========================================');
    buffer.writeln('SPLITTERBUD FINANCIAL REPORT');
    buffer.writeln('Workspace: ${workspace.name}');
    buffer.writeln('Period: $periodLabel');
    buffer.writeln('========================================');
    buffer.writeln('Total Spending: ${CurrencyFormatter.format(totalSpending)}');
    buffer.writeln('You Paid: ${CurrencyFormatter.format(userPaid)}');
    buffer.writeln('$partnerName Paid: ${CurrencyFormatter.format(partnerPaid)}');
    buffer.writeln('----------------------------------------');
    if (balance.abs() < 0.01) {
      buffer.writeln('Balance: All settled up (0.00 ETB)');
    } else if (balance > 0) {
      buffer.writeln('Balance: $partnerName owes you ${CurrencyFormatter.format(balance)}');
    } else {
      buffer.writeln('Balance: You owe $partnerName ${CurrencyFormatter.format(balance.abs())}');
    }
    buffer.writeln('========================================');
    return buffer.toString();
  }
}
