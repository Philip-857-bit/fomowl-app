import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class SettingsSectionHeader extends StatelessWidget {
  final String title;

  const SettingsSectionHeader({
    super.key,
    required this.title,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 10, 24, 10),
      child: Text(
        title.toUpperCase(),
        style: GoogleFonts.outfit(
          fontSize: 14,
          letterSpacing: 2.0,
          fontWeight: FontWeight.w500,
          color: const Color(0xFF6C7A99),
        ),
      ),
    );
  }
}
