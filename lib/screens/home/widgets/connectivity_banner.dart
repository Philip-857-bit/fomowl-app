import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../constants/app_colors.dart';

class ConnectivityBanner extends StatelessWidget {
  final bool show;
  final String statusText;

  const ConnectivityBanner({
    super.key,
    required this.show,
    required this.statusText,
  });

  @override
  Widget build(BuildContext context) {
    if (!show) return const SizedBox.shrink();
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      color: AppColors.error.withValues(alpha: 0.1),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.wifi_off, size: 14, color: AppColors.error),
          const SizedBox(width: 8),
          Text(
            statusText,
            style: GoogleFonts.outfit(fontSize: 13, color: AppColors.error),
          ),
        ],
      ),
    );
  }
}
