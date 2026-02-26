import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../constants/app_colors.dart';

class TokenActionData {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const TokenActionData({
    required this.icon,
    required this.label,
    required this.onTap,
  });
}

class TokenActionsRow extends StatelessWidget {
  final List<TokenActionData> actions;

  const TokenActionsRow({super.key, required this.actions});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: actions.map((action) {
        return GestureDetector(
          onTap: action.onTap,
          child: Column(
            children: [
              Container(
                width: 62,
                height: 62,
                decoration: const BoxDecoration(
                  color: AppColors.cardDark,
                  shape: BoxShape.circle,
                ),
                child: Icon(action.icon, color: AppColors.accentRed, size: 26),
              ),
              const SizedBox(height: 6),
              Text(action.label, style: GoogleFonts.outfit(color: Colors.white70)),
            ],
          ),
        );
      }).toList(),
    );
  }
}
