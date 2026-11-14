import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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
    final blockchain = Provider.of<BlockchainService>(context);
    return AppChainTheme.forNetworkKey(blockchain.activeNetworkKey).accentColor;
  } catch (_) {
    try {
      final blockchain = Provider.of<BlockchainService>(context, listen: false);
      return AppChainTheme.forNetworkKey(
        blockchain.activeNetworkKey,
      ).accentColor;
    } catch (_) {
      return AppChainTheme.fomowlSignature.accentColor;
    }
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

/// Shared status pill badge matching Figma (#5888:9025 / #5888:9591).
class BurstStatusBadge extends StatelessWidget {
  const BurstStatusBadge({
    super.key,
    required this.status,
    this.showDot = false,
  });

  final String status;
  final bool showDot;

  @override
  Widget build(BuildContext context) {
    final normalized = status.toLowerCase();
    final accent = burstAccent(context);
    final (label, textColor, fillColor, borderColor) = switch (normalized) {
      'active' => (
        'Active',
        accent,
        accent.withValues(alpha: 0.14),
        accent.withValues(alpha: 0.28),
      ),
      'root_pending' => (
        'Triggering',
        const Color(0xFFFC9915),
        const Color(0x24FC9915),
        const Color(0x47FC9915),
      ),
      'claiming' => (
        'Claiming',
        const Color(0xFF18C783),
        const Color(0xFF14362B),
        const Color(0xFF1C604C),
      ),
      'completed' => (
        'Completed',
        const Color(0xFF18C783),
        const Color(0xFF14362B),
        const Color(0xFF1C604C),
      ),
      'cancelled' => (
        'Cancelled',
        const Color(0xFFFF8B91),
        const Color(0x26FF8B91),
        const Color(0x47FF8B91),
      ),
      _ => (
        status.isEmpty
            ? 'Draft'
            : '${status[0].toUpperCase()}${status.substring(1)}',
        Colors.white70,
        const Color(0xFF252525),
        Colors.white.withValues(alpha: 0.1),
      ),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: fillColor,
        border: Border.all(color: borderColor),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (showDot) ...[
            Container(
              width: 6,
              height: 6,
              decoration: BoxDecoration(
                color: textColor,
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 6),
          ],
          Text(
            label.toUpperCase(),
            style: TextStyle(
              color: textColor,
              fontSize: 10,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.4,
            ),
          ),
        ],
      ),
    );
  }
}

/// Shared invite code box matching Figma node 5888:9434 with copy action.
class BurstInviteCodeCard extends StatelessWidget {
  const BurstInviteCodeCard({
    super.key,
    required this.code,
    this.maxWidth = 342,
  });

  final String code;
  final double maxWidth;

  @override
  Widget build(BuildContext context) {
    final accent = burstAccent(context);
    final isCompactCode = code.length <= 12;
    return Center(
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: maxWidth),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          decoration: BoxDecoration(
            color: const Color(0x4D353534),
            border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Flexible(
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: SelectableText(
                    code,
                    maxLines: 1,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: accent,
                      fontSize: isCompactCode ? 28 : 18,
                      fontWeight: FontWeight.bold,
                      letterSpacing: isCompactCode ? 4.8 : 2.0,
                      height: 1.2,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 16),
              SizedBox(
                width: 40,
                height: 40,
                child: IconButton(
                  padding: EdgeInsets.zero,
                  tooltip: 'Copy code',
                  onPressed: () async {
                    await Clipboard.setData(ClipboardData(text: code));
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Invite code copied'),
                          duration: Duration(seconds: 2),
                        ),
                      );
                    }
                  },
                  icon: const Icon(
                    Icons.content_copy_rounded,
                    size: 20,
                    color: Color(0xFFB9CBBC),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
