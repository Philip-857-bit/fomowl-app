import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../l10n/app_localizations.dart';

class TokenManagementSearchBar extends StatelessWidget {
  final TextEditingController controller;
  final String query;

  const TokenManagementSearchBar({
    super.key,
    required this.controller,
    required this.query,
  });

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return Container(
      decoration: BoxDecoration(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white12),
      ),
      child: TextField(
        controller: controller,
        style: GoogleFonts.outfit(color: Colors.white),
        decoration: InputDecoration(
          hintText: l.searchTokenOrPasteContract,
          hintStyle: GoogleFonts.outfit(color: Colors.white54),
          prefixIcon: const Icon(Icons.search, color: Colors.white54),
          suffixIcon: query.isEmpty
              ? null
              : IconButton(
                  onPressed: controller.clear,
                  tooltip: l.clearSearch,
                  icon: const Icon(Icons.close, color: Colors.white54),
                ),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(vertical: 16),
        ),
      ),
    );
  }
}
