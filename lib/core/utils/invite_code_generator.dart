import 'dart:math';

class InviteCodeGenerator {
  InviteCodeGenerator._();

  // Distinct uppercase alphanumeric characters avoiding confusion (e.g., no '0', 'O', '1', 'I')
  static const String _chars = '23456789ABCDEFGHJKLMNPQRSTUVWXYZ';
  static final Random _random = Random.secure();

  /// Generates a random, collision-resistant 6-character uppercase invite code.
  static String generate([int length = 6]) {
    return List.generate(
      length,
      (_) => _chars[_random.nextInt(_chars.length)],
    ).join();
  }

  /// Normalizes and validates a user-entered invite code.
  static String normalize(String code) {
    return code.trim().toUpperCase();
  }

  static bool isValidFormat(String code) {
    final normalized = normalize(code);
    if (normalized.length != 6) return false;
    final regex = RegExp(r'^[A-Z0-9]{6}$');
    return regex.hasMatch(normalized);
  }
}
