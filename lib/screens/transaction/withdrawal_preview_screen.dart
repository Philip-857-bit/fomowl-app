import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../constants/app_colors.dart';

class WithdrawalPreviewDialog extends StatelessWidget {
  final String bankName;
  final String accountNumber;
  final String accountName;
  final String token;
  final String amount;
  final String fee;
  final String estimatedTime;

  const WithdrawalPreviewDialog({
    super.key,
    required this.bankName,
    required this.accountNumber,
    required this.accountName,
    required this.token,
    required this.amount,
    required this.fee,
    required this.estimatedTime,
  });

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 16),
      child: Container(
        width: double.infinity,
        decoration: BoxDecoration(
          color: AppColors.background,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Close X button
            Align(
              alignment: Alignment.topRight,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(0, 16, 16, 0),
                child: GestureDetector(
                  onTap: () => Navigator.pop(context),
                  child: Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.05),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.close, color: Colors.white54, size: 18),
                  ),
                ),
              ),
            ),

            // Title & Subtitle
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Withdrawal Preview',
                    style: GoogleFonts.outfit(
                      fontSize: 24,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'You are about to withdraw your funds',
                    style: GoogleFonts.outfit(
                      fontSize: 14,
                      color: Colors.white.withValues(alpha: 0.5),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // Warning Banner
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 24),
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: AppColors.error.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.error.withValues(alpha: 0.3)),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.info, color: AppColors.error, size: 20),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Please confirm the withdrawal details are correct to avoid loosing your funds. Funds lost can not be recovered again',
                      style: GoogleFonts.outfit(
                        fontSize: 12,
                        color: Colors.white,
                        height: 1.4,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // Bank Details Card
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 24),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.cardDark,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                children: [
                  _buildDetailRow('Bank Name', bankName),
                  const SizedBox(height: 16),
                  _buildDetailRow('Bank Account No.', accountNumber),
                  const SizedBox(height: 16),
                  _buildDetailRow('Bank Account Name', accountName),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Transaction Details Card
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 24),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.cardDark,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                children: [
                  _buildDetailRow('Token', token),
                  const SizedBox(height: 16),
                  _buildDetailRow('Fee Estimate', fee),
                  const SizedBox(height: 16),
                  _buildDetailRow('Estimated Time', estimatedTime),
                  const SizedBox(height: 16),
                  _buildDetailRow('Amt.', amount, isValueBold: true),
                ],
              ),
            ),
            const SizedBox(height: 32),

            // Buttons
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 0, 24, 32),
              child: Row(
                children: [
                  // Cancel
                  Expanded(
                    child: GestureDetector(
                      onTap: () => Navigator.pop(context),
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        decoration: BoxDecoration(
                          color: const Color(0xFF4A4A4A),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        alignment: Alignment.center,
                        child: Text(
                          'Cancel',
                          style: GoogleFonts.outfit(
                            fontSize: 18,
                            fontWeight: FontWeight.w600,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  // Confirm
                  Expanded(
                    child: GestureDetector(
                      onTap: () {
                        Navigator.pop(context); // Close dialog
                        Navigator.pushNamed(context, '/transaction-processing');
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        decoration: BoxDecoration(
                          color: AppColors.accentRed, // Solid red, slightly darker
                          borderRadius: BorderRadius.circular(16),
                        ),
                        alignment: Alignment.center,
                        child: Text(
                          'Confirm',
                          style: GoogleFonts.outfit(
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
          ],
        ),
      ),
    );
  }

  Widget _buildDetailRow(String label, String value, {bool isValueBold = false}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: GoogleFonts.outfit(
            fontSize: 13,
            color: Colors.white.withValues(alpha: 0.6),
            fontWeight: FontWeight.w500,
          ),
        ),
        Text(
          value,
          style: GoogleFonts.outfit(
            fontSize: 14,
            fontWeight: isValueBold ? FontWeight.w700 : FontWeight.w600,
            color: Colors.white,
          ),
        ),
      ],
    );
  }
}
