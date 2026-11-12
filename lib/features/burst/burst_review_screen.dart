import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../widgets/bottom_navigation.dart';
import '../shell/app_shell_controller.dart';
import 'burst_created_success_screen.dart';
import 'burst_share.dart';
import 'burst_theme.dart';
import 'burst_transaction_executor.dart';

export 'burst_created_success_screen.dart';

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

/// Modal bottom sheet drawer matching Figma node 5888:8978 ("Burst summary").
///
/// Invoked via [showModalBottomSheet] with [isScrollControlled] set to true.
/// Renders solid pitch black `#000000`, 8px rounded top corners, a 36px pull handle,
/// centered "Confirm Burst" title, and no AppBar or back button.
class BurstReviewSheet extends StatefulWidget {
  const BurstReviewSheet({
    super.key,
    required this.prepared,
    required this.executor,
    required this.nativeSymbol,
    this.chainName,
    this.onCompleted,
    this.loadNetworkFee,
    this.allowEdit = false,
  });

  final Map<String, dynamic> prepared;
  final BurstTransactionExecutor executor;
  final String nativeSymbol;
  final String? chainName;
  final Future<void> Function()? onCompleted;
  final Future<BigInt> Function()? loadNetworkFee;
  final bool allowEdit;

  @override
  State<BurstReviewSheet> createState() => _BurstReviewSheetState();
}

class _BurstReviewSheetState extends State<BurstReviewSheet> {
  bool _busy = false;
  String? _error;
  String? _unknownReference;
  final _confirmed = <String>{};
  BigInt? _networkFeeWei;
  bool _estimatingFee = false;
  bool _feeFailed = false;
  bool _submissionStarted = false;

  @override
  void initState() {
    super.initState();
    if (widget.loadNetworkFee != null) _loadFee();
  }

