import 'package:flutter/material.dart';

import '../../../theme/app_chain_theme.dart';
import 'swap_figma_icons.dart';

class SwapDirectionButton extends StatelessWidget {
  final VoidCallback onPressed;

  const SwapDirectionButton({super.key, required this.onPressed});

  @override
  Widget build(BuildContext context) {
    final theme = context.chainTheme;

    return Center(
      child: GestureDetector(
        onTap: onPressed,
        child: Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: const Color(0xFF000000),
            shape: BoxShape.circle,
            border: Border.all(color: const Color(0xFF121212), width: 4),
          ),
          child: Center(
            child: FigmaSwapDirectionIcon(color: theme.accentColor, width: 16),
          ),
        ),
      ),
    );
  }
}
