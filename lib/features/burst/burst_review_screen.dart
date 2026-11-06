import 'package:flutter/material.dart';

import 'burst_theme.dart';
import 'package:flutter/services.dart';

import '../../widgets/bottom_navigation.dart';
import '../shell/app_shell_controller.dart';
import 'package:flutter_svg/flutter_svg.dart';

import 'burst_transaction_executor.dart';
import 'burst_share.dart';

String burstNativeAmount(String raw, String symbol) {
  final value = BigInt.tryParse(raw);
  if (value == null || value.isNegative) return 'Unavailable';
  final unit = BigInt.from(10).pow(18);
  final whole = value ~/ unit;
  final fraction = (value % unit)
      .toString()
      .padLeft(18, '0')
      .replaceFirst(RegExp(r'0+$'), '');
  return '$whole${fraction.isEmpty ? '' : '.$fraction'} $symbol';
}

String burstAssetAmount(String raw, int decimals, String symbol) {
  final value = BigInt.tryParse(raw);
  if (value == null || value.isNegative || decimals < 0 || decimals > 255) {
    return 'Unavailable';
  }
  final unit = BigInt.from(10).pow(decimals);
  final fraction = decimals == 0
      ? ''
      : (value % unit)
            .toString()
            .padLeft(decimals, '0')
            .replaceFirst(RegExp(r'0+$'), '');
  return '${value ~/ unit}${fraction.isEmpty ? '' : '.$fraction'} $symbol';
}

String burstUpfrontNativeCost(Map campaign, String symbol) {
  final values = [
    campaign['platformFeeBaseUnits'],
    campaign['gasSponsorshipFeeBaseUnits'],
    if (campaign['assetKind'] == 'native') campaign['totalAmountBaseUnits'],
  ];
  var total = BigInt.zero;
  for (final raw in values) {
    if (raw is! String || !RegExp(r'^\d+$').hasMatch(raw)) return 'Unavailable';
    final value = BigInt.parse(raw);
    if (value.bitLength > 256) return 'Unavailable';
    total += value;
  }
  return burstNativeAmount(total.toString(), symbol);
}

class BurstReviewScreen extends StatefulWidget {
  const BurstReviewScreen({
    super.key,
    required this.prepared,
    required this.executor,
    required this.nativeSymbol,
    this.chainName,
    this.onCompleted,
  });
  final Map<String, dynamic> prepared;
  final BurstTransactionExecutor executor;
  final String nativeSymbol;
  final String? chainName;
  final Future<void> Function()? onCompleted;
  @override
  State<BurstReviewScreen> createState() => _BurstReviewScreenState();
}

