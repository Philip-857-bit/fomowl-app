import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'package:package_info_plus/package_info_plus.dart';
import 'package:provider/provider.dart';

import '../../config/app_environment.dart';
import '../../constants/app_colors.dart';
import '../../l10n/app_localizations.dart';
import '../../services/blockchain_service.dart';
import '../../services/currency_controller.dart';
import '../../services/storage_service.dart';
import '../../services/wallet_service.dart';
import '../../services/language_controller.dart';
import '../../utils/app_error_utils.dart';
import '../../utils/language_utils.dart';
import '../../services/push_notification_registration_service.dart';

import '../../widgets/bottom_navigation.dart';
import '../admin/admin_dashboard_screen.dart';
import '../home/widgets/network_selector_sheet.dart';
import '../onboarding/language_selection_screen.dart';
import 'widgets/settings_group_card.dart';
import 'widgets/settings_item_tile.dart';
import 'widgets/settings_section_header.dart';
import 'widgets/settings_wallet_header_card.dart';

class DecentralizedProfileScreen extends StatefulWidget {
  const DecentralizedProfileScreen({super.key});

  @override
  State<DecentralizedProfileScreen> createState() =>
      _DecentralizedProfileScreenState();
}

class _DecentralizedProfileScreenState
    extends State<DecentralizedProfileScreen> {
  final WalletService _walletService = WalletService();
  final StorageService _storageService = StorageService();

  String _walletName = 'Main Wallet';
  String _walletAddress = '--';
  String _currency = 'USD';
  String _versionLabel = 'Owllet v1.0.0';
  bool _loading = true;
  bool _isNotificationsEnabled = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Widget _valueTrailing(String value) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          value,
          style: GoogleFonts.outfit(
            color: AppColors.textSecondary,
            fontSize: 15,
            fontWeight: FontWeight.w400,
          ),
        ),
        const SizedBox(width: 6),
        Icon(
          Icons.arrow_forward_ios_rounded,
          color: AppColors.textSecondary.withValues(alpha: 0.9),
          size: 13,
        ),
      ],
    );
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

    final normalizedWallet = walletAddress ?? '';
    final reg = normalizedWallet.isEmpty
        ? null
        : await _storageService.getNotificationDeviceRegistration(
            normalizedWallet,
          );
    final isNotificationsEnabled = reg != null && reg['token'] != null;

    setState(() {
      _walletName = walletName ?? 'Main Wallet';
      _walletAddress = walletAddress ?? '--';
      _currency = currency;
      _isNotificationsEnabled = isNotificationsEnabled;
      _loading = false;
    });
  }

  String _currencyDisplayName(String code, AppLocalizations l) {
    switch (code) {
      case 'USD':
        return l.currencyUsd;
      case 'EUR':
        return l.currencyEur;
      case 'GBP':
        return l.currencyGbp;
      case 'NGN':
        return l.currencyNgn;
      default:
        return code;
    }
  }

  Future<void> _pickCurrency() async {
    final l = AppLocalizations.of(context);
    final currencyController = context.read<CurrencyController>();
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
              decoration: BoxDecoration(
                color: Colors.white24,
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            const SizedBox(height: 14),
            Text(
              l.currency,
              style: GoogleFonts.outfit(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            for (final item in options)
              ListTile(
                title: Text(
                  _currencyDisplayName(item, l),
                  style: GoogleFonts.outfit(color: Colors.white),
                ),
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
    if (!mounted) return;
    await currencyController.setCurrencyCode(selected);
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
          onAddCustomNetwork: () async {
            Navigator.pop(ctx);
            await Navigator.pushNamed(context, '/add-network');
            if (mounted) {
              setState(() {});
            }
          },
        ),
      ),
    );
  }

  Future<void> _handleAdminTrigger() async {
    final l = AppLocalizations.of(context);
    final secretController = TextEditingController();
    try {
      final blockchain = Provider.of<BlockchainService>(context, listen: false);
      final chainId = blockchain.activeChain.chainId;
      final walletAddress = await _walletService.getCurrentWalletAddress();
      if (walletAddress == null || walletAddress.isEmpty) {
        throw Exception('No wallet connected');
      }

      final timestamp = DateTime.now().toUtc().toIso8601String();
      final message =
          'Owllet Admin Access\nWallet: $walletAddress\nChain: $chainId\nTimestamp: $timestamp';
      final signature = await _walletService.signMessageForAddress(
        walletAddress,
        message,
      );

      final verifyResponse = await http
          .post(
            AppEnvironment.blockchain('/$chainId/admin/verify'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({
              'walletAddress': walletAddress,
              'message': message,
              'signature': '0x$signature',
            }),
          )
          .timeout(const Duration(seconds: 10));

      if (verifyResponse.statusCode != 200) {
        if (verifyResponse.statusCode == 403) {
          return;
        }
        final errorMessage = AppErrorUtils.backendMessage(
          verifyResponse.body,
          fallback: 'Admin access denied.',
        );
        throw Exception(errorMessage);
      }

      if (!mounted) return;
      final secret = await showDialog<String>(
        context: context,
        builder: (ctx) => AlertDialog(
          backgroundColor: AppColors.cardDark,
          title: Text(
            l.adminControlCenter,
            style: GoogleFonts.outfit(color: Colors.white),
          ),
          content: TextField(
            controller: secretController,
            obscureText: true,
            style: const TextStyle(color: Colors.white),
            decoration: InputDecoration(
              hintText: 'Enter admin secret',
              hintStyle: const TextStyle(color: Colors.white54),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text(l.cancel),
            ),
            TextButton(
              onPressed: () => Navigator.pop(ctx, secretController.text),
              child: Text(l.continue_),
            ),
          ],
        ),
      );

      final trimmedSecret = secret?.trim() ?? '';
      if (trimmedSecret.isEmpty) {
        if (!mounted) return;
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(l.adminSecretRequired)));
        return;
      }

      debugPrint(
        'Admin access verified for wallet $walletAddress on chain $chainId',
      );
      if (!mounted) return;
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) =>
              AdminDashboardScreen(adminSecret: trimmedSecret),
        ),
      );
    } catch (e, st) {
      debugPrint('Admin access failed: $e\n$st');
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Admin access failed: $e')));
    } finally {
      secretController.dispose();
    }
  }

  Future<void> _confirmReset() async {
    final l = AppLocalizations.of(context);
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.cardDark,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          '${l.resetApp}?',
          style: GoogleFonts.outfit(
            color: Colors.white,
            fontWeight: FontWeight.w600,
          ),
        ),
        content: Text(
          l.confirmClearLocalData,
          style: GoogleFonts.outfit(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(
              l.cancel,
              style: GoogleFonts.outfit(color: Colors.white54),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(
              l.resetApp,
              style: GoogleFonts.outfit(color: AppColors.accentRed),
            ),
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
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: Text(
            l.resetApp,
            style: GoogleFonts.outfit(
              color: Colors.white,
              fontWeight: FontWeight.w600,
            ),
          ),
          content: Text(
            l.resetFailed,
            style: GoogleFonts.outfit(color: Colors.white70),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text(
                l.continue_,
                style: GoogleFonts.outfit(color: AppColors.accentRed),
              ),
            ),
          ],
        ),
      );
      return;
    }
    if (!mounted) return;
    Navigator.pushNamedAndRemoveUntil(context, '/welcome', (route) => false);
  }

  Future<void> _setNotificationsEnabled(bool enabled) async {
    final l = AppLocalizations.of(context);
    try {
      final service = PushNotificationRegistrationService();
      if (enabled) {
        await service.syncForActiveWallet();
      } else {
        await service.disableForActiveWallet();
      }

      final reg = await _storageService.getNotificationDeviceRegistration(
        _walletAddress,
      );
      final success = reg != null && reg['token'] != null;

      if (!mounted) return;
      setState(() => _isNotificationsEnabled = success);

      if (success) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(l.notifications)));
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to enable notifications: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final blockchain = Provider.of<BlockchainService>(context);
    final localeName =
        LanguageUtils.languageNamesByCode[Localizations.localeOf(
          context,
        ).languageCode] ??
        LanguageUtils.languageNamesByCode['en']!;

    return Scaffold(
      backgroundColor: AppColors.background,
      bottomNavigationBar: BottomNavBar(
        currentIndex: 2,
        onTap: (index) => BottomNavBar.handleNavigation(context, index, 2),
      ),
      body: SafeArea(
        child: _loading
            ? const Center(
                child: CircularProgressIndicator(color: AppColors.accentRed),
              )
            : SingleChildScrollView(
                padding: const EdgeInsets.only(bottom: 26),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 6),
                      child: Center(
                        child: Text(
                          l.profile,
                          style: GoogleFonts.outfit(
                            color: Colors.white,
                            fontSize: 22,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
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
                          trailing: _valueTrailing(blockchain.activeChain.name),
                          onTap: _showNetworkSheet,
                        ),
                        SettingsItemTile(
                          icon: Icons.attach_money_rounded,
                          title: l.currency,
                          trailing: _valueTrailing(_currency),
                          onTap: _pickCurrency,
                        ),
                        SettingsItemTile(
                          icon: Icons.language_rounded,
                          title: l.chooseYourLanguage,
                          trailing: _valueTrailing(localeName),
                          onTap: () async {
                            final langController = context
                                .read<LanguageController>();
                            final languageCode = await Navigator.push<String>(
                              context,
                              MaterialPageRoute(
                                builder: (_) => const LanguageSelectionScreen(),
                              ),
                            );
                            if (!mounted) return;
                            if (languageCode != null) {
                              await langController.setLanguageCode(
                                languageCode,
                              );
                              await _load();
                            }
                          },
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    SettingsSectionHeader(title: l.security),
                    SettingsGroupCard(
                      children: [
                        SettingsItemTile(
                          icon: Icons.lock_outline_rounded,
                          title: l.changePassword,
                          subtitle: l.passcodeUnlock,
                          onTap: () => Navigator.pushNamed(
                            context,
                            '/password-security',
                          ),
                        ),
                        SettingsItemTile(
                          icon: Icons.vpn_key_rounded,
                          title: l.seedPhraseBackup,
                          subtitle: l.actionRequired,
                          attention: true,
                          onTap: () => Navigator.pushNamed(
                            context,
                            '/backup-seed-phrase',
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    SettingsSectionHeader(title: l.notificationsSettings),
                    SettingsGroupCard(
                      children: [
                        SettingsItemTile(
                          icon: Icons.notifications_active_outlined,
                          title: l.enablePushNotifications,
                          subtitle: l.pushNotificationsDesc,
                          trailing: Switch.adaptive(
                            value: _isNotificationsEnabled,
                            activeTrackColor: AppColors.primaryAccent,
                            onChanged: _setNotificationsEnabled,
                          ),
                          onTap: () => _setNotificationsEnabled(
                            !_isNotificationsEnabled,
                          ),
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
                          onTap: () =>
                              Navigator.pushNamed(context, '/privacy-policy'),
                        ),
                        SettingsItemTile(
                          icon: Icons.description_outlined,
                          title: l.termsOfService,
                          onTap: () => Navigator.pushNamed(
                            context,
                            '/terms-and-conditions',
                          ),
                        ),
                        SettingsItemTile(
                          icon: Icons.chat_bubble_outline_rounded,
                          title: l.feedback,
                          onTap: () =>
                              Navigator.pushNamed(context, '/feedback'),
                        ),
                        SettingsItemTile(
                          icon: Icons.groups_2_outlined,
                          title: l.joinOurCommunity,
                          onTap: () =>
                              Navigator.pushNamed(context, '/community'),
                        ),
                      ],
                    ),
                    const SizedBox(height: 22),
                    Center(
                      child: GestureDetector(
                        onLongPress: _handleAdminTrigger,
                        child: Text(
                          _versionLabel,
                          style: GoogleFonts.outfit(
                            color: AppColors.textSecondary,
                            fontSize: 15,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Center(
                      child: OutlinedButton.icon(
                        onPressed: _confirmReset,
                        icon: const Icon(Icons.refresh_rounded),
                        label: Text(
                          l.resetApp,
                          style: GoogleFonts.outfit(
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppColors.accentRed,
                          side: BorderSide(
                            color: AppColors.accentRed.withValues(alpha: 0.7),
                          ),
                          minimumSize: const Size(168, 44),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(24),
                          ),
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
