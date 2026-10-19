import 'package:flutter/material.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../../models/bitcoin_account_state.dart';
import '../../../../theme/app_chain_theme.dart';

/// Address-sharing preference only; switching formats never allocates an index.
class BitcoinReceiveFormatSelector extends StatelessWidget {
  final BitcoinPurpose selected;
  final ValueChanged<BitcoinPurpose> onChanged;
  const BitcoinReceiveFormatSelector({
    super.key,
    this.selected = BitcoinPurpose.bip84,
    required this.onChanged,
  });
  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final accent = context.chainTheme.accentColor;
    return SegmentedButton<BitcoinPurpose>(
      key: const Key('bitcoin-receive-formats'),
      showSelectedIcon: false,
      segments: [
        ButtonSegment(
          value: BitcoinPurpose.bip84,
          label: Text(l.bitcoinNativeSegwit),
        ),
        ButtonSegment(
          value: BitcoinPurpose.bip86,
          label: Text(l.bitcoinTaproot),
        ),
      ],
      selected: {selected},
      style: ButtonStyle(
        backgroundColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected)
              ? accent.withValues(alpha: 0.2)
              : Colors.transparent,
        ),
        foregroundColor: WidgetStateProperty.resolveWith(
          (states) =>
              states.contains(WidgetState.selected) ? accent : Colors.white70,
        ),
      ),
      onSelectionChanged: (values) => onChanged(values.single),
    );
  }
}
