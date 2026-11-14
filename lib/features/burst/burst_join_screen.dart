import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import 'burst_api_client.dart';
import 'burst_theme.dart';

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

  Future<void> _pasteCode() async {
    final data = await Clipboard.getData(Clipboard.kTextPlain);
    final raw = data?.text?.trim();
    if (raw == null || raw.isEmpty || !mounted) return;
    final sanitized = raw.replaceAll(RegExp(r'[^a-zA-Z2-7-]'), '').toUpperCase();
    if (sanitized.isEmpty) return;
    _code.value = TextEditingValue(
      text: sanitized,
      selection: TextSelection.collapsed(offset: sanitized.length),
    );
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
      final joinedCount = campaign['participantCount'];
      final maxGuests = campaign['maxParticipants'];
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (dialog) => AlertDialog(
          backgroundColor: const Color(0xFF141414),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
            side: BorderSide(color: Colors.white.withValues(alpha: 0.1)),
          ),
          title: const Text(
            'Confirm your Burst',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '${campaign['title']}',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                'Network: ${campaign['chainId']}'
                '${joinedCount is int && maxGuests is int ? '\nGuests: $joinedCount / $maxGuests' : ''}'
                '\nReceiving wallet: ${widget.walletAddress}',
                style: const TextStyle(
                  color: Colors.white70,
                  fontSize: 13,
                  height: 1.5,
                ),
              ),
              const SizedBox(height: 10),
              const Text(
                'Your reward will be sent to this wallet.',
                style: TextStyle(color: Colors.white54, fontSize: 12),
              ),
            ],
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
  Widget build(BuildContext context) {
    final accent = burstAccent(context);
    return Scaffold(
      backgroundColor: const Color(0xFF050505),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        foregroundColor: Colors.white,
        title: const BurstHeader(),
        centerTitle: true,
      ),
      body: SafeArea(
        child: Stack(
          children: [
            Positioned.fill(
              child: IgnorePointer(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: RadialGradient(
                      center: const Alignment(0, -0.5),
                      radius: 0.9,
                      colors: [
                        accent.withValues(alpha: 0.08),
                        Colors.transparent,
                      ],
                    ),
                  ),
                ),
              ),
            ),
            ListView(
              padding: const EdgeInsets.all(24),
              children: [
                const SizedBox(height: 28),
                const Text(
                  'ENTER CODE',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.white54,
                    letterSpacing: 3,
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
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
                const SizedBox(height: 8),
                const Text(
                  'Enter or paste the invite code from your host.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.white60, fontSize: 13),
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
                  style: const TextStyle(
                    color: Colors.white,
                    letterSpacing: 3,
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                  textAlign: TextAlign.center,
                  decoration: InputDecoration(
                    labelText: 'Burst access code',
                    hintText: 'X7K6P2',
                    hintStyle: const TextStyle(
                      color: Colors.white24,
                      letterSpacing: 3,
                    ),
                    filled: true,
                    fillColor: const Color(0xFF181818),
                    suffixIcon: IconButton(
                      tooltip: 'Paste code',
                      onPressed: _busy ? null : _pasteCode,
                      icon: const Icon(
                        Icons.content_paste_rounded,
                        color: Colors.white60,
                        size: 20,
                      ),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(
                        color: Colors.white.withValues(alpha: 0.08),
                      ),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: accent),
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.03),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.06),
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Joining wallet',
                        style: TextStyle(color: Colors.white54, fontSize: 11),
                      ),
                      const SizedBox(height: 6),
                      SelectableText(
                        widget.walletAddress,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                ),
                if (_error != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 20),
                    child: Text(
                      _error!,
                      style: const TextStyle(color: Color(0xFFFF8B91)),
                    ),
                  ),
                const SizedBox(height: 32),
                Container(
                  decoration: BoxDecoration(
                    boxShadow: burstActionShadow(context),
                  ),
                  child: FilledButton(
                    onPressed: _busy ? null : _join,
                    style: FilledButton.styleFrom(
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      backgroundColor: accent,
                      foregroundColor: burstOnAccent(context),
                      minimumSize: const Size.fromHeight(56),
                    ),
                    child: Text(
                      _busy ? 'Joining…' : 'Join Burst',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
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

  String _shortAddress(String address) {
    if (address.length <= 12) return address;
    return '${address.substring(0, 6)}…${address.substring(address.length - 4)}';
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
    _timer = Timer.periodic(const Duration(seconds: 4), (_) => _refresh());
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
        backgroundColor: const Color(0xFF141414),
        title: const Text(
          'Leave this Burst?',
          style: TextStyle(color: Colors.white),
        ),
        content: const Text(
          'Your place will be available to someone else.',
          style: TextStyle(color: Colors.white70),
        ),
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
    final accent = burstAccent(context);
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
    final hostAddress = _campaign?['hostWalletAddress']?.toString() ?? '';

    if (confirmed && _campaign != null && _proof != null) {
      return Scaffold(
        backgroundColor: const Color(0xFF131313),
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          foregroundColor: Colors.white,
          title: const BurstHeader(),
          centerTitle: true,
        ),
        body: SafeArea(
          child: ListView(
            padding: const EdgeInsets.all(24),
            children: [
              const SizedBox(height: 12),
              Center(
                child: Container(
                  width: 104,
                  height: 104,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: const Color(0xFF103829),
                    border: Border.all(
                      color: const Color(0xFF1C604C),
                      width: 2,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF18C783).withValues(alpha: 0.25),
                        blurRadius: 32,
                      ),
                    ],
                  ),
                  child: const Icon(
                    Icons.check_rounded,
                    color: Color(0xFF18C783),
                    size: 56,
                  ),
                ),
              ),
              const SizedBox(height: 24),
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
              const SizedBox(height: 40),
              const Text(
                'YOU RECEIVED',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.white60,
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 1.5,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                _receiptAmount(_campaign!, _proof!),
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: accent,
                  fontSize: 30,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 28),
              Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: const Color(0xFF171717),
                  border: Border.all(
                    color: const Color(0xFF94A3B8).withValues(alpha: 0.35),
                  ),
                  borderRadius: BorderRadius.circular(17),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFF14362B),
                        borderRadius: BorderRadius.circular(999),
                        border: Border.all(color: const Color(0xFF1C604C)),
                      ),
                      child: const Text(
                        'CONFIRMED',
                        style: TextStyle(
                          color: Color(0xFF18C783),
                          fontWeight: FontWeight.bold,
                          fontSize: 11,
                          letterSpacing: 0.8,
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Network: ${_chainName ?? _campaign!['chainId'] ?? 'Unavailable'}',
                      style: const TextStyle(color: Colors.white70),
                    ),
                    const SizedBox(height: 10),
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
                          padding: EdgeInsets.zero,
                          foregroundColor: accent,
                        ),
                        child: const Text('View on block explorer'),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color(0xFF111111),
                  border: Border.all(color: const Color(0xFF222222)),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Send a thank-you message (optional)',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: _message,
                      maxLength: 280,
                      minLines: 2,
                      maxLines: 4,
                      style: const TextStyle(color: Colors.white),
                      decoration: InputDecoration(
                        hintText: 'Write a brief message to the host...',
                        hintStyle: const TextStyle(color: Colors.white38),
                        filled: true,
                        fillColor: const Color(0xFF181818),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: const BorderSide(
                            color: Color(0xFF2A2A2A),
                          ),
                        ),
                      ),
                    ),
                    TextButton(
                      onPressed: _savingMessage ? null : _saveMessage,
                      style: TextButton.styleFrom(foregroundColor: accent),
                      child: Text(_savingMessage ? 'Sending…' : 'Send message'),
                    ),
                    if (_messageStatus != null)
                      Text(
                        _messageStatus!,
                        style: const TextStyle(color: Colors.white70),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              Container(
                decoration: BoxDecoration(
                  boxShadow: burstActionShadow(context),
                ),
                child: FilledButton(
                  onPressed: () => Navigator.of(context).popUntil(
                    (route) => route.settings.name == '/shell' || route.isFirst,
                  ),
                  style: FilledButton.styleFrom(
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    backgroundColor: accent,
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
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.of(context).pop(),
                      style: OutlinedButton.styleFrom(
                        minimumSize: const Size.fromHeight(48),
                        backgroundColor: const Color(0xFF201F1F),
                        foregroundColor: Colors.white,
                        side: BorderSide(
                          color: Colors.white.withValues(alpha: 0.1),
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: const Text('Done'),
                    ),
                  ),
                  const SizedBox(width: 14),
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
                        style: OutlinedButton.styleFrom(
                          minimumSize: const Size.fromHeight(48),
                          backgroundColor: const Color(0xFF201F1F),
                          foregroundColor: Colors.white,
                          side: BorderSide(
                            color: Colors.white.withValues(alpha: 0.1),
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            SvgPicture.asset('assets/burst/share.svg'),
                            const SizedBox(width: 6),
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

    final tall = MediaQuery.sizeOf(context).height >= 700;
    final ratio = joined is num && maximum is num && maximum > 0
        ? (joined / maximum).clamp(0.0, 1.0).toDouble()
        : 0.0;

    return Scaffold(
      backgroundColor: const Color(0xFF0F0F0F),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        foregroundColor: Colors.white,
        title: const BurstHeader(),
        centerTitle: true,
      ),
      body: SafeArea(
        child: Stack(
          children: [
            Positioned.fill(
              child: IgnorePointer(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: RadialGradient(
                      center: const Alignment(0, -0.35),
                      radius: 0.85,
                      colors: [
                        accent.withValues(alpha: 0.09),
                        Colors.transparent,
                      ],
                    ),
                  ),
                ),
              ),
            ),
            ListView(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
              children: [
                SizedBox(height: tall ? 28 : 4),
                Center(
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFF2A2A2A),
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(
                      widget.title.toUpperCase(),
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: accent,
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        letterSpacing: 1.2,
                      ),
                    ),
                  ),
                ),
                if (hostAddress.isNotEmpty) ...[
                  SizedBox(height: tall ? 16 : 8),
                  Text.rich(
                    TextSpan(
                      style: const TextStyle(
                        color: Color(0xFFB9CBBC),
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                      ),
                      children: [
                        const TextSpan(text: 'Host: '),
                        TextSpan(
                          text: _shortAddress(hostAddress),
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
                SizedBox(height: tall ? 48 : 16),
                Center(
                  child: Container(
                    width: tall ? 96 : 76,
                    height: tall ? 96 : 76,
                    decoration: BoxDecoration(
                      gradient: confirmed
                          ? null
                          : LinearGradient(
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                              colors: [
                                accent,
                                accent.withValues(alpha: 0.72),
                              ],
                            ),
                      color: confirmed ? const Color(0xFF123B2B) : null,
                      borderRadius: BorderRadius.circular(tall ? 32 : 24),
                      boxShadow: [
                        BoxShadow(
                          color: (confirmed ? Colors.green : accent).withValues(
                            alpha: 0.45,
                          ),
                          blurRadius: 40,
                          spreadRadius: 2,
                        ),
                      ],
                    ),
                    child: Center(
                      child: confirmed
                          ? const Icon(
                              Icons.check,
                              color: Color(0xFF18C88A),
                              size: 40,
                            )
                          : SvgPicture.asset(
                              'assets/burst/waiting_rocket.svg',
                              width: 40,
                              height: 40,
                              colorFilter: ColorFilter.mode(
                                burstOnAccent(context),
                                BlendMode.srcIn,
                              ),
                            ),
                    ),
                  ),
                ),
                SizedBox(height: tall ? 40 : 14),
                Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 265),
                    child: Text(
                      title,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: const Color(0xFFE5E2E1),
                        fontSize: tall ? 30 : 28,
                        fontWeight: FontWeight.bold,
                        height: 1.2,
                        letterSpacing: -0.75,
                      ),
                    ),
                  ),
                ),
                SizedBox(height: tall ? 40 : 14),
                if (joined is num && maximum is num)
                  Container(
                    padding: EdgeInsets.all(tall ? 24 : 14),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.04),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: accent.withValues(alpha: 0.26),
                      ),
                    ),
                    child: Column(
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            _GuestAvatarStack(
                              joinedCount: joined.toInt(),
                              size: tall ? 40 : 28,
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 6,
                              ),
                              decoration: BoxDecoration(
                                color: accent.withValues(alpha: 0.22),
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(
                                  color: const Color(0xFF303030),
                                ),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    Icons.check_circle_outline_rounded,
                                    size: 14,
                                    color: accent,
                                  ),
                                  const SizedBox(width: 6),
                                  Text(
                                    'YOU’RE IN!',
                                    style: TextStyle(
                                      color: accent,
                                      fontSize: 12,
                                      fontWeight: FontWeight.bold,
                                      letterSpacing: 0.3,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        SizedBox(height: tall ? 24 : 12),
                        Text(
                          '$joined of $maximum guests joined',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: const Color(0xFFE5E2E1),
                            fontSize: tall ? 22 : 18,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        SizedBox(height: tall ? 16 : 10),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(99),
                          child: LinearProgressIndicator(
                            value: ratio,
                            minHeight: 4,
                            color: accent,
                            backgroundColor: const Color(0xFF353534),
                          ),
                        ),
                      ],
                    ),
                  ),
                if (_claimError != null || _error != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 14),
                    child: Text(
                      _claimError ?? _error!,
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: Color(0xFFFF8B91)),
                    ),
                  ),
                if (closed && !pending)
                  Padding(
                    padding: const EdgeInsets.only(top: 14),
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
                    padding: EdgeInsets.only(top: 14),
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
                    padding: const EdgeInsets.only(top: 14),
                    child: FilledButton(
                      onPressed: _claiming ? null : _claim,
                      style: FilledButton.styleFrom(
                        shape: burstButtonShape,
                        backgroundColor: accent,
                        foregroundColor: burstOnAccent(context),
                        minimumSize: const Size.fromHeight(48),
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
                    padding: const EdgeInsets.only(top: 14),
                    child: FilledButton(
                      onPressed: _claiming ? null : _claim,
                      style: FilledButton.styleFrom(
                        shape: burstButtonShape,
                        backgroundColor: accent,
                        foregroundColor: burstOnAccent(context),
                        minimumSize: const Size.fromHeight(48),
                      ),
                      child: Text(_claiming ? 'Requesting…' : 'Try claiming'),
                    ),
                  ),
                SizedBox(height: tall ? 56 : 8),
                if (campaignStatus == 'active' && _proof == null) ...[
                  Center(
                    child: TextButton(
                      onPressed: _leaving ? null : _leave,
                      style: TextButton.styleFrom(
                        backgroundColor: accent.withValues(alpha: 0.18),
                        foregroundColor: accent,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 20,
                          vertical: 10,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      child: Text(
                        _leaving ? 'Leaving…' : 'Leave Burst',
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                    ),
                  ),
                  SizedBox(height: tall ? 8 : 4),
                ],
                Center(
                  child: TextButton(
                    onPressed: _refresh,
                    style: TextButton.styleFrom(
                      foregroundColor: Colors.white54,
                    ),
                    child: const Text(
                      'Refresh',
                      style: TextStyle(fontSize: 12),
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
}

class _GuestAvatarStack extends StatelessWidget {
  const _GuestAvatarStack({this.joinedCount = 1, this.size = 40});

  final int joinedCount;
  final double size;

  @override
  Widget build(BuildContext context) {
    const colors = [
      Color(0xFFEA2A33),
      Color(0xFFFC9915),
      Color(0xFF18C783),
    ];
    final visible = joinedCount <= 0
        ? 1
        : (joinedCount > 3 ? 3 : joinedCount);
    final extra = joinedCount > 3 ? joinedCount - 3 : 0;
    final total = visible + (extra > 0 ? 1 : 0);
    final overlap = size * 0.30;
    final step = size - overlap;
    final totalWidth = size + (total - 1) * step;
    return SizedBox(
      width: totalWidth,
      height: size,
      child: Stack(
        children: [
          for (var i = 0; i < visible; i++)
            Positioned(
              left: i * step,
              child: Container(
                width: size,
                height: size,
                decoration: BoxDecoration(
                  color: colors[i].withValues(alpha: 0.22),
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: const Color(0xFF0E0E0E),
                    width: 2,
                  ),
                ),
                child: Icon(
                  Icons.person_outline_rounded,
                  size: size * 0.45,
                  color: colors[i],
                ),
              ),
            ),
          if (extra > 0)
            Positioned(
              left: visible * step,
              child: Container(
                width: size,
                height: size,
                decoration: BoxDecoration(
                  color: const Color(0xFF353534),
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: const Color(0xFF0E0E0E),
                    width: 2,
                  ),
                ),
                child: Center(
                  child: Text(
                    '+$extra',
                    style: const TextStyle(
                      color: Color(0xFFB9CBBC),
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
