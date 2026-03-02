import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:provider/provider.dart';

import '../../constants/app_colors.dart';
import '../../l10n/app_localizations.dart';
import '../../main.dart';
import '../../services/blockchain_service.dart';
import '../../services/storage_service.dart';
import '../../services/wallet_service.dart';
import '../../widgets/bottom_navigation.dart';
import '../home/widgets/network_selector_sheet.dart';
import '../onboarding/language_selection_screen.dart';
import 'widgets/settings_group_card.dart';
import 'widgets/settings_item_tile.dart';
import 'widgets/settings_section_header.dart';
import 'widgets/settings_wallet_header_card.dart';

class DecentralizedProfileScreen extends StatefulWidget {
  const DecentralizedProfileScreen({super.key});

  @override
  State<DecentralizedProfileScreen> createState() => _DecentralizedProfileScreenState();
}

class _DecentralizedProfileScreenState extends State<DecentralizedProfileScreen> {
  final WalletService _walletService = WalletService();
  final StorageService _storageService = StorageService();

  String _walletName = 'Main Wallet';
  String _walletAddress = '--';
  String _currency = 'USD';
  String _versionLabel = 'Owllet v1.0.0';
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final walletName = await _storageService.getWalletName();
    final walletAddress = await _walletService.getCurrentWalletAddress();
    final currency = await _storageService.getCurrency();
    try {
      final info = await PackageInfo.fromPlatform();
      _versionLabel = 'Owllet v${info.version}';
    } catch (_) {
      _versionLabel = 'Owllet v1.0.0';
    }

