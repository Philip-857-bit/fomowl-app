import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../models/chain.dart';
import '../../../models/wallet_account.dart';

/// Returns a human-readable type label for the subtitle row (OKX-style).
/// Examples: "Seed Phrase", "Private Key · EVM", "Private Key · Solana".
String walletTypeLabel(WalletAccount account) {
  if (account.origin == WalletOrigin.derived) return 'Seed Phrase';
  final families = account.addressesByFamily.keys.toSet();
  if (families.contains(ChainFamily.solana) &&
      !families.contains(ChainFamily.evm)) {
    return 'Private Key · Solana';
  }
  if (families.contains(ChainFamily.tron) &&
      !families.contains(ChainFamily.evm)) {
    return 'Private Key · Tron';
  }
  return 'Private Key · EVM';
}

/// Returns a compact badge for a wallet's origin, or null for derived wallets
/// (no badge needed — seed-phrase wallets are the default and need no label).
Widget? walletOriginBadge(WalletAccount account) {
  if (account.origin != WalletOrigin.imported) return null;

  final families = account.addressesByFamily.keys.toSet();
  final String label;
  if (families.contains(ChainFamily.solana) &&
      !families.contains(ChainFamily.evm)) {
    label = 'Imported · SOL';
  } else if (families.contains(ChainFamily.tron) &&
      !families.contains(ChainFamily.evm)) {
    label = 'Imported · TRX';
  } else {
    label = 'Imported';
  }

  return Container(
    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
    decoration: BoxDecoration(
      color: const Color(0xFFF59E0B).withValues(alpha: 0.15),
      borderRadius: BorderRadius.circular(6),
      border: Border.all(
        color: const Color(0xFFF59E0B).withValues(alpha: 0.45),
        width: 0.8,
      ),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Icon(
          Icons.file_download_outlined,
          size: 10,
          color: Color(0xFFF59E0B),
        ),
        const SizedBox(width: 3),
        Text(
          label,
          style: GoogleFonts.outfit(
            fontSize: 10,
            fontWeight: FontWeight.w600,
            color: const Color(0xFFF59E0B),
            height: 1.2,
          ),
        ),
      ],
    ),
  );
}
