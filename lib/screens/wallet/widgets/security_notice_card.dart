import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../constants/app_colors.dart';

class SecurityNoticeCard extends StatelessWidget {
  const SecurityNoticeCard({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
      ),
      child: Row(
        children: [
          Icon(Icons.shield_outlined, size: 20, color: AppColors.accentRed.withValues(alpha: 0.6)),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              'Your wallet keys are stored securely on this device. Never share your seed phrase or private key.',
              style: GoogleFonts.outfit(fontSize: 12, color: Colors.white.withValues(alpha: 0.4), height: 1.4),
            ),
          ),
        ],
      ),
    );
  }
}
