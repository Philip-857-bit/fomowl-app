import 'package:flutter/material.dart';

import '../../theme/app_chain_theme.dart';

const burstButtonShape = RoundedRectangleBorder(
  borderRadius: BorderRadius.all(Radius.circular(10)),
);

/// The mark and title used by the Burst creation and join screens.
class BurstHeader extends StatelessWidget {
  const BurstHeader({super.key});

  @override
  Widget build(BuildContext context) {
    final accent = burstAccent(context);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Image.asset(
          'assets/burst/create_icon.png',
          width: 48,
          height: 27,
          fit: BoxFit.contain,
          color: accent == const Color(0xffea2a33) ? null : accent,
          colorBlendMode: BlendMode.srcIn,
          excludeFromSemantics: true,
        ),
        const SizedBox(width: 8),
        const Text(
          'Burst',
          style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
        ),
      ],
    );
  }
}

/// Preserve the Burst design in Classic while following the active network in
/// the wallet's Adaptive theme.
Color burstAccent(BuildContext context) {
  final theme = context.chainTheme;
  return theme.id == 'fomowl_signature'
      ? const Color(0xffea2a33)
      : theme.accentColor;
}

Color burstOnAccent(BuildContext context) =>
    ThemeData.estimateBrightnessForColor(burstAccent(context)) ==
        Brightness.light
    ? Colors.black
    : Colors.white;

/// Applies the active wallet accent to Material controls on each Burst route.
class BurstPageRoute<T> extends MaterialPageRoute<T> {
  BurstPageRoute({required WidgetBuilder builder})
    : super(
        builder: (context) =>
            _BurstRouteTheme(child: Builder(builder: builder)),
      );
}

class _BurstRouteTheme extends StatelessWidget {
  const _BurstRouteTheme({required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Theme(
      data: theme.copyWith(
        colorScheme: theme.colorScheme.copyWith(
          primary: burstAccent(context),
          onPrimary: burstOnAccent(context),
          secondary: burstAccent(context),
          onSecondary: burstOnAccent(context),
        ),
      ),
      child: child,
    );
  }
}
