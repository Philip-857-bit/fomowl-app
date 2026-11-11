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

/// Tier 1: Invariant brand electric red for primary CTAs, total highlights, and ambient glow.
const Color burstPrimaryActionColor = Color(0xffea2a33);

/// Ambient glow shadow for primary Burst action buttons per Figma.
const List<BoxShadow> burstPrimaryActionShadow = [
  BoxShadow(
    color: Color(0x4dea2a33), // rgba(234, 42, 51, 0.30)
    blurRadius: 30,
    spreadRadius: 0,
    offset: Offset.zero,
  ),
];

/// Tier 1: Invariant Electric Red (#EA2A33) across all chains for primary CTAs
/// and total highlights.
Color burstAccent(BuildContext context) => burstPrimaryActionColor;

Color burstOnAccent(BuildContext context) => Colors.white;

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
