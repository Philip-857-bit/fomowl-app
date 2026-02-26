import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../constants/app_colors.dart';

class SwapGaslessToggle extends StatelessWidget {
  final bool value;
  final ValueChanged<bool> onChanged;

  const SwapGaslessToggle({
    super.key,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.cardDark,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
      ),
      child: SwitchListTile(
        title: Row(
          children: [
            Icon(Icons.bolt, color: value ? AppColors.accentRed : Colors.white54, size: 20),
            const SizedBox(width: 8),
            Text(
              'Owllet Gasless Beta',
              style: GoogleFonts.outfit(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: value ? AppColors.accentRed : Colors.white,
              ),
            ),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: AppColors.primaryAccent.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                'BETA',
                style: GoogleFonts.outfit(fontSize: 10, fontWeight: FontWeight.w800, color: AppColors.primaryAccent),
              ),
            ),
          ],
        ),
        subtitle: Text(
          'Trade without paying native network gas fees. Powered by Owllet decentralized relayers.',
          style: GoogleFonts.outfit(fontSize: 12, color: Colors.white54),
        ),
        value: value,
        activeTrackColor: AppColors.primaryAccent,
        onChanged: onChanged,
      ),
    );
  }
}