class _BurstReviewScreenState extends State<BurstReviewScreen> {
  final _scrollController = ScrollController();
  bool _busy = false;
  bool _complete = false;
  bool _allowCompletePop = false;
  String? _error;
  String? _unknownReference;
  final _confirmed = <String>{};

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _leaveComplete(bool viewCampaign) {
    if (_allowCompletePop) return;
    setState(() => _allowCompletePop = true);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) Navigator.of(context).pop(viewCampaign);
    });
  }

  Future<void> _create() async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final transactions = widget.prepared['transactions'];
      if (transactions is! List || transactions.isEmpty) {
        throw const FormatException('The transaction list is unavailable.');
      }
      for (final item in transactions) {
        if (item is! Map || item['reference'] is! String) {
          throw const FormatException('Invalid Burst transaction.');
        }
        final reference = item['reference'] as String;
        if (_confirmed.contains(reference)) continue;
        final result = await widget.executor.execute(
          reference,
          expectedTransaction: Map<String, dynamic>.from(item),
          expectedCampaignId:
              (widget.prepared['campaign'] as Map)['id'] as String,
        );
        if (!result.confirmed) {
          throw StateError(
            'The transaction is pending. Check again before continuing.',
          );
        }
        _confirmed.add(reference);
      }
      await widget.onCompleted?.call();
      if (mounted) {
        setState(() => _complete = true);
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted && _scrollController.hasClients) {
            _scrollController.jumpTo(0);
          }
        });
      }
    } catch (error) {
      if (error is BurstUnknownSubmission) _unknownReference = error.reference;
      if (mounted) {
        setState(
          () => _error = error
              .toString()
              .replaceFirst('Bad state: ', '')
              .replaceFirst('FormatException: ', ''),
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _recover() async {
    final reference = _unknownReference;
    if (reference == null || _busy) return;
    final controller = TextEditingController();
    final hash = await showDialog<String>(
      context: context,
      builder: (dialog) => AlertDialog(
        title: const Text('Recover transaction'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Paste the transaction hash from wallet history. Owllet will verify it matches this Burst.',
            ),
            TextField(
              controller: controller,
              decoration: const InputDecoration(labelText: 'Transaction hash'),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialog),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialog, controller.text),
            child: const Text('Verify'),
          ),
        ],
      ),
    );
    controller.dispose();
    if (hash == null || !mounted) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final items = widget.prepared['transactions'] as List;
      final item = items.whereType<Map>().firstWhere(
        (value) => value['reference'] == reference,
      );
      final result = await widget.executor.recoverUnknown(
        reference,
        hash,
        expectedTransaction: Map<String, dynamic>.from(item),
        expectedCampaignId:
            (widget.prepared['campaign'] as Map)['id'] as String,
      );
      if (result.confirmed) _confirmed.add(reference);
      if (mounted) {
        setState(() {
          _unknownReference = null;
          if (!result.confirmed) {
            _error =
                'The transaction is pending. Check again before continuing.';
          }
        });
      }
    } catch (error) {
      if (mounted) {
        setState(
          () => _error = error
              .toString()
              .replaceFirst('Bad state: ', '')
              .replaceFirst('FormatException: ', ''),
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final campaign = widget.prepared['campaign'] as Map;
    final code = widget.prepared['joinCode'] as String;
    String displayTime(Object? raw) {
      if (raw is! int || raw < 0 || raw > 8640000000000) {
        return 'Unavailable';
      }
      final date = DateTime.fromMillisecondsSinceEpoch(raw * 1000).toLocal();
      final localizations = MaterialLocalizations.of(context);
      return '${localizations.formatMediumDate(date)} ${localizations.formatTimeOfDay(TimeOfDay.fromDateTime(date))}';
    }

    return PopScope<bool>(
      canPop: !_complete || _allowCompletePop,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop && _complete) _leaveComplete(false);
      },
      child: Scaffold(
        backgroundColor: Colors.black,
        bottomNavigationBar: _complete && widget.onCompleted != null
            ? BottomNavBar(
                currentTab: AppShellTab.wallet,
                onCurrentTabTap: () =>
                    Navigator.of(context).pushNamedAndRemoveUntil(
                      '/shell',
                      (route) => false,
                      arguments: AppShellTab.wallet.index,
                    ),
              )
            : null,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          foregroundColor: Colors.white,
          title: _complete ? const BurstHeader() : const Text('Confirm Burst'),
          centerTitle: true,
        ),
        body: SafeArea(
          child: ListView(
            controller: _scrollController,
            padding: const EdgeInsets.all(24),
            children: [
              if (_complete) ...[
                Center(
                  child: Container(
                    width: 105,
                    height: 105,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: burstAccent(context).withValues(alpha: 0.6),
                          blurRadius: 30,
                          spreadRadius: 2,
                        ),
                      ],
                    ),
                    child: Image.asset(
                      'assets/burst/create_icon.png',
                      width: 105,
                      height: 105,
                      fit: BoxFit.contain,
                      color: burstAccent(context),
                      colorBlendMode: BlendMode.srcIn,
                      excludeFromSemantics: true,
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                const Text(
                  'Burst Created!',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 12),
                const Text(
                  'Your Owllet Burst is live and ready for guests.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.white70),
                ),
                const SizedBox(height: 30),
                Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 300),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xff191516),
                        border: Border.all(color: const Color(0xff302829)),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Flexible(
                            child: SelectableText(
                              code,
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                color: burstAccent(context),
                                fontSize: 24,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          IconButton(
                            tooltip: 'Copy code',
                            onPressed: () =>
                                Clipboard.setData(ClipboardData(text: code)),
                            icon: const Icon(
                              Icons.content_copy,
                              color: Colors.white70,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                const Text(
                  'INVITE CODE',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.white70, fontSize: 11),
                ),
                const SizedBox(height: 20),
                Builder(
                  builder: (shareContext) => FilledButton(
                    onPressed: () => shareBurstCode(shareContext, code),
                    style: FilledButton.styleFrom(
                      shape: burstButtonShape,
                      backgroundColor: burstAccent(context),
                      foregroundColor: burstOnAccent(context),
                      minimumSize: const Size.fromHeight(56),
                    ),
                    child: const Text('Share code'),
                  ),
                ),
                const SizedBox(height: 16),
                OutlinedButton(
                  onPressed: () => _leaveComplete(true),
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size.fromHeight(56),
                    backgroundColor: const Color(0xff1b1b1b),
                    foregroundColor: Colors.white,
                    side: const BorderSide(color: Color(0xff414141)),
                    shape: burstButtonShape,
                  ),
                  child: const Text('View My Burst'),
                ),
              ] else ...[
                _line('Asset', campaign['assetSymbol']?.toString() ?? ''),
                if (campaign['assetKind'] == 'native' ||
                    campaign['assetKind'] == 'erc20')
                  _line(
                    'Distribution amount',
                    burstAssetAmount(
                      campaign['totalAmountBaseUnits']?.toString() ?? '',
                      campaign['assetDecimals'] is int
                          ? campaign['assetDecimals'] as int
                          : -1,
                      campaign['assetSymbol']?.toString() ?? '',
                    ),
                  ),
                if (campaign['assetKind'] == 'erc721' ||
                    campaign['assetKind'] == 'erc1155')
                  _line(
                    'NFT allocations',
                    '${campaign['maxParticipants'] ?? ''}',
                  ),
                _line(
                  'Network',
                  widget.chainName ?? '${campaign['chainId'] ?? ''}',
                ),
                _line('Maximum guests', '${campaign['maxParticipants'] ?? ''}'),
                _line('Starts', displayTime(campaign['startTime'])),
                _line('Claims end', displayTime(campaign['endTime'])),
                const Divider(color: Colors.white24),
                _line(
                  'Platform fee',
                  burstNativeAmount(
                    campaign['platformFeeBaseUnits']?.toString() ?? '',
                    widget.nativeSymbol,
                  ),
                ),
                _line(
                  'Gas sponsorship',
                  burstNativeAmount(
                    campaign['gasSponsorshipFeeBaseUnits']?.toString() ?? '',
                    widget.nativeSymbol,
                  ),
                ),
                if (campaign['gasSponsorshipFeeBaseUnits'] != '0')
                  const Padding(
                    padding: EdgeInsets.only(top: 4, bottom: 12),
                    child: Text(
                      'Collected upfront for the full participant capacity. Unused sponsorship is not refunded.',
                      style: TextStyle(color: Colors.white70, fontSize: 12),
                    ),
                  ),
                const Divider(color: Colors.white24),
                _line(
                  'Upfront native cost',
                  burstUpfrontNativeCost(campaign, widget.nativeSymbol),
                ),
                const SizedBox(height: 20),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SvgPicture.asset('assets/burst/fee_info.svg'),
                    const SizedBox(width: 10),
                    const Expanded(
                      child: Text(
                        'Network fees are paid separately by your wallet. You will review each transaction before signing.',
                        style: TextStyle(color: Colors.white70),
                      ),
                    ),
                  ],
                ),
                if (_error != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 20),
                    child: Text(
                      _error!,
                      style: const TextStyle(color: Color(0xffff8b91)),
                    ),
                  ),
                if (_unknownReference != null)
                  TextButton(
                    onPressed: _busy ? null : _recover,
                    child: const Text('Recover transaction'),
                  ),
                const SizedBox(height: 30),
                FilledButton(
                  onPressed: _busy ? null : _create,
                  style: FilledButton.styleFrom(
                    backgroundColor: burstAccent(context),
                    foregroundColor: burstOnAccent(context),
                    minimumSize: const Size.fromHeight(56),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: Text(_busy ? 'Processing…' : 'Create Burst'),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _line(String label, String value) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 10),
    child: Row(
      children: [
        Expanded(
          child: Text(label, style: const TextStyle(color: Colors.white70)),
        ),
        Expanded(
          child: Text(
            value,
            textAlign: TextAlign.end,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ],
    ),
  );
}
