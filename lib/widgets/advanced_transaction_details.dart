import 'package:flutter/material.dart';

/// Public, user-facing protocol mechanics supplied by each confirmation host.
class AdvancedTransactionDetail {
  final String label;
  final String value;
  final bool selectable;
  const AdvancedTransactionDetail({
    required this.label,
    required this.value,
    this.selectable = false,
  });
}

/// Presentation only: no account, transaction or chain-specific dependencies.
class AdvancedTransactionDetails extends StatefulWidget {
  final String title;
  final List<AdvancedTransactionDetail> items;
  const AdvancedTransactionDetails({
    super.key,
    required this.title,
    required this.items,
  });
  @override
  State<AdvancedTransactionDetails> createState() =>
      _AdvancedTransactionDetailsState();
}

class _AdvancedTransactionDetailsState
    extends State<AdvancedTransactionDetails> {
  bool _expanded = false;
  @override
  Widget build(BuildContext context) => Material(
    color: Colors.white.withValues(alpha: 0.05),
    borderRadius: BorderRadius.circular(14),
    clipBehavior: Clip.antiAlias,
    child: Column(
      children: [
        Semantics(
          expanded: _expanded,
          child: ListTile(
            key: const Key('advanced-transaction-details-toggle'),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
            ),
            title: Text(
              widget.title,
              style: const TextStyle(fontSize: 14, color: Colors.white),
            ),
            trailing: Icon(
              _expanded ? Icons.expand_less : Icons.expand_more,
              color: Colors.white70,
            ),
            onTap: () => setState(() => _expanded = !_expanded),
          ),
        ),
        if (_expanded)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
            child: Column(
              children: [
                for (final item in widget.items)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Text(
                            item.label,
                            style: const TextStyle(
                              fontSize: 13,
                              color: Colors.white60,
                            ),
                          ),
                        ),
                        const SizedBox(width: 16),
                        Flexible(
                          child: item.selectable
                              ? SelectableText(
                                  item.value,
                                  textAlign: TextAlign.end,
                                  style: const TextStyle(
                                    fontSize: 13,
                                    color: Colors.white,
                                  ),
                                )
                              : Text(
                                  item.value,
                                  textAlign: TextAlign.end,
                                  style: const TextStyle(
                                    fontSize: 13,
                                    color: Colors.white,
                                  ),
                                ),
                        ),
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
