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
          color: Color(0xFF171717),
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
            // Top Mascot & Header Banner (Figma #319:2721)
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
                    // Warm golden radial glow behind mascot
                    Positioned(
                      left: 36,
                      top: 24,
                      child: Container(
                        width: 100,
                        height: 100,
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
                    // 3D Mascot Image
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
                    // Header text & Badge
                    Positioned(
                      right: 18,
                      left: 160,
                      top: 24,
                      bottom: 16,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          // Gold Badge (NEW VERSION / UPDATE REQUIRED)
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 14,
                              vertical: 6,
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
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                                color: isForced ? Colors.white : Colors.black,
                                letterSpacing: 0.3,
                              ),
                            ),
                          ),
                          const SizedBox(height: 12),
                          Text(
                            isForced
                                ? 'Mandatory Security Update'
                                : 'Get the brand new app',
                            style: GoogleFonts.inter(
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                              color: Colors.white,
                              height: 1.2,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            versionLabel,
                            style: GoogleFonts.inter(
                              fontSize: 11,
                              fontWeight: FontWeight.w500,
                              color: const Color(0xFF9CA3AF),
                              decoration: TextDecoration.underline,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // Scrollable Content Area (Release Notes)
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
                      _buildNoteItem(
                        isUpdate
                            ? 'Performance enhancements and bug fixes are ready for your device.'
                            : 'Welcome to the latest version of Owllet with enhanced stability and security.',
                      ),
                    ],
                  ],
                ),
              ),
            ),

            // Bottom Actions (Always pinned and visible)
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 8, 24, 20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  SizedBox(
                    width: double.infinity,
                    height: 54,
                    child: ElevatedButton(
                      onPressed: () {
                        if (isUpdate || isForced) {
                          (appStoreService ?? AppStoreService())
                              .openStoreListing();
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
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
                  if (!isForced && isUpdate) ...[
                    const SizedBox(height: 8),
                    TextButton(
                      onPressed: () => Navigator.of(context).pop(),
                      child: Text(
                        'Maybe later',
                        style: GoogleFonts.inter(
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                          color: const Color(0xFF9CA3AF),
                        ),
                      ),
                    ),
                  ],
                ],
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
