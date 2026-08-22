import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../../../theme/theme_controller.dart';

/// Wallet Theme Selector modal / bottom sheet matching Figma #318:2526 & #318:2332.
/// Allows toggling between Classic (Owllet Default Mode) and Adaptive Theme.
class WalletThemeSelectorSheet extends StatelessWidget {
  const WalletThemeSelectorSheet({super.key});

  static Future<void> show(BuildContext context) {
    return showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => const WalletThemeSelectorSheet(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final themeController = context.watch<ThemeController>();
    final isClassic = themeController.isClassic;
    final isAdaptive = themeController.isAdaptive;

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 20),
        child: Container(
          decoration: BoxDecoration(
            color: const Color(0xFF171717),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: Colors.white.withValues(alpha: 0.08),
              width: 1,
            ),
            boxShadow: const [
              BoxShadow(
                color: Color(0x33000000),
                blurRadius: 16,
                offset: Offset(0, 8),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Sheet Drag handle & Header with Close "X"
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 16, 12),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Wallet Theme',
                      style: GoogleFonts.inter(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    IconButton(
                      icon: const Icon(
                        Icons.close_rounded,
                        color: Colors.white,
                        size: 20,
                      ),
                      onPressed: () => Navigator.of(context).pop(),
                      splashRadius: 20,
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(
                        minWidth: 32,
                        minHeight: 32,
                      ),
                    ),
                  ],
                ),
              ),
              Divider(
                color: Colors.white.withValues(alpha: 0.05),
                height: 1,
                thickness: 1,
              ),

              // Option 1: Classic (Owllet Default Mode)
              _buildThemeOptionTile(
                title: 'Classic',
                subtitle: '(Owllet Default Mode)',
                isActive: isClassic,
                onTap: () {
                  themeController.setThemeMode(AppThemeMode.classic);
                },
              ),
              Divider(
                color: Colors.white.withValues(alpha: 0.05),
                height: 1,
                thickness: 1,
              ),

              // Option 2: Adaptive Theme
              _buildThemeOptionTile(
                title: 'Adaptive Theme',
                subtitle: 'Dynamic colors matching active network',
                isActive: isAdaptive,
                onTap: () {
                  themeController.setThemeMode(AppThemeMode.adaptive);
                },
              ),
              const SizedBox(height: 12),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildThemeOptionTile({
    required String title,
    required String subtitle,
    required bool isActive,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: GoogleFonts.inter(
                        color: Colors.white,
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      subtitle,
                      style: GoogleFonts.inter(
                        color: const Color(0xFF94A3B8),
                        fontSize: 12,
                        fontWeight: FontWeight.w400,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              // Custom Toggle Switch matching Figma #318:2526 & #318:2332
              _FigmaToggleSwitch(value: isActive, onChanged: (_) => onTap()),
            ],
          ),
        ),
      ),
    );
  }
}

/// Pill toggle switch styled after Figma #318:2526 and #318:2332
class _FigmaToggleSwitch extends StatelessWidget {
  const _FigmaToggleSwitch({required this.value, required this.onChanged});

  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    const double width = 48.0;
    const double height = 24.0;
    const double thumbSize = 20.0;
    const double padding = 2.0;

    final trackColor = value
        ? const Color(0xFFEA2A33) // Active red in Figma
        : const Color(0xFF2D2D2E); // Inactive dark in Figma

    final thumbColor = value ? Colors.white : const Color(0xFF6C6C6D);

    return GestureDetector(
      onTap: () => onChanged(!value),
      behavior: HitTestBehavior.opaque,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeInOut,
        width: width,
        height: height,
        decoration: BoxDecoration(
          color: trackColor,
          borderRadius: BorderRadius.circular(height / 2),
        ),
        padding: const EdgeInsets.symmetric(horizontal: padding),
        child: AnimatedAlign(
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeInOut,
          alignment: value ? Alignment.centerRight : Alignment.centerLeft,
          child: Container(
            width: thumbSize,
            height: thumbSize,
            decoration: BoxDecoration(
              color: thumbColor,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.25),
                  blurRadius: 4,
                  offset: const Offset(0, 1),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
