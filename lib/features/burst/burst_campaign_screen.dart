import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'burst_api_client.dart';
import 'burst_review_screen.dart' show burstAssetAmount;
import 'burst_share.dart';
import 'burst_theme.dart';
import 'burst_transaction_executor.dart';

class BurstCampaignScreen extends StatefulWidget {
  const BurstCampaignScreen({
    super.key,
    required this.api,
    required this.executor,
    required this.campaignId,
    required this.wallet,
    required this.chainId,
  });
  final BurstApiClient api;
  final BurstTransactionExecutor executor;
  final String campaignId;
  final String wallet;
  final int chainId;
  @override
  State<BurstCampaignScreen> createState() => _BurstCampaignScreenState();
}

class _BurstCampaignScreenState extends State<BurstCampaignScreen> {
  Timer? _pollTimer;
  Map<String, dynamic>? _campaign;
  String? _error;
  String? _code;
  Map<String, dynamic>? _unknownPlan;
  List<dynamic>? _messages;
  String? _messageCursor;
  bool _loadingMessages = false;
  bool _loading = false;
  bool _triggering = false;

  @override
  void initState() {
    super.initState();
    _refresh();
    _pollTimer = Timer.periodic(const Duration(seconds: 2), (_) {
      final status = _campaign?['status']?.toString() ?? '';
      if (mounted &&
          !_loading &&
          !_triggering &&
          (status.isEmpty ||
              status == 'active' ||
              status == 'root_pending' ||
              status == 'claiming')) {
        _refresh();
      }
    });
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    super.dispose();
  }

  Future<void> _refresh() async {
    if (_loading) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final campaign = await widget.api.campaign(widget.campaignId);
      if (campaign['id'] != widget.campaignId) {
        throw const FormatException('Campaign identity mismatch.');
      }
      if (mounted) setState(() => _campaign = campaign);
    } catch (error) {
      if (mounted) {
        setState(
          () => _error = error.toString().replaceFirst('FormatException: ', ''),
        );
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _trigger() async {
    if (_triggering || _campaign == null) return;
    final campaign = _campaign!;
    if (campaign['hostWalletAddress']?.toString().toLowerCase() !=
            widget.wallet.toLowerCase() ||
        campaign['chainId'] != widget.chainId) {
      setState(
        () => _error = 'Select the wallet and network that created this Burst.',
      );
      return;
    }
    final accepted =
        await showDialog<bool>(
          context: context,
          builder: (dialog) => AlertDialog(
            backgroundColor: const Color(0xFF141414),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(18),
              side: BorderSide(color: Colors.white.withValues(alpha: 0.1)),
            ),
            title: const Text(
              'Trigger Burst?',
              style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
            ),
            content: const Text(
              'This freezes the guest list and prepares their allocations. You will approve the on-chain transaction once.',
              style: TextStyle(color: Colors.white70, height: 1.4),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialog, false),
                child: const Text('Cancel'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(dialog, true),
                child: const Text('Continue'),
              ),
            ],
          ),
        ) ??
        false;
    if (!accepted || !mounted) return;
    setState(() {
      _triggering = true;
      _error = null;
    });
    try {
      final finalized = await widget.api.finalize(widget.campaignId);
      final tx = finalized['transaction'];
      final root = finalized['merkleRoot']?.toString().toLowerCase() ?? '';
      if (finalized['campaignId'] != widget.campaignId ||
          tx is! Map ||
          tx['reference'] is! String ||
          tx['operation'] != 'set_root' ||
          tx['chainId'] != widget.chainId ||
          tx['toAddress']?.toString().toLowerCase() !=
              campaign['campaignAddress']?.toString().toLowerCase() ||
          !RegExp(r'^0x[0-9a-f]{64}$').hasMatch(root) ||
          tx['calldata']?.toString().toLowerCase() !=
              '0x7cb64759${root.substring(2)}') {
        throw const FormatException('Invalid Burst distribution transaction.');
      }
      _unknownPlan = Map<String, dynamic>.from(tx);
      final result = await widget.executor.execute(
        tx['reference'] as String,
        expectedTransaction: Map<String, dynamic>.from(tx),
        expectedCampaignId: widget.campaignId,
      );
      if (!result.confirmed) {
        throw StateError(
          'The transaction is pending. Open this Burst again to check its status.',
        );
      }
      _unknownPlan = null;
      await _refresh();
    } catch (error) {
      if (error is! BurstUnknownSubmission) _unknownPlan = null;
      if (mounted) {
        setState(
          () => _error = error
              .toString()
              .replaceFirst('Bad state: ', '')
              .replaceFirst('FormatException: ', ''),
        );
      }
    } finally {
      if (mounted) setState(() => _triggering = false);
    }
  }