    if (!mounted) return;
    setState(() {
      _walletName = walletName ?? 'Main Wallet';
      _walletAddress = walletAddress ?? '--';
      _currency = currency;
      _loading = false;
    });
  }

  Future<void> _pickCurrency() async {
    final l = AppLocalizations.of(context);
    final options = <String>['USD', 'EUR', 'GBP', 'NGN'];
    final selected = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: AppColors.cardDark,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 10),
            Container(
              width: 42,
              height: 4,
              decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(10)),
            ),
            const SizedBox(height: 14),
            Text(
              l.currency,
              style: GoogleFonts.outfit(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 8),
            for (final item in options)
              ListTile(
                title: Text(item, style: GoogleFonts.outfit(color: Colors.white)),
                trailing: _currency == item
                    ? const Icon(Icons.check_circle, color: AppColors.accentRed)
                    : null,
                onTap: () => Navigator.pop(ctx, item),
              ),
            const SizedBox(height: 10),
          ],
        ),
      ),
    );
    if (selected == null || selected == _currency) return;
    await _storageService.setCurrency(selected);
    if (!mounted) return;
    setState(() => _currency = selected);
  }

  Future<void> _showNetworkSheet() async {
    final blockchain = Provider.of<BlockchainService>(context, listen: false);
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: AppColors.cardDark,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      isScrollControlled: true,
      builder: (ctx) => SafeArea(
        child: NetworkSelectorSheet(
          chains: blockchain.allChains,
          activeChainId: blockchain.activeChain.chainId,
          onSelect: (chain) {
            blockchain.setActiveChain(chain);
            Navigator.pop(ctx);
            if (mounted) setState(() {});
          },
        ),
      ),
    );
  }

  Future<void> _confirmReset() async {
    final l = AppLocalizations.of(context);
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.cardDark,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text('${l.resetApp}?', style: GoogleFonts.outfit(color: Colors.white, fontWeight: FontWeight.w600)),
        content: Text(
          l.confirmClearLocalData,
          style: GoogleFonts.outfit(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(l.cancel, style: GoogleFonts.outfit(color: Colors.white54)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(l.resetApp, style: GoogleFonts.outfit(color: AppColors.accentRed)),
          ),
        ],
      ),
    );
    if (confirm != true) return;
    try {
      await _walletService.deleteWallet();
    } catch (e) {
      if (!mounted) return;
      await showDialog<void>(
        context: context,
        builder: (ctx) => AlertDialog(
          backgroundColor: AppColors.cardDark,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Text(l.resetApp, style: GoogleFonts.outfit(color: Colors.white, fontWeight: FontWeight.w600)),
          content: Text(
            l.resetFailed,
            style: GoogleFonts.outfit(color: Colors.white70),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text(l.continue_, style: GoogleFonts.outfit(color: AppColors.accentRed)),
            ),
          ],
        ),
      );
      return;
    }
    if (!mounted) return;
    Navigator.pushNamedAndRemoveUntil(context, '/welcome', (route) => false);
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final blockchain = Provider.of<BlockchainService>(context);
    final localeName = AppLocalizations.languageNames[l.locale.languageCode] ?? AppLocalizations.languageNames['en']!;

    return Scaffold(
      backgroundColor: AppColors.background,
      bottomNavigationBar: BottomNavBar(
        currentIndex: 4,
        onTap: (index) => BottomNavBar.handleNavigation(context, index, 4),
      ),
      body: SafeArea(
        child: _loading
            ? const Center(child: CircularProgressIndicator(color: AppColors.accentRed))
            : SingleChildScrollView(
                padding: const EdgeInsets.only(bottom: 26),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 18, 16, 12),
                      child: Center(
                        child: Text(
                          l.profile,
                          style: GoogleFonts.outfit(
                            color: Colors.white,
                            fontSize: 34,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                    SettingsWalletHeaderCard(
                      walletName: _walletName,
                      walletAddress: _walletAddress,
                      onTap: () => Navigator.pushNamed(context, '/wallets'),
                    ),
                    const SizedBox(height: 16),
                    SettingsSectionHeader(title: l.general),
                    SettingsGroupCard(
                      children: [
                        SettingsItemTile(
                          icon: Icons.wallet_outlined,
                          title: l.manageWallets,
                          onTap: () => Navigator.pushNamed(context, '/wallets'),
                        ),
                        SettingsItemTile(
                          icon: Icons.hub_outlined,
                          title: l.switchNetwork,
                          subtitle: blockchain.activeChain.name,
                          onTap: _showNetworkSheet,
                        ),
                        SettingsItemTile(
                          icon: Icons.attach_money_rounded,
                          title: l.currency,
                          subtitle: _currency,
                          onTap: _pickCurrency,
                        ),
                        SettingsItemTile(
                          icon: Icons.language_rounded,
                          title: l.chooseYourLanguage,
                          subtitle: localeName,
                          onTap: () async {
                            final languageCode = await Navigator.push<String>(
                              context,
                              MaterialPageRoute(builder: (_) => const LanguageSelectionScreen()),
                            );
                            if (!mounted) return;
                            if (languageCode != null) {
                              FOMOwlWalletApp.setLocale(this.context, languageCode);
                              await _load();
                            }
                          },
                        ),
                        SettingsItemTile(
                          icon: Icons.card_giftcard_rounded,
                          title: l.referrals,
                          onTap: () => Navigator.pushNamed(context, '/referrals'),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    SettingsSectionHeader(title: l.security),
                    SettingsGroupCard(
                      children: [
                        SettingsItemTile(
                          icon: Icons.vpn_key_rounded,
                          title: l.seedPhraseBackup,
                          subtitle: l.actionRequired,
                          attention: true,
                          onTap: () => Navigator.pushNamed(context, '/backup-seed-phrase'),
                        ),
                        SettingsItemTile(
                          icon: Icons.shield_outlined,
                          title: l.passwordSecurity,
                          onTap: () => Navigator.pushNamed(context, '/password-security'),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    SettingsSectionHeader(title: l.others),
                    SettingsGroupCard(
                      children: [
                        SettingsItemTile(
                          icon: Icons.privacy_tip_outlined,
                          title: l.privacyPolicy,
                          onTap: () => Navigator.pushNamed(context, '/privacy-policy'),
                        ),
                        SettingsItemTile(
                          icon: Icons.description_outlined,
                          title: l.termsOfService,
                          onTap: () => Navigator.pushNamed(context, '/terms-and-conditions'),
                        ),
                        SettingsItemTile(
                          icon: Icons.chat_bubble_outline_rounded,
                          title: l.feedback,
                          onTap: () => Navigator.pushNamed(context, '/feedback'),
                        ),
                        SettingsItemTile(
                          icon: Icons.groups_2_outlined,
                          title: l.joinOurCommunity,
                          onTap: () => Navigator.pushNamed(context, '/community'),
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),
                    Center(
                      child: Text(
                        _versionLabel,
                        style: GoogleFonts.outfit(
                          color: const Color(0xFF5C6A87),
                          fontSize: 16,
                        ),
                      ),
                    ),
                    const SizedBox(height: 14),
                    Center(
                      child: OutlinedButton.icon(
                        onPressed: _confirmReset,
                        icon: const Icon(Icons.refresh_rounded),
                        label: Text(
                          l.resetApp,
                          style: GoogleFonts.outfit(fontWeight: FontWeight.w600),
                        ),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppColors.accentRed,
                          side: BorderSide(color: AppColors.accentRed.withValues(alpha: 0.7)),
                          minimumSize: const Size(160, 46),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
      ),
    );
  }
}
