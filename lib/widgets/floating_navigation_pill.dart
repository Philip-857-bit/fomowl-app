import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../theme/app_chain_theme.dart';

sealed class FloatingNavigationItemData {
  const FloatingNavigationItemData({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;
}

final class FloatingNavigationDestinationData
    extends FloatingNavigationItemData {
  const FloatingNavigationDestinationData({
    required super.icon,
    required this.selectedIcon,
    required super.label,
    required this.selected,
    required super.onTap,
  });

  final IconData selectedIcon;
  final bool selected;
}

final class FloatingNavigationActionData extends FloatingNavigationItemData {
  const FloatingNavigationActionData({
    required super.icon,
    required super.label,
    required super.onTap,
  });
}

/// Shared floating, blurred navigation surface used by both the app shell and
/// legacy standalone screens.
class FloatingNavigationPill extends StatelessWidget {
  const FloatingNavigationPill({super.key, required this.destinations});

  final List<FloatingNavigationItemData> destinations;

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.paddingOf(context).bottom;
    return ColoredBox(
      color: Colors.transparent,
      child: Padding(
        padding: EdgeInsets.fromLTRB(16, 4, 16, 8 + bottomInset),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(999),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
            child: Container(
              key: const ValueKey('floating-bottom-navigation'),
              height: 64,
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: const Color(0xEB1C1C1C),
                borderRadius: BorderRadius.circular(999),
                border: Border.all(color: Colors.white.withValues(alpha: 0.09)),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.4),
                    blurRadius: 20,
                    offset: const Offset(0, 8),
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

  final FloatingNavigationItemData destination;

  @override
  Widget build(BuildContext context) {
    final theme = context.chainTheme;
    final accent = theme.id == 'fomowl_signature'
        ? const Color(0xFFEA2A33)
        : theme.accentColor;
    final selected = switch (destination) {
      FloatingNavigationDestinationData item => item.selected,
      FloatingNavigationActionData() => false,
    };
    final isAction = destination is FloatingNavigationActionData;
    final icon = switch (destination) {
      FloatingNavigationDestinationData item when item.selected =>
        item.selectedIcon,
      _ => destination.icon,
    };

    final child = InkWell(
      onTap: destination.onTap,
      borderRadius: BorderRadius.circular(999),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOutCubic,
        decoration: BoxDecoration(
          color: isAction
              ? accent
              : selected
              ? accent.withValues(alpha: 0.16)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(999),
        ),
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              color: isAction
                  ? Colors.white
                  : selected
                  ? accent
                  : Colors.white.withValues(alpha: 0.65),
              size: 21,
            ),
            const SizedBox(height: 2),
            Text(
              destination.label,
              maxLines: 1,
              overflow: TextOverflow.fade,
              softWrap: false,
              style: GoogleFonts.inter(
                color: isAction || selected
                    ? Colors.white
                    : Colors.white.withValues(alpha: 0.65),
                fontSize: 10,
                fontWeight: isAction || selected
                    ? FontWeight.w600
                    : FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );

    if (isAction) {
      return Semantics(button: true, label: destination.label, child: child);
    }
    return Semantics(
      selected: selected,
      button: true,
      label: destination.label,
      child: child,
    );
  }
}
