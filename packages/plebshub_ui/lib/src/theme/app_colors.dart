import 'package:flutter/material.dart';

/// PlebsHub color palette
abstract final class AppColors {
  // Background
  static const background = Color(0xFF0D0D0D);
  static const surface = Color(0xFF1A1A1A);
  static const surfaceVariant = Color(0xFF242424);
  static const surfaceHover = Color(0xFF2A2A2A);

  // Primary (Bitcoin orange)
  static const primary = Color(0xFFF7931A);
  static const primaryVariant = Color(0xFFFF9500);
  static const primaryDark = Color(0xFFCC7A15);

  // Text
  static const textPrimary = Color(0xFFFFFFFF);
  static const textSecondary = Color(0xFFAAAAAA);
  static const textTertiary = Color(0xFF666666);
  static const textDisabled = Color(0xFF444444);

  // Semantic
  static const success = Color(0xFF4CAF50);
  static const error = Color(0xFFE53935);
  static const warning = Color(0xFFFFC107);
  static const info = Color(0xFF2196F3);

  // Zap specific
  static const zapGold = Color(0xFFFFD700);
  static const zapOrange = Color(0xFFF7931A);
  static const zapGlow = Color(0x40FFD700);

  // Borders
  static const border = Color(0xFF333333);
  static const borderLight = Color(0xFF444444);

  // Overlay
  static const overlay = Color(0x80000000);

  // Light theme variants
  static const lightBackground = Color(0xFFF5F5F5);
  static const lightSurface = Color(0xFFFFFFFF);
  static const lightTextPrimary = Color(0xFF1A1A1A);
  static const lightTextSecondary = Color(0xFF666666);
}
