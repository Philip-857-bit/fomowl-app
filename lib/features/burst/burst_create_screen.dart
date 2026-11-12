import 'dart:math';
import 'dart:convert';

import 'package:flutter/material.dart';

import 'burst_theme.dart';
import 'package:provider/provider.dart';

import '../../models/token.dart';
import '../../models/token_standard.dart';
import '../../services/blockchain_service.dart';
import '../../services/nft_service.dart';
import 'burst_api_client.dart';
import 'burst_campaign_draft.dart';
import 'burst_draft_store.dart';
import 'burst_draft_editor.dart';
import 'burst_nft_gallery_screen.dart';
import 'burst_prepared_campaign.dart';
import 'burst_review_screen.dart' show burstAssetAmount;

/// Prepares a campaign only; transaction approval is a separate native step.
class BurstCreateScreen extends StatefulWidget {
  const BurstCreateScreen({
    super.key,
    required this.api,
    required this.wallet,
    required this.config,
    required this.onPrepared,
    required this.profileId,
    required this.store,
    this.loadNfts,
    this.initialDraft,
    this.canEditPrepared,
  });
  final BurstApiClient api;
  final String wallet;
  final Map<String, dynamic> config;
  final Future<void> Function(Map<String, dynamic> prepared) onPrepared;
  final String profileId;
  final BurstDraftStore store;
  final Map<String, dynamic>? initialDraft;
  final Future<bool> Function(Map<String, dynamic> prepared)? canEditPrepared;
  final Future<List<NftAsset>> Function({
    required int chainId,
    required String chainName,
    required String walletAddress,
  })?
  loadNfts;

  @override
  State<BurstCreateScreen> createState() => _BurstCreateScreenState();
}

class _BurstCreateScreenState extends State<BurstCreateScreen> {
  final _title = TextEditingController();
  final _description = TextEditingController();
  final _amount = TextEditingController();
  final _participants = TextEditingController();
  late String _idempotencyKey;
  Map<String, dynamic>? _savedDraft;
  Token? _token;
  List<NftAsset>? _inventory;
  final List<BurstNftAllocation> _allocations = [];
  bool _nft = false;
  bool _randomizeNfts = false;
  bool _busy = false;
  String? _error;
  Map<String, dynamic>? _preparedPayload;
  late String _savedFormState;
  bool _allowLeave = false;
  bool _revisionConflict = false;

  @override
  void initState() {
    super.initState();
    _amount.addListener(_updatePreview);
    _participants.addListener(_updatePreview);
    _title.addListener(_updatePreview);
    _description.addListener(_updatePreview);
    _idempotencyKey = _newKey();
    final saved = widget.initialDraft;
    if (saved != null) {
      _savedDraft = Map<String, dynamic>.from(saved);
      final pending = saved['pendingUpdate'];
      final request = Map<String, dynamic>.from(
        (pending is Map ? pending : saved['request']) as Map,
      )..remove('previousIdempotencyKey');
      if (pending is Map) _preparedPayload = request;
      _restore(request);
    }
    _savedFormState = _formState();
  }

  String _formState() => jsonEncode([
    _title.text,
    _description.text,
    _amount.text,
    _participants.text,
    _nft,
    _token?.contractAddress,
    _token?.symbol,
    _randomizeNfts,
    for (final allocation in _allocations)
      [
        allocation.asset.contractAddress,
        allocation.asset.tokenId,
        allocation.quantity,
      ],
  ]);

