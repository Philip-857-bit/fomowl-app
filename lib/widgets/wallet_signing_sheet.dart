import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../constants/app_colors.dart';

class WalletSigningField {
  const WalletSigningField({required this.label, required this.value});

  final String label;
  final String value;
}

class WalletSigningSheet extends StatelessWidget {
  const WalletSigningSheet({
    super.key,
    required this.title,
    required this.confirmLabel,
    required this.fields,
    this.subtitle,
    this.note,
  });

  final String title;
  final String confirmLabel;
  final List<WalletSigningField> fields;
  final String? subtitle;
  final String? note;

  static Future<bool> show(
    BuildContext context, {
    required String title,
    required String confirmLabel,
    required List<WalletSigningField> fields,
    String? subtitle,
    String? note,
  }) async {
    final result = await showModalBottomSheet<bool>(
      context: context,
      useRootNavigator: true,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => WalletSigningSheet(
        title: title,
        confirmLabel: confirmLabel,
        fields: fields,
        subtitle: subtitle,
        note: note,
      ),
    );
    return result ?? false;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 20),
        child: Container(
          decoration: BoxDecoration(
            color: AppColors.cardDark,
            borderRadius: BorderRadius.circular(28),
            border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
          ),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Container(
                      width: 46,
                      height: 46,
                      decoration: BoxDecoration(
                        color: AppColors.accentRed.withValues(alpha: 0.14),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.lock_clock_outlined,
                        color: AppColors.accentRed,
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Text(
                        title,
                        style: GoogleFonts.outfit(
                          fontSize: 22,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                        ),
                      ),
                    ),
                    IconButton(
                      onPressed: () => Navigator.of(context).pop(false),
                      icon: const Icon(Icons.close, color: Colors.white70),
                    ),
                  ],
                ),
                if (subtitle != null && subtitle!.trim().isNotEmpty) ...[
                  const SizedBox(height: 12),
                  Text(
                    subtitle!,
                    style: GoogleFonts.outfit(
                      fontSize: 14,
                      color: Colors.white.withValues(alpha: 0.75),
                      height: 1.4,
                    ),
                  ),
                ],
                const SizedBox(height: 18),
                Container(
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.04),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Column(
                    children: [
                      for (var index = 0; index < fields.length; index++) ...[
                        Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 14,
                          ),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(
                                child: Text(
                                  fields[index].label,
                                  style: GoogleFonts.outfit(
                                    fontSize: 13,
                                    color: Colors.white.withValues(alpha: 0.58),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Text(
                                  fields[index].value,
                                  textAlign: TextAlign.right,
                                  style: GoogleFonts.outfit(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600,
                                    color: Colors.white,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        if (index != fields.length - 1)
                          Divider(
                            height: 1,
                            color: Colors.white.withValues(alpha: 0.06),
                          ),
                      ],
                    ],
                  ),
                ),
                if (note != null && note!.trim().isNotEmpty) ...[
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: AppColors.accentRed.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: AppColors.accentRed.withValues(alpha: 0.18),
                      ),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Padding(
                          padding: EdgeInsets.only(top: 2),
                          child: Icon(
                            Icons.verified_user_outlined,
                            size: 18,
                            color: AppColors.accentRed,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            note!,
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: Colors.white.withValues(alpha: 0.82),
                              height: 1.4,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
                const SizedBox(height: 22),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => Navigator.of(context).pop(false),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.white,
                          side: BorderSide(
                            color: Colors.white.withValues(alpha: 0.14),
                          ),
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                        ),
                        child: const Text('Cancel'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () => Navigator.of(context).pop(true),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.accentRed,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                        ),
                        child: Text(confirmLabel),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
