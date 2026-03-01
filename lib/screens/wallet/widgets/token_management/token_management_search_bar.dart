import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../constants/app_colors.dart';

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
    return Container(
      decoration: BoxDecoration(
        color: AppColors.cardDark,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.divider),
      ),
      child: TextField(
        controller: controller,
        style: GoogleFonts.outfit(color: Colors.white),
        decoration: InputDecoration(
          hintText: 'Search token or paste contract address',
          hintStyle: GoogleFonts.outfit(color: Colors.white54),
          prefixIcon: const Icon(Icons.search, color: Colors.white54),
          suffixIcon: query.isEmpty
              ? null
              : IconButton(
                  onPressed: controller.clear,
                  icon: const Icon(Icons.close, color: Colors.white54),
                ),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(vertical: 16),
        ),
      ),
    );
  }
}