  Future<void> _confirmLeave() async {
    if (_busy) return;
    final leave = await showDialog<bool>(
      context: context,
      builder: (dialog) => AlertDialog(
        title: const Text('Discard unsaved changes?'),
        content: const Text(
          'Your changes have not been saved. Any previously saved Burst draft will be kept.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialog, false),
            child: const Text('Keep editing'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(dialog, true),
            child: const Text('Discard changes'),
          ),
        ],
      ),
    );
    if (leave == true && mounted) {
      setState(() => _allowLeave = true);
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) Navigator.of(context).pop();
      });
    }
  }

  String _newKey() {
    final random = Random.secure();
    return 'native-${List.generate(16, (_) => random.nextInt(256).toRadixString(16).padLeft(2, '0')).join()}';
  }

  void _restore(Map<String, dynamic> request) {
    _title.text = request['title']?.toString() ?? '';
    _description.text = request['description']?.toString() ?? '';
    _participants.text = request['maxParticipants']?.toString() ?? '';
    final kind = request['assetKind'];
    _nft = kind == 'erc721' || kind == 'erc1155';
    final chain = context.read<BlockchainService>();
    if (!_nft) {
      final address = request['assetAddress']?.toString().toLowerCase();
      _token = chain.tokens
          .where(
            (token) =>
                token.decimals == request['assetDecimals'] &&
                (kind == 'native'
                    ? token.effectiveTokenStandard == TokenStandard.native ||
                          (token.symbol == request['assetSymbol'] &&
                              (token.contractAddress?.isEmpty ?? true))
                    : token.contractAddress?.toLowerCase() == address),
          )
          .firstOrNull;
      _token ??= Token(
        symbol: request['assetSymbol'] as String,
        name: 'Saved asset (unavailable)',
        contractAddress: request['assetAddress'] as String?,
        decimals: request['assetDecimals'] as int,
        balance: 0,
        valueUsd: 0,
        changePercent24h: 0,
        tokenStandard: kind == 'native'
            ? TokenStandard.native
            : TokenStandard.erc20,
      );
      _amount.text = burstAssetAmount(
        request['totalAmountBaseUnits'].toString(),
        request['assetDecimals'] as int,
        '',
      ).trim();
    } else {
      for (final raw in (request['nftAllocations'] as List? ?? const [])) {
        final allocation = raw as Map;
        final quantity = int.parse(allocation['amount'].toString());
        _allocations.add(
          BurstNftAllocation(
            asset: NftAsset(
              name: 'Saved NFT',
              collection: 'Saved collection',
              description: '',
              count: quantity,
              chainName: chain.activeChain.name,
              chainId: request['chainId'] as int,
              imageUrl: '',
              contractAddress: request['assetAddress'] as String,
              tokenId: allocation['tokenId'].toString(),
              tokenType: kind == 'erc1155' ? 'ERC1155' : 'ERC721',
              isProjectNft: false,
            ),
            quantity: quantity,
          ),
        );
      }
    }
  }

  void _updatePreview() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _amount.removeListener(_updatePreview);
    _participants.removeListener(_updatePreview);
    _title.removeListener(_updatePreview);
    _description.removeListener(_updatePreview);
    _title.dispose();
    _description.dispose();
    _amount.dispose();
    _participants.dispose();
    super.dispose();
  }

  Future<void> _loadNfts() async {
    if (_inventory != null || _busy) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final blockchain = context.read<BlockchainService>();
      final assets = await (widget.loadNfts ?? NftService().fetchOwnedNfts)(
        chainId: blockchain.activeChain.chainId,
        chainName: blockchain.activeChain.name,
        walletAddress: widget.wallet,
      );
      if (mounted) {
        setState(
          () => _inventory = assets
              .where((asset) => !asset.isCompressed && asset.count > 0)
              .toList(),
        );
      }
    } catch (_) {
      if (mounted) {
        setState(
          () => _error = 'Unable to load your NFT inventory. Try again.',
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _openNftGallery() async {
    if (_inventory == null) await _loadNfts();
    if (!mounted || _inventory == null) return;
    final selected = await Navigator.of(context).push<BurstNftSelection>(
      BurstPageRoute(
        builder: (_) => BurstNftGalleryScreen(
          inventory: _inventory!,
          selected: _allocations,
          randomize: _randomizeNfts,
        ),
      ),
    );
    if (mounted && selected != null) {
      setState(() {
        _allocations
          ..clear()
          ..addAll(selected.allocations);
        _randomizeNfts = selected.randomize;
        _error = null;
      });
    }
  }

  void _changeQuantity(int index, int delta) {
    final allocation = _allocations[index];
    final quantity = allocation.quantity + delta;
    if (!allocation.asset.isErc1155 || quantity < 1) return;
    final used = _allocations
        .where(
          (item) =>
              item.asset.tokenId == allocation.asset.tokenId &&
              item.asset.contractAddress.toLowerCase() ==
                  allocation.asset.contractAddress.toLowerCase(),
        )
        .fold<int>(0, (sum, item) => sum + item.quantity);
    if (used + delta > allocation.asset.count) {
      setState(() => _error = 'NFT allocations exceed your available copies.');
      return;
    }
    setState(() {
      _error = null;
      _allocations[index] = BurstNftAllocation(
        asset: allocation.asset,
        quantity: quantity,
      );
    });
  }

  Future<void> _prepare() async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      if (widget.config['gaslessClaimsEnabled'] != true) {
        throw const FormatException(
          'Burst claims are currently unavailable on this network. Try again when the claim relayer is enabled.',
        );
      }
      final blockchain = context.read<BlockchainService>();
      final chainId = blockchain.activeChain.chainId;
      final configuredChain = widget.config['chainId'];
      if (configuredChain is int && configuredChain != chainId) {
        throw const FormatException(
          'The network changed. Close Burst and open it again before creating a campaign.',
        );
      }
      if (_preparedPayload != null) {
        await _saveAndReview(_preparedPayload!, chainId);
        return;
      }
      if (_nft) {
        final owned = await (widget.loadNfts ?? NftService().fetchOwnedNfts)(
          chainId: chainId,
          chainName: blockchain.activeChain.name,
          walletAddress: widget.wallet,
        );
        final refreshed = <BurstNftAllocation>[];
        for (final allocation in _allocations) {
          final asset = owned
              .where(
                (item) =>
                    !item.isCompressed &&
                    item.contractAddress.toLowerCase() ==
                        allocation.asset.contractAddress.toLowerCase() &&
                    item.tokenId == allocation.asset.tokenId &&
                    item.isErc1155 == allocation.asset.isErc1155,
              )
              .firstOrNull;
          final total = _allocations
              .where(
                (item) =>
                    item.asset.contractAddress.toLowerCase() ==
                        allocation.asset.contractAddress.toLowerCase() &&
                    item.asset.tokenId == allocation.asset.tokenId,
              )
              .fold<int>(0, (sum, item) => sum + item.quantity);
          if (asset == null || total > asset.count) {
            throw const FormatException(
              'A saved NFT is no longer available in this wallet. Update your NFT selection.',
            );
          }
          refreshed.add(
            BurstNftAllocation(asset: asset, quantity: allocation.quantity),
          );
        }
        _inventory = owned;
        _allocations
          ..clear()
          ..addAll(refreshed);
      }
      final selected = _nft
          ? (_allocations.isEmpty ? null : _allocations.first.asset)
          : null;
      final token = _nft || _token == null
          ? blockchain.tokens.first
          : blockchain.tokens
                .where(
                  (item) =>
                      item.contractAddress?.toLowerCase() ==
                          _token!.contractAddress?.toLowerCase() &&
                      item.symbol == _token!.symbol &&
                      item.decimals == _token!.decimals,
                )
                .firstOrNull;
      if (token == null) {
        throw const FormatException(
          'The selected asset is no longer available.',
        );
      }
      final tokenAddress = token.contractAddress?.trim();
      final kind = _nft
          ? (selected?.isErc1155 == true ? 'erc1155' : 'erc721')
          : (token.effectiveTokenStandard == TokenStandard.native ||
                    tokenAddress == null ||
                    tokenAddress.isEmpty
                ? 'native'
                : 'erc20');
      final supported = widget.config['supportedAssetKinds'];
      if (supported is! List || !supported.contains(kind)) {
        throw const FormatException(
          'This asset is not supported on this network.',
        );
      }
      final draft = BurstCampaignDraft(
        chainId: chainId,
        title: _title.text,
        description: _description.text,
        kind: kind,
        symbol: _nft ? 'NFT' : token.symbol,
        decimals: _nft ? 0 : token.decimals,
        participants: int.tryParse(_participants.text) ?? 0,
        amount: _amount.text,
        assetAddress: _nft
            ? selected?.contractAddress
            : (kind == 'native' ? null : tokenAddress),
        nfts: _allocations,
        randomizeNfts: _randomizeNfts,
        startTime: (_savedDraft?['request'] as Map?)?['startTime'] as int?,
        endTime: (_savedDraft?['request'] as Map?)?['endTime'] as int?,
      );
      final max = widget.config['maxParticipants'];
      if (max is! int) {
        throw const FormatException('Burst limits are unavailable.');
      }
      final payload =
          _preparedPayload ??
          draft.toRequest(
            idempotencyKey: _idempotencyKey,
            maxParticipants: max,
            now: DateTime.now(),
          );
      await _saveAndReview(payload, chainId);
    } catch (error) {
      if (mounted) {
        setState(
          () => _error = error is BurstApiException
              ? error.message
              : error is FormatException
              ? error.message
              : 'Unable to prepare this Burst. Try again.',
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _saveAndReview(Map<String, dynamic> payload, int chainId) async {
    _preparedPayload = payload;
    final existing = await widget.store.read(
      widget.profileId,
      widget.wallet,
      chainId,
    );
    if (_savedDraft == null &&
        existing != null &&
        (existing['request'] as Map)['idempotencyKey'] != _idempotencyKey) {
      throw const FormatException(
        'Resume your existing Burst before creating another.',
      );
    }
    final Map<String, dynamic> prepared;
    try {
      if (_savedDraft != null) {
        prepared = await BurstDraftEditor(
          api: widget.api,
          store: widget.store,
          profileId: widget.profileId,
          wallet: widget.wallet,
          chainId: chainId,
          validate: (response, request) => BurstPreparedCampaign.parse(
            response,
            request,
            factoryAddress: widget.config['factoryAddress']?.toString() ?? '',
            wallet: widget.wallet,
            proxyInitCodeHash: widget.config['proxyInitCodeHash']?.toString(),
          ),
        ).update(saved: _savedDraft!, request: payload);
      } else {
        await widget.store.write(widget.profileId, widget.wallet, chainId, {
          'request': payload,
        });
        prepared = await widget.api.prepare(payload);
      }
    } on BurstApiException catch (error) {
      // A validation response means the backend did not create this draft.
      // Keep the draft for timeouts and other uncertain outcomes so a retry
      // uses the same idempotency key and cannot duplicate a campaign.
      if (error.statusCode == 400 ||
          _savedDraft != null && error.statusCode == 409) {
        if (_savedDraft == null) {
          await widget.store.clear(widget.profileId, widget.wallet, chainId);
        }
        _preparedPayload = null;
      }
      if (_savedDraft != null) {
        _savedDraft = await widget.store.read(
          widget.profileId,
          widget.wallet,
          chainId,
        );
      }
      if (_savedDraft != null && error.statusCode == 409) {
        _revisionConflict = true;
        throw const BurstApiException(
          'This draft changed or submission has started. Close and reopen it to load its current state. Your saved draft is kept.',
          statusCode: 409,
        );
      }
      rethrow;
    }
    BurstPreparedCampaign.parse(
      prepared,
      payload,
      factoryAddress: widget.config['factoryAddress']?.toString() ?? '',
      wallet: widget.wallet,
      proxyInitCodeHash: widget.config['proxyInitCodeHash']?.toString(),
    );
    await widget.store.write(widget.profileId, widget.wallet, chainId, {
      'request': payload,
      'prepared': prepared,
    });
    _savedDraft = {'request': payload, 'prepared': prepared};
    _savedFormState = _formState();
    if (!mounted) return;
    await widget.onPrepared(prepared);
    if (mounted && widget.canEditPrepared != null) {
      final editable = await widget.canEditPrepared!(prepared);
      if (!mounted) return;
      if (editable) {
        setState(() {
          _preparedPayload = null;
          _idempotencyKey = _newKey();
        });
      } else {
        setState(() => _allowLeave = true);
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) Navigator.of(context).pop();
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final availableTokens = context.watch<BlockchainService>().tokens;
    final tokens = [
      ...availableTokens,
      if (_token != null &&
          !availableTokens.any(
            (token) =>
                token.contractAddress?.toLowerCase() ==
                    _token!.contractAddress?.toLowerCase() &&
                token.symbol == _token!.symbol &&
                token.decimals == _token!.decimals,
          ))
        _token!,
    ];
    final currentToken =
        tokens
            .where(
              (token) =>
                  token.contractAddress?.toLowerCase() ==
                      _token?.contractAddress?.toLowerCase() &&
                  token.symbol == _token?.symbol &&
                  token.decimals == _token?.decimals,
            )
            .firstOrNull ??
        tokens.first;
    final perParticipant = burstPerParticipant(
      _amount.text,
      currentToken.decimals,
      int.tryParse(_participants.text) ?? 0,
    );
    return PopScope<Object?>(
      canPop: _allowLeave || !_busy && _formState() == _savedFormState,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop) _confirmLeave();
      },
      child: Scaffold(
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
              const Text(
                'Select the asset and number of guests.',
                style: TextStyle(color: Colors.white70),
              ),
              if (_savedDraft != null)
                const Padding(
                  padding: EdgeInsets.only(top: 12),
                  child: Text(
                    'Edit draft',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              if (_savedDraft?['pendingUpdate'] is Map)
                const Padding(
                  padding: EdgeInsets.only(top: 12),
                  child: Text(
                    'Your last save is awaiting confirmation. Review again to check the same update.',
                    style: TextStyle(color: Colors.white70),
                  ),
                ),
              if (!_nft &&
                  _token != null &&
                  !availableTokens.any(
                    (token) =>
                        token.contractAddress?.toLowerCase() ==
                            _token!.contractAddress?.toLowerCase() &&
                        token.symbol == _token!.symbol &&
                        token.decimals == _token!.decimals,
                  ))
                const Padding(
                  padding: EdgeInsets.only(top: 12),
                  child: Text(
                    'The saved asset is unavailable. Select another asset to continue.',
                    style: TextStyle(color: Color(0xffff8b91)),
                  ),
                ),
              const SizedBox(height: 24),
              SegmentedButton<bool>(
                style: ButtonStyle(
                  backgroundColor: const WidgetStatePropertyAll(
                    Colors.transparent,
                  ),
                  shape: const WidgetStatePropertyAll(burstButtonShape),
                  foregroundColor: WidgetStateProperty.resolveWith(
                    (states) => states.contains(WidgetState.selected)
                        ? burstAccent(context)
                        : Colors.white70,
                  ),
                  side: WidgetStateProperty.resolveWith(
                    (states) => BorderSide(
                      color: states.contains(WidgetState.selected)
                          ? burstAccent(context)
                          : const Color(0xff414141),
                    ),
                  ),
                ),
                segments: const [
                  ButtonSegment(
                    value: false,
                    icon: Icon(Icons.monetization_on_outlined, size: 18),
                    label: Text('Token Burst'),
                  ),
                  ButtonSegment(
                    value: true,
                    icon: Icon(Icons.photo_outlined, size: 18),
                    label: Text('NFT Burst'),
                  ),
                ],
                selected: {_nft},
                onSelectionChanged: _busy || _preparedPayload != null
                    ? null
                    : (value) {
                        setState(() {
                          _nft = value.first;
                          _error = null;
                        });
                        if (_nft) _loadNfts();
                      },
              ),
              const SizedBox(height: 24),
              _labeledField(
                controller: _title,
                label: 'Burst name',
                hintText: 'e.g. Genesis Liquidity Drop',
              ),
              const SizedBox(height: 16),
              _labeledField(
                controller: _description,
                label: 'Description',
                hintText: 'Describe this distribution event...',
                maxLines: 3,
              ),
              const SizedBox(height: 16),
              if (!_nft) ...[
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Select Asset',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 8),
                    DropdownButtonFormField<Token>(
                      initialValue: currentToken,
                      dropdownColor: const Color(0xff222222),
                      style: const TextStyle(color: Colors.white),
                      decoration: InputDecoration(
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: const BorderSide(
                            color: Color(0xff333333),
                          ),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: const BorderSide(
                            color: Color(0xff333333),
                          ),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: BorderSide(
                            color: burstAccent(context),
                            width: 1.5,
                          ),
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 14,
                        ),
                      ),
                      items: tokens
                          .map(
                            (token) => DropdownMenuItem(
                              value: token,
                              child: Text(token.symbol),
                            ),
                          )
                          .toList(),
                      onChanged: _busy || _preparedPayload != null
                          ? null
                          : (value) => setState(() => _token = value),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: _labeledField(
                        controller: _amount,
                        label: 'Distribution amount',
                        hintText: '0.0',
                        number: true,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _labeledField(
                        controller: _participants,
                        label: 'Maximum participants',
                        hintText: '500',
                        number: true,
                      ),
                    ),
                  ],
                ),
              ] else ...[
                const Text(
                  'Select one NFT allocation per participant',
                  style: TextStyle(color: Colors.white70),
                ),
                OutlinedButton(
                  onPressed: _busy || _preparedPayload != null
                      ? null
                      : _openNftGallery,
                  child: const Text('Select NFTs'),
                ),
                if (_allocations.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  Text(
                    '${_allocations.length} allocations selected',
                    style: const TextStyle(color: Colors.white),
                  ),
                  ..._allocations.asMap().entries.map(
                    (entry) => ListTile(
                      dense: true,
                      title: Text(
                        '${entry.value.asset.name} #${entry.value.asset.tokenId}',
                        style: const TextStyle(color: Colors.white70),
                      ),
                      subtitle: entry.value.asset.isErc1155
                          ? Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                IconButton(
                                  tooltip: 'Decrease quantity',
                                  onPressed: _busy || _preparedPayload != null
                                      ? null
                                      : () => _changeQuantity(entry.key, -1),
                                  icon: const Icon(
                                    Icons.remove,
                                    color: Colors.white70,
                                  ),
                                ),
                                Text(
                                  '${entry.value.quantity}',
                                  style: const TextStyle(color: Colors.white),
                                ),
                                IconButton(
                                  tooltip: 'Increase quantity',
                                  onPressed: _busy || _preparedPayload != null
                                      ? null
                                      : () => _changeQuantity(entry.key, 1),
                                  icon: const Icon(
                                    Icons.add,
                                    color: Colors.white70,
                                  ),
                                ),
                              ],
                            )
                          : null,
                      trailing: IconButton(
                        icon: const Icon(Icons.close, color: Colors.white70),
                        onPressed: _busy || _preparedPayload != null
                            ? null
                            : () => setState(
                                () => _allocations.removeAt(entry.key),
                              ),
                      ),
                    ),
                  ),
                ],
              ],
              if (_nft) ...[
                const SizedBox(height: 16),
                _labeledField(
                  controller: _participants,
                  label: 'Maximum participants',
                  hintText: '500',
                  number: true,
                ),
              ],
              const SizedBox(height: 24),
              // Live Summary Card (Figma Node #5888:9293 & #5888:9393)
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 16,
                ),
                decoration: BoxDecoration(
                  color: const Color(0xff141414),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xff333333)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Flexible(
                          child: Text(
                            _nft ? 'Total NFTs to Distribute' : 'Total Tokens',
                            style: const TextStyle(
                              color: Color(0xff888888),
                              fontSize: 15,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Flexible(
                          child: Text(
                            _nft
                                ? '${_allocations.fold<int>(0, (sum, a) => sum + a.quantity)} NFTs'
                                : (_amount.text.trim().isEmpty
                                      ? '--'
                                      : '${_amount.text.trim()} ${currentToken.symbol}'),
                            textAlign: TextAlign.end,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 18,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Flexible(
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Flexible(
                                child: Text(
                                  'Reward per User',
                                  style: TextStyle(
                                    color: Color(0xff888888),
                                    fontSize: 15,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              SizedBox(width: 4),
                              Icon(
                                Icons.info_outline,
                                size: 14,
                                color: Color(0xff888888),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                        Flexible(
                          child: Text(
                            _nft
                                ? (_participants.text.isEmpty ? '--' : '1 NFT')
                                : (perParticipant == null
                                      ? '--'
                                      : burstAssetAmount(
                                          perParticipant.toString(),
                                          currentToken.decimals,
                                          currentToken.symbol,
                                        )),
                            textAlign: TextAlign.end,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 18,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                    if (!_nft &&
                        _amount.text.isNotEmpty &&
                        _participants.text.isNotEmpty &&
                        perParticipant == null)
                      const Padding(
                        padding: EdgeInsets.only(top: 8),
                        child: Text(
                          'The amount must divide evenly across participants.',
                          style: TextStyle(
                            color: Color(0xffff8b91),
                            fontSize: 13,
                          ),
                        ),
                      ),
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 16),
                      child: Divider(color: Color(0xff333333), height: 1),
                    ),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Image.asset(
                          'assets/burst/create_icon.png',
                          width: 14,
                          height: 16,
                          color: burstAccent(context),
                          colorBlendMode: BlendMode.srcIn,
                          excludeFromSemantics: true,
                        ),
                        const SizedBox(width: 10),
                        const Expanded(
                          child: Text(
                            'These assets will be locked in the smart contract until the burst is triggered or canceled.',
                            style: TextStyle(
                              color: Color(0xff888888),
                              fontSize: 13,
                              height: 1.35,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              if (_error != null)
                Padding(
                  padding: const EdgeInsets.only(top: 20),
                  child: Text(
                    _error!,
                    style: const TextStyle(color: Color(0xffff8b91)),
                  ),
                ),
              if (_revisionConflict)
                TextButton(
                  onPressed: _busy
                      ? null
                      : () {
                          setState(() => _allowLeave = true);
                          WidgetsBinding.instance.addPostFrameCallback((_) {
                            if (mounted) Navigator.of(context).pop();
                          });
                        },
                  child: const Text('Close and refresh'),
                ),
              const SizedBox(height: 28),
              FilledButton(
                onPressed: _busy || _revisionConflict ? null : _prepare,
                style: FilledButton.styleFrom(
                  shape: burstButtonShape,
                  backgroundColor: burstAccent(context),
                  foregroundColor: burstOnAccent(context),
                  minimumSize: const Size.fromHeight(56),
                ),
                child: Text(_busy ? 'Preparing…' : 'Review Burst'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _labeledField({
    required TextEditingController controller,
    required String label,
    String? hintText,
    bool number = false,
    int maxLines = 1,
  }) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(
        label,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 14,
          fontWeight: FontWeight.w500,
        ),
      ),
      const SizedBox(height: 8),
      TextField(
        key: ValueKey(label),
        controller: controller,
        enabled: !_busy && _preparedPayload == null,
        maxLines: maxLines,
        keyboardType: number
            ? const TextInputType.numberWithOptions(decimal: true)
            : TextInputType.text,
        style: const TextStyle(color: Colors.white),
        decoration: InputDecoration(
          hintText: hintText,
          hintStyle: const TextStyle(color: Color(0xff888888), fontSize: 15),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: const BorderSide(color: Color(0xff333333)),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: const BorderSide(color: Color(0xff333333)),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: BorderSide(color: burstAccent(context), width: 1.5),
          ),
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 14,
          ),
        ),
      ),
    ],
  );
}
