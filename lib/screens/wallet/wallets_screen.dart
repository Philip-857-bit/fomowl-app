import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../constants/app_colors.dart';
import '../../services/wallet_service.dart';
import '../../services/storage_service.dart';
import '../../models/wallet_account.dart';
import '../../l10n/app_localizations.dart';
import '../../utils/toast_utils.dart';
import '../../utils/sensitive_access_guard.dart';
import 'widgets/wallets_header.dart';
import 'widgets/active_wallet_card.dart';
import 'widgets/wallet_list.dart';
import 'widgets/security_notice_card.dart';
import 'widgets/add_wallet_button.dart';
import 'widgets/wallet_option_card.dart';

/// Wallets Screen
/// Manage wallets — view current, create new, or import existing
class WalletsScreen extends StatefulWidget {
  const WalletsScreen({super.key});

  @override
  State<WalletsScreen> createState() => _WalletsScreenState();
}

class _WalletsScreenState extends State<WalletsScreen> {
  final WalletService _walletService = WalletService();
  final StorageService _storage = StorageService();

  String? _walletName;
  String? _walletAddress;
  bool _isLoading = true;
  List<WalletAccount> _walletAccounts = [];

  @override
  void initState() {
    super.initState();
    _loadWallet();
  }

  Future<void> _loadWallet() async {
    try {
      final name = await _storage.getWalletName();
      final address = await _walletService.getCurrentWalletAddress();
      final accounts = await _walletService.getWalletAccounts();
      if (mounted) {
        setState(() {
          _walletName = name ?? 'Main Wallet';
          _walletAddress = address;
          _walletAccounts = accounts;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  String _shortenAddress(String address) {
    if (address.length > 13) {
      return '${address.substring(0, 6)}...${address.substring(address.length - 4)}';
    }
    return address;
  }

  void _copyAddress() {
    if (_walletAddress != null) {
      Clipboard.setData(ClipboardData(text: _walletAddress!));
      ToastUtils.showInfo('Address copied to clipboard');
    }
  }

  void _showAddWalletOptions(AppLocalizations l) {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.cardDark,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 36),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40, height: 4,
              decoration: BoxDecoration(
                color: Colors.white24,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 20),
            Text(
              l.addWallet,
              style: GoogleFonts.outfit(fontSize: 20, fontWeight: FontWeight.w600, color: Colors.white),
            ),
            const SizedBox(height: 8),
            Text(
              'Choose how you want to add a wallet',
              style: GoogleFonts.outfit(fontSize: 13, color: Colors.white54),
            ),
            const SizedBox(height: 24),

            // Create new wallet
            WalletOptionCard(
              icon: Icons.add_circle_outline,
              title: l.createNewWallet,
              subtitle: 'Create a new wallet inside this app',
              gradient: AppColors.primaryGradient,
              onTap: () {
                Navigator.pop(ctx);
                _confirmCreateAdditionalWallet();
              },
            ),
            const SizedBox(height: 12),

            // Import via seed phrase
            WalletOptionCard(
              icon: Icons.key,
              title: l.importSeedPhrase,
              subtitle: 'Recover using your 12 or 24 word phrase',
              gradient: const LinearGradient(
                colors: [Color(0xFF2D5AA0), Color(0xFF1A3660)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              onTap: () {
                Navigator.pop(ctx);
                Navigator.pushNamed(context, '/import-secret-phrase');
              },
            ),
            const SizedBox(height: 12),

            // Import via private key
            WalletOptionCard(
              icon: Icons.vpn_key_outlined,
              title: l.importPrivateKey,
              subtitle: 'Paste your private key to access your wallet',
              gradient: const LinearGradient(
                colors: [Color(0xFF5C4D9B), Color(0xFF362D5E)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              onTap: () {
                Navigator.pop(ctx);
                Navigator.pushNamed(context, '/import-private-key');
              },
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          children: [
            // Header
            WalletsHeader(
              title: l.wallets,
              onBack: () => Navigator.pop(context),
            ),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.only(bottom: 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 24),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            l.activeWallet.toUpperCase(),
                            style: GoogleFonts.outfit(fontSize: 11, fontWeight: FontWeight.w600, color: Colors.white38, letterSpacing: 1.2),
                          ),
                          const SizedBox(height: 12),
                          if (_isLoading)
                            const Center(child: CircularProgressIndicator(color: AppColors.accentRed))
                          else
                            ActiveWalletCard(
                              walletName: _walletName ?? 'Main Wallet',
                              displayAddress: _walletAddress != null ? _shortenAddress(_walletAddress!) : '--',
                              fullAddress: _walletAddress,
                              onCopyAddress: _copyAddress,
                              onViewPrivateKey: _showPrivateKey,
                            ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 32),
                    if (!_isLoading && _walletAccounts.length > 1) ...[
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 20),
                        child: WalletList(
                          wallets: _walletAccounts,
                          activeAddress: _walletAddress,
                          onSelect: _switchWallet,
                          onRename: _promptRenameWallet,
                          shortenAddress: _shortenAddress,
                        ),
                      ),
                      const SizedBox(height: 32),
                    ],
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      child: const SecurityNoticeCard(),
                    ),
                    const SizedBox(height: 32),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      child: AddWalletButton(
                        label: l.addWallet,
                        onPressed: () => _showAddWalletOptions(l),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _confirmCreateAdditionalWallet() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.cardDark,
        title: Text('Create new wallet', style: GoogleFonts.outfit(color: Colors.white)),
        content: Text(
          'We will add another wallet to your account. Keep your recovery phrase stored safely.',
          style: GoogleFonts.outfit(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Cancel', style: GoogleFonts.outfit(color: Colors.white54)),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _createAdditionalWallet();
            },
            child: Text('Create', style: GoogleFonts.outfit(color: AppColors.accentRed)),
          ),
        ],
      ),
    );
  }

  Future<void> _createAdditionalWallet() async {
    try {
      await _walletService.createAdditionalWallet();
      if (mounted) {
        ToastUtils.showSuccess('New wallet created');
        await _loadWallet();
      }
    } catch (e) {
      if (mounted) {
        ToastUtils.showError('Unable to create wallet: $e');
      }
    }
  }

  Future<void> _switchWallet(WalletAccount account) async {
    if (_walletAddress != null && _walletAddress!.toLowerCase() == account.address.toLowerCase()) {
      return;
    }
    setState(() => _isLoading = true);
    try {
      await _walletService.setActiveWallet(account.address);
      await _loadWallet();
      if (mounted) {
        ToastUtils.showSuccess('${account.name} set as active');
      }
    } catch (e) {
      if (mounted) {
        ToastUtils.showError('Unable to switch wallet: $e');
      }
    }
  }

  Future<void> _promptRenameWallet(WalletAccount account) async {
    final controller = TextEditingController(text: account.name);
    final newName = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.cardDark,
        title: Text('Rename Wallet', style: GoogleFonts.outfit(color: Colors.white)),
        content: TextField(
          controller: controller,
          style: GoogleFonts.outfit(color: Colors.white),
          decoration: InputDecoration(
            hintText: 'Enter wallet name',
            hintStyle: GoogleFonts.outfit(color: Colors.white54),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Cancel', style: GoogleFonts.outfit(color: Colors.white54)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, controller.text.trim()),
            child: Text('Save', style: GoogleFonts.outfit(color: AppColors.accentRed)),
          ),
        ],
      ),
    );
    if (newName == null || newName.isEmpty) return;
    await _storage.renameWallet(account.address, newName);
    await _loadWallet();
    if (mounted) {
      ToastUtils.showSuccess('Wallet renamed');
    }
  }

  Future<void> _showPrivateKey() async {
    final authenticated = await SensitiveAccessGuard.verify(
      context,
      reason: 'Authenticate to view your private key',
    );
    if (!authenticated) {
      ToastUtils.showError('Authentication required to view private key');
      return;
    }
    try {
      final privateKey = await _walletService.getPrivateKey();
      if (!mounted) return;
      if (privateKey == null) {
        ToastUtils.showError('No private key found');
        return;
      }
      showModalBottomSheet(
        context: context,
        backgroundColor: AppColors.cardDark,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        builder: (context) => Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Private Key', style: GoogleFonts.outfit(fontSize: 16, fontWeight: FontWeight.w600, color: Colors.white)),
              const SizedBox(height: 12),
              SelectableText(
                privateKey,
                style: GoogleFonts.outfit(color: Colors.white70),
              ),
              const SizedBox(height: 12),
              Text(
                'Never share this private key. Anyone with this key can control your funds.',
                style: GoogleFonts.outfit(fontSize: 12, color: Colors.white38),
              ),
            ],
          ),
        ),
      );
    } catch (e) {
      if (mounted) {
        ToastUtils.showError('Unable to display private key: $e');
      }
    }
  }

}
