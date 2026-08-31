import 'package:intl/intl.dart';

class DateFormatter {
  DateFormatter._();

  static final DateFormat _shortDate = DateFormat('MMM d, yyyy');
  static final DateFormat _shortDateTime = DateFormat('MMM d, yyyy • h:mm a');
  static final DateFormat _timeOnly = DateFormat('h:mm a');

  /// Formats a DateTime into a friendly relative string.
  /// Examples: "Just now", "5 minutes ago", "2 hours ago", "Yesterday", "MMM d, yyyy"
  static String formatRelative(DateTime dateTime) {
    final now = DateTime.now();
    final difference = now.difference(dateTime);

    if (difference.isNegative || difference.inSeconds < 45) {
      return 'Just now';
    } else if (difference.inMinutes < 60) {
      final mins = difference.inMinutes;
      return mins == 1 ? '1 minute ago' : '$mins minutes ago';
    } else if (difference.inHours < 24) {
      final hours = difference.inHours;
      return hours == 1 ? '1 hour ago' : '$hours hours ago';
    } else if (difference.inDays == 1) {
      return 'Yesterday at ${_timeOnly.format(dateTime)}';
    } else if (difference.inDays < 7) {
      return '${difference.inDays} days ago';
    } else {
      return _shortDate.format(dateTime);
    }
  }

  static String formatFull(DateTime dateTime) {
    return _shortDateTime.format(dateTime);
  }

  static String formatDateOnly(DateTime dateTime) {
    return _shortDate.format(dateTime);
  }
}
