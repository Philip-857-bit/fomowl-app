import 'package:flutter/material.dart';

import 'swap_figma_icons.dart';

class SwapDirectionButton extends StatelessWidget {
  final VoidCallback onPressed;

  const SwapDirectionButton({super.key, required this.onPressed});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: GestureDetector(
        onTap: onPressed,
        child: Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: const Color(0xFF000000),
            shape: BoxShape.circle,
            border: Border.all(color: const Color(0xFF131313), width: 4),
          ),
          child: const Center(
            child: FigmaSwapDirectionIcon(color: Color(0xFFEA2A33), width: 16),
          ),
        ),
      ),
    );
  }
}
