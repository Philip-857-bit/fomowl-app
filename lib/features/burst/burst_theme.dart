import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../services/blockchain_service.dart';
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
          color: accent,
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

/// Brand fallback, used only when a chain has no usable accent.
const Color burstPrimaryActionColor = Color(0xffea2a33);

/// Ambient glow for primary Burst actions, derived from the active accent.
List<BoxShadow> burstActionShadow(BuildContext context) => [
  BoxShadow(
    color: burstAccent(context).withValues(alpha: 0.30),
    blurRadius: 30,
    spreadRadius: 0,
    offset: Offset.zero,
  ),
];

/// Primary Burst accent follows the active chain theme (adaptive theming).
Color burstAccent(BuildContext context) {
  final accent = burstChainAccent(context);
  return accent.a == 0 ? burstPrimaryActionColor : accent;
}

Color burstOnAccent(BuildContext context) => burstOnChainAccent(context);

/// Tier 2: Dynamic chain accents strictly for network badges, tags, and selector borders.
Color burstChainAccent(BuildContext context) {
  try {
    final blockchain = Provider.of<BlockchainService>(context, listen: false);
    return AppChainTheme.forNetworkKey(blockchain.activeNetworkKey).accentColor;
  } catch (_) {
    return context.chainTheme.accentColor;
  }
}

Color burstOnChainAccent(BuildContext context) =>
    ThemeData.estimateBrightnessForColor(burstChainAccent(context)) ==
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
