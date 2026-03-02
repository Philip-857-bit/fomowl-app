import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../constants/app_colors.dart';
import '../../models/wallet_account.dart';
import '../../services/storage_service.dart';
import '../../services/wallet_service.dart';
import '../../utils/sensitive_access_guard.dart';
import '../../utils/toast_utils.dart';
import 'widgets/manage_wallet/create_wallet_action_sheet.dart';
import 'widgets/manage_wallet/manage_wallet_tile.dart';

class WalletsScreen extends StatefulWidget {
  const WalletsScreen({super.key});

  @override
  State<WalletsScreen> createState() => _WalletsScreenState();
}

class _WalletsScreenState extends State<WalletsScreen> {
  final WalletService _walletService = WalletService();
  final StorageService _storage = StorageService();

  bool _loading = true;
  String? _activeAddress;
  List<WalletAccount> _walletAccounts = const [];

  @override
  void initState() {
    super.initState();
    _loadWallets();
  }

  Future<void> _loadWallets() async {
    try {
      final accounts = await _walletService.getWalletAccounts();
      final active = await _walletService.getCurrentWalletAddress();
      if (!mounted) return;
      setState(() {
        _walletAccounts = accounts;
        _activeAddress = active;
        _loading = false;
      });
    } catch (e) {
      debugPrint('Failed to load wallets: $e');
      if (!mounted) return;
      setState(() => _loading = false);
      ToastUtils.showError('Unable to load wallets');
    }
  }