  Future<void> _loadFee() async {
    setState(() {
      _estimatingFee = true;
      _feeFailed = false;
    });
    try {
      final fee = await widget.loadNetworkFee!();
      if (fee.isNegative) throw const FormatException('Invalid network fee');
      if (mounted) setState(() => _networkFeeWei = fee);
    } catch (_) {
      if (mounted) setState(() => _feeFailed = true);
    } finally {
      if (mounted) setState(() => _estimatingFee = false);
    }
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
        setState(() => _submissionStarted = true);
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
        Navigator.of(context).pop(true);
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
    final tokenDisplay = _resolveTokenDisplay(campaign, widget.nativeSymbol);
    final feePrepared = <String, dynamic>{
      ...widget.prepared,
      if (_networkFeeWei != null) 'networkFeeBaseUnits': '$_networkFeeWei',
    };
    final (estUsd, platformUsd, networkUsd, totalUsd) = _resolveFees(
      feePrepared,
    );
    final networkFeeWei =
        _networkFeeWei ??
        BigInt.tryParse(
          widget.prepared['networkFeeBaseUnits']?.toString() ?? '',
        );
    final networkText = _estimatingFee
        ? 'Estimating…'
        : networkUsd != null
        ? _formatUsd(networkUsd)
        : networkFeeWei != null
        ? burstNativeAmount('$networkFeeWei', widget.nativeSymbol)
        : 'Unavailable';
    final upfront = burstUpfrontNativeCost(campaign, widget.nativeSymbol);
    final upfrontRaw = upfront == 'Unavailable'
        ? null
        : BigInt.parse(campaign['platformFeeBaseUnits'].toString()) +
              BigInt.parse(campaign['gasSponsorshipFeeBaseUnits'].toString()) +
              (campaign['assetKind'] == 'native'
                  ? BigInt.parse(campaign['totalAmountBaseUnits'].toString())
                  : BigInt.zero);
    final totalNative = upfrontRaw == null || networkFeeWei == null
        ? (_estimatingFee ? 'Estimating…' : 'Unavailable')
        : burstNativeAmount(
            (upfrontRaw + networkFeeWei).toString(),
            widget.nativeSymbol,
          );
    final totalDisplay = campaign['assetKind'] == 'native'
        ? totalNative
        : '$tokenDisplay + $totalNative';

    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 390),
        child: Container(
          decoration: const BoxDecoration(
            color: Color(0xFF000000),
            borderRadius: BorderRadius.vertical(top: Radius.circular(8)),
          ),
          child: SafeArea(
            top: false,
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Pull handle indicator
                  Center(
                    child: Container(
                      width: 36,
                      height: 4,
                      margin: const EdgeInsets.only(bottom: 12),
                      decoration: BoxDecoration(
                        color: const Color(0xFF3F3F46),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  // Title
                  const Text(
                    'Confirm Burst',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Color(0xFFE2E2E2),
                      fontSize: 20,
                      fontWeight: FontWeight.w500,
                      letterSpacing: -0.5,
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Parameter group
                  _sheetParamLine(
                    'Asset',
                    campaign['assetSymbol']?.toString() ?? '',
                  ),
                  _sheetParamLine(
                    'Chain',
                    widget.chainName ?? '${campaign['chainId'] ?? ''}',
                  ),
                  _sheetParamLine(
                    'Maximum guests',
                    '${campaign['maxParticipants'] ?? ''} wallets',
                  ),
                  if (campaign['assetKind'] == 'erc721' ||
                      campaign['assetKind'] == 'erc1155')
                    _sheetParamLine(
                      'NFT allocations',
                      '${campaign['maxParticipants'] ?? ''}',
                    ),

                  // Divider 1
                  const Divider(color: Color(0xFF29292E), height: 28),

                  // Middle Fee breakdown
                  _sheetFeeLine('Network Fee', networkText),
                  if (_feeFailed)
                    TextButton(
                      onPressed: _estimatingFee ? null : _loadFee,
                      child: const Text(
                        'Unable to estimate network fee. Retry',
                      ),
                    ),
                  _sheetFeeLine('Platform Fee', _formatUsd(platformUsd)),
                  _sheetEstAmountLine(
                    'Est. Burst Amount',
                    tokenDisplay,
                    '(${_formatUsd(estUsd)})',
                  ),

                  // Divider 2 / Highlighted Total Row
                  Container(
                    margin: const EdgeInsets.symmetric(vertical: 11),
                    padding: const EdgeInsets.symmetric(vertical: 11),
                    decoration: const BoxDecoration(
                      border: Border(
                        top: BorderSide(color: Color(0xFF2A2A2A)),
                        bottom: BorderSide(color: Color(0xFF2A2A2A)),
                      ),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        const Expanded(
                          child: Text(
                            'Total. Burst Amount + Fees',
                            style: TextStyle(
                              color: Color(0xFFE2E2E2),
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text(
                              totalDisplay,
                              style: TextStyle(
                                color: burstAccent(context),
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              '(${_formatUsd(totalUsd)})',
                              style: const TextStyle(
                                color: Color(0xFFA0A0A0),
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),

                  // Congestion Disclaimer
                  Padding(
                    padding: const EdgeInsets.only(top: 8, bottom: 20),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        SvgPicture.asset(
                          'assets/burst/fee_info.svg',
                          width: 17,
                          height: 17,
                          colorFilter: ColorFilter.mode(
                            burstAccent(context),
                            BlendMode.srcIn,
                          ),
                        ),
                        const SizedBox(width: 8),
                        const Expanded(
                          child: Text(
                            'Network fees apply based on current congestion. No tokens are sold during burst generation. Please ensure sufficient wallet balance.',
                            style: TextStyle(
                              color: Color(0xFF888888),
                              fontSize: 10,
                              height: 1.5,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  if (_error != null)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 16),
                      child: Text(
                        _error!,
                        style: const TextStyle(color: Color(0xffff8b91)),
                      ),
                    ),
                  if (_unknownReference != null)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 16),
                      child: TextButton(
                        onPressed: _busy ? null : _recover,
                        child: const Text('Recover transaction'),
                      ),
                    ),

                  // Primary CTA Button
                  if (widget.allowEdit && !_submissionStarted)
                    TextButton(
                      onPressed: _busy
                          ? null
                          : () => Navigator.of(context).pop(),
                      child: const Text('Edit draft'),
                    ),
                  Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.all(Radius.circular(12)),
                      boxShadow: [
                        BoxShadow(
                          color: burstAccent(
                            context,
                          ).withValues(alpha: 0.30), // rgba(234, 42, 51, 0.30)
                          blurRadius: 30,
                          spreadRadius: 0,
                          offset: Offset.zero,
                        ),
                      ],
                    ),
                    child: FilledButton(
                      onPressed: _busy ? null : _create,
                      style: FilledButton.styleFrom(
                        backgroundColor: burstAccent(context),
                        foregroundColor: Colors.white,
                        minimumSize: const Size.fromHeight(56),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: Text(
                        _busy ? 'Processing…' : 'Create Burst',
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _sheetParamLine(String label, String value) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 4),
    child: Row(
      children: [
        Expanded(
          child: Text(
            label,
            style: const TextStyle(color: Color(0xFFA1A1AA), fontSize: 13),
          ),
        ),
        Expanded(
          child: Text(
            value,
            textAlign: TextAlign.end,
            style: const TextStyle(
              color: Color(0xFFF9F9F9),
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    ),
  );

  Widget _sheetFeeLine(String label, String value) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 4),
    child: Row(
      children: [
        Expanded(
          child: Text(
            label,
            style: const TextStyle(color: Color(0xFFA0A0A0), fontSize: 14),
          ),
        ),
        Expanded(
          child: Text(
            value,
            textAlign: TextAlign.end,
            style: const TextStyle(
              color: Color(0xFFE2E2E2),
              fontSize: 14,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ],
    ),
  );

  Widget _sheetEstAmountLine(
    String label,
    String tokenValue,
    String fiatValue,
  ) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 4),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Text(
            label,
            style: const TextStyle(color: Color(0xFFA0A0A0), fontSize: 14),
          ),
        ),
        Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              tokenValue,
              style: const TextStyle(
                color: Color(0xFFE2E2E2),
                fontSize: 14,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              fiatValue,
              style: const TextStyle(color: Color(0xFFA0A0A0), fontSize: 12),
            ),
          ],
        ),
      ],
    ),
  );
}

/// Backward compatibility wrapper for [BurstReviewSheet].
///
/// Can be pushed as a full-page route while preserving test expectations
/// and transitioning into [BurstCreatedSuccessScreen] on completion.
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
    final code = widget.prepared['joinCode'] as String? ?? '';
    final tokenDisplay = _resolveTokenDisplay(campaign, widget.nativeSymbol);
    final (estUsd, platformUsd, networkUsd, totalUsd) = _resolveFees(
      widget.prepared,
    );

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
                  builder: (shareContext) => Container(
                    decoration: BoxDecoration(
                      boxShadow: burstActionShadow(context),
                    ),
                    child: FilledButton(
                      onPressed: () => shareBurstCode(shareContext, code),
                      style: FilledButton.styleFrom(
                        shape: burstButtonShape,
                        backgroundColor: burstAccent(context),
                        foregroundColor: Colors.white,
                        minimumSize: const Size.fromHeight(56),
                      ),
                      child: const Text('Share code'),
                    ),
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
                _line(
                  'Chain',
                  widget.chainName ?? '${campaign['chainId'] ?? ''}',
                ),
                _line(
                  'Maximum guests',
                  '${campaign['maxParticipants'] ?? ''} wallets',
                ),
                if (campaign['assetKind'] == 'erc721' ||
                    campaign['assetKind'] == 'erc1155')
                  _line(
                    'NFT allocations',
                    '${campaign['maxParticipants'] ?? ''}',
                  ),
                const Divider(color: Color(0xFF29292E), height: 28),
                _line('Network Fee', _formatUsd(networkUsd)),
                _line('Platform Fee', _formatUsd(platformUsd)),
                _estAmountLine(
                  'Est. Burst Amount',
                  tokenDisplay,
                  '(${_formatUsd(estUsd)})',
                ),
                Container(
                  margin: const EdgeInsets.symmetric(vertical: 11),
                  padding: const EdgeInsets.symmetric(vertical: 11),
                  decoration: const BoxDecoration(
                    border: Border(
                      top: BorderSide(color: Color(0xFF2A2A2A)),
                      bottom: BorderSide(color: Color(0xFF2A2A2A)),
                    ),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Total. Burst Amount + Fees',
                        style: TextStyle(
                          color: Color(0xFFE2E2E2),
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                            tokenDisplay,
                            style: TextStyle(
                              color: burstAccent(context),
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            '(${_formatUsd(totalUsd)})',
                            style: const TextStyle(
                              color: Color(0xFFA0A0A0),
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.only(top: 8, bottom: 20),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SvgPicture.asset(
                        'assets/burst/fee_info.svg',
                        width: 17,
                        height: 17,
                        colorFilter: ColorFilter.mode(
                          burstAccent(context),
                          BlendMode.srcIn,
                        ),
                      ),
                      const SizedBox(width: 8),
                      const Expanded(
                        child: Text(
                          'Network fees apply based on current congestion. No tokens are sold during burst generation. Please ensure sufficient wallet balance.',
                          style: TextStyle(
                            color: Color(0xFF888888),
                            fontSize: 10,
                            height: 1.5,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                if (_error != null)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 16),
                    child: Text(
                      _error!,
                      style: const TextStyle(color: Color(0xffff8b91)),
                    ),
                  ),
                if (_unknownReference != null)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 16),
                    child: TextButton(
                      onPressed: _busy ? null : _recover,
                      child: const Text('Recover transaction'),
                    ),
                  ),
                Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.all(Radius.circular(12)),
                    boxShadow: [
                      BoxShadow(
                        color: burstAccent(context).withValues(alpha: 0.30),
                        blurRadius: 30,
                        spreadRadius: 0,
                        offset: Offset.zero,
                      ),
                    ],
                  ),
                  child: FilledButton(
                    onPressed: _busy ? null : _create,
                    style: FilledButton.styleFrom(
                      backgroundColor: burstAccent(context),
                      foregroundColor: Colors.white,
                      minimumSize: const Size.fromHeight(56),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: Text(
                      _busy ? 'Processing…' : 'Create Burst',
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _line(String label, String value) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 6),
    child: Row(
      children: [
        Expanded(
          child: Text(
            label,
            style: const TextStyle(color: Color(0xFFA1A1AA), fontSize: 13),
          ),
        ),
        Expanded(
          child: Text(
            value,
            textAlign: TextAlign.end,
            style: const TextStyle(
              color: Color(0xFFF9F9F9),
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    ),
  );

  Widget _estAmountLine(String label, String tokenValue, String fiatValue) =>
      Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Text(
                label,
                style: const TextStyle(color: Color(0xFFA0A0A0), fontSize: 14),
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  tokenValue,
                  style: const TextStyle(
                    color: Color(0xFFE2E2E2),
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  fiatValue,
                  style: const TextStyle(
                    color: Color(0xFFA0A0A0),
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ],
        ),
      );
}

String _resolveTokenDisplay(Map campaign, String nativeSymbol) {
  final kind = campaign['assetKind']?.toString() ?? 'native';
  final rawAmount = campaign['totalAmountBaseUnits']?.toString() ?? '';
  final symbol = campaign['assetSymbol']?.toString() ?? '';
  if (kind == 'native') {
    return burstNativeAmount(
      rawAmount,
      symbol.isNotEmpty ? symbol : nativeSymbol,
    );
  } else if (kind == 'erc20') {
    final decimals = campaign['assetDecimals'] is int
        ? campaign['assetDecimals'] as int
        : 18;
    return burstAssetAmount(rawAmount, decimals, symbol);
  } else if (kind == 'erc721' || kind == 'erc1155') {
    return '${campaign['maxParticipants'] ?? ''} NFTs';
  }
  return symbol.isNotEmpty ? symbol : 'FOWL';
}

/// USD figures are derived from the prepared campaign and the native price the
/// backend resolved. Unknown values stay null and render as an em dash instead
/// of a placeholder number.
(double?, double?, double?, double?) _resolveFees(Map prepared) {
  final campaign = prepared['campaign'] is Map
      ? prepared['campaign'] as Map
      : const <String, dynamic>{};
  final price = double.tryParse(prepared['nativePriceUsd']?.toString() ?? '');
  final decimals = (campaign['assetDecimals'] as num?)?.toInt() ?? 18;
  final isNative = (campaign['assetKind']?.toString() ?? 'native') == 'native';

  double? toUsd(Object? raw, int unitDecimals) {
    if (price == null || price <= 0) return null;
    final value = BigInt.tryParse(raw?.toString() ?? '');
    if (value == null || value.isNegative) return null;
    final scale = math.pow(10, unitDecimals).toDouble();
    return (value.toDouble() / scale) * price;
  }

  final estUsd = isNative
      ? toUsd(campaign['totalAmountBaseUnits'], decimals)
      : null;
  // Platform fees are always charged in the native coin.
  final platformUsd = toUsd(campaign['platformFeeBaseUnits'], 18);
  final networkUsd =
      toUsd(prepared['networkFeeBaseUnits'], 18) ??
      double.tryParse(prepared['networkFeeUsd']?.toString() ?? '');
  final sponsorshipUsd = toUsd(campaign['gasSponsorshipFeeBaseUnits'], 18);
  final totalUsd =
      (estUsd != null &&
          platformUsd != null &&
          networkUsd != null &&
          sponsorshipUsd != null)
      ? double.parse(
          (estUsd + platformUsd + networkUsd + sponsorshipUsd).toStringAsFixed(
            2,
          ),
        )
      : null;
  return (estUsd, platformUsd, networkUsd, totalUsd);
}

String _formatUsd(double? value) {
  if (value == null) return '—';
  if (value > 0 && value < 0.01) return '\$${value.toStringAsFixed(4)}';
  return '\$${value.toStringAsFixed(2)}';
}
