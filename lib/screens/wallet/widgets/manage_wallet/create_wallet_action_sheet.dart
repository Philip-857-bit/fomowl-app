import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../constants/app_colors.dart';

enum WalletCreateMode { create, importSeedPhrase, importPrivateKey }

class CreateWalletActionSheet extends StatefulWidget {
  final ValueChanged<WalletCreateMode> onConfirm;

  const CreateWalletActionSheet({super.key, required this.onConfirm});

  @override
  State<CreateWalletActionSheet> createState() =>
      _CreateWalletActionSheetState();
}

class _CreateWalletActionSheetState extends State<CreateWalletActionSheet> {
  WalletCreateMode _selected = WalletCreateMode.create;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(18, 12, 18, 22),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 46,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.white24,
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'Create / Add Wallet',
              style: GoogleFonts.outfit(
                color: Colors.white,
                fontSize: 26,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 16),
            _optionTile(
              icon: Icons.playlist_add_circle_outlined,
              title: 'Create New Wallet',
              mode: WalletCreateMode.create,
            ),
            const SizedBox(height: 10),
            _optionTile(
              icon: Icons.vpn_key_outlined,
              title: 'Add using Seed Phrase',
              mode: WalletCreateMode.importSeedPhrase,
            ),
            const SizedBox(height: 10),
            _optionTile(
              icon: Icons.lock_outline_rounded,
              title: 'Add using Private Key',
              mode: WalletCreateMode.importPrivateKey,
            ),
            const SizedBox(height: 18),
            ElevatedButton(
              onPressed: () => widget.onConfirm(_selected),
              style: ElevatedButton.styleFrom(
                minimumSize: const Size.fromHeight(54),
                backgroundColor: AppColors.accentRed,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              child: Text(
                'Confirm',
                style: GoogleFonts.outfit(
                  fontWeight: FontWeight.w700,
                  fontSize: 17,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _optionTile({
    required IconData icon,
    required String title,
    required WalletCreateMode mode,
  }) {
    final selected = _selected == mode;
    return InkWell(
      onTap: () => setState(() => _selected = mode),
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.03),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: selected
                ? AppColors.accentRed.withValues(alpha: 0.6)
                : Colors.white.withValues(alpha: 0.1),
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                color: Colors.white.withValues(alpha: 0.06),
              ),
              child: Icon(icon, color: const Color(0xFFA7B1C4)),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                title,
                style: GoogleFonts.outfit(color: Colors.white, fontSize: 17),
              ),
            ),
            Icon(
              selected
                  ? Icons.radio_button_checked_rounded
                  : Icons.radio_button_off_rounded,
              color: selected ? AppColors.accentRed : Colors.white38,
            ),
          ],
        ),
      ),
    );
  }
}
