import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../../constants/app_colors.dart';
import '../../widgets/bottom_navigation.dart';
import '../../services/wallet_service.dart';
import '../../services/storage_service.dart';
import '../../services/blockchain_service.dart';
import '../../l10n/app_localizations.dart';
import '../../main.dart';
import '../onboarding/language_selection_screen.dart';
import '../../utils/toast_utils.dart';

/// Decentralized Profile Screen — No backend required
/// Shows wallet info, seed phrase backup, language, network, and privacy policy
class DecentralizedProfileScreen extends StatefulWidget {
  const DecentralizedProfileScreen({super.key});

  @override
  State<DecentralizedProfileScreen> createState() => _DecentralizedProfileScreenState();
}

class _DecentralizedProfileScreenState extends State<DecentralizedProfileScreen> {
  final WalletService _walletService = WalletService();
  final StorageService _storage = StorageService();

  String _walletName = 'Main Wallet';
  String? _walletAddress;

  @override
  void initState() {
    super.initState();
    _loadWalletInfo();
  }

  Future<void> _loadWalletInfo() async {
    final name = await _storage.getWalletName();
    final address = await _walletService.getCurrentWalletAddress();
    if (mounted) {
      setState(() {
        _walletName = name ?? 'Main Wallet';
        _walletAddress = address;
      });
    }
  }

