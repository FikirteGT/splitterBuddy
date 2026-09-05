import 'package:flutter/material.dart';

class AppColors {
  AppColors._();

  // Primary brand colors
  static const Color primary = Color(0xFF10B981); // Vibrant Emerald
  static const Color primaryLight = Color(0xFF34D399);
  static const Color primaryDark = Color(0xFF059669);

  // Secondary accent colors
  static const Color secondary = Color(0xFF6366F1); // Indigo Accent
  static const Color secondaryLight = Color(0xFF818CF8);
  static const Color secondaryDark = Color(0xFF4F46E5);

  // Neutral tones (Dark mode first / High contrast)
  static const Color background = Color(0xFF0F172A); // Slate 900
  static const Color surface = Color(0xFF1E293B);    // Slate 800
  static const Color card = Color(0xFF1E293B);       // Slate 800
  static const Color surfaceElevated = Color(0xFF334155); // Slate 700
  static const Color cardBorder = Color(0xFF334155);

  // Text colors
  static const Color textPrimary = Color(0xFFF8FAFC);
  static const Color textSecondary = Color(0xFF94A3B8);
  static const Color textMuted = Color(0xFF64748B);

  // Status & semantic colors
  static const Color success = Color(0xFF10B981);
  static const Color warning = Color(0xFFF59E0B);
  static const Color error = Color(0xFFEF4444);
  static const Color info = Color(0xFF38BDF8);

  // Action chips & badges
  static const Color badgeGreenBg = Color(0x2210B981);
  static const Color badgeAmberBg = Color(0x22F59E0B);
  static const Color badgeRedBg = Color(0x22EF4444);
  static const Color badgeBlueBg = Color(0x2238BDF8);

  // Balance specific
  static const Color owesYou = Color(0xFF10B981); // Green - You receive
  static const Color youOwe = Color(0xFFEF4444);  // Red - You pay
  static const Color settled = Color(0xFF94A3B8); // Grey - Zero balance
}
