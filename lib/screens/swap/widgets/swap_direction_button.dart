import 'package:flutter/material.dart';

import '../../../constants/app_colors.dart';

class SwapDirectionButton extends StatelessWidget {
  final VoidCallback onPressed;

  const SwapDirectionButton({super.key, required this.onPressed});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: GestureDetector(
        onTap: onPressed,
        child: Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: AppColors.accentRed,
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: AppColors.accentRed.withValues(alpha: 0.4),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: const Icon(Icons.swap_vert, color: Colors.white, size: 22),
        ),
      ),
    );
  }
}
