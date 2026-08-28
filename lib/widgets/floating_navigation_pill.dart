import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../constants/app_colors.dart';
import '../theme/app_chain_theme.dart';

class FloatingNavigationDestinationData {
  const FloatingNavigationDestinationData({
    required this.icon,
    required this.selectedIcon,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final IconData icon;
  final IconData selectedIcon;
  final String label;
  final bool selected;
  final VoidCallback onTap;
}

/// Shared floating, blurred navigation surface used by both the app shell and
/// legacy standalone screens.
class FloatingNavigationPill extends StatelessWidget {
  const FloatingNavigationPill({super.key, required this.destinations});

  final List<FloatingNavigationDestinationData> destinations;

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.paddingOf(context).bottom;
    return ColoredBox(
      color: Colors.transparent,
      child: Padding(
        padding: EdgeInsets.fromLTRB(14, 4, 14, 12 + bottomInset),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(30),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 22, sigmaY: 22),
            child: Container(
              key: const ValueKey('floating-bottom-navigation'),
              height: 70,
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 7),
              decoration: BoxDecoration(
                color: AppColors.navBackground.withValues(alpha: 0.9),
                borderRadius: BorderRadius.circular(30),
                border: Border.all(color: Colors.white.withValues(alpha: 0.09)),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.45),
                    blurRadius: 30,
                    offset: const Offset(0, 14),
                  ),
                ],
              ),
              child: Row(
                children: destinations
                    .map(
                      (destination) => Expanded(
                        child: _NavigationItem(destination: destination),
                      ),
                    )
                    .toList(growable: false),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _NavigationItem extends StatelessWidget {
  const _NavigationItem({required this.destination});

  final FloatingNavigationDestinationData destination;

  @override
  Widget build(BuildContext context) {
    final accent = context.chainTheme.accentColor;
    final selected = destination.selected;
    return Semantics(
      selected: selected,
      button: true,
      label: destination.label,
      child: InkWell(
        onTap: destination.onTap,
        borderRadius: BorderRadius.circular(22),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOutCubic,
          decoration: BoxDecoration(
            color: selected
                ? accent.withValues(alpha: 0.12)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(22),
          ),
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                selected ? destination.selectedIcon : destination.icon,
                color: selected ? accent : Colors.white.withValues(alpha: 0.48),
                size: 21,
              ),
              const SizedBox(height: 4),
              Text(
                destination.label,
                maxLines: 1,
                overflow: TextOverflow.fade,
                softWrap: false,
                style: GoogleFonts.inter(
                  color: selected
                      ? Colors.white
                      : Colors.white.withValues(alpha: 0.46),
                  fontSize: 10,
                  fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
