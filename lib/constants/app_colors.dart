import 'package:flutter/material.dart';

/// FOMOwl Wallet Color Palette
/// Upgraded Premium Neo-Dark System
class AppColors {
  // Primary Colors (OLED friendly)
  static const Color background = Color(0xFF060606); // True deep black
  static const Color primaryAccent = Color(0xFFE53935); // Vibrant modern red
  
  // Accent
  static const Color accentRed = Color(0xFFFF3344); // Neon glow red
  static const Color accentGradientStart = Color(0xFFFF4B4B);
  static const Color accentGradientEnd = Color(0xFF900B09);
  
  // Text Colors
  static const Color textPrimary = Color(0xFFF9F9F9); // Crisp off-white
  static const Color textSecondary = Color(0xFFA1A1AA); // Cool zinc gray
  
  // UI Colors
  static const Color cardBackground = Color(0xFF0A0A0B);
  static const Color cardDark = Color(0xFF121214); // Sleek surface for cards
  static const Color divider = Color(0xFF27272A); // Subtle dark borders
  static const Color inputBackground = Color(0xFF18181B);
  static const Color navBackground = Color(0xFF09090B); // Pure dark nav bar
  static const Color darkRed = Color(0xFF6C0808);
  
  // Status Colors
  static const Color success = Color(0xFF10B981); // Emerald
  static const Color error = Color(0xFFEF4444); // Red
  static const Color warning = Color(0xFFF59E0B); // Amber
  
  // Gradients
  static const LinearGradient primaryGradient = LinearGradient(
    colors: [Color(0xFFFF4B4B), Color(0xFF900B09)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient balanceGradient = LinearGradient(
    colors: [Color(0xFFFF4D5A), Color(0xFF7C0508)],
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
  );
}
