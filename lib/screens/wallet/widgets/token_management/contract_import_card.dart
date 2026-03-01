import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../constants/app_colors.dart';

class ContractImportCard extends StatelessWidget {
  final bool isLoading;
  final VoidCallback onAdd;

  const ContractImportCard({
    super.key,
    required this.isLoading,
    required this.onAdd,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.cardDark,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.accentRed.withValues(alpha: 0.35)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              'Contract detected. Import token metadata automatically.',
              style: GoogleFonts.outfit(fontSize: 13, color: Colors.white70),
            ),
          ),
          const SizedBox(width: 12),
          ElevatedButton(
            onPressed: isLoading ? null : onAdd,
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.accentRed,
              foregroundColor: Colors.white,
            ),
            child: isLoading
                ? const SizedBox(
                    width: 14,
                    height: 14,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : Text('Add', style: GoogleFonts.outfit(fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
  }
}
