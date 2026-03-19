import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../constants/app_colors.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../../models/token.dart';
import '../../../../widgets/token_icon.dart';

class TransactionDetailsCard extends StatelessWidget {
  final String fromAddress;
  final String toAddress;
  final String network;
  final Token? token;
  final int chainId;
  final bool isLoadingGas;
  final bool gasEstimationFailed;
  final String gasLabel;
  final String gasValue;
  final String gasValueUsd;
  final String totalLabel;
  final String maxTotalDisplay;

  const TransactionDetailsCard({
    super.key,
    required this.fromAddress,
    required this.toAddress,
    required this.network,
    this.token,
    required this.chainId,
    required this.isLoadingGas,
    this.gasEstimationFailed = false,
    required this.gasLabel,
    required this.gasValue,
    required this.gasValueUsd,
    required this.totalLabel,
    required this.maxTotalDisplay,
  });

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        children: [
          _buildDetailRow(l.swapFromLabel, fromAddress),
          _buildDivider(),
          _buildDetailRow(l.swapToLabel, toAddress),
          _buildDivider(),
          _buildNetworkRow(l.network, network),
          _buildDivider(),
          const SizedBox(height: 8),
          isLoadingGas
              ? _buildGasLoading(l)
              : _buildFeeRow(
                  gasLabel,
                  gasValue,
                  gasValueUsd,
                  gasEstimationFailed,
                ),
          const SizedBox(height: 16),
          _buildDivider(),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                totalLabel,
                style: GoogleFonts.outfit(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                ),
              ),
              Text(
                maxTotalDisplay,
                style: GoogleFonts.outfit(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: GoogleFonts.outfit(
              fontSize: 14,
              color: Colors.white.withValues(alpha: 0.6),
            ),
          ),
          Text(
            value,
            style: GoogleFonts.outfit(
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: Colors.white,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNetworkRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: GoogleFonts.outfit(
              fontSize: 14,
              color: Colors.white.withValues(alpha: 0.6),
            ),
          ),
          Row(
            children: [
              TokenIcon(
                tokenSymbol: token?.symbol ?? 'ETH',
                tokenAddress: token?.contractAddress,
                tokenImageUrl: token?.imageUrl,
                size: 18,
                chainId: chainId,
              ),
              const SizedBox(width: 6),
              Text(
                value,
                style: GoogleFonts.outfit(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: Colors.white,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildGasLoading(AppLocalizations l) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Text(
            l.gasFee,
            style: GoogleFonts.outfit(fontSize: 14, color: Colors.white60),
          ),
          const Spacer(),
          const SizedBox(
            width: 14,
            height: 14,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: AppColors.accentRed,
            ),
          ),
          const SizedBox(width: 8),
          Text(
            l.loading,
            style: GoogleFonts.outfit(fontSize: 13, color: Colors.white38),
          ),
        ],
      ),
    );
  }

  Widget _buildFeeRow(
    String label,
    String value,
    String usdValue,
    bool isError,
  ) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Row(
          children: [
            Text(
              label,
              style: GoogleFonts.outfit(
                fontSize: 14,
                color: isError
                    ? AppColors.accentRed
                    : Colors.white.withValues(alpha: 0.6),
              ),
            ),
            const SizedBox(width: 4),
            Icon(
              isError ? Icons.warning_amber_rounded : Icons.help_outline,
              size: 14,
              color: isError
                  ? AppColors.accentRed
                  : Colors.white.withValues(alpha: 0.3),
            ),
          ],
        ),
        Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              value,
              style: GoogleFonts.outfit(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: isError ? AppColors.accentRed : Colors.white,
              ),
            ),
            if (!isError)
              Text(
                usdValue,
                style: GoogleFonts.outfit(
                  fontSize: 11,
                  color: Colors.white.withValues(alpha: 0.4),
                ),
              ),
          ],
        ),
      ],
    );
  }

  Widget _buildDivider() =>
      Divider(height: 1, color: Colors.white.withValues(alpha: 0.08));
}
