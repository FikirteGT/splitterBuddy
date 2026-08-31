import 'package:intl/intl.dart';
import '../constants/app_constants.dart';

class CurrencyFormatter {
  CurrencyFormatter._();

  static final NumberFormat _formatterWithDecimals = NumberFormat('#,##0.00');
  static final NumberFormat _formatterCompact = NumberFormat('#,##0');

  /// Formats amount in ETB with standard symbol/suffix.
  /// Example: 1000 -> "1,000 ETB", 1000.5 -> "1,000.50 ETB"
  static String format(double amount, {String currency = AppConstants.defaultCurrency, bool forceDecimals = false}) {
    final hasFraction = (amount.abs() % 1.0) >= 0.01;
    final formattedNumber = (hasFraction || forceDecimals)
        ? _formatterWithDecimals.format(amount)
        : _formatterCompact.format(amount);
    return '$formattedNumber $currency';
  }

  /// Parses a string input into a valid monetary double.
  /// Returns null if invalid or <= 0.
  static double? parseAmount(String input) {
    final sanitized = input.trim().replaceAll(',', '');
    if (sanitized.isEmpty) return null;
    final value = double.tryParse(sanitized);
    if (value == null || value.isNaN || value.isInfinite || value <= 0) return null;
    // Round to 2 decimal places to prevent floating point drift
    return (value * 100).roundToDouble() / 100.0;
  }

  /// Safely rounds a double to 2 decimal places.
  static double roundMoney(double value) {
    return (value * 100).roundToDouble() / 100.0;
  }
}
