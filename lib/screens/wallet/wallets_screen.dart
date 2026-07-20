import 'dart:async';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../../constants/app_colors.dart';
import '../../l10n/app_localizations.dart';
import '../../models/chain.dart';
import '../../models/wallet_account.dart';
import '../../services/blockchain_service.dart';
import '../../services/storage_service.dart';
import '../../services/wallet_service.dart';
import '../../utils/app_error_utils.dart';
import '../../utils/sensitive_access_guard.dart';
import '../../utils/toast_utils.dart';
import '../../utils/value_formatter.dart';
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
  bool _hasMnemonic = false;
  BlockchainService? _blockchain;

  @override
  void initState() {
    super.initState();
    _loadWallets();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final blockchain = Provider.of<BlockchainService>(context, listen: false);
    if (!identical(_blockchain, blockchain)) {
      _blockchain?.removeListener(_handleBlockchainChange);
      _blockchain = blockchain;
      _blockchain?.addListener(_handleBlockchainChange);
    }
  }

  @override
  void dispose() {
    _blockchain?.removeListener(_handleBlockchainChange);
    super.dispose();
  }

  void _handleBlockchainChange() {
    if (!mounted) return;
    final nextActive =
        _blockchain?.activeWalletAddress.trim().toLowerCase() ?? '';
    final currentActive = (_activeAddress ?? '').toLowerCase();
    if (nextActive.isEmpty || nextActive == currentActive) {
      return;
    }
    unawaited(_loadWallets());
  }

  Future<void> _loadWallets() async {
    final l = AppLocalizations.of(context);
    try {
      final accounts = await _walletService.getWalletAccounts();
      final active = await _walletService.getCurrentWalletAddress();
      final hasMnemonic = await _hasAnySeedPhrase(accounts);
      if (!mounted) return;
      setState(() {
        _walletAccounts = accounts;
        _activeAddress = active;
        _hasMnemonic = hasMnemonic;
        _loading = false;
      });
      _syncActiveWalletContext(accounts, active);
    } catch (e) {
      debugPrint('Failed to load wallets: $e');
      if (!mounted) return;
      setState(() => _loading = false);
      ToastUtils.showError(l.unableToLoadWallets);
    }
  }

  Future<bool> _hasAnySeedPhrase(List<WalletAccount> accounts) async {
    for (final account in accounts) {
      if (account.origin != WalletOrigin.derived) continue;
      final mnemonic = await _walletService.getMnemonic(account.address);
      if (mnemonic != null && mnemonic.isNotEmpty) return true;
    }
    return false;
  }

  Future<void> _openCreateSheet() async {
    await showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.cardDark,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => CreateWalletActionSheet(
        canCreateNew: _hasMnemonic,
        onConfirm: (mode) {
          Navigator.pop(ctx);
          switch (mode) {
            case WalletCreateMode.create:
              if (_hasMnemonic) {
                _createWallet();
              } else {
                // No mnemonic — take the user through the full create-wallet
                // onboarding flow to generate a brand-new seed phrase.
                Navigator.pushNamed(
                  context,
                  '/create-wallet',
                ).then((_) => _loadWallets());
              }
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
    final l = AppLocalizations.of(context);
    try {
      final seedGroupId = await _selectSeedGroupForNewAccount();
      if (seedGroupId == null) return;
      await _walletService.createAdditionalWallet(seedGroupId: seedGroupId);
      await _loadWallets();
      ToastUtils.showSuccess(l.newWalletCreated);
    } catch (e) {
      ToastUtils.showError(
        AppErrorUtils.userMessage(
          e,
          fallback: l.unableToCreateWallet('Please try again.'),
        ),
      );
    }
  }

  Map<String, List<WalletAccount>> _seedGroups() {
    final groups = <String, List<WalletAccount>>{};
    for (final account in _walletAccounts) {
      if (account.origin != WalletOrigin.derived) continue;
      final groupId = account.seedGroupId?.trim().isNotEmpty == true
          ? account.seedGroupId!.trim()
          : 'seed_legacy';
      groups.putIfAbsent(groupId, () => <WalletAccount>[]).add(account);
    }
    return groups;
  }

  Future<String?> _selectSeedGroupForNewAccount() async {
    final groups = _seedGroups();
    if (groups.isEmpty) return null;
    if (groups.length == 1) return groups.keys.first;

    final ordered = groups.entries.toList()
      ..sort(
        (a, b) => a.value.first.createdAt.compareTo(b.value.first.createdAt),
      );
    return showModalBottomSheet<String>(
      context: context,
      backgroundColor: AppColors.cardDark,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(18, 16, 18, 22),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Add account to',
                style: GoogleFonts.outfit(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 12),
              for (var i = 0; i < ordered.length; i++)
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(
                    Icons.account_balance_wallet_rounded,
                    color: Color(0xFFAFC2E8),
                  ),
                  title: Text(
                    _seedGroupLabel(ordered[i].key, i),
                    style: GoogleFonts.outfit(color: Colors.white),
                  ),
                  subtitle: Text(
                    '${ordered[i].value.length} account${ordered[i].value.length == 1 ? '' : 's'}',
                    style: GoogleFonts.outfit(color: Colors.white54),
                  ),
                  onTap: () => Navigator.pop(ctx, ordered[i].key),
                ),
            ],
          ),
        ),
      ),
    );
  }

  /// Pushes the active wallet's address and the chain families it actually
  /// supports into [BlockchainService]. This is what makes the home,
  /// settings, and network selector update when the wallet changes from any
  /// tab in the [IndexedStack]-based shell.
  void _syncActiveWalletContext(
    List<WalletAccount> accounts,
    String? activeAddress,
  ) {
    final blockchain = _blockchain;
    if (blockchain == null) return;
    final normalizedActive = (activeAddress ?? '').trim().toLowerCase();
    if (normalizedActive.isEmpty) {
      blockchain.setActiveWalletContext(
        address: '',
        supportedFamilies: const {ChainFamily.evm},
      );
      return;
    }
    WalletAccount? active;
    for (final account in accounts) {
      if (account.address.toLowerCase() == normalizedActive) {
        active = account;
        break;
      }
    }
    final supported =
        active?.addressesByFamily.keys.toSet() ?? const {ChainFamily.evm};
    blockchain.setActiveWalletContext(
      address: activeAddress ?? '',
      supportedFamilies: supported,
    );
  }

  Future<void> _switchWallet(WalletAccount account) async {
    final l = AppLocalizations.of(context);
    if (_activeAddress?.toLowerCase() == account.address.toLowerCase()) return;
    try {
      // Fast storage write — update active address immediately so the tile
      // highlights without waiting for any network call.
      await _walletService.setActiveWallet(account.address);
      if (mounted) {
        setState(() => _activeAddress = account.address);
      }

      // Notify BlockchainService in the background — do NOT await so the UI
      // remains responsive while tokens reload for the new wallet.
      if (mounted) {
        final blockchain = Provider.of<BlockchainService>(
          context,
          listen: false,
        );
        // Push the new wallet context BEFORE refresh so listeners that fire
        // on refresh see the up-to-date address and supported families.
        blockchain.setActiveWalletContext(
          address: account.address,
          supportedFamilies: account.addressesByFamily.keys.toSet(),
        );
        blockchain.refresh();
      }

      // Reload the wallet list metadata (no network involved, just storage).
      await _loadWallets();
      if (mounted) {
        ToastUtils.showSuccess(l.walletSetAsActive(account.name));
      }
    } catch (e) {
      ToastUtils.showError(
        AppErrorUtils.userMessage(
          e,
          fallback: l.unableToSwitchWallet('Please try again.'),
        ),
      );
    }
  }

  Future<void> _showWalletActions(WalletAccount account) async {
    final l = AppLocalizations.of(context);
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
                l.renameWallet,
                style: GoogleFonts.outfit(color: Colors.white),
              ),
              onTap: () => Navigator.pop(ctx, 'rename'),
            ),
            ListTile(
              leading: const Icon(Icons.key_rounded, color: Colors.white70),
              title: Text(
                l.viewPrivateKey,
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
                l.removeWallet,
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
    final l = AppLocalizations.of(context);
    final controller = TextEditingController(text: account.name);
    final newName = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.cardDark,
        title: Text(
          l.renameWallet,
          style: GoogleFonts.outfit(color: Colors.white),
        ),
        content: TextField(
          controller: controller,
          style: GoogleFonts.outfit(color: Colors.white),
          decoration: InputDecoration(
            hintText: l.enterWalletNameHint,
            hintStyle: GoogleFonts.outfit(color: Colors.white54),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(
              l.cancel,
              style: GoogleFonts.outfit(color: Colors.white54),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, controller.text.trim()),
            child: Text(
              l.save,
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
      ToastUtils.showSuccess(l.walletRenamed);
    } catch (e) {
      ToastUtils.showError(
        AppErrorUtils.userMessage(
          e,
          fallback: l.unableToRenameWallet('Please try again.'),
        ),
      );
    }
  }

  Future<void> _confirmDeleteWallet(WalletAccount account) async {
    final l = AppLocalizations.of(context);
    final canDelete = _walletAccounts.length > 1;
    if (!canDelete) {
      ToastUtils.showError(l.mustKeepOneWallet);
      return;
    }
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.cardDark,
        title: Text(
          l.removeWallet,
          style: GoogleFonts.outfit(color: Colors.white),
        ),
        content: Text(
          l.removeWalletWarning,
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
              l.removeWallet,
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
      ToastUtils.showSuccess(l.walletRemoved);
    } catch (e) {
      ToastUtils.showError(
        AppErrorUtils.userMessage(
          e,
          fallback: l.unableToRemoveWallet('Please try again.'),
        ),
      );
    }
  }

  Future<void> _showPrivateKey(WalletAccount account) async {
    final l = AppLocalizations.of(context);
    final authenticated = await SensitiveAccessGuard.verify(
      context,
      reason: l.authenticateToViewPrivateKey,
    );
    if (!authenticated) {
      ToastUtils.showError(l.authenticationRequired);
      return;
    }
    try {
      final activeFamily = _blockchain?.activeFamily ?? ChainFamily.evm;
      final exportFamily = account.addressesByFamily.containsKey(activeFamily)
          ? activeFamily
          : account.addressesByFamily.keys.first;
      final privateKey = await _walletService.exportPrivateKeyForFamily(
        account,
        exportFamily,
      );
      final familyAddress =
          account.getWalletAddressForFamily(exportFamily) ?? account.address;
      if (!mounted) return;
      if (privateKey.isEmpty) {
        ToastUtils.showError(l.noPrivateKeyFound);
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
                  '${_familyLabel(exportFamily)} ${l.privateKey}',
                  style: GoogleFonts.outfit(
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                    fontSize: 18,
                  ),
                ),
                const SizedBox(height: 10),
                SelectableText(
                  familyAddress,
                  style: GoogleFonts.outfit(
                    color: Colors.white54,
                    fontSize: 12,
                  ),
                ),
                const SizedBox(height: 10),
                SelectableText(
                  privateKey,
                  style: GoogleFonts.outfit(color: Colors.white70, height: 1.4),
                ),
                const SizedBox(height: 10),
                Text(
                  l.privateKeySecurityWarning,
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
      ToastUtils.showError(
        AppErrorUtils.userMessage(
          e,
          fallback: l.unableToLoadPrivateKey('Please try again.'),
        ),
      );
    }
  }

  String _familyLabel(ChainFamily family) => switch (family) {
    ChainFamily.evm => 'EVM',
    ChainFamily.solana => 'Solana',
    ChainFamily.tron => 'Tron',
  };

  String _walletValueLabel(WalletAccount account) {
    if (account.address.toLowerCase() == (_activeAddress ?? '').toLowerCase()) {
      return AppLocalizations.of(context).activeWalletLabel;
    }
    return ValueFormatter.formatUsdValue(ValueFormatter.decimalFromNum(0));
  }

  String _seedGroupLabel(String seedGroupId, int index) {
    return 'Wallet ${index + 1}';
  }

  Widget _sectionHeader(String title, {String? subtitle}) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(2, 16, 2, 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: GoogleFonts.outfit(
              color: Colors.white.withValues(alpha: 0.9),
              fontSize: 14,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.4,
            ),
          ),
          if (subtitle != null) ...[
            const SizedBox(height: 2),
            Text(
              subtitle,
              style: GoogleFonts.outfit(color: Colors.white38, fontSize: 12),
            ),
          ],
        ],
      ),
    );
  }

  Widget _walletTile(WalletAccount account) {
    return ManageWalletTile(
      account: account,
      isActive:
          account.address.toLowerCase() == (_activeAddress ?? '').toLowerCase(),
      balanceLabel: _walletValueLabel(account),
      onTap: () => _switchWallet(account),
      onEdit: () => _showWalletActions(account),
    );
  }

  List<Widget> _walletListItems() {
    final items = <Widget>[];
    final seedGroups = _seedGroups().entries.toList()
      ..sort(
        (a, b) => a.value.first.createdAt.compareTo(b.value.first.createdAt),
      );

    for (var i = 0; i < seedGroups.length; i++) {
      final entry = seedGroups[i];
      items.add(
        _sectionHeader(
          _seedGroupLabel(entry.key, i),
          subtitle: 'Seed phrase accounts',
        ),
      );
      final accounts = List<WalletAccount>.from(entry.value)
        ..sort(
          (a, b) => (a.derivationIndex ?? 0).compareTo(b.derivationIndex ?? 0),
        );
      for (final account in accounts) {
        items.add(_walletTile(account));
      }
    }

    final importedAccounts =
        _walletAccounts
            .where((account) => account.origin == WalletOrigin.imported)
            .toList()
          ..sort((a, b) => a.createdAt.compareTo(b.createdAt));
    if (importedAccounts.isNotEmpty) {
      items.add(
        _sectionHeader('Imported accounts', subtitle: 'Private-key wallets'),
      );
      for (final account in importedAccounts) {
        items.add(_walletTile(account));
      }
    }
    return items;
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
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
                        l.manageWalletsTitle,
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
                      children: _walletListItems(),
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
                  l.createAddWallet,
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
