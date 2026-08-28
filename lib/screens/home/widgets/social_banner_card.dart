import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../constants/app_colors.dart';
import '../../../l10n/app_localizations.dart';
import '../../../theme/app_chain_theme.dart';

class SocialBannerCard extends StatelessWidget {
  final VoidCallback onTap;
  final EdgeInsetsGeometry margin;

  const SocialBannerCard({
    super.key,
    required this.onTap,
    this.margin = const EdgeInsets.symmetric(horizontal: 20),
  });

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final theme = context.chainTheme;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: margin,
        constraints: const BoxConstraints(minHeight: 99),
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: AppColors.topBarSurface,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
        ),
        child: Row(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: theme.accentColor.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(24),
              ),
              child: Icon(
                Icons.campaign_rounded,
                color: theme.accentColor,
                size: 24,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    l.joinOurCommunity,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.inter(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Telegram  •  @FOMOWL',
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: theme.accentColor,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
