import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../constants/app_colors.dart';

class PrivacyPolicyScreen extends StatelessWidget {
  const PrivacyPolicyScreen({super.key});

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
                  Text(
                    'Privacy Policy',
                    style: GoogleFonts.outfit(
                      fontSize: 34,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildSectionCard(
                      '1. Overview',
                      'Owllet is an EVM-only, self-custody wallet. All key generation and signing happen on your device '
                          'using battle-tested BIP-39/BIP-32 libraries. We never run a centralized ledger or take possession of your assets.',
                    ),
                    _buildSectionCard(
                      '2. Data Stored Locally',
                      'We store the following items with Flutter Secure Storage or SharedPreferences on your device:\n'
                          '• Wallet names, addresses, and derivation indexes\n'
                          '• Encrypted private keys, seed phrase (if you save it), and your passcode hash\n'
                          '• Biometric toggles plus language/UI preferences\n'
                          'Deleting the app or clearing secure storage permanently removes this data. It never leaves your device.',
                    ),
                    _buildSectionCard(
                      '3. Third-Party Services',
                      'To display balances, price data, and execute swaps the app connects directly to:\n'
                          '• RPC providers such as Alchemy and any custom RPC you add\n'
                          '• CoinGecko for market data and charts\n'
                          '• Public AMM routers (Uniswap, QuickSwap, PancakeSwap, SushiSwap, etc.) when you submit swaps or approvals\n'
                          'These providers may log IP addresses or wallet activity under their own policies.',
                    ),
                    _buildSectionCard(
                      '4. Device Permissions',
                      'Camera access is used only for QR scanning. Biometric prompts (Face/Touch ID, fingerprint) are handled by the operating system; '
                          'we receive only success/failure. We do not access your photos, contacts, microphone, or location.',
                    ),
                    _buildSectionCard(
                      '5. Your Responsibilities',
                      '• Back up your 12-word seed phrase offline and never share it\n'
                          '• Verify destination addresses and approvals before signing\n'
                          '• Keep your device updated, set a strong passcode, and enable biometrics\n'
                          '• Understand that blockchain transactions are irreversible',
                    ),
                    _buildSectionCard(
                      '6. Updates & Contact',
                      'We may revise this notice as we add networks or features. The latest version is always available in the app. '
                          'Reach us on X (@fomowlhq) if you have privacy questions.',
                    ),
                    const SizedBox(height: 6),
                    Center(
                      child: Text(
                        'Last updated: February 2026',
                        style: GoogleFonts.outfit(
                          fontSize: 12,
                          color: const Color(0xFF5B6C8A),
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionCard(String title, String content) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF121315),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withValues(alpha: 0.07)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: GoogleFonts.outfit(
              fontSize: 15,
              fontWeight: FontWeight.w600,
              color: AppColors.accentRed,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            content,
            style: GoogleFonts.outfit(
              fontSize: 13,
              color: const Color(0xFFBCC7DB),
              height: 1.55,
            ),
          ),
        ],
      ),
    );
  }
}
