import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../l10n/app_localizations.dart';
import '../../../models/chain.dart';
import '../../../models/wallet_account.dart';
import '../../../services/blockchain_service.dart';
import '../../../services/wallet_service.dart';
import '../../../services/bitcoin/bitcoin_network_preference_service.dart';
import 'settings_item_tile.dart';

class BitcoinNetworkPreferenceTile extends StatefulWidget {
  final WalletOrigin origin;
  final WalletService wallet;
  const BitcoinNetworkPreferenceTile({
    super.key,
    required this.origin,
    required this.wallet,
  });
  @override
  State<BitcoinNetworkPreferenceTile> createState() =>
      _BitcoinNetworkPreferenceTileState();
}

class _BitcoinNetworkPreferenceTileState
    extends State<BitcoinNetworkPreferenceTile> {
  bool _busy = false;
  Future<void> _toggle(BlockchainService blockchain, bool enabled) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      await BitcoinNetworkPreferenceService(
        blockchain: blockchain,
        wallet: widget.wallet,
      ).setEnabled(enabled);
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              AppLocalizations.of(context).bitcoinCapabilityUnavailable,
            ),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final blockchain = context.watch<BlockchainService>();
    if (widget.origin != WalletOrigin.derived ||
        !blockchain.activeWalletSupportedFamilies.contains(
          ChainFamily.bitcoin,
        ) ||
        !blockchain.isBitcoinNetworkAvailable('bitcoin:mainnet')) {
      return const SizedBox.shrink();
    }
    final l = AppLocalizations.of(context);
    final enabled = blockchain.enabledFamilies.contains(ChainFamily.bitcoin);
    return SettingsItemTile(
      icon: Icons.currency_bitcoin,
      title: 'Bitcoin',
      subtitle: 'BTC · ${l.bitcoinNativeSegwit} / ${l.bitcoinTaproot}',
      onTap: _busy ? null : () => _toggle(blockchain, !enabled),
      trailing: Switch(
        key: const Key('bitcoin-network-preference'),
        value: enabled,
        onChanged: _busy ? null : (value) => _toggle(blockchain, value),
      ),
    );
  }
}
