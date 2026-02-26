import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../constants/app_colors.dart';
import '../../widgets/mobile_scaffold.dart';

/// Import Wallet Screen
/// Allows users to add an existing wallet using secret phrase or private key
class ImportWalletScreen extends StatelessWidget {
  const ImportWalletScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return MobileScaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Back button
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: IconButton(
                icon: const Icon(
                  Icons.arrow_back,
                  color: Colors.white,
                  size: 24,
                ),
                onPressed: () {
                  Navigator.pop(context);
                },
              ),
            ),
            
            const SizedBox(height: 20),
            
            // Title
            Center(
              child: Text(
                'Add existing wallet',
                style: GoogleFonts.outfit(
                  fontSize: 32,
                  fontWeight: FontWeight.w600,
                  color: Colors.white,
                ),
                textAlign: TextAlign.center,
              ),
            ),
            
            const SizedBox(height: 40),
            
            // "Most popular" label
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 23),
              child: Text(
                'Most popular',
                style: GoogleFonts.outfit(
                  fontSize: 19,
                  fontWeight: FontWeight.w500,
                  color: const Color(0xFFD2D0D0),
                ),
              ),
            ),
            
            const SizedBox(height: 23),
            
            // Secret phrase option
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 21),
              child: _buildImportOption(
                context: context,
                icon: Icons.lock,
                iconColor: const Color(0xFFEB3F3F),
                title: 'Secret phrase',
                onTap: () {
                  Navigator.pushNamed(context, '/import-secret-phrase');
                },
              ),
            ),
            
            const SizedBox(height: 22),
            
            // Private key option
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 21),
              child: _buildImportOption(
                context: context,
                icon: Icons.vpn_key,
                iconColor: const Color(0xFFEB3F3F),
                title: 'Private Key',
                onTap: () {
                  Navigator.pushNamed(context, '/import-private-key');
                },
              ),
            ),
            
            const Spacer(),
            

            
            const SizedBox(height: 12),
          ],
        ),
      ),
    );
  }

  Widget _buildImportOption({
    required BuildContext context,
    required IconData icon,
    required Color iconColor,
    required String title,
    required VoidCallback onTap,
  }) {
    return Container(
      height: 74,
      decoration: BoxDecoration(
        color: const Color(0xFF333232).withValues(alpha: 0.7),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.2),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 26),
            child: Row(
              children: [
                // Icon
                Container(
                  width: 34,
                  height: 34,
                  decoration: BoxDecoration(
                    color: iconColor.withValues(alpha: 0.2),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    icon,
                    color: iconColor,
                    size: 20,
                  ),
                ),
                
                const SizedBox(width: 23),
                
                // Title
                Expanded(
                  child: Text(
                    title,
                    style: GoogleFonts.outfit(
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                      color: Colors.white.withValues(alpha: 0.95),
                      letterSpacing: -0.06,
                    ),
                  ),
                ),
                
                // Arrow
                const Icon(
                  Icons.arrow_forward_ios,
                  color: Colors.white,
                  size: 18,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
