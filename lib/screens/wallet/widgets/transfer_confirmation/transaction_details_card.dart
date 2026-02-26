import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../constants/app_colors.dart';

class TransactionDetailsCard extends StatelessWidget {
  final String fromAddress;
  final String toAddress;
  final String network;
  final bool isLoadingGas;
  final String gasLabel;
  final String gasValue;
  final String gasValueUsd;
  final String maxTotalDisplay;

  const TransactionDetailsCard({
    super.key,
    required this.fromAddress,
    required this.toAddress,
    required this.network,
    required this.isLoadingGas,
    required this.gasLabel,
    required this.gasValue,
    required this.gasValueUsd,
    required this.maxTotalDisplay,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        children: [
          _buildDetailRow('From', fromAddress),
          _buildDivider(),
          _buildDetailRow('To', toAddress),
          _buildDivider(),
          _buildNetworkRow(network),
          _buildDivider(),
          const SizedBox(height: 8),
          isLoadingGas ? _buildGasLoading() : _buildFeeRow(gasLabel, gasValue, gasValueUsd),
          const SizedBox(height: 16),
          _buildDivider(),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('MAX TOTAL', style: GoogleFonts.outfit(fontSize: 14, fontWeight: FontWeight.w700, color: Colors.white)),
              Text(
                maxTotalDisplay,
                style: GoogleFonts.outfit(fontSize: 16, fontWeight: FontWeight.w700, color: Colors.white),
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
          Text(label, style: GoogleFonts.outfit(fontSize: 14, color: Colors.white.withValues(alpha: 0.6))),
          Text(value, style: GoogleFonts.outfit(fontSize: 14, fontWeight: FontWeight.w500, color: Colors.white)),
        ],
      ),
    );
  }

  Widget _buildNetworkRow(String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text('Network', style: GoogleFonts.outfit(fontSize: 14, color: Colors.white.withValues(alpha: 0.6))),
          Row(
            children: [
              Container(
                width: 18,
                height: 18,
                decoration: const BoxDecoration(color: AppColors.warning, shape: BoxShape.circle),
                child: const Icon(Icons.circle, size: 8, color: Colors.white),
              ),
              const SizedBox(width: 6),
              Text(value, style: GoogleFonts.outfit(fontSize: 14, fontWeight: FontWeight.w500, color: Colors.white)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildGasLoading() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Text('Gas Fee', style: GoogleFonts.outfit(fontSize: 14, color: Colors.white60)),
          const Spacer(),
          const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.accentRed)),
          const SizedBox(width: 8),
          Text('Estimating...', style: GoogleFonts.outfit(fontSize: 13, color: Colors.white38)),
        ],
      ),
    );
  }

  Widget _buildFeeRow(String label, String value, String usdValue) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Row(
          children: [
            Text(label, style: GoogleFonts.outfit(fontSize: 14, color: Colors.white.withValues(alpha: 0.6))),
            const SizedBox(width: 4),
            Icon(Icons.help_outline, size: 14, color: Colors.white.withValues(alpha: 0.3)),
          ],
        ),
        Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(value, style: GoogleFonts.outfit(fontSize: 14, fontWeight: FontWeight.w500, color: Colors.white)),
            Text(usdValue, style: GoogleFonts.outfit(fontSize: 11, color: Colors.white.withValues(alpha: 0.4))),
          ],
        ),
      ],
    );
  }

  Widget _buildDivider() => Divider(height: 1, color: Colors.white.withValues(alpha: 0.08));
}
