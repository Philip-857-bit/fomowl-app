import 'dart:async';

import 'package:flutter/material.dart';

import '../../services/blockchain/asset_chain_bridge_client.dart';
import '../../services/blockchain/asset_chain_native_bridge_service.dart';
import '../../services/blockchain_service.dart';
import '../../services/runtime_config_service.dart';
import '../../services/wallet_service.dart';
import '../../utils/amount_utils.dart';
import '../../utils/sensitive_access_guard.dart';
import '../../widgets/runtime_feature_gate.dart';

/// Native BridgeAssist transfers to and from Asset Chain. Relay remains a
/// separate option on the existing bridge tab.
class AssetChainNativeBridgeScreen extends StatefulWidget {
  final BlockchainService blockchain;
  final WalletService walletService;
  final String walletAddress;
  final AssetChainNativeBridgeService? service;
  const AssetChainNativeBridgeScreen({
    super.key,
    required this.blockchain,
    required this.walletService,
    required this.walletAddress,
    this.service,
  });
  @override
  State<AssetChainNativeBridgeScreen> createState() =>
      _AssetChainNativeBridgeScreenState();
}

class _AssetChainNativeBridgeScreenState
    extends State<AssetChainNativeBridgeScreen> {
  late final _service =
      widget.service ??
      AssetChainNativeBridgeService(wallet: widget.walletService);
  final _amount = TextEditingController();
  List<AssetChainNativeBridgeRoute> _routes = [];
  List<AssetChainBridgeTransaction> _transfers = [];
  List<Map<String, dynamic>> _pending = [];
  AssetChainNativeBridgeRoute? _route;
  AssetChainNativeBridgeQuote? _quote;
  String? _error, _status;
  bool _loading = true, _busy = false;
  int _generation = 0;

  @override
  void initState() {
    super.initState();
    unawaited(_load());
  }

  bool get _allowed =>
      RuntimeConfigService.instance.snapshot.allows(RuntimeFeature.bridges) &&
      RuntimeConfigService.instance.snapshot.allows(RuntimeFeature.transfers);

  Future<void> _load() async {
    final generation = ++_generation;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final deployments = await _service.api.getBridges();
      final routes = AssetChainNativeBridgeService.routes(
        deployments,
        widget.blockchain.allChains,
      );
      await _service.synchronize(
        widget.walletAddress,
        widget.blockchain.allChains,
      );
      final transfers = await _service.api.getTransactions(
        userAddress: widget.walletAddress,
        forceSync: true,
        limit: 100,
      );
      final pending = await _service.pending(widget.walletAddress);
      if (!mounted || generation != _generation) return;
      setState(() {
        _routes = routes;
        _route =
            routes.where((route) => route.id == _route?.id).firstOrNull ??
            routes
                .where(
                  (route) =>
                      route.sourceChain.chainId ==
                      widget.blockchain.activeChain.chainId,
                )
                .firstOrNull ??
            routes.firstOrNull;
        _quote = null;
        _transfers = transfers.items;
        _pending = pending;
      });
    } catch (error) {
      if (mounted && generation == _generation) {
        setState(() => _error = _message(error));
      }
    } finally {
      if (mounted && generation == _generation) {
        setState(() => _loading = false);
      }
    }
  }

  String _message(Object error) =>
      error.toString().replaceFirst(RegExp(r'^(Bad state: |Exception: )'), '');

  Future<void> _preview() async {
    final route = _route;
    if (route == null || _busy) return;
    setState(() {
      _busy = true;
      _error = null;
      _quote = null;
    });
    try {
      final quote = await _service.quote(route, _amount.text.trim());
      if (mounted) setState(() => _quote = quote);
    } catch (error) {
      if (mounted) setState(() => _error = _message(error));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _execute({
    AssetChainBridgeTransaction? transfer,
    AssetChainNativeBridgeRoute? claimRoute,
  }) async {
    if (_busy || !_allowed) return;
    final approved = _quote;
    if (transfer == null && approved == null) return;
    setState(() {
      _busy = true;
      _error = null;
      _status = null;
    });
    try {
      final accepted = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: Text(
            transfer == null
                ? 'Confirm bridge transfer'
                : 'Confirm bridge claim',
          ),
          content: Text(
            transfer == null
                ? '${_amount.text.trim()} ${approved!.route.symbol}\n${approved.route.sourceChain.name} → ${approved.route.destinationChain.name}\n\nEstimated received: ${approved.receivedText} ${approved.route.destination.token!.symbol}\n\nNetwork fees are charged on each network. A token approval may be required. The destination requires a separate claim.'
                : 'Claim ${transfer.symbol} on ${claimRoute!.destinationChain.name} to your wallet. A destination network fee is required.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Continue'),
            ),
          ],
        ),
      );
      if (accepted != true || !mounted || !_allowed) return;
      final authenticated = await SensitiveAccessGuard.verify(
        context,
        reason: transfer == null
            ? 'Authenticate to bridge your tokens.'
            : 'Authenticate to claim your bridged tokens.',
        requireTwoFactor: false,
      );
      if (!authenticated || !mounted || !_allowed) return;
      bool current() => mounted && _allowed;
      void status(String value) {
        if (mounted) setState(() => _status = value);
      }

      final hash = transfer == null
          ? await _service.send(
              approved!,
              widget.walletAddress,
              isCurrent: current,
              onStatus: status,
            )
          : await _service.claim(
              transfer,
              claimRoute!,
              widget.walletAddress,
              isCurrent: current,
              onStatus: status,
            );
      if (!mounted) return;
      setState(
        () => _status = transfer == null
            ? 'Source transfer confirmed: $hash. Refresh transfers to check when your claim is ready.'
            : 'Claim confirmed: $hash',
      );
      await _load();
      if (transfer == null) _amount.clear();
    } catch (error) {
      if (mounted) {
        setState(() => _error = _message(error));
        final pending = await _service.pending(widget.walletAddress);
        if (mounted) setState(() => _pending = pending);
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  AssetChainNativeBridgeRoute? _claimRoute(
    AssetChainBridgeTransaction transfer,
  ) {
    final matches = _routes
        .where(
          (route) =>
              route.source.chainId ==
                  transfer.fromChain.replaceFirst('evm.', '') &&
              route.destination.chainId ==
                  transfer.toChain.replaceFirst('evm.', '') &&
              AssetChainNativeBridgeService.normalizedSymbol(route.symbol) ==
                  AssetChainNativeBridgeService.normalizedSymbol(
                    transfer.symbol,
                  ) &&
              (transfer.bridgeInfoId == null ||
                  transfer.bridgeInfoId == route.source.id),
        )
        .toList();
    return matches.length == 1 ? matches.single : null;
  }

  @override
  void dispose() {
    ++_generation;
    _amount.dispose();
    if (widget.service == null) _service.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => RuntimeFeatureGate(
    feature: RuntimeFeature.bridges,
    child: PopScope(
      canPop: !_busy,
      child: Scaffold(
        appBar: AppBar(title: const Text('Asset Chain native bridge')),
        body: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            Text(
              'Transfer to your wallet',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 8),
            const Text(
              'Bridge supported tokens to or from Asset Chain, then claim them on the destination network.',
            ),
            const SizedBox(height: 20),
            if (_loading) const LinearProgressIndicator(),
            if (_error != null)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 12),
                child: Text(
                  _error!,
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              ),
            if (!_loading && _routes.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 12),
                child: Text(
                  'No native bridge routes are configured for the wallet’s supported networks.',
                ),
              ),
            if (_routes.isNotEmpty) ...[
              DropdownButtonFormField<String>(
                initialValue: _route?.id,
                isExpanded: true,
                decoration: const InputDecoration(labelText: 'Token and route'),
                items: _routes
                    .map(
                      (route) => DropdownMenuItem(
                        value: route.id,
                        child: Text(
                          '${route.symbol} · ${route.sourceChain.name} → ${route.destinationChain.name}',
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    )
                    .toList(),
                onChanged: _busy || _loading
                    ? null
                    : (value) => setState(() {
                        _route = _routes.firstWhere(
                          (route) => route.id == value,
                        );
                        _quote = null;
                      }),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _amount,
                enabled: !_busy && !_loading,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                decoration: InputDecoration(
                  labelText: 'Amount ${_route?.symbol ?? ''}',
                ),
                onChanged: (_) => setState(() => _quote = null),
              ),
              const SizedBox(height: 12),
              OutlinedButton(
                onPressed: _busy || _loading || _pending.isNotEmpty
                    ? null
                    : _preview,
                child: const Text('Review bridge amount'),
              ),
              if (_quote != null)
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Estimated received'),
                        Text(
                          '${_quote!.receivedText} ${_quote!.route.destination.token!.symbol}',
                          style: Theme.of(context).textTheme.titleLarge,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Send fee: ${(_quote!.sendFee.toDouble() / _quote!.denominator.toDouble() * 100).toStringAsFixed(2)}% · Claim fee: ${(_quote!.receiveFee.toDouble() / _quote!.denominator.toDouble() * 100).toStringAsFixed(2)}%',
                        ),
                        const Text(
                          'Network fees are additional and depend on each network.',
                        ),
                        const SizedBox(height: 12),
                        FilledButton(
                          onPressed: _busy || !_allowed || _pending.isNotEmpty
                              ? null
                              : () => _execute(),
                          child: const Text('Bridge tokens'),
                        ),
                      ],
                    ),
                  ),
                ),
            ],
            if (_status != null)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 12),
                child: SelectableText(_status!),
              ),
            if (_pending.isNotEmpty)
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Saved transactions'),
                      const Text(
                        'Check these submissions before sending again.',
                      ),
                      for (final item in _pending)
                        SelectableText('${item['kind']} · ${item['hash']}'),
                    ],
                  ),
                ),
              ),
            const SizedBox(height: 24),
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Your transfers',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                ),
                TextButton(
                  onPressed: _busy || _loading ? null : _load,
                  child: const Text('Refresh'),
                ),
              ],
            ),
            if (!_loading && _transfers.isEmpty)
              const Text('No bridge transfers found for this wallet.'),
            for (final transfer in _transfers) _transferCard(context, transfer),
          ],
        ),
      ),
    ),
  );

  Widget _transferCard(
    BuildContext context,
    AssetChainBridgeTransaction transfer,
  ) {
    final route = _claimRoute(transfer);
    final self =
        transfer.toUser.toLowerCase() == widget.walletAddress.toLowerCase() &&
        transfer.fromUser.toLowerCase() == widget.walletAddress.toLowerCase();
    final claimText = route == null
        ? 'Route unavailable'
        : transfer.fulfilled
        ? 'Claimed'
        : 'Claim on ${route.destinationChain.name}';
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '${transfer.symbol} · ${transfer.fromChain} → ${transfer.toChain}',
            ),
            if (route != null)
              Text(
                '${AmountUtils.formatBaseUnits(BigInt.tryParse(transfer.amount) ?? BigInt.zero, route.source.tokenDecimal, maxFractionDigits: 8)} ${transfer.symbol}',
              ),
            SelectableText(
              transfer.transactionHash,
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: 8),
            Text(
              transfer.fulfilled
                  ? 'Destination claim confirmed'
                  : 'Awaiting destination claim; relayer confirmations may still be pending.',
            ),
            if (!transfer.fulfilled && self)
              TextButton(
                onPressed:
                    _busy ||
                        _loading ||
                        !_allowed ||
                        route == null ||
                        _pending.any(
                          (item) => item['transactionId'] == transfer.id,
                        )
                    ? null
                    : () => _execute(transfer: transfer, claimRoute: route),
                child: Text(claimText),
              ),
          ],
        ),
      ),
    );
  }
}
