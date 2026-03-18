import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../constants/app_colors.dart';

class AdminStatCard extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final bool wide;
  final bool useExpanded;

  const AdminStatCard({
    super.key,
    required this.label,
    required this.value,
    required this.icon,
    this.wide = false,
    this.useExpanded = true,
  });

  @override
  Widget build(BuildContext context) {
    final card = Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.cardDark,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          Icon(icon, color: AppColors.accentRed, size: 24),
          const SizedBox(height: 8),
          Text(
            value,
            style: GoogleFonts.outfit(
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
          Text(
            label,
            style: GoogleFonts.outfit(color: Colors.white54, fontSize: 12),
          ),
        ],
      ),
    );
    if (!useExpanded) return card;
    return Expanded(flex: wide ? 2 : 1, child: card);
  }
}