  String _shortenAddress(String? address) {
    if (address == null || address.length < 10) return address ?? '--';
    return '${address.substring(0, 6)}...${address.substring(address.length - 4)}';
  }



  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return Scaffold(
      backgroundColor: AppColors.background,
      bottomNavigationBar: BottomNavBar(
        currentIndex: 4,
        onTap: (index) => BottomNavBar.handleNavigation(context, index, 4),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                child: Center(
                  child: Text(
                    l.profile,
                    style: GoogleFonts.outfit(fontSize: 22, fontWeight: FontWeight.w600, color: Colors.white),
                  ),
                ),
              ),
              const SizedBox(height: 24),

              // Wallet Identity Card
              _buildWalletCard(),
              const SizedBox(height: 24),

              // Seed Phrase Backup
              _buildSectionHeader('Security'),
              _buildMenuItem(Icons.vpn_key_outlined, 'Backup Seed Phrase', () {
                Navigator.pushNamed(context, '/backup-seed-phrase');
              }),
              _buildMenuItem(Icons.lock_outline, 'Password & Security', () {
                Navigator.pushNamed(context, '/coming-soon', arguments: 'Password & Security');
              }),
              const SizedBox(height: 8),

              // Settings
              _buildSectionHeader(l.settings),
              _buildMenuItem(Icons.language, l.chooseLanguage, () async {
                final languageCode = await Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const LanguageSelectionScreen(),
                  ),
                );
                
                if (languageCode != null && context.mounted) {
                  FOMOwlWalletApp.setLocale(context, languageCode);
                }
              }, subtitle: AppLocalizations.languageNames[l.locale.languageCode]),
              _buildMenuItem(Icons.settings_outlined, l.network, () {
                _showNetworkSelector(l);
              }, subtitle: Provider.of<BlockchainService>(context).activeChain.name),
              const SizedBox(height: 8),

              // Legal
              _buildSectionHeader('Legal'),
              _buildMenuItem(Icons.privacy_tip_outlined, l.privacyPolicy, () {
                Navigator.pushNamed(context, '/privacy-policy');
              }),
              _buildMenuItem(Icons.article_outlined, 'Terms of Service', () {
                Navigator.pushNamed(context, '/terms-and-conditions');
              }),

              const SizedBox(height: 8),
              _buildSectionHeader('Support'),
              _buildMenuItem(Icons.build_outlined, 'Version', () {
                ToastUtils.showInfo('Owllet Wallet v1.0.1');
              }),
              _buildMenuItem(Icons.delete_outline, l.resetWallet, () {
                _showResetWalletDialog();
              }),

              const SizedBox(height: 30),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildWalletCard() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: AppColors.primaryGradient,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        children: [
          // Owl avatar
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.15),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.account_balance_wallet, color: Colors.white, size: 28),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _walletName,
                  style: GoogleFonts.outfit(fontSize: 20, fontWeight: FontWeight.w600, color: Colors.white),
                ),
                const SizedBox(height: 4),
                GestureDetector(
                  onTap: () {
                    if (_walletAddress != null) {
                      Clipboard.setData(ClipboardData(text: _walletAddress!));
                      ToastUtils.showSuccess('Address copied to clipboard');
                    }
                  },
                  child: Row(
                    children: [
                      Text(
                        _shortenAddress(_walletAddress),
                        style: GoogleFonts.outfit(fontSize: 13, color: Colors.white.withValues(alpha: 0.8)),
                      ),
                      const SizedBox(width: 6),
                      Icon(Icons.copy, size: 14, color: Colors.white.withValues(alpha: 0.6)),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _showResetWalletDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.cardDark,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text('Reset Wallet?', style: GoogleFonts.outfit(fontSize: 18, fontWeight: FontWeight.w600, color: Colors.white)),
        content: Text(
          'This will delete your wallet data from this device. Make sure you have backed up your seed phrase before proceeding.',
          style: GoogleFonts.outfit(fontSize: 14, color: Colors.white70, height: 1.5),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('Cancel', style: GoogleFonts.outfit(color: Colors.white54)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.error,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            onPressed: () async {
              Navigator.pop(ctx);
              await _walletService.deleteWallet();
              if (mounted) {
                Navigator.pushNamedAndRemoveUntil(context, '/welcome', (route) => false);
              }
            },
            child: Text('Reset', style: GoogleFonts.outfit(fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 8),
      child: Text(
        title,
        style: GoogleFonts.outfit(
          fontSize: 13,
          fontWeight: FontWeight.w400,
          color: Colors.white.withValues(alpha: 0.4),
        ),
      ),
    );
  }

  Widget _buildMenuItem(IconData icon, String label, VoidCallback onTap, {String? subtitle}) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
        child: Row(
          children: [
            Container(
              width: 32, height: 32,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.06),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: Colors.white.withValues(alpha: 0.7), size: 17),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: GoogleFonts.outfit(fontSize: 15, fontWeight: FontWeight.w500, color: Colors.white),
                  ),
                  if (subtitle != null)
                    Text(
                      subtitle,
                      style: GoogleFonts.outfit(fontSize: 12, color: AppColors.accentRed.withValues(alpha: 0.8)),
                    ),
                ],
              ),
            ),
            Icon(Icons.arrow_forward_ios, size: 14, color: Colors.white.withValues(alpha: 0.3)),
          ],
        ),
      ),
    );
  }

  void _showNetworkSelector(AppLocalizations l) {
    final blockchain = Provider.of<BlockchainService>(context, listen: false);
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.cardDark,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => DraggableScrollableSheet(
        initialChildSize: 0.6,
        maxChildSize: 0.85,
        minChildSize: 0.4,
        expand: false,
        builder: (_, scrollController) => Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
          child: Column(
            children: [
              Container(
                width: 40, height: 4,
                decoration: BoxDecoration(
                  color: Colors.white24,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                l.selectNetwork,
                style: GoogleFonts.outfit(fontSize: 18, fontWeight: FontWeight.w600, color: Colors.white),
              ),
              const SizedBox(height: 16),
              Expanded(
                child: ListView(
                  controller: scrollController,
                  children: [
                    ...blockchain.allChains.map((chain) {
                      final isActive = blockchain.activeChain.chainId == chain.chainId;
                      return Dismissible(
                        key: ValueKey(chain.chainId),
                        direction: chain.isCustom ? DismissDirection.endToStart : DismissDirection.none,
                        background: Container(
                          alignment: Alignment.centerRight,
                          padding: const EdgeInsets.only(right: 20),
                          color: AppColors.error.withValues(alpha: 0.3),
                          child: const Icon(Icons.delete, color: Colors.white),
                        ),
                        onDismissed: (_) {
                          blockchain.removeCustomChain(chain.chainId);
                          if (mounted) setState(() {});
                        },
                        child: ListTile(
                          leading: Container(
                            width: 36, height: 36,
                            decoration: BoxDecoration(
                              color: isActive ? AppColors.accentRed.withValues(alpha: 0.2) : Colors.white.withValues(alpha: 0.06),
                              shape: BoxShape.circle,
                            ),
                            child: Center(
                              child: Text(
                                chain.symbol.substring(0, chain.symbol.length > 3 ? 3 : chain.symbol.length),
                                style: GoogleFonts.outfit(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                  color: isActive ? AppColors.accentRed : Colors.white60,
                                ),
                              ),
                            ),
                          ),
                          title: Row(
                            children: [
                              Expanded(
                                child: Text(
                                  chain.name,
                                  style: GoogleFonts.outfit(
                                    fontSize: 15,
                                    fontWeight: isActive ? FontWeight.w600 : FontWeight.w400,
                                    color: isActive ? AppColors.accentRed : Colors.white,
                                  ),
                                ),
                              ),
                              if (chain.isCustom)
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: Colors.white.withValues(alpha: 0.08),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Text('Custom', style: GoogleFonts.outfit(fontSize: 9, color: Colors.white38)),
                                ),
                            ],
                          ),
                          subtitle: Text(
                            'Chain ID: ${chain.chainId}',
                            style: GoogleFonts.outfit(fontSize: 12, color: Colors.white38),
                          ),
                          trailing: isActive
                            ? const Icon(Icons.check_circle, color: AppColors.accentRed, size: 20)
                            : null,
                          onTap: () {
                            blockchain.setActiveChain(chain);
                            Navigator.pop(ctx);
                            if (mounted) setState(() {});
                          },
                        ),
                      );
                    }),

                    // Add Custom Network button
                    const SizedBox(height: 12),
                    GestureDetector(
                      onTap: () {
                        Navigator.pop(ctx);
                        Navigator.pushNamed(context, '/add-network').then((_) {
                          if (mounted) setState(() {});
                        });
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.06),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: AppColors.accentRed.withValues(alpha: 0.3)),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Icons.add_circle_outline, color: AppColors.accentRed, size: 20),
                            const SizedBox(width: 8),
                            Text(
                              l.addCustomNetwork,
                              style: GoogleFonts.outfit(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.accentRed),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