  Future<void> _openCreateSheet() async {
    await showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.cardDark,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => CreateWalletActionSheet(
        onConfirm: (mode) {
          Navigator.pop(ctx);
          switch (mode) {
            case WalletCreateMode.create:
              _createWallet();
              break;
            case WalletCreateMode.importSeedPhrase:
              Navigator.pushNamed(
                context,
                '/import-secret-phrase',
              ).then((_) => _loadWallets());
              break;
            case WalletCreateMode.importPrivateKey:
              Navigator.pushNamed(
                context,
                '/import-private-key',
              ).then((_) => _loadWallets());
              break;
          }
        },
      ),
    );
  }

  Future<void> _createWallet() async {
    try {
      await _walletService.createAdditionalWallet();
      await _loadWallets();
      ToastUtils.showSuccess('New wallet created');
    } catch (e) {
      ToastUtils.showError('Unable to create wallet: $e');
    }
  }

  Future<void> _switchWallet(WalletAccount account) async {
    if (_activeAddress?.toLowerCase() == account.address.toLowerCase()) return;
    setState(() => _loading = true);
    try {
      await _walletService.setActiveWallet(account.address);
      await _loadWallets();
      ToastUtils.showSuccess('${account.name} set as active');
    } catch (e) {
      setState(() => _loading = false);
      ToastUtils.showError('Unable to switch wallet: $e');
    }
  }

  Future<void> _showWalletActions(WalletAccount account) async {
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
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            const SizedBox(height: 14),
            ListTile(
              leading: const Icon(Icons.edit_rounded, color: Colors.white70),
              title: Text(
                'Rename Wallet',
                style: GoogleFonts.outfit(color: Colors.white),
              ),
              onTap: () => Navigator.pop(ctx, 'rename'),
            ),
            ListTile(
              leading: const Icon(Icons.key_rounded, color: Colors.white70),
              title: Text(
                'View Private Key',
                style: GoogleFonts.outfit(color: Colors.white),
              ),
              onTap: () => Navigator.pop(ctx, 'privateKey'),
            ),
            ListTile(
              leading: const Icon(
                Icons.delete_outline_rounded,
                color: AppColors.error,
              ),
              title: Text(
                'Remove Wallet',
                style: GoogleFonts.outfit(color: AppColors.error),
              ),
              onTap: () => Navigator.pop(ctx, 'remove'),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );

    if (selected == 'rename') {
      await _promptRenameWallet(account);
      return;
    }
    if (selected == 'privateKey') {
      await _showPrivateKey(account);
      return;
    }
    if (selected == 'remove') {
      await _confirmDeleteWallet(account);
    }
  }

  Future<void> _promptRenameWallet(WalletAccount account) async {
    final controller = TextEditingController(text: account.name);
    final newName = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.cardDark,
        title: Text(
          'Rename Wallet',
          style: GoogleFonts.outfit(color: Colors.white),
        ),
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
            onPressed: () => Navigator.pop(ctx),
            child: Text(
              'Cancel',
              style: GoogleFonts.outfit(color: Colors.white54),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, controller.text.trim()),
            child: Text(
              'Save',
              style: GoogleFonts.outfit(color: AppColors.accentRed),
            ),
          ),
        ],
      ),
    );
    if (newName == null || newName.isEmpty) return;
    try {
      await _storage.renameWallet(account.address, newName);
      await _loadWallets();
      ToastUtils.showSuccess('Wallet renamed');
    } catch (e) {
      ToastUtils.showError('Unable to rename wallet: $e');
    }
  }

  Future<void> _confirmDeleteWallet(WalletAccount account) async {
    final canDelete = _walletAccounts.length > 1;
    if (!canDelete) {
      ToastUtils.showError('You must keep at least one wallet');
      return;
    }
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.cardDark,
        title: Text(
          'Remove Wallet',
          style: GoogleFonts.outfit(color: Colors.white),
        ),
        content: Text(
          'Remove "${account.name}" from this device? This does not delete the wallet onchain.',
          style: GoogleFonts.outfit(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(
              'Cancel',
              style: GoogleFonts.outfit(color: Colors.white54),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(
              'Remove',
              style: GoogleFonts.outfit(color: AppColors.error),
            ),
          ),
        ],
      ),
    );
    if (confirm != true) return;

    try {
      await _walletService.removeWalletAccount(account.address);
      await _loadWallets();
      ToastUtils.showSuccess('Wallet removed');
    } catch (e) {
      ToastUtils.showError('Unable to remove wallet: $e');
    }
  }

  Future<void> _showPrivateKey(WalletAccount account) async {
    final authenticated = await SensitiveAccessGuard.verify(
      context,
      reason: 'Authenticate to view your private key',
    );
    if (!authenticated) {
      ToastUtils.showError('Authentication required');
      return;
    }
    try {
      final privateKey = await _walletService.getPrivateKey(account.address);
      if (!mounted) return;
      if (privateKey == null || privateKey.isEmpty) {
        ToastUtils.showError('No private key found');
        return;
      }
      await showModalBottomSheet<void>(
        context: context,
        backgroundColor: AppColors.cardDark,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        builder: (ctx) => SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(18),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Private Key',
                  style: GoogleFonts.outfit(
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                    fontSize: 18,
                  ),
                ),
                const SizedBox(height: 10),
                SelectableText(
                  privateKey,
                  style: GoogleFonts.outfit(color: Colors.white70, height: 1.4),
                ),
                const SizedBox(height: 10),
                Text(
                  'Never share this with anyone. Anyone with this key can access your funds.',
                  style: GoogleFonts.outfit(
                    color: Colors.white38,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    } catch (e) {
      ToastUtils.showError('Unable to load private key: $e');
    }
  }

  String _walletValueLabel(WalletAccount account) {
    if (account.address.toLowerCase() == (_activeAddress ?? '').toLowerCase()) {
      return 'Active wallet';
    }
    return '\$0.00';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 16, 8, 10),
              child: Row(
                children: [
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(
                      Icons.arrow_back_ios_new_rounded,
                      color: Colors.white,
                    ),
                  ),
                  Expanded(
                    child: Center(
                      child: Text(
                        'Manage Wallets',
                        style: GoogleFonts.outfit(
                          color: Colors.white,
                          fontWeight: FontWeight.w600,
                          fontSize: 18,
                        ),
                      ),
                    ),
                  ),
                  IconButton(
                    onPressed: _openCreateSheet,
                    icon: const Icon(
                      Icons.add_rounded,
                      color: AppColors.accentRed,
                      size: 24,
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: _loading
                  ? const Center(
                      child: CircularProgressIndicator(
                        color: AppColors.accentRed,
                      ),
                    )
                  : ListView(
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 20),
                      children: [
                        for (final account in _walletAccounts)
                          ManageWalletTile(
                            account: account,
                            isActive:
                                account.address.toLowerCase() ==
                                (_activeAddress ?? '').toLowerCase(),
                            balanceLabel: _walletValueLabel(account),
                            onTap: () => _switchWallet(account),
                            onEdit: () => _showWalletActions(account),
                          ),
                      ],
                    ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 20),
              child: ElevatedButton(
                onPressed: _openCreateSheet,
                style: ElevatedButton.styleFrom(
                  minimumSize: const Size.fromHeight(58),
                  backgroundColor: AppColors.accentRed,
                  foregroundColor: Colors.white,
                  elevation: 8,
                  shadowColor: AppColors.accentRed.withValues(alpha: 0.4),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(18),
                  ),
                ),
                child: Text(
                  'Create / Add Wallet',
                  style: GoogleFonts.outfit(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
