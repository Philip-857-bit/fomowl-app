import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../constants/app_colors.dart';

class SwapNetworkCard extends StatelessWidget {
  const SwapNetworkCard({
    super.key,
    required this.networkName,
    required this.accentColor,
    required this.canSwitch,
    this.logoUrl,
    this.onChangeNetwork,
  });

  final String networkName;
  final Color accentColor;
  final bool canSwitch;
  final String? logoUrl;
  final VoidCallback? onChangeNetwork;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Network',
          style: GoogleFonts.inter(
            fontSize: 12,
            fontWeight: FontWeight.w500,
            color: const Color(0xFF8894A0),
            letterSpacing: 0.3,
          ),
        ),
        const SizedBox(height: 8),
        Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: canSwitch ? onChangeNetwork : null,
            borderRadius: BorderRadius.circular(8),
            child: Ink(
              padding: const EdgeInsets.all(13),
              decoration: BoxDecoration(
                color: const Color(0xFF151C24),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: const Color(0xFF2A333D)),
              ),
              child: Row(
                children: [
                  Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      color: accentColor.withAlpha(40),
                      shape: BoxShape.circle,
                    ),
                    clipBehavior: Clip.antiAlias,
                    child: logoUrl != null && logoUrl!.isNotEmpty
                        ? Image.network(
                            logoUrl!,
                            width: 32,
                            height: 32,
                            fit: BoxFit.cover,
                            errorBuilder: (context, error, stackTrace) => Icon(
                              Icons.language,
                              color: accentColor,
                              size: 16,
                            ),
                          )
                        : Icon(Icons.language, color: accentColor, size: 16),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      networkName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.inter(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        color: Colors.white,
                      ),
                    ),
                  ),
                  if (canSwitch) ...[
                    Text(
                      'Change',
                      style: TextStyle(
                        fontSize: 11,
                        color: AppColors.textSecondary,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Icon(
                      Icons.keyboard_arrow_down_rounded,
                      size: 20,
                      color: AppColors.textSecondary,
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}
