import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../constants/app_colors.dart';
import '../../../../widgets/token_icon.dart';

class ContractImportCard extends StatelessWidget {
  final bool isLoading;
  final VoidCallback onAdd;
  final String? tokenName;
  final String? tokenSymbol;
  final String? tokenImageUrl;
  final int? chainId;

  const ContractImportCard({
    super.key,
    required this.isLoading,
    required this.onAdd,
    this.tokenName,
    this.tokenSymbol,
    this.tokenImageUrl,
    this.chainId,
  });

  @override
  Widget build(BuildContext context) {
    final hasInfo = tokenName != null && tokenSymbol != null;
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.cardDark,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.accentRed.withValues(alpha: 0.35)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'Contract detected. Import token metadata automatically.',
                  style: GoogleFonts.outfit(
                    fontSize: 13,
                    color: Colors.white70,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              ElevatedButton(
                onPressed: isLoading ? null : onAdd,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.accentRed,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                  minimumSize: const Size(60, 34),
                ),
                child: isLoading
                    ? const SizedBox(
                        width: 14,
                        height: 14,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : Text(
                        'Add',
                        style: GoogleFonts.outfit(fontWeight: FontWeight.w600),
                      ),
              ),
            ],
          ),
          if (hasInfo) ...[
            const SizedBox(height: 10),
            Row(
              children: [
                TokenIcon(
                  tokenSymbol: tokenSymbol!,
                  tokenImageUrl: tokenImageUrl,
                  size: 30,
                  chainId: chainId,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        tokenName!,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.outfit(
                          color: Colors.white,
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      Text(
                        tokenSymbol!,
                        style: GoogleFonts.outfit(
                          color: Colors.white54,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}
