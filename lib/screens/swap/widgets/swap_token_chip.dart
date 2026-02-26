import 'package:flutter/material.dart';

import '../../../constants/app_colors.dart';
import '../../../models/token.dart';

class SwapTokenChip extends StatelessWidget {
  final Token? token;
  final VoidCallback onTap;

  const SwapTokenChip({
    super.key,
    required this.token,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final symbol = token?.symbol ?? '--';
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 24,
              height: 24,
              decoration: const BoxDecoration(
                color: AppColors.accentRed,
                shape: BoxShape.circle,
              ),
              child: token?.imageUrl != null
                  ? ClipOval(
                      child: Image.network(
                        token!.imageUrl!,
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) => _defaultIcon(symbol),
                      ),
                    )
                  : _defaultIcon(symbol),
            ),
            const SizedBox(width: 6),
            Text(
              symbol,
              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Colors.white),
            ),
            const SizedBox(width: 4),
            Icon(Icons.keyboard_arrow_down, size: 16, color: Colors.white.withValues(alpha: 0.7)),
          ],
        ),
      ),
    );
  }

  Widget _defaultIcon(String symbol) {
    return Center(
      child: Text(
        symbol.isNotEmpty ? symbol[0] : '?',
        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.white),
      ),
    );
  }
}