  Future<void> _recover() async {
    final transaction = _unknownPlan;
    if (transaction == null || _triggering) return;
    final controller = TextEditingController();
    final hash = await showDialog<String>(
      context: context,
      builder: (dialog) => AlertDialog(
        backgroundColor: const Color(0xFF141414),
        title: const Text(
          'Recover transaction',
          style: TextStyle(color: Colors.white),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Paste the transaction hash from wallet history. Owllet will verify it matches this Burst.',
              style: TextStyle(color: Colors.white70),
            ),
            TextField(
              controller: controller,
              style: const TextStyle(color: Colors.white),
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
      _triggering = true;
      _error = null;
    });
    try {
      final result = await widget.executor.recoverUnknown(
        transaction['reference'] as String,
        hash,
        expectedTransaction: transaction,
        expectedCampaignId: widget.campaignId,
      );
      _unknownPlan = null;
      if (result.confirmed) {
        await _refresh();
      } else if (mounted) {
        setState(
          () => _error =
              'The transaction is pending. Refresh to check its status.',
        );
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
      if (mounted) setState(() => _triggering = false);
    }
  }

  bool _validRecoveryCall(Map tx, Map campaign, String action) {
    final data = tx['calldata']?.toString().toLowerCase() ?? '';
    if (tx['operation'] != action ||
        tx['chainId'] != widget.chainId ||
        tx['valueBaseUnits'] != '0' ||
        tx['reference'] is! String ||
        tx['toAddress']?.toString().toLowerCase() !=
            campaign['campaignAddress']?.toString().toLowerCase()) {
      return false;
    }
    if (action == 'cancel') return data == '0xea8a1af0';
    if (campaign['assetKind'] == 'native' || campaign['assetKind'] == 'erc20') {
      return data == '0xc44337b4';
    }
    if (campaign['assetKind'] != 'erc721' &&
        campaign['assetKind'] != 'erc1155') {
      return false;
    }
    if (!RegExp(r'^0xf44ae513[0-9a-f]+$').hasMatch(data) || data.length < 138) {
      return false;
    }
    final offset = BigInt.tryParse(data.substring(10, 74), radix: 16);
    final count = BigInt.tryParse(data.substring(74, 138), radix: 16);
    if (offset != BigInt.from(32) ||
        count == null ||
        count < BigInt.one ||
        count > BigInt.from(250) ||
        data.length != 138 + count.toInt() * 64) {
      return false;
    }
    BigInt? previous;
    for (var index = 0; index < count.toInt(); index++) {
      final id = BigInt.parse(
        data.substring(138 + index * 64, 202 + index * 64),
        radix: 16,
      );
      if (previous != null && id <= previous) return false;
      previous = id;
    }
    return true;
  }

  Future<void> _prepareAssetRecovery(String action) async {
    final campaign = _campaign;
    if (_triggering || campaign == null) return;
    if (campaign['hostWalletAddress']?.toString().toLowerCase() !=
            widget.wallet.toLowerCase() ||
        campaign['chainId'] != widget.chainId) {
      setState(
        () => _error = 'Select the wallet and network that created this Burst.',
      );
      return;
    }
    final nft =
        campaign['assetKind'] == 'erc721' || campaign['assetKind'] == 'erc1155';
    final accepted =
        await showDialog<bool>(
          context: context,
          builder: (dialog) => AlertDialog(
            backgroundColor: const Color(0xFF141414),
            title: Text(
              action == 'cancel'
                  ? 'Cancel this Burst?'
                  : 'Recover unclaimed assets?',
              style: const TextStyle(color: Colors.white),
            ),
            content: Text(
              action == 'cancel'
                  ? (nft
                        ? 'Cancellation stops claims. NFTs must then be recovered in a separate transaction.'
                        : 'Cancellation stops claims and returns the remaining assets to this wallet. Network fees apply.')
                  : 'The contract allows recovery after the claim window ends${nft ? ' or after cancellation' : ''}. The assets return to this wallet and network fees apply.',
              style: const TextStyle(color: Colors.white70),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialog, false),
                child: const Text('Back'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(dialog, true),
                child: const Text('Continue'),
              ),
            ],
          ),
        ) ??
        false;
    if (!accepted || !mounted) return;
    setState(() {
      _triggering = true;
      _error = null;
    });
    try {
      final response = await widget.api.prepareRecovery(
        widget.campaignId,
        action,
      );
      final tx = response['transaction'];
      if (tx is! Map || !_validRecoveryCall(tx, campaign, action)) {
        throw const FormatException('Invalid Burst recovery transaction.');
      }
      _unknownPlan = Map<String, dynamic>.from(tx);
      final result = await widget.executor.execute(
        tx['reference'] as String,
        expectedTransaction: Map<String, dynamic>.from(tx),
        expectedCampaignId: widget.campaignId,
      );
      if (!result.confirmed) {
        throw StateError(
          'The transaction is pending. Select the action again to check it.',
        );
      }
      _unknownPlan = null;
      await _refresh();
    } catch (error) {
      if (error is! BurstUnknownSubmission) _unknownPlan = null;
      if (mounted) {
        setState(
          () => _error = error
              .toString()
              .replaceFirst('Bad state: ', '')
              .replaceFirst('FormatException: ', ''),
        );
      }
    } finally {
      if (mounted) setState(() => _triggering = false);
    }
  }

  Future<void> _showCode() async {
    try {
      final result = await widget.api.campaignCode(widget.campaignId);
      final code = result['joinCode'];
      if (code is! String || code.isEmpty) {
        throw const FormatException('The Burst code is unavailable.');
      }
      if (mounted) {
        setState(() {
          _code = code;
          _error = null;
        });
      }
    } catch (error) {
      if (mounted) {
        setState(
          () => _error = error.toString().replaceFirst('FormatException: ', ''),
        );
      }
    }
  }

  Future<void> _loadMessages({bool more = false}) async {
    if (_loadingMessages) return;
    setState(() {
      _loadingMessages = true;
      _error = null;
    });
    try {
      final response = await widget.api.messages(
        widget.campaignId,
        after: more ? _messageCursor : null,
      );
      if (response['messages'] is! List) {
        throw const FormatException('Unable to load messages.');
      }
      final cursor = response['nextCursor'];
      if (cursor != null &&
          (cursor is! String ||
              cursor.isEmpty ||
              (more && cursor == _messageCursor))) {
        throw const FormatException('Invalid message page.');
      }
      if (mounted) {
        setState(() {
          _messages = [
            ...(more ? _messages ?? [] : []),
            ...response['messages'] as List,
          ];
          _messageCursor = cursor as String?;
        });
      }
    } catch (error) {
      if (mounted) {
        setState(
          () => _error = error.toString().replaceFirst('FormatException: ', ''),
        );
      }
    } finally {
      if (mounted) setState(() => _loadingMessages = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final accent = burstAccent(context);
    final campaign = _campaign;
    final isWallet =
        campaign?['hostWalletAddress']?.toString().toLowerCase() ==
            widget.wallet.toLowerCase() &&
        campaign?['chainId'] == widget.chainId;
    final status = campaign?['status']?.toString() ?? '';
    final canTrigger = status == 'active' || status == 'root_pending';
    final joined = campaign?['participantCount'] is int
        ? campaign!['participantCount'] as int
        : 0;
    final maxGuests = campaign?['maxParticipants'] is int
        ? campaign!['maxParticipants'] as int
        : 0;
    final percent = maxGuests > 0
        ? ((joined / maxGuests).clamp(0.0, 1.0) * 100).round()
        : 0;
    final isNft =
        campaign?['assetKind'] == 'erc721' ||
        campaign?['assetKind'] == 'erc1155';
    final decimals = campaign?['assetDecimals'];
    final perGuest = campaign?['amountPerParticipantBaseUnits']?.toString();
    final rewardSummary = isNft
        ? 'NFT distribution'
        : decimals is int && perGuest != null
        ? '${burstAssetAmount(perGuest, decimals, campaign?['assetSymbol']?.toString() ?? '')} per guest'
        : null;

    final tall = MediaQuery.sizeOf(context).height >= 700;
    return Scaffold(
      backgroundColor: const Color(0xFF050505),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        foregroundColor: Colors.white,
        title: const BurstHeader(),
        centerTitle: true,
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          children: [
            if (_loading && campaign == null)
              const Padding(
                padding: EdgeInsets.only(top: 64),
                child: Center(child: CircularProgressIndicator()),
              )
            else if (campaign != null) ...[
              Container(
                padding: EdgeInsets.all(tall ? 22 : 14),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      accent.withValues(alpha: 0.14),
                      const Color(0xFF141414),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(
                    color: accent.withValues(alpha: 0.28),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        BurstStatusBadge(
                          status: status,
                          showDot:
                              status == 'active' || status == 'root_pending',
                        ),
                        if (campaign['assetSymbol'] is String &&
                            (campaign['assetSymbol'] as String).isNotEmpty)
                          Text(
                            campaign['assetSymbol'].toString(),
                            style: const TextStyle(
                              color: Colors.white60,
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                      ],
                    ),
                    SizedBox(height: tall ? 12 : 8),
                    Text(
                      campaign['title']?.toString() ?? 'Burst',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: tall ? 28 : 26,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    if ((campaign['description']?.toString() ?? '').isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 6),
                        child: Text(
                          campaign['description']?.toString() ?? '',
                          style: const TextStyle(
                            color: Colors.white70,
                            fontSize: 13,
                          ),
                        ),
                      ),
                    if (rewardSummary != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 12),
                        child: Text(
                          rewardSummary,
                          style: TextStyle(
                            color: accent,
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    SizedBox(height: tall ? 16 : 10),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          '$joined of $maxGuests guests',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        Text(
                          '$percent%',
                          style: TextStyle(
                            color: accent,
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(99),
                      child: LinearProgressIndicator(
                        value: maxGuests > 0
                            ? (joined / maxGuests).clamp(0.0, 1.0).toDouble()
                            : 0,
                        minHeight: 6,
                        color: accent,
                        backgroundColor: const Color(0xFF2D2D2D),
                      ),
                    ),
                  ],
                ),
              ),
              if (!isWallet)
                const Padding(
                  padding: EdgeInsets.only(top: 20),
                  child: Text(
                    'Choose the wallet and network that created this Burst to manage it.',
                    style: TextStyle(color: Colors.white70),
                  ),
                ),
              if (canTrigger && isWallet)
                Padding(
                  padding: EdgeInsets.only(top: tall ? 16 : 12),
                  child: Container(
                    decoration: BoxDecoration(
                      boxShadow: burstActionShadow(
                        context,
                        enabled: !_triggering,
                      ),
                    ),
                    child: FilledButton(
                      onPressed: _triggering ? null : _trigger,
                      style: burstPrimaryButtonStyle(
                        context,
                        height: tall ? 54 : 48,
                        backgroundColor: accent,
                        foregroundColor: burstOnAccent(context),
                      ),
                      child: Text(
                        _triggering
                            ? 'Processing…'
                            : status == 'root_pending'
                            ? 'Resume Burst'
                            : 'Trigger Burst',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                ),
              if (isWallet && {'active', 'root_pending'}.contains(status)) ...[
                const SizedBox(height: 12),
                if (_code == null)
                  OutlinedButton.icon(
                    onPressed: _showCode,
                    style: OutlinedButton.styleFrom(
                      minimumSize: const Size.fromHeight(44),
                      backgroundColor: const Color(0xFF161616),
                      foregroundColor: Colors.white,
                      side: const BorderSide(color: Colors.white10),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    icon: const Icon(Icons.qr_code_rounded, size: 18),
                    label: const Text('Show join code'),
                  )
                else ...[
                  BurstInviteCodeCard(code: _code!),
                  const SizedBox(height: 10),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      TextButton(
                        onPressed: () =>
                            Clipboard.setData(ClipboardData(text: _code!)),
                        child: const Text('Copy code'),
                      ),
                      Builder(
                        builder: (shareContext) => TextButton(
                          onPressed: () =>
                              shareBurstCode(shareContext, _code!),
                          child: const Text('Share code'),
                        ),
                      ),
                    ],
                  ),
                ],
              ],
              if (status == 'claiming')
                Container(
                  margin: const EdgeInsets.only(top: 14),
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: const Color(0xFF103829),
                    border: Border.all(color: const Color(0xFF1C604C)),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Row(
                    children: [
                      Icon(
                        Icons.bolt_rounded,
                        color: Color(0xFF18C783),
                        size: 20,
                      ),
                      SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          'Delivering Burst rewards to guests…',
                          style: TextStyle(color: Colors.white),
                        ),
                      ),
                    ],
                  ),
                ),
              if (status == 'completed')
                Container(
                  margin: const EdgeInsets.only(top: 14),
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: const Color(0xFF103829),
                    border: Border.all(color: const Color(0xFF1C604C)),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Row(
                    children: [
                      Icon(
                        Icons.check_circle_outline_rounded,
                        color: Color(0xFF18C783),
                        size: 20,
                      ),
                      SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          'All Burst rewards have been delivered.',
                          style: TextStyle(color: Colors.white),
                        ),
                      ),
                    ],
                  ),
                ),
              if (isWallet &&
                  campaign['campaignAddress'] is String &&
                  {
                    'pending_chain',
                    'active',
                    'root_pending',
                    'claiming',
                  }.contains(status))
                TextButton(
                  onPressed: _triggering
                      ? null
                      : () => _prepareAssetRecovery('cancel'),
                  child: const Text('Cancel Burst'),
                ),
              if (isWallet &&
                  campaign['campaignAddress'] is String &&
                  ({
                        'pending_chain',
                        'active',
                        'root_pending',
                        'claiming',
                      }.contains(status) ||
                      (status == 'cancelled' &&
                          (campaign['assetKind'] == 'erc721' ||
                              campaign['assetKind'] == 'erc1155'))))
                TextButton(
                  onPressed: _triggering
                      ? null
                      : () => _prepareAssetRecovery('sweep'),
                  child: const Text('Recover unclaimed assets'),
                ),
              if (isWallet) ...[
                const SizedBox(height: 12),
                OutlinedButton(
                  onPressed: _loadingMessages ? null : () => _loadMessages(),
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size.fromHeight(44),
                    backgroundColor: const Color(0xFF161616),
                    foregroundColor: accent,
                    side: const BorderSide(color: Colors.white10),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: Text(
                    _loadingMessages
                        ? 'Loading messages…'
                        : 'View thank-you messages',
                  ),
                ),
                if (_messages != null && _messages!.isEmpty)
                  const Padding(
                    padding: EdgeInsets.only(top: 8),
                    child: Text(
                      'No messages yet.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.white70),
                    ),
                  ),
                if (_messages != null)
                  ..._messages!.whereType<Map>().map(
                    (message) => Container(
                      margin: const EdgeInsets.only(top: 6),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFF121212),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: Colors.white.withValues(alpha: 0.08),
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            message['message']?.toString() ?? '',
                            style: const TextStyle(color: Colors.white),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            message['walletAddress']?.toString() ?? '',
                            style: const TextStyle(
                              color: Colors.white54,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                if (_messageCursor != null)
                  TextButton(
                    onPressed: _loadingMessages
                        ? null
                        : () => _loadMessages(more: true),
                    child: const Text('Load more messages'),
                  ),
              ],
            ],
            if (_error != null)
              Padding(
                padding: const EdgeInsets.only(top: 20),
                child: Text(
                  _error!,
                  style: const TextStyle(color: Color(0xFFFF8B91)),
                ),
              ),
            if (_unknownPlan != null)
              TextButton(
                onPressed: _triggering ? null : _recover,
                child: const Text('Recover transaction'),
              ),
            const SizedBox(height: 16),
            Center(
              child: TextButton(
                onPressed: _refresh,
                style: TextButton.styleFrom(foregroundColor: Colors.white54),
                child: const Text('Refresh', style: TextStyle(fontSize: 12)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
