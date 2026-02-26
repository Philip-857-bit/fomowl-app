import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../constants/app_colors.dart';

/// Terms of Use Screen
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
              padding: const EdgeInsets.fromLTRB(8, 8, 16, 0),
              child: Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.arrow_back, color: Colors.white),
                    onPressed: () => Navigator.pop(context),
                  ),
                  Text(
                    'Terms of Use',
                    style: GoogleFonts.outfit(fontSize: 20, fontWeight: FontWeight.w600, color: Colors.white),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildSection('1. Acceptance of Terms',
                      'By installing or using Owllet you confirm that you are legally allowed to hold digital assets and that you accept these Terms. '
                      'If you disagree, uninstall the application immediately.'
                    ),
                    _buildSection('2. Self-Custody Responsibilities',
                      'Owllet only generates keys and signs transactions locally. You control the mnemonic, derived wallets, approvals, and transactions. '
                      'We cannot recover a forgotten passcode, seed phrase, or private key.'
                    ),
                    _buildSection('3. Blockchain Transactions & Fees',
                      'Every transfer, approval, or swap you send is broadcast to the EVM network you selected. Gas estimates are best-effort and the final cost '
                      'is determined by the network. You are responsible for verifying recipient addresses and paying all network fees.'
                    ),
                    _buildSection('4. Third-Party Services & Swaps',
                      'The app relies on RPC providers (e.g., Alchemy and any custom RPC you add), CoinGecko, and public AMM routers such as Uniswap, QuickSwap, '
                      'PancakeSwap, and SushiSwap. Service interruptions, inaccurate market data, or smart-contract bugs can cause losses or failed transactions. '
                      'We do not audit tokens, pools, or smart contracts.'
                    ),
                    _buildSection('5. Compliance & Taxes',
                      'You are solely responsible for determining whether your use of Owllet is legal in your jurisdiction and for paying any taxes or reporting obligations '
                      'related to your digital-asset activity.'
                    ),
                    _buildSection('6. Prohibited Use',
                      'You may not use the app for illicit activity, sanctions evasion, malware distribution, or to violate the terms of any blockchain, RPC provider, or applicable law. '
                      'We reserve the right to disable access to network features that are abused.'
                    ),
                    _buildSection('7. Disclaimer of Warranties',
                      'THE APP IS PROVIDED "AS IS" AND "AS AVAILABLE" WITHOUT WARRANTIES OF ANY KIND, EXPRESS OR IMPLIED. '
                      'WE DO NOT GUARANTEE THAT PRICE DATA IS ACCURATE, THAT TRANSACTIONS WILL SUCCEED, OR THAT THE SOFTWARE IS ERROR-FREE.'
                    ),
                    _buildSection('8. Limitation of Liability',
                      'To the maximum extent permitted by law, we are not liable for lost funds, lost seed phrases, market losses, smart-contract exploits, indirect, incidental, or '
                      'consequential damages arising out of your use of the app.'
                    ),
                    _buildSection('9. Changes & Contact',
                      'We may update these Terms as we launch new features or networks. Continued use after a change means you accept the new Terms. '
                      'Contact us on X (@fomowlhq) if you need clarification.'
                    ),
                    const SizedBox(height: 16),
                    Center(
                      child: Text(
                        'Effective Date: February 2026',
                        style: GoogleFonts.outfit(fontSize: 12, color: Colors.white.withValues(alpha: 0.3)),
                      ),
                    ),
                    const SizedBox(height: 40),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSection(String title, String content) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: GoogleFonts.outfit(fontSize: 16, fontWeight: FontWeight.w600, color: AppColors.accentRed),
          ),
          const SizedBox(height: 8),
          Text(
            content,
            style: GoogleFonts.outfit(fontSize: 13, color: Colors.white.withValues(alpha: 0.75), height: 1.6),
          ),
        ],
      ),
    );
  }
}
