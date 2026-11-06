import 'package:flutter/material.dart';

import 'burst_theme.dart';
import 'package:flutter/services.dart';

import 'burst_api_client.dart';
import 'burst_transaction_executor.dart';
import 'burst_share.dart';

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
            title: const Text('Trigger Burst?'),
            content: const Text(
              'This freezes the guest list and prepares their allocations. You will review the on-chain transaction before signing.',
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
            title: Text(
              action == 'cancel'
                  ? 'Cancel this Burst?'
                  : 'Recover unclaimed assets?',
            ),
            content: Text(
              action == 'cancel'
                  ? (nft
                        ? 'Cancellation stops claims. NFTs must then be recovered in a separate transaction.'
                        : 'Cancellation stops claims and returns the remaining assets to this wallet. Network fees apply.')
                  : 'The contract allows recovery after the claim window ends${nft ? ' or after cancellation' : ''}. The assets return to this wallet and network fees apply.',
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
    final campaign = _campaign;
    final isWallet =
        campaign?['hostWalletAddress']?.toString().toLowerCase() ==
            widget.wallet.toLowerCase() &&
        campaign?['chainId'] == widget.chainId;
    final status = campaign?['status']?.toString() ?? '';
    final canTrigger = status == 'active' || status == 'root_pending';
    return Scaffold(
      backgroundColor: const Color(0xff0a0a0a),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        foregroundColor: Colors.white,
        title: const Text('Burst details'),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(24),
          children: [
            if (_loading && campaign == null)
              const Center(child: CircularProgressIndicator())
            else if (campaign != null) ...[
              Text(
                campaign['title']?.toString() ?? 'Burst',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                campaign['description']?.toString() ?? '',
                style: const TextStyle(color: Colors.white70),
              ),
              const SizedBox(height: 32),
              Text(
                '${campaign['participantCount'] ?? 0} of ${campaign['maxParticipants'] ?? 0} guests',
                style: const TextStyle(color: Colors.white, fontSize: 20),
              ),
              const SizedBox(height: 12),
              Text(
                'Status: $status',
                style: const TextStyle(color: Colors.white70),
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
                  padding: const EdgeInsets.only(top: 32),
                  child: FilledButton(
                    onPressed: _triggering ? null : _trigger,
                    style: FilledButton.styleFrom(
                      shape: burstButtonShape,
                      backgroundColor: burstAccent(context),
                      foregroundColor: burstOnAccent(context),
                      minimumSize: const Size.fromHeight(56),
                    ),
                    child: Text(
                      _triggering
                          ? 'Processing…'
                          : status == 'root_pending'
                          ? 'Resume Burst'
                          : 'Trigger Burst',
                    ),
                  ),
                ),
              if (isWallet &&
                  {'active', 'root_pending', 'claiming'}.contains(status)) ...[
                TextButton(
                  onPressed: _showCode,
                  child: const Text('Show join code'),
                ),
                if (_code != null) ...[
                  SelectableText(
                    _code!,
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: Colors.white, fontSize: 20),
                  ),
                  TextButton(
                    onPressed: () =>
                        Clipboard.setData(ClipboardData(text: _code!)),
                    child: const Text('Copy code'),
                  ),
                  Builder(
                    builder: (shareContext) => TextButton(
                      onPressed: () => shareBurstCode(shareContext, _code!),
                      child: const Text('Share code'),
                    ),
                  ),
                ],
              ],
              if (status == 'claiming')
                const Padding(
                  padding: EdgeInsets.only(top: 24),
                  child: Text(
                    'Distribution is ready for participants to claim.',
                    style: TextStyle(color: Colors.white70),
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
                const SizedBox(height: 24),
                TextButton(
                  onPressed: _loadingMessages ? null : () => _loadMessages(),
                  child: Text(
                    _loadingMessages
                        ? 'Loading messages…'
                        : 'View thank-you messages',
                  ),
                ),
                if (_messages != null && _messages!.isEmpty)
                  const Text(
                    'No messages yet.',
                    style: TextStyle(color: Colors.white70),
                  ),
                if (_messages != null)
                  ..._messages!.whereType<Map>().map(
                    (message) => ListTile(
                      contentPadding: EdgeInsets.zero,
                      title: Text(
                        message['message']?.toString() ?? '',
                        style: const TextStyle(color: Colors.white),
                      ),
                      subtitle: Text(
                        message['walletAddress']?.toString() ?? '',
                        style: const TextStyle(color: Colors.white70),
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
                  style: const TextStyle(color: Color(0xffff8b91)),
                ),
              ),
            if (_unknownPlan != null)
              TextButton(
                onPressed: _triggering ? null : _recover,
                child: const Text('Recover transaction'),
              ),
            const SizedBox(height: 20),
            TextButton(onPressed: _refresh, child: const Text('Refresh')),
          ],
        ),
      ),
    );
  }
}
