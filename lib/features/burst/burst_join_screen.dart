import 'dart:async';

import 'package:flutter/material.dart';

import 'burst_theme.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import 'burst_api_client.dart';

/// Participant flow. The code is kept in memory only and is never put in logs.
class BurstJoinScreen extends StatefulWidget {
  const BurstJoinScreen({
    super.key,
    required this.api,
    required this.walletAddress,
    required this.chainId,
  });
  final BurstApiClient api;
  final String walletAddress;
  final int chainId;

  @override
  State<BurstJoinScreen> createState() => _BurstJoinScreenState();
}

class _BurstJoinScreenState extends State<BurstJoinScreen> {
  final _code = TextEditingController();
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _code.dispose();
    super.dispose();
  }

  Future<void> _join() async {
    final code = _code.text.trim().toUpperCase();
    if (code.isEmpty || _busy) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final preview = await widget.api.previewJoin(code);
      final campaign = preview['campaign'];
      if (campaign is! Map ||
          campaign['title'] is! String ||
          campaign['id'] is! String ||
          campaign['chainId'] is! int) {
        throw const BurstApiException('Burst returned an invalid campaign.');
      }
      if (campaign['chainId'] != widget.chainId) {
        throw BurstApiException(
          'This Burst is on network ${campaign['chainId']}. Switch to that network before joining.',
        );
      }
      if (!mounted) return;
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (dialog) => AlertDialog(
          title: const Text('Confirm your Burst'),
          content: Text(
            '${campaign['title']}\nNetwork: ${campaign['chainId']}\nReceiving wallet: ${widget.walletAddress}\n\nYour reward will be sent to this wallet.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialog, false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(dialog, true),
              child: const Text('Confirm join'),
            ),
          ],
        ),
      );
      if (confirmed != true || !mounted) return;
      final joined = await widget.api.join(code);
      final id = joined['campaignId'];
      final wallet = joined['walletAddress'];
      if (id is! String ||
          id.isEmpty ||
          id != campaign['id'] ||
          wallet is! String ||
          wallet.toLowerCase() != widget.walletAddress.toLowerCase()) {
        throw const BurstApiException(
          'The joined wallet does not match the selected wallet.',
        );
      }
      if (!mounted) return;
      await Navigator.of(context).pushReplacement(
        BurstPageRoute<void>(
          builder: (_) => BurstWaitingScreen(
            api: widget.api,
            campaignId: id,
            title: campaign['title'] as String,
          ),
        ),
      );
    } catch (error) {
      if (mounted) {
        setState(
          () => _error = error is BurstApiException
              ? error.message
              : 'Unable to join this Burst. Try again.',
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: const Color(0xff0a0a0a),
    appBar: AppBar(
      backgroundColor: Colors.transparent,
      foregroundColor: Colors.white,
      title: const BurstHeader(),
      centerTitle: true,
    ),
    body: SafeArea(
      child: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          const SizedBox(height: 35),
          const Text(
            'ENTER CODE',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.grey,
              letterSpacing: 3,
              fontSize: 12,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Join Burst',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.white,
              fontSize: 32,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 32),
          TextField(
            controller: _code,
            enabled: !_busy,
            textCapitalization: TextCapitalization.characters,
            inputFormatters: [
              FilteringTextInputFormatter.allow(RegExp('[a-zA-Z2-7-]')),
              LengthLimitingTextInputFormatter(47),
            ],
            style: const TextStyle(color: Colors.white, letterSpacing: 2),
            textAlign: TextAlign.center,
            decoration: InputDecoration(
              labelText: 'Burst access code',
              hintText: 'Enter or paste code',
              filled: true,
              fillColor: const Color(0xff181818),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
          const SizedBox(height: 20),
          const Text('Joining wallet', style: TextStyle(color: Colors.grey)),
          const SizedBox(height: 8),
          SelectableText(
            widget.walletAddress,
            style: const TextStyle(color: Colors.white),
          ),
          if (_error != null)
            Padding(
              padding: const EdgeInsets.only(top: 20),
              child: Text(
                _error!,
                style: const TextStyle(color: Color(0xffff8b91)),
              ),
            ),
          const SizedBox(height: 32),
          FilledButton(
            onPressed: _busy ? null : _join,
            style: FilledButton.styleFrom(
              shape: burstButtonShape,
              backgroundColor: burstAccent(context),
              foregroundColor: burstOnAccent(context),
              minimumSize: const Size.fromHeight(56),
            ),
            child: Text(_busy ? 'Joining…' : 'Join Burst'),
          ),
        ],
      ),
    ),
  );
}

class BurstWaitingScreen extends StatefulWidget {
  const BurstWaitingScreen({
    super.key,
    required this.api,
    required this.campaignId,
    required this.title,
  });
  final BurstApiClient api;
  final String campaignId;
  final String title;
  @override
  State<BurstWaitingScreen> createState() => _BurstWaitingScreenState();
}

class _BurstWaitingScreenState extends State<BurstWaitingScreen> {
  final _message = TextEditingController();
  Timer? _timer;
  Map<String, dynamic>? _campaign;
  Map<String, dynamic>? _proof;
  Uri? _explorer;
  String? _chainName;
  String? _error;
  String? _claimError;
  bool _loading = false;
  bool _claiming = false;
  bool _leaving = false;
  bool _savingMessage = false;
  String? _messageStatus;

  String _receiptHash() {
    final hash = _proof?['claimTransactionHash']?.toString() ?? '';
    if (_explorer != null && RegExp(r'^0x[0-9a-fA-F]{64}$').hasMatch(hash)) {
      return '${hash.substring(0, 8)}…${hash.substring(hash.length - 4)}';
    }
    return hash.isEmpty ? 'Unavailable' : hash;
  }

  String _receiptAmount(
    Map<String, dynamic> campaign,
    Map<String, dynamic> proof,
  ) {
    final kind = proof['assetKind']?.toString();
    if (kind == 'erc721' || kind == 'erc1155') {
      return '${proof['tokenAmount'] ?? '1'} NFT · #${proof['tokenId'] ?? '?'}';
    }
    final decimals = campaign['assetDecimals'];
    final raw = proof['amountBaseUnits']?.toString() ?? '';
    if (decimals is! int ||
        decimals < 0 ||
        decimals > 255 ||
        !RegExp(r'^\d+$').hasMatch(raw)) {
      return 'Reward received';
    }
    final units = BigInt.parse(raw);
    final scale = BigInt.from(10).pow(decimals);
    final fraction = decimals == 0
        ? ''
        : (units % scale)
              .toString()
              .padLeft(decimals, '0')
              .replaceFirst(RegExp(r'0+$'), '');
    return '${units ~/ scale}${fraction.isEmpty ? '' : '.$fraction'} ${campaign['assetSymbol'] ?? ''}';
  }

  @override
  void initState() {
    super.initState();
    _refresh();
    _timer = Timer.periodic(const Duration(seconds: 10), (_) => _refresh());
  }

  @override
  void dispose() {
    _timer?.cancel();
    _message.dispose();
    super.dispose();
  }

  Future<void> _saveMessage() async {
    final message = _message.text.trim();
    if (message.isEmpty || _savingMessage) return;
    setState(() {
      _savingMessage = true;
      _messageStatus = null;
    });
    try {
      await widget.api.saveMessage(widget.campaignId, message);
      if (mounted) setState(() => _messageStatus = 'Message sent to the host.');
    } catch (error) {
      if (mounted) {
        setState(
          () => _messageStatus = error is BurstApiException
              ? error.message
              : 'Unable to send your message.',
        );
      }
    } finally {
      if (mounted) setState(() => _savingMessage = false);
    }
  }

  Future<void> _refresh() async {
    if (_loading) return;
    _loading = true;
    try {
      final campaign = await widget.api.participation(widget.campaignId);
      if (campaign['id'] != widget.campaignId) {
        throw const BurstApiException('This Burst could not be verified.');
      }
      Map<String, dynamic>? proof;
      try {
        proof = await widget.api.proof(widget.campaignId);
      } on BurstApiException catch (e) {
        if (e.statusCode != 404 && e.statusCode != 409) rethrow;
      }
      Uri? explorer;
      String? chainName;
      if (proof?['claimStatus'] == 'claimed' && campaign['chainId'] is int) {
        try {
          final config = await widget.api.config(campaign['chainId'] as int);
          chainName = config['chainName']?.toString();
          final base = Uri.tryParse(config['explorerUrl']?.toString() ?? '');
          final hash = proof?['claimTransactionHash']?.toString() ?? '';
          if (base != null &&
              base.scheme == 'https' &&
              base.host.isNotEmpty &&
              RegExp(r'^0x[0-9a-fA-F]{64}$').hasMatch(hash)) {
            explorer = base.replace(
              path: '${base.path.replaceAll(RegExp(r'/+$'), '')}/tx/$hash',
              query: null,
              fragment: null,
            );
          }
        } catch (_) {
          /* Receipt remains useful if explorer configuration is unavailable. */
        }
      }
      if (mounted) {
        setState(() {
          _campaign = Map<String, dynamic>.from(campaign);
          _proof = proof;
          _explorer = explorer;
          _chainName = chainName;
          _error = null;
        });
      }
    } catch (error) {
      if (mounted) {
        setState(
          () => _error = error is BurstApiException
              ? error.message
              : 'Unable to refresh Burst.',
        );
      }
    } finally {
      _loading = false;
    }
  }

  Future<void> _claim() async {
    if (_claiming) return;
    setState(() {
      _claiming = true;
      _claimError = null;
    });
    try {
      await widget.api.claim(widget.campaignId);
      await _refresh();
    } catch (error) {
      if (mounted) {
        setState(
          () => _claimError = error is BurstApiException
              ? error.message
              : 'Unable to request the reward.',
        );
      }
    } finally {
      if (mounted) setState(() => _claiming = false);
    }
  }

  Future<void> _leave() async {
    if (_leaving) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialog) => AlertDialog(
        title: const Text('Leave this Burst?'),
        content: const Text('Your place will be available to someone else.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialog, false),
            child: const Text('Stay'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialog, true),
            child: const Text('Leave Burst'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    setState(() {
      _leaving = true;
      _error = null;
    });
    try {
      final result = await widget.api.leave(widget.campaignId);
      if (result['left'] != true) {
        throw const BurstApiException(
          'Unable to confirm that you left this Burst.',
        );
      }
      if (mounted) Navigator.of(context).pop();
    } catch (error) {
      if (mounted) {
        setState(
          () => _error = error is BurstApiException
              ? error.message
              : 'Unable to leave this Burst.',
        );
      }
    } finally {
      if (mounted) setState(() => _leaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final status = _proof?['claimStatus']?.toString().toLowerCase();
    final job = _proof?['claimJobStatus']?.toString().toLowerCase();
    final confirmed = status == 'claimed';
    final failed = job == 'failed';
    final campaignStatus = _campaign?['status']?.toString().toLowerCase();
    final startTime = _campaign?['startTime'];
    final endTime = _campaign?['endTime'];
    final now = DateTime.now().toUtc().millisecondsSinceEpoch ~/ 1000;
    final validWindow =
        startTime is int &&
        endTime is int &&
        startTime >= 0 &&
        endTime > startTime;
    final beforeWindow = validWindow && now < startTime;
    final afterWindow = validWindow && now > endTime;
    final closed =
        campaignStatus == 'cancelled' ||
        campaignStatus == 'completed' ||
        afterWindow;
    final claimsOpen =
        campaignStatus == 'claiming' &&
        validWindow &&
        !beforeWindow &&
        !afterWindow;
    final pending = const {
      'queued',
      'leased',
      'retry',
      'submitted',
      'confirmed',
    }.contains(job);
    final title = confirmed
        ? 'Burst Received!'
        : pending && campaignStatus == 'claiming'
        ? 'Reward processing'
        : closed
        ? (campaignStatus == 'cancelled' ? 'Burst cancelled' : 'Burst ended')
        : campaignStatus == 'claiming' && beforeWindow
        ? 'Claims open soon'
        : _proof != null && claimsOpen
        ? (failed
              ? 'Reward needs attention'
              : pending
              ? 'Reward processing'
              : 'Your reward is ready')
        : 'Waiting for host to Burst…';
    final joined = _campaign?['participantCount'];
    final maximum = _campaign?['maxParticipants'];
    if (confirmed && _campaign != null && _proof != null) {
      return Scaffold(
        backgroundColor: const Color(0xff111111),
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          foregroundColor: Colors.white,
        ),
        body: SafeArea(
          child: ListView(
            padding: const EdgeInsets.all(24),
            children: [
              const SizedBox(height: 18),
              Center(
                child: Container(
                  width: 104,
                  height: 104,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: const Color(0xff103d2e),
                    border: Border.all(color: const Color(0xff176b4e)),
                  ),
                  child: const Icon(
                    Icons.check,
                    color: Color(0xff18c88a),
                    size: 56,
                  ),
                ),
              ),
              const SizedBox(height: 28),
              const Text(
                'Burst Received!',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 32,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 10),
              const Text(
                'Your reward has been delivered to your wallet.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.white70),
              ),
              const SizedBox(height: 52),
              const Text(
                'YOU RECEIVED',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.white70, letterSpacing: 1.3),
              ),
              const SizedBox(height: 8),
              Text(
                _receiptAmount(_campaign!, _proof!),
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: burstAccent(context),
                  fontSize: 30,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 30),
              Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  border: Border.all(color: const Color(0xff414141)),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'CONFIRMED',
                      style: TextStyle(
                        color: Color(0xff18c88a),
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                      ),
                    ),
                    const SizedBox(height: 20),
                    Text(
                      'Network: ${_chainName ?? _campaign!['chainId'] ?? 'Unavailable'}',
                      style: const TextStyle(color: Colors.white70),
                    ),
                    const SizedBox(height: 12),
                    SelectableText(
                      'Transaction: ${_receiptHash()}',
                      style: const TextStyle(color: Colors.white70),
                    ),
                    if (_explorer != null)
                      TextButton(
                        onPressed: () => launchUrl(
                          _explorer!,
                          mode: LaunchMode.externalApplication,
                        ),
                        style: TextButton.styleFrom(
                          foregroundColor: burstAccent(context),
                        ),
                        child: const Text('View on block explorer'),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 28),
              const Text(
                'Send a thank-you message (optional)',
                style: TextStyle(color: Colors.white),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _message,
                maxLength: 280,
                minLines: 2,
                maxLines: 4,
                style: const TextStyle(color: Colors.white),
                decoration: const InputDecoration(
                  hintText: 'Write a brief message to the host...',
                  hintStyle: TextStyle(color: Colors.white54),
                  border: OutlineInputBorder(),
                ),
              ),
              TextButton(
                onPressed: _savingMessage ? null : _saveMessage,
                child: Text(_savingMessage ? 'Sending…' : 'Send message'),
              ),
              if (_messageStatus != null)
                Text(
                  _messageStatus!,
                  style: const TextStyle(color: Colors.white70),
                ),
              const SizedBox(height: 28),
              FilledButton(
                onPressed: () => Navigator.of(context).popUntil(
                  (route) => route.settings.name == '/shell' || route.isFirst,
                ),
                style: FilledButton.styleFrom(
                  shape: burstButtonShape,
                  backgroundColor: burstAccent(context),
                  foregroundColor: burstOnAccent(context),
                  minimumSize: const Size.fromHeight(54),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text('View in Wallet'),
                    const SizedBox(width: 8),
                    SvgPicture.asset(
                      'assets/burst/view_wallet.svg',
                      colorFilter: ColorFilter.mode(
                        burstOnAccent(context),
                        BlendMode.srcIn,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.of(context).pop(),
                      child: const Text('Done'),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Builder(
                      builder: (buttonContext) => OutlinedButton(
                        onPressed: () async {
                          final box =
                              buttonContext.findRenderObject() as RenderBox?;
                          final amount = _receiptAmount(_campaign!, _proof!);
                          final link = _explorer;
                          try {
                            await SharePlus.instance.share(
                              ShareParams(
                                text:
                                    'I received $amount in a Burst.${link == null ? '' : '\n$link'}',
                                sharePositionOrigin: box == null
                                    ? null
                                    : box.localToGlobal(Offset.zero) & box.size,
                              ),
                            );
                          } catch (_) {
                            if (buttonContext.mounted) {
                              ScaffoldMessenger.of(buttonContext).showSnackBar(
                                const SnackBar(
                                  content: Text(
                                    'Unable to open sharing. Try again.',
                                  ),
                                ),
                              );
                            }
                          }
                        },
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            SvgPicture.asset('assets/burst/share.svg'),
                            const SizedBox(width: 4),
                            const Text('Share'),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      );
    }
    return Scaffold(
      backgroundColor: const Color(0xff0f0f0f),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        foregroundColor: Colors.white,
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(24),
          children: [
            Center(
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 13,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: const Color(0xff2a2a2a),
                  borderRadius: BorderRadius.circular(99),
                ),
                child: Text(
                  widget.title.toUpperCase(),
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: burstAccent(context),
                    fontSize: 12,
                    letterSpacing: 1.2,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 64),
            Center(
              child: Container(
                width: 96,
                height: 96,
                decoration: BoxDecoration(
                  color: confirmed
                      ? const Color(0xff123b2b)
                      : burstAccent(context),
                  borderRadius: BorderRadius.circular(30),
                  boxShadow: [
                    BoxShadow(
                      color: (confirmed ? Colors.green : burstAccent(context))
                          .withValues(alpha: 0.22),
                      blurRadius: 36,
                    ),
                  ],
                ),
                child: Center(
                  child: confirmed
                      ? const Icon(
                          Icons.check,
                          color: Color(0xff18c88a),
                          size: 48,
                        )
                      : SvgPicture.asset('assets/burst/waiting_rocket.svg'),
                ),
              ),
            ),
            const SizedBox(height: 40),
            Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 262),
                child: Text(
                  title,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 30,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 38),
            if (joined is num && maximum is num)
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 24,
                ),
                decoration: BoxDecoration(
                  color: const Color(0xff171918),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: const Color(0xff372021)),
                ),
                child: Column(
                  children: [
                    Align(
                      alignment: Alignment.centerRight,
                      child: Text(
                        '●  YOU’RE IN',
                        style: TextStyle(
                          color: burstAccent(context),
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),
                    Text(
                      '$joined of $maximum guests joined',
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: Colors.white, fontSize: 20),
                    ),
                    const SizedBox(height: 16),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(99),
                      child: LinearProgressIndicator(
                        value: maximum > 0
                            ? (joined / maximum).clamp(0.0, 1.0).toDouble()
                            : 0,
                        minHeight: 4,
                        color: burstAccent(context),
                        backgroundColor: const Color(0xff343434),
                      ),
                    ),
                  ],
                ),
              ),
            if (_claimError != null || _error != null)
              Padding(
                padding: const EdgeInsets.only(top: 20),
                child: Text(
                  _claimError ?? _error!,
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Color(0xffff8b91)),
                ),
              ),
            if (closed && !pending)
              Padding(
                padding: const EdgeInsets.only(top: 24),
                child: Text(
                  campaignStatus == 'claiming'
                      ? 'This Burst may no longer be accepting claims.'
                      : 'This Burst is no longer accepting claims.',
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.white70),
                ),
              )
            else if (failed && claimsOpen)
              const Padding(
                padding: EdgeInsets.only(top: 24),
                child: Text(
                  'Your claim could not be completed. Contact Owllet support with this Burst’s details.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.white70),
                ),
              ),
            if (_proof != null &&
                claimsOpen &&
                !confirmed &&
                !pending &&
                !failed &&
                !closed)
              Padding(
                padding: const EdgeInsets.only(top: 32),
                child: FilledButton(
                  onPressed: _claiming ? null : _claim,
                  style: FilledButton.styleFrom(
                    shape: burstButtonShape,
                    backgroundColor: burstAccent(context),
                    foregroundColor: burstOnAccent(context),
                    minimumSize: const Size.fromHeight(56),
                  ),
                  child: Text(_claiming ? 'Requesting…' : 'Claim reward'),
                ),
              ),
            if (_proof != null &&
                campaignStatus == 'claiming' &&
                validWindow &&
                !claimsOpen &&
                !confirmed &&
                !pending &&
                !failed)
              Padding(
                padding: const EdgeInsets.only(top: 32),
                child: FilledButton(
                  onPressed: _claiming ? null : _claim,
                  style: FilledButton.styleFrom(
                    shape: burstButtonShape,
                    backgroundColor: burstAccent(context),
                    foregroundColor: burstOnAccent(context),
                    minimumSize: const Size.fromHeight(56),
                  ),
                  child: Text(_claiming ? 'Requesting…' : 'Try claiming'),
                ),
              ),
            const SizedBox(height: 20),
            TextButton(
              onPressed: _refresh,
              style: TextButton.styleFrom(
                foregroundColor: burstAccent(context),
              ),
              child: const Text('Refresh'),
            ),
            if (campaignStatus == 'active' && _proof == null)
              TextButton(
                onPressed: _leaving ? null : _leave,
                style: TextButton.styleFrom(
                  foregroundColor: burstAccent(context),
                ),
                child: Text(_leaving ? 'Leaving…' : 'Leave Burst'),
              ),
          ],
        ),
      ),
    );
  }
}
