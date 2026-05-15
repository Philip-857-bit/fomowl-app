import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../l10n/app_localizations.dart';
import '../../../models/token.dart';
import '../../../utils/value_formatter.dart';
import 'swap_token_chip.dart';

class SwapToCard extends StatelessWidget {
  final Token? token;
  final String amountText;
  final double usdValue;
  final double balance;
  final bool isCalculating;
  final VoidCallback onSelectToken;
  final int? chainId;
  final String? statusMessage;

  const SwapToCard({
    super.key,
    required this.token,
    required this.amountText,
    required this.usdValue,
    required this.balance,
    required this.isCalculating,
    required this.onSelectToken,
    this.chainId,
    this.statusMessage,
  });

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return LayoutBuilder(
      builder: (context, constraints) {
        final horizontalPadding = constraints.maxWidth < 340 ? 16.0 : 24.0;
        return Container(
          padding: EdgeInsets.fromLTRB(
            horizontalPadding,
            16,
            horizontalPadding,
            16,
          ),
          decoration: BoxDecoration(
            color: const Color(0xFF151C24),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: const Color(0x0DFFFFFF)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'SWAP TO',
                style: GoogleFonts.inter(
                  fontSize: 10,
                  fontWeight: FontWeight.w500,
                  color: const Color(0xFFA1A1A1),
                  letterSpacing: 1.0,
                ),
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  Expanded(
                    child: isCalculating
                        ? Row(
                            children: [
                              const SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(
                                  color: Color(0xFFEA2A33),
                                  strokeWidth: 2,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Flexible(
                                child: Text(
                                  l.calculatingLabel,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: GoogleFonts.inter(
                                    fontSize: 16,
                                    color: Colors.white54,
                                  ),
                                ),
                              ),
                            ],
                          )
                        : Text(
                            amountText.isEmpty ? '0' : amountText,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: GoogleFonts.inter(
                              fontSize: 20,
                              fontWeight: FontWeight.w600,
                              color: const Color(0xFFE2E2E2),
                            ),
                          ),
                  ),
                  const SizedBox(width: 8),
                  SwapTokenChip(
                    token: token,
                    onTap: onSelectToken,
                    chainId: chainId,
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      ValueFormatter.formatCurrencyWithGrouping(
                        ValueFormatter.decimalFromNum(usdValue),
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        color: const Color(0xFF848E9C),
                      ),
                    ),
                  ),
                  const SizedBox(width: 4),
                  Flexible(
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.account_balance_wallet_outlined,
                          size: 11,
                          color: Color(0xFF848E9C),
                        ),
                        const SizedBox(width: 4),
                        Flexible(
                          child: Text(
                            '${balance.toStringAsFixed(4)} ${token?.symbol ?? ""}',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: GoogleFonts.inter(
                              fontSize: 12,
                              color: const Color(0xFF848E9C),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              if (statusMessage != null &&
                  statusMessage!.trim().isNotEmpty) ...[
                const SizedBox(height: 8),
                Text(
                  statusMessage!,
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: const Color(0xFFEA2A33),
                    height: 1.4,
                  ),
                ),
              ],
            ],
          ),
        );
      },
    );
  }
}
