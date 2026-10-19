import 'package:flutter/material.dart';

import '../../../../constants/app_colors.dart';

class TransferHeader extends StatelessWidget {
  final VoidCallback onBack;
  final Color accentColor;

  const TransferHeader({
    super.key,
    required this.onBack,
    this.accentColor = AppColors.accentRed,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [accentColor.withValues(alpha: 0.2), AppColors.background],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ),
      ),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.arrow_back, color: Colors.white),
            onPressed: onBack,
          ),
          const Spacer(),
        ],
      ),
    );
  }
}
