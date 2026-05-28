import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../constants/app_colors.dart';
import 'legal_content.dart';

class LegalDocumentView extends StatelessWidget {
  const LegalDocumentView({
    required this.title,
    required this.document,
    super.key,
  });

  final String title;
  final LegalDocument document;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 12, 8, 6),
              child: Stack(
                alignment: Alignment.center,
                children: [
                  Align(
                    alignment: Alignment.centerLeft,
                    child: IconButton(
                      icon: const Icon(
                        Icons.arrow_back_ios_new_rounded,
                        color: Colors.white,
                      ),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 56),
                    child: Text(
                      title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.outfit(
                        fontSize: 24,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(16, 10, 16, 28),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _LegalHero(document: document),
                    const SizedBox(height: 18),
                    for (final section in document.sections)
                      _LegalSectionCard(section: section),
                    const SizedBox(height: 8),
                    Center(
                      child: Column(
                        children: [
                          Text(
                            document.finalQuote,
                            textAlign: TextAlign.center,
                            style: GoogleFonts.outfit(
                              fontSize: 17,
                              fontStyle: FontStyle.italic,
                              fontWeight: FontWeight.w700,
                              color: AppColors.textPrimary,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            document.finalBody,
                            textAlign: TextAlign.center,
                            style: GoogleFonts.outfit(
                              fontSize: 12.5,
                              height: 1.5,
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _LegalHero extends StatelessWidget {
  const _LegalHero({required this.document});

  final LegalDocument document;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.cardDark,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppColors.divider.withValues(alpha: 0.35)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: AppColors.accentRed.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(999),
              border: Border.all(
                color: AppColors.accentRed.withValues(alpha: 0.35),
              ),
            ),
            child: Text(
              'EFFECTIVE DATE: ${document.effectiveDate}',
              style: GoogleFonts.outfit(
                fontSize: 10,
                letterSpacing: 1,
                color: AppColors.accentRed,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          const SizedBox(height: 18),
          Text(
            document.heroTitle.toUpperCase(),
            style: GoogleFonts.outfit(
              fontSize: 30,
              height: 0.98,
              fontWeight: FontWeight.w800,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 14),
          Text(
            document.intro,
            style: GoogleFonts.outfit(
              fontSize: 13,
              height: 1.5,
              color: AppColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}

class _LegalSectionCard extends StatelessWidget {
  const _LegalSectionCard({required this.section});

  final LegalSection section;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: section.accent ? const Color(0xFF1F1F1F) : AppColors.cardDark,
        borderRadius: BorderRadius.circular(section.accent ? 18 : 16),
        border: Border(
          left: BorderSide(
            color: section.accent ? AppColors.accentRed : AppColors.divider,
            width: section.accent ? 3 : 1,
          ),
          top: BorderSide(color: AppColors.divider.withValues(alpha: 0.35)),
          right: BorderSide(color: AppColors.divider.withValues(alpha: 0.35)),
          bottom: BorderSide(color: AppColors.divider.withValues(alpha: 0.35)),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                width: 36,
                child: Text(
                  section.number,
                  style: GoogleFonts.outfit(
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                    color: AppColors.accentRed.withValues(alpha: 0.35),
                  ),
                ),
              ),
              Expanded(
                child: Text(
                  section.title.toUpperCase(),
                  style: GoogleFonts.outfit(
                    fontSize: 15,
                    height: 1.2,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          for (final paragraph in section.paragraphs) ...[
            Text(
              paragraph,
              style: GoogleFonts.outfit(
                fontSize: 13,
                height: 1.55,
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: 8),
          ],
          if (section.bullets.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(left: 4, bottom: 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  for (final bullet in section.bullets)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 6),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Padding(
                            padding: EdgeInsets.only(top: 8),
                            child: Icon(
                              Icons.circle,
                              size: 5,
                              color: AppColors.accentRed,
                            ),
                          ),
                          const SizedBox(width: 9),
                          Expanded(
                            child: Text(
                              bullet,
                              style: GoogleFonts.outfit(
                                fontSize: 13,
                                height: 1.45,
                                color: AppColors.textSecondary,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
          if (section.warning != null)
            Container(
              width: double.infinity,
              margin: const EdgeInsets.only(top: 4, bottom: 8),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.accentRed.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: AppColors.accentRed.withValues(alpha: 0.25),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    section.warning!.title,
                    style: GoogleFonts.outfit(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    section.warning!.body,
                    style: GoogleFonts.outfit(
                      fontSize: 12.5,
                      height: 1.45,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
          if (section.contactRows.isNotEmpty)
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (final row in section.contactRows)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 5),
                    child: RichText(
                      text: TextSpan(
                        style: GoogleFonts.outfit(fontSize: 13, height: 1.45),
                        children: [
                          TextSpan(
                            text: '${row.label}: ',
                            style: const TextStyle(
                              color: AppColors.textPrimary,
                            ),
                          ),
                          TextSpan(
                            text: row.value,
                            style: const TextStyle(
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
        ],
      ),
    );
  }
}
