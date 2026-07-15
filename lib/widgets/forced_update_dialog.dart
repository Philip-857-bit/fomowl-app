import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../constants/app_colors.dart';
import '../services/app_store_service.dart';

class ForcedUpdateDialog extends StatelessWidget {
  const ForcedUpdateDialog({
    super.key,
    required this.version,
    this.appStoreService,
  });

  final String version;
  final AppStoreService? appStoreService;

  static Future<void> show(BuildContext context, {required String version}) {
    return showDialog<void>(
      context: context,
      barrierDismissible: false,
      barrierColor: Colors.black.withValues(alpha: 0.72),
      builder: (_) => ForcedUpdateDialog(version: version),
    );
  }

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    return PopScope(
      canPop: false,
      child: Dialog(
        elevation: 0,
        insetPadding: const EdgeInsets.symmetric(horizontal: 32),
        backgroundColor: Colors.transparent,
        child: Container(
          width: width < 420 ? width - 64 : 360,
          padding: const EdgeInsets.fromLTRB(22, 28, 22, 24),
          decoration: BoxDecoration(
            color: AppColors.cardDark,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: AppColors.divider,
              width: 1,
            ),
            boxShadow: [
              BoxShadow(
                color: const Color(0xCC000000),
                blurRadius: 30,
                offset: const Offset(0, 18),
              ),
              BoxShadow(
                color: AppColors.primaryAccent.withValues(alpha: 0.08),
                blurRadius: 60,
                spreadRadius: 4,
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Discover a\nNew Version',
                          style: GoogleFonts.outfit(
                            fontSize: 28,
                            height: 1.12,
                            fontWeight: FontWeight.w800,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Owllet $version',
                          style: GoogleFonts.outfit(
                            fontSize: 17,
                            fontWeight: FontWeight.w700,
                            color: AppColors.primaryAccent,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Image.asset(
                    'assets/images/logo.png',
                    width: 96,
                    height: 96,
                    fit: BoxFit.contain,
                  ),
                ],
              ),
              const SizedBox(height: 48),
              Text(
                'Upgrade your app to the latest version to enhance account security and enjoy better services.',
                style: GoogleFonts.outfit(
                  fontSize: 15,
                  height: 1.28,
                  fontWeight: FontWeight.w400,
                  color: AppColors.textSecondary,
                ),
              ),
              const SizedBox(height: 36),
              GestureDetector(
                onTap: () =>
                    (appStoreService ?? AppStoreService()).openStoreListing(),
                child: Container(
                  width: double.infinity,
                  height: 56,
                  decoration: BoxDecoration(
                    gradient: AppColors.primaryGradient,
                    borderRadius: BorderRadius.circular(999),
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.primaryAccent.withValues(alpha: 0.3),
                        blurRadius: 20,
                        offset: const Offset(0, 8),
                      ),
                    ],
                  ),
                  child: Center(
                    child: Text(
                      'Upgrade Now',
                      style: GoogleFonts.outfit(
                        fontSize: 17,
                        fontWeight: FontWeight.w800,
                        color: AppColors.textPrimary,
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
}
