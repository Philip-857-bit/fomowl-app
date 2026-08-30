import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../services/app_release_checker.dart';
import '../../../services/app_store_service.dart';
import '../../../widgets/forced_update_dialog.dart';

class WhatsNewSheet extends StatelessWidget {
  const WhatsNewSheet({super.key, required this.result, this.appStoreService});

  final WhatsNewResult result;
  final AppStoreService? appStoreService;

  static Future<void> show(BuildContext context, WhatsNewResult result) {
    if (result.isUpdateRequired) {
      return ForcedUpdateDialog.show(
        context,
        version: result.serverVersion.toLowerCase().startsWith('v')
            ? result.serverVersion
            : 'v${result.serverVersion}',
        releaseNotes: result.releaseNotes,
      );
    }

    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => WhatsNewSheet(result: result),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isUpdate = result.isUpdateAvailable;
    final isForced = result.isUpdateRequired;
    final notes = result.releaseNotes;
    final versionLabel = result.serverVersion.toLowerCase().startsWith('v')
        ? result.serverVersion
        : 'v${result.serverVersion}';

    final maxHeight = MediaQuery.sizeOf(context).height * 0.85;

    return SafeArea(
      top: false,
      child: Container(
        constraints: BoxConstraints(maxHeight: maxHeight),
        decoration: const BoxDecoration(
          color: Color(0xFF000000),
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          boxShadow: [
            BoxShadow(
              color: Color(0x66000000),
              blurRadius: 24,
              offset: Offset(0, -6),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Top Mascot & Header Banner (Figma #319:2721 & #319:2895)
            ClipRRect(
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(24),
              ),
              child: Container(
                height: 152,
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [Color(0x63EA2A33), Color(0x63000000)],
                  ),
                ),
                child: Stack(
                  children: [
                    // Warm golden radial glow behind mascot (Figma #319:2901)
                    Positioned(
                      left: 36,
                      top: 24,
                      child: Container(
                        width: 97,
                        height: 102,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: const Color(0x78FFAE0D),
                          boxShadow: [
                            BoxShadow(
                              color: const Color(0x78FFAE0D),
                              blurRadius: 28,
                              spreadRadius: 8,
                            ),
                          ],
                        ),
                      ),
                    ),
                    // 3D Mascot Image (Figma #319:2902)
                    Positioned(
                      left: 18,
                      top: 10,
                      bottom: 0,
                      child: Image.asset(
                        'assets/images/rate_us_mascot.png',
                        width: 132,
                        height: 132,
                        fit: BoxFit.contain,
                      ),
                    ),
                    // Header text & Badge (Figma #319:2903)
                    Positioned(
                      right: 18,
                      left: 160,
                      top: 22,
                      bottom: 16,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          // Gold Badge (NEW VERSION / UPDATE REQUIRED) (Figma #319:2904)
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 14,
                              vertical: 5,
                            ),
                            decoration: BoxDecoration(
                              color: isForced
                                  ? const Color(0xFFEA2A33)
                                  : const Color(0xFFF3BA2F),
                              borderRadius: BorderRadius.circular(16),
                              boxShadow: [
                                BoxShadow(
                                  color:
                                      (isForced
                                              ? const Color(0xFFEA2A33)
                                              : const Color(0xFFF3BA2F))
                                          .withValues(alpha: 0.35),
                                  blurRadius: 10,
                                  offset: const Offset(0, 2),
                                ),
                              ],
                            ),
                            child: Text(
                              isForced ? 'UPDATE REQUIRED' : 'NEW VERSION',
                              style: GoogleFonts.inter(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                                color: isForced ? Colors.white : Colors.black,
                                letterSpacing: 0.2,
                              ),
                            ),
                          ),
                          const SizedBox(height: 10),
                          // Subtitle 1: "Get the brand new app" (Figma #319:2907)
                          Text(
                            isForced
                                ? 'Mandatory Security Update'
                                : 'Get the brand new app',
                            style: GoogleFonts.inter(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              color: Colors.white,
                              decoration: TextDecoration.underline,
                              decorationColor: Colors.white,
                              height: 1.2,
                            ),
                          ),
                          const SizedBox(height: 4),
                          // Subtitle 2: Version number (Figma #319:2908)
                          Text(
                            versionLabel,
                            style: GoogleFonts.inter(
                              fontSize: 9,
                              fontWeight: FontWeight.w400,
                              color: const Color(0xFF9CA3AF),
                              decoration: TextDecoration.underline,
                              decorationColor: const Color(0xFF9CA3AF),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // Scrollable Content Area (Release Notes - Figma #319:2910)
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(24, 20, 24, 16),
                physics: const BouncingScrollPhysics(),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (notes.isNotEmpty) ...[
                      for (final note in notes) _buildNoteItem(note),
                    ] else ...[
                      // Figma node #319:2910 default bullets
                      _buildNoteItem(
                        '**New homepage:** AI market signals and curated news in one feed',
                      ),
                      _buildNoteItem(
                        '**Owllet Wallet Card:** Fewer steps to apply, and smoother spending',
                      ),
                      _buildNoteItem(
                        '**Robinhood Chain now supported:** Send, receive, and swap trending and new tokens',
                      ),
                    ],
                  ],
                ),
              ),
            ),

            // Bottom Action Button (Figma #319:2898)
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
              child: SizedBox(
                width: double.infinity,
                height: 59,
                child: ElevatedButton(
                  onPressed: () {
                    if (isUpdate || isForced) {
                      (appStoreService ?? AppStoreService()).openStoreListing();
                    } else {
                      Navigator.of(context).pop();
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFEA2A33),
                    foregroundColor: Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(9999),
                    ),
                  ),
                  child: Text(
                    isUpdate || isForced ? 'Upgrade now' : 'Got it',
                    style: GoogleFonts.inter(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNoteItem(String text) {
    // Check if note has bold title prefix (e.g. "**Title:** Description" or "Title: Description")
    final colonIndex = text.indexOf(':');
    final hasPrefix = colonIndex != -1 && colonIndex < 35;

    final title = hasPrefix
        ? text.substring(0, colonIndex + 1).replaceAll('*', '')
        : '';
    final body = hasPrefix
        ? text.substring(colonIndex + 1).replaceAll('*', '')
        : text.replaceAll('*', '');

    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 6, right: 12),
            child: Container(
              width: 5,
              height: 5,
              decoration: const BoxDecoration(
                color: Color(0xFF6B7280),
                shape: BoxShape.circle,
              ),
            ),
          ),
          Expanded(
            child: Text.rich(
              TextSpan(
                style: GoogleFonts.inter(
                  fontSize: 14,
                  height: 1.45,
                  color: const Color(0xFFD1D5DB),
                ),
                children: [
                  if (title.isNotEmpty)
                    TextSpan(
                      text: '$title ',
                      style: GoogleFonts.inter(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: const Color(0xFFE5E7EB),
                      ),
                    ),
                  TextSpan(text: body.trimLeft()),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
