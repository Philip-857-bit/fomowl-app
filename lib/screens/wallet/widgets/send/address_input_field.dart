import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../constants/app_colors.dart';

class AddressInputField extends StatelessWidget {
  final TextEditingController controller;
  final bool isInterTransfer;
  final VoidCallback? onQrTap;

  const AddressInputField({
    super.key,
    required this.controller,
    required this.isInterTransfer,
    this.onQrTap,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'TO',
          style: GoogleFonts.outfit(
            fontSize: 11,
            fontWeight: FontWeight.w500,
            letterSpacing: 1,
            color: Colors.white.withValues(alpha: 0.5),
          ),
        ),
        const SizedBox(height: 10),
        Container(
          decoration: BoxDecoration(
            color: AppColors.cardDark,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
          ),
          child: TextField(
            controller: controller,
            style: GoogleFonts.outfit(color: Colors.white, fontSize: 14),
            decoration: InputDecoration(
              hintText: isInterTransfer ? 'Fomowl Email or Username' : 'Receiving address',
              hintStyle: GoogleFonts.outfit(fontSize: 14, color: Colors.white.withValues(alpha: 0.3)),
              border: InputBorder.none,
              contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 16),
              suffixIcon: !isInterTransfer && onQrTap != null
                  ? IconButton(
                      icon: const Icon(Icons.qr_code_scanner, color: Color(0xFFE00000), size: 22),
                      onPressed: onQrTap,
                    )
                  : null,
            ),
          ),
        ),
      ],
    );
  }
}
