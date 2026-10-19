import 'dart:async';
import 'package:flutter/material.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../../l10n/app_localizations_en.dart';
import '../../../../models/bitcoin_account_state.dart';
import '../../../../models/bitcoin_network_data.dart';
import '../../../../services/bitcoin/bitcoin_network_service.dart';
import '../../../../theme/app_chain_theme.dart';

/// Fee-rate facts only. The SDK planner calculates the actual transaction fee.
class BitcoinFeeTierSelector extends StatefulWidget {
  final BitcoinProductNetwork network;
  final BitcoinFeeTier selected;
  final ValueChanged<BitcoinFeeTier> onChanged;
  final bool enabled;
  final BitcoinNetworkApi? api;
  const BitcoinFeeTierSelector({
    super.key,
    required this.network,
    this.selected = BitcoinFeeTier.normal,
    required this.onChanged,
    this.enabled = true,
    this.api,
  });
  @override
  State<BitcoinFeeTierSelector> createState() => _BitcoinFeeTierSelectorState();
}

class _BitcoinFeeTierSelectorState extends State<BitcoinFeeTierSelector> {
  BitcoinFeeRates? _rates;
  bool _failed = false;
  int _generation = 0;
  Timer? _refresh;
  @override
  void initState() {
    super.initState();
    _load();
    _refresh = Timer.periodic(
      const Duration(minutes: 1),
      (_) => _load(clear: false),
    );
  }

  @override
  void dispose() {
    _refresh?.cancel();
    super.dispose();
  }

  @override
  void didUpdateWidget(BitcoinFeeTierSelector oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.network != widget.network || oldWidget.api != widget.api) {
      _load();
    }
  }

  Future<void> _load({bool clear = true}) async {
    final generation = ++_generation;
    if (clear) {
      setState(() {
        _rates = null;
        _failed = false;
      });
    }
    try {
      final rates = await (widget.api ?? BitcoinNetworkService()).fetchFeeRates(
        widget.network,
      );
      if (mounted && generation == _generation) setState(() => _rates = rates);
    } catch (_) {
      if (mounted && generation == _generation) setState(() => _failed = true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l =
        Localizations.of<AppLocalizations>(context, AppLocalizations) ??
        AppLocalizationsEn();
    final rates = _rates;
    final accent = context.chainTheme.accentColor;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            rates?.hasDistinctTiers == true
                ? l.bitcoinNetworkSpeed
                : l.bitcoinNetworkFee,
            style: const TextStyle(
              fontSize: 11,
              letterSpacing: 1,
              color: Colors.white60,
            ),
          ),
          const SizedBox(height: 12),
          if (rates == null)
            if (_failed)
              TextButton.icon(
                onPressed: widget.enabled ? _load : null,
                icon: const Icon(Icons.refresh),
                label: Text(l.retry),
              )
            else
              LinearProgressIndicator(color: accent)
          else if (!rates.hasDistinctTiers)
            Text(
              l.bitcoinEqualFeeTiers,
              key: const Key('bitcoin-equivalent-fees'),
              style: const TextStyle(fontSize: 13, color: Colors.white70),
            )
          else
            SizedBox(
              width: double.infinity,
              child: SegmentedButton<BitcoinFeeTier>(
                key: const Key('bitcoin-fee-tiers'),
                showSelectedIcon: false,
                style: ButtonStyle(
                  visualDensity: VisualDensity.compact,
                  padding: const WidgetStatePropertyAll(
                    EdgeInsets.symmetric(horizontal: 8, vertical: 12),
                  ),
                  backgroundColor: WidgetStateProperty.resolveWith(
                    (states) => states.contains(WidgetState.selected)
                        ? accent.withValues(alpha: 0.2)
                        : Colors.transparent,
                  ),
                  foregroundColor: WidgetStateProperty.resolveWith(
                    (states) => states.contains(WidgetState.selected)
                        ? accent
                        : Colors.white70,
                  ),
                ),
                segments: [
                  ButtonSegment(
                    value: BitcoinFeeTier.economy,
                    label: Text(l.bitcoinEconomy),
                  ),
                  ButtonSegment(
                    value: BitcoinFeeTier.normal,
                    label: Text(l.bitcoinNormal),
                  ),
                  ButtonSegment(
                    value: BitcoinFeeTier.priority,
                    label: Text(l.bitcoinPriority),
                  ),
                ],
                selected: {widget.selected},
                onSelectionChanged: widget.enabled
                    ? (values) => widget.onChanged(values.single)
                    : null,
              ),
            ),
        ],
      ),
    );
  }
}
