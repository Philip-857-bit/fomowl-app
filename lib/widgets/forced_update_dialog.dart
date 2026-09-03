import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../services/app_store_service.dart';

class ForcedUpdateDialog extends StatelessWidget {
  const ForcedUpdateDialog({
    super.key,
    required this.version,
    this.appStoreService,
    this.releaseNotes = const [],
  });

  final String version;
  final AppStoreService? appStoreService;
  final List<String> releaseNotes;

  static Future<void> show(
    BuildContext context, {
    required String version,
    List<String> releaseNotes = const [],
  }) {
    return showDialog<void>(
      context: context,
      barrierDismissible: false,
      barrierColor: Colors.black.withValues(alpha: 0.8),
      builder: (_) =>
          ForcedUpdateDialog(version: version, releaseNotes: releaseNotes),
    );
  }

  @override
  Widget build(BuildContext context) {
    final versionLabel = version.toLowerCase().startsWith('v')
        ? version
        : 'v$version';

    final maxHeight = MediaQuery.sizeOf(context).height * 0.85;

    return PopScope(
      canPop: false,
      child: Dialog(
        elevation: 0,
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
        child: Container(
          constraints: BoxConstraints(maxHeight: maxHeight, maxWidth: 390),
          decoration: BoxDecoration(
            color: const Color(0xFF171717),
            borderRadius: BorderRadius.circular(24),
            boxShadow: const [
              BoxShadow(
                color: Color(0x99000000),
                blurRadius: 32,
                offset: Offset(0, 12),
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
                          decoration: const BoxDecoration(
                            shape: BoxShape.circle,
                            color: Color(0x78FFAE0D),
                            boxShadow: [
                              BoxShadow(
                                color: Color(0x78FFAE0D),
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
                            // Red Badge (UPDATE REQUIRED)
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 6,
                              ),
                              decoration: BoxDecoration(
                                color: const Color(0xFFEA2A33),
                                borderRadius: BorderRadius.circular(16),
                                boxShadow: [
                                  BoxShadow(
                                    color: const Color(
                                      0xFFEA2A33,
                                    ).withValues(alpha: 0.35),
                                    blurRadius: 10,
                                    offset: const Offset(0, 2),
                                  ),
                                ],
                              ),
                              child: Text(
                                'UPDATE REQUIRED',
                                style: GoogleFonts.inter(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                  color: Colors.white,
                                  letterSpacing: 0.3,
                                ),
                              ),
                            ),
                            const SizedBox(height: 10),
                            Text(
                              'Security & Stability Update',
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

              // Scrollable Content Area (Release Notes / Security Notice)
              Flexible(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(24, 20, 24, 16),
                  physics: const BouncingScrollPhysics(),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (releaseNotes.isNotEmpty) ...[
                        for (final note in releaseNotes) _buildNoteItem(note),
                      ] else ...[
                        _buildNoteItem(
                          '**Security Enhancement:** Critical protocol security fixes and performance upgrades required to safeguard your funds.',
                        ),
                        _buildNoteItem(
                          '**Latest Features:** Access updated swap routing, chain support, and enhanced wallet stability.',
                        ),
                      ],
                    ],
                  ),
                ),
              ),

              // Pinned Bottom Action Button (Upgrade now)
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
                child: SizedBox(
                  width: double.infinity,
                  height: 54,
                  child: ElevatedButton(
                    onPressed: () => (appStoreService ?? AppStoreService())
                        .openStoreListing(),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFEA2A33),
                      foregroundColor: Colors.white,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(9999),
                      ),
                    ),
                    child: Text(
                      'Upgrade now',
                      style: GoogleFonts.inter(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildNoteItem(String text) {
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
