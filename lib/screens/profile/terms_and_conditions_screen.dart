import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../constants/app_colors.dart';

class TermsAndConditionsScreen extends StatelessWidget {
  const TermsAndConditionsScreen({super.key});

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
                    'Terms of Service',
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
                      '1. Acceptance of Terms',
                      'By installing or using Owllet you confirm that you are legally allowed to hold digital assets and that you accept these terms. '
                          'If you disagree, uninstall the application immediately.',
                    ),
                    _buildSectionCard(
                      '2. Self-Custody Responsibilities',
                      'Owllet only generates keys and signs transactions locally. You control the mnemonic, derived wallets, approvals, and transactions. '
                          'We cannot recover a forgotten passcode, seed phrase, or private key.',
                    ),
                    _buildSectionCard(
                      '3. Blockchain Transactions & Fees',
                      'Every transfer, approval, or swap you send is broadcast to the EVM network you selected. Gas estimates are best-effort and the final cost '
                          'is determined by the network. You are responsible for verifying recipient addresses and paying all network fees.',
                    ),
                    _buildSectionCard(
                      '4. Third-Party Services & Swaps',
                      'The app relies on RPC providers (e.g., Alchemy and any custom RPC you add), CoinGecko, and public AMM routers such as Uniswap, QuickSwap, '
                          'PancakeSwap, and SushiSwap. Service interruptions, inaccurate market data, or smart-contract bugs can cause losses or failed transactions. '
                          'We do not audit tokens, pools, or smart contracts.',
                    ),
                    _buildSectionCard(
                      '5. Compliance & Taxes',
                      'You are solely responsible for determining whether your use of Owllet is legal in your jurisdiction and for paying any taxes or reporting obligations '
                          'related to your digital-asset activity.',
                    ),
                    _buildSectionCard(
                      '6. Prohibited Use',
                      'You may not use the app for illicit activity, sanctions evasion, malware distribution, or to violate the terms of any blockchain, RPC provider, or applicable law. '
                          'We reserve the right to disable access to network features that are abused.',
                    ),
                    _buildSectionCard(
                      '7. Disclaimer of Warranties',
                      'The app is provided "as is" and "as available" without warranties of any kind, express or implied. '
                          'We do not guarantee that price data is accurate, that transactions will succeed, or that the software is error-free.',
                    ),
                    _buildSectionCard(
                      '8. Limitation of Liability',
                      'To the maximum extent permitted by law, we are not liable for lost funds, lost seed phrases, market losses, smart-contract exploits, indirect, incidental, or '
                          'consequential damages arising out of your use of the app.',
                    ),
                    _buildSectionCard(
                      '9. Changes & Contact',
                      'We may update these terms as we launch new features or networks. Continued use after a change means you accept the new terms. '
                          'Contact us on X (@fomowlhq) if you need clarification.',
                    ),
                    const SizedBox(height: 6),
                    Center(
                      child: Text(
                        'Effective date: February 2026',
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
