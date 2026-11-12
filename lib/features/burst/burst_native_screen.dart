import 'package:flutter/material.dart';

import 'burst_theme.dart';
import 'package:http/http.dart' as http;
import 'package:provider/provider.dart';
import 'package:web3dart/web3dart.dart';

import '../../config/app_environment.dart';
import '../../models/chain.dart';
import '../../services/blockchain_service.dart';
import '../../services/http_client_service.dart';
import '../../services/wallet_service.dart';
import '../../utils/sensitive_access_guard.dart';
import '../mini_apps/burst_account_session.dart';
import '../mini_apps/burst_sign_in.dart';
import 'burst_api_client.dart';
import 'burst_campaign_screen.dart';
import 'burst_create_screen.dart';
import 'burst_draft_recovery.dart';
import 'burst_draft_store.dart';
import 'burst_execution_plan.dart';
import 'burst_history_screen.dart';
import 'burst_home_components.dart';
import 'burst_join_screen.dart';
import 'burst_native_session.dart';
import 'burst_network_fee.dart';
import 'burst_prepared_campaign.dart';
import 'burst_review_screen.dart';
import 'burst_transaction_executor.dart';

/// Native Burst entry point. Account credentials and signing stay in Owllet.
class BurstNativeScreen extends StatefulWidget {
  const BurstNativeScreen({super.key, this.networksLoader});

  /// Optional network discovery source, useful for embedding and testing.
  final Future<Map<String, dynamic>> Function()? networksLoader;

  @override
  State<BurstNativeScreen> createState() => _BurstNativeScreenState();
}

class _BurstNativeScreenState extends State<BurstNativeScreen> {
  final _wallet = WalletService();
  final _drafts = BurstDraftStore();
  BurstNativeSession? _session;
  BurstApiClient? _api;
  List<dynamic> _campaigns = const [];
  List<dynamic> _participations = const [];
  String? _address;
  Map<String, dynamic>? _config;
  BurstSignInIdentity? _openedIdentity;
  bool _hasDraft = false;
  bool _recoveryOnly = false;
  String? _error;
  bool _loading = false;
  List<Map<String, dynamic>>? _availableNetworks;
  final _feeQuotes = <String, BurstNetworkFee>{};

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _open());
  }

  @override
  void dispose() {
    _session?.close(retainForReuse: true);
    super.dispose();
  }

  Future<BurstSignInIdentity> _identity() async {
    if (!mounted) throw StateError('Burst was closed.');
    final blockchain = context.read<BlockchainService>();
    final network = blockchain.activeNetworkKey;
    final address = await _wallet.getWalletAddressForFamily(ChainFamily.evm);
    if (!network.startsWith('evm:') || address == null || address.isEmpty) {
      throw StateError('Select an EVM wallet and network to use Burst.');
    }
    return BurstSignInIdentity(
      address: address,
      networkKey: network,
      origin: 'native',
      profileId: '',
    );
  }

  Future<bool> _confirm(String message, String address) async {
    if (!mounted) return false;
    return await showDialog<bool>(
          context: context,
          builder: (dialog) => AlertDialog(
            title: const Text('Use this wallet for Burst'),
            content: Text(
              'Confirm that $address belongs to you. This signature does not send a transaction or cost gas.',
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
  }

  Future<void> _open() async {
    if (_loading || !mounted) return;
    setState(() {
      _loading = true;
      _error = null;
      _availableNetworks = null;
    });
    try {
      if (_api == null) {
        final blockchain = context.read<BlockchainService>();
        final currentNetwork = blockchain.activeNetworkKey;
        final publicApi = BurstApiClient(
          api: AppEnvironment.api,
          client: HttpClientService().client,
          authorize: (_) => throw StateError('Authentication is not needed.'),
        );
        try {
          final response =
              await (widget.networksLoader?.call() ?? publicApi.networks());
          final rawNetworks = response['supportedChains'];
          if (rawNetworks is! List) {
            throw StateError('Unable to load Burst networks.');
          }
          final networks = rawNetworks
              .whereType<Map<String, dynamic>>()
              .toList();
          if (!networks.any((item) => item['networkKey'] == currentNetwork)) {
            if (mounted) setState(() => _availableNetworks = networks);
            return;
          }
        } on BurstApiException catch (error) {
          // Let the existing draft recovery path run during a temporary pause.
          if (error.statusCode != 503 || !currentNetwork.startsWith('evm:')) {
            rethrow;
          }
        }
      }
      if (_api != null) {
        if (_recoveryOnly) {
          final identity = _openedIdentity;
          final chainId = identity == null
              ? null
              : int.tryParse(identity.networkKey.substring(4));
          if (chainId == null) throw StateError('Select a supported network.');
          try {
            final config = await _api!.config(chainId);
            if (config['enabled'] != true) return;
            _config = config;
            _recoveryOnly = false;
          } on BurstApiException catch (error) {
            if (error.statusCode == 503) return;
            rethrow;
          }
        }
        final campaigns = await _api!.campaigns();
        final joined = await _api!.participations();
        if (campaigns['campaigns'] is! List) {
          throw StateError('Unable to load your Bursts.');
        }
        if (joined['campaigns'] is! List) {
          throw StateError('Unable to load joined Bursts.');
        }
        if (mounted) {
          final identity = _openedIdentity;
          final chainId = identity == null
              ? null
              : int.tryParse(identity.networkKey.substring(4));
          final saved = identity == null || chainId == null
              ? null
              : await readRecoverableBurstDraft(
                  api: _api!,
                  store: _drafts,
                  profileId: identity.profileId,
                  wallet: identity.address,
                  chainId: chainId,
                );
          if (!mounted) return;
          setState(() {
            _hasDraft = saved != null;
            _campaigns = campaigns['campaigns'] as List;
            _participations = joined['campaigns'] as List;
          });
        }
        return;
      }
      final identity = await _identity();
      final chainId = int.tryParse(identity.networkKey.substring(4));
      if (chainId == null) throw StateError('Select a supported network.');
      final session = BurstNativeSession(
        client: HttpClientService().client,
        api: AppEnvironment.api,
        readAccountToken: () async => null,
        readIdentity: _identity,
        confirm: _confirm,
        authenticate: () async =>
            mounted &&
            await SensitiveAccessGuard.verify(
              context,
              reason: 'Confirm your wallet for Burst',
            ),
        signMessage: _wallet.signMessageForAddress,
      );
      _session = session;
      final api = await session.open();
      final savedDraft = await readRecoverableBurstDraft(
        api: api,
        store: _drafts,
        profileId: identity.profileId,
        wallet: identity.address,
        chainId: chainId,
      );
      Map<String, dynamic> config;
      var recoveryOnly = false;
      try {
        config = await api.config(chainId);
      } on BurstApiException catch (error) {
        if (error.statusCode != 503 || savedDraft?['prepared'] is! Map) rethrow;
        config = await api.config(chainId, recovery: true);
        recoveryOnly = true;
      }
      if (config['enabled'] != true) {
        throw StateError('Burst is unavailable on this network.');
      }
      final campaigns = recoveryOnly
          ? {'campaigns': <dynamic>[]}
          : await api.campaigns();
      final joined = recoveryOnly
          ? {'campaigns': <dynamic>[]}
          : await api.participations();
      if (campaigns['campaigns'] is! List) {
        throw StateError('Unable to load your Bursts.');
      }
      if (joined['campaigns'] is! List) {
        throw StateError('Unable to load joined Bursts.');
      }
      if (!mounted) {
        await session.close();
        return;
      }
      setState(() {
        _api = api;
        _address = identity.address;
        _openedIdentity = identity;
        _config = config;
        _recoveryOnly = recoveryOnly;
        _hasDraft = savedDraft != null;
        _campaigns = campaigns['campaigns'] as List;
        _participations = joined['campaigns'] as List;
      });
    } catch (error) {
      if (_api == null ||
          error is BurstApiException &&
              (error.statusCode == 401 ||
                  {
                    'CONTEXT_CHANGED',
                    'BURST_CONNECTION_EXPIRED',
                    'BURST_CONNECTION_REQUIRED',
                    'CONNECTION_REQUIRED',
                    'ACCOUNT_REQUIRED',
                  }.contains(error.code)) ||
          error is BurstConnectionFailure &&
              {
                'CONTEXT_CHANGED',
                'BURST_CONNECTION_EXPIRED',
                'BURST_CONNECTION_REQUIRED',
                'CONNECTION_REQUIRED',
                'ACCOUNT_REQUIRED',
              }.contains(error.code)) {
        await _session?.close();
        _session = null;
        _api = null;
      }
      if (mounted) {
        setState(
          () => _error = error.toString().replaceFirst('Bad state: ', ''),
        );
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<bool> _approveTransaction(BurstExecutionPlan plan) async {
    if (!mounted) return false;
    final chain = context.read<BlockchainService>().activeChain;
    if (chain.chainId != plan.chainId) {
      throw StateError('The selected network changed.');
    }
    final rpc = Web3Client(chain.rpcUrl, http.Client());
    late final BurstNetworkFee fee;
    try {
      fee = await BurstNetworkFee.estimate(rpc, plan);
    } finally {
      rpc.dispose();
    }
    if (!mounted) return false;
    final accepted =
        await showDialog<bool>(
          context: context,
          builder: (dialog) => AlertDialog(
            title: const Text('Review Burst transaction'),
            content: SelectableText(
              'Action: ${plan.operation}\nNetwork: ${chain.name}\nTo: ${plan.to}\nValue: ${burstNativeAmount(plan.value.toString(), chain.symbol)}\nMaximum network fee: ${burstNativeAmount(fee.maximumFeeWei.toString(), chain.symbol)}${plan.approvalDescription == null ? '' : '\n\n${plan.approvalDescription}'}\n\nNetwork fees are paid by this wallet.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialog, false),
                child: const Text('Cancel'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(dialog, true),
                child: const Text('Approve'),
              ),
            ],
          ),
        ) ??
        false;
    if (!accepted || !mounted) return false;
    final authenticated = await SensitiveAccessGuard.verify(
      context,
      reason: 'Approve this Burst transaction',
    );
    if (authenticated) _feeQuotes[plan.reference] = fee;
    return authenticated;
  }

  Future<BigInt> _estimateReviewFee(
    Map<String, dynamic> prepared,
    BurstSignInIdentity identity,
  ) async {
    if (!identity.matches(await _identity()) || !mounted) {
      throw StateError('The wallet or network changed.');
    }
    final chain = context.read<BlockchainService>().activeChain;
    final rpc = Web3Client(chain.rpcUrl, http.Client());
    try {
      final transactions = prepared['transactions'];
      if (transactions is! List || transactions.isEmpty) {
        throw const FormatException('The transaction list is unavailable.');
      }
      var total = BigInt.zero;
      for (final item in transactions) {
        final transaction = Map<String, dynamic>.from(item as Map);
        final plan = BurstExecutionPlan.parse(
          {
            'walletAddress': identity.address,
            'campaignId': (prepared['campaign'] as Map)['id'],
            'transaction': transaction,
          },
          reference: transaction['reference'] as String,
          wallet: identity.address,
          chainId: chain.chainId,
        );
        final fee = await BurstNetworkFee.estimate(rpc, plan);
        total += fee.maximumFeeWei;
      }
      return total;
    } finally {
      rpc.dispose();
    }
  }

  BurstTransactionExecutor _executor(
    BurstApiClient api,
    BurstSignInIdentity identity,
  ) {
    final blockchain = context.read<BlockchainService>();
    final chain = blockchain.activeChain;
    return BurstTransactionExecutor(
      api: api,
      journal: BurstPreferencesJournal(),
      wallet: identity.address,
      chainId: chain.chainId,
      allowNewTransactions: !_recoveryOnly,
      isCurrent: () async => mounted && identity.matches(await _identity()),
      approve: _approveTransaction,
      beginSubmission: (plan) => api.beginExecution(plan.reference),
      verifyBroadcast: (plan, hash) async {
        final rpc = Web3Client(chain.rpcUrl, http.Client());
        try {
          return await BurstNetworkFee.matchesTransaction(rpc, plan, hash);
        } finally {
          rpc.dispose();
        }
      },
      broadcast: (plan) {
        final fee = _feeQuotes.remove(plan.reference);
        if (fee == null) {
          throw StateError('The network fee must be reviewed again.');
        }
        return _wallet.sendRawTransactionRequest(
          rpcUrl: chain.rpcUrl,
          chainId: plan.chainId,
          expectedFromAddress: identity.address,
          toAddress: plan.to,
          valueInWei: plan.value,
          dataHex: plan.data,
          gasLimit: fee.gasLimit,
          gasPriceWei: fee.gasPriceWei,
        );
      },
    );
  }

  Future<bool> _canEditPrepared(Map<String, dynamic> prepared) async {
    final api = _api;
    if (api == null) return false;
    final transactions = prepared['transactions'];
    if (transactions is! List || transactions.isEmpty) return false;
    final journal = BurstPreferencesJournal();
    for (final transaction in transactions) {
      if (transaction is! Map ||
          transaction['reference'] is! String ||
          await journal.read(transaction['reference'] as String) != null) {
        return false;
      }
    }
    try {
      final draft = await api.draft(
        (prepared['campaign'] as Map)['id'] as String,
      );
      return draft['editable'] == true;
    } catch (_) {
      return false;
    }
  }

  Future<void> _startBurst({Map<String, dynamic>? initialDraft}) async {
    final api = _api;
    final identity = _openedIdentity;
    final config = _config;
    if (api == null || identity == null || config == null) return;
    final chain = context.read<BlockchainService>().activeChain;
    final executor = _executor(api, identity);
    final viewCampaign = await Navigator.of(context).push<Map<String, dynamic>>(
      BurstPageRoute<Map<String, dynamic>>(
        builder: (_) => BurstCreateScreen(
          api: api,
          wallet: identity.address,
          config: config,
          profileId: identity.profileId,
          store: _drafts,
          initialDraft: initialDraft,
          canEditPrepared: _canEditPrepared,
          onPrepared: (prepared) async {
            if (!mounted) return;
            final completed = await showModalBottomSheet<bool>(
              context: context,
              isScrollControlled: true,
              backgroundColor: Colors.transparent,
              builder: (_) => BurstReviewSheet(
                prepared: prepared,
                loadNetworkFee: () => _estimateReviewFee(prepared, identity),
                executor: executor,
                nativeSymbol: chain.symbol,
                chainName: chain.name,
                allowEdit: true,
                onCompleted: () async {
                  await _drafts.clear(
                    identity.profileId,
                    identity.address,
                    chain.chainId,
                  );
                  if (mounted) setState(() => _hasDraft = false);
                },
              ),
            );
            if (completed == true && mounted) {
              await _drafts.clear(
                identity.profileId,
                identity.address,
                chain.chainId,
              );
              if (!mounted) return;
              setState(() => _hasDraft = false);
              final viewCampaign = await Navigator.of(context).push<bool>(
                BurstPageRoute(
                  builder: (_) => BurstCreatedSuccessScreen(
                    campaign: Map<String, dynamic>.from(
                      prepared['campaign'] as Map,
                    ),
                    joinCode: prepared['joinCode'] as String? ?? '',
                    nativeSymbol: chain.symbol,
                    chainName: chain.name,
                    onViewBurst: () => Navigator.of(context).pop(true),
                  ),
                ),
              );
              if (mounted) {
                Navigator.of(context).pop(
                  viewCampaign == true
                      ? Map<String, dynamic>.from(prepared['campaign'] as Map)
                      : null,
                );
              }
            } else if (completed == false && mounted) {
              await _drafts.clear(
                identity.profileId,
                identity.address,
                chain.chainId,
              );
              if (mounted) {
                setState(() => _hasDraft = false);
                Navigator.of(context).pop(null);
              }
            } else if (mounted) {
              setState(() => _hasDraft = true);
            }
          },
        ),
      ),
    );
    final saved = await _drafts.read(
      identity.profileId,
      identity.address,
      chain.chainId,
    );
    if (mounted) {
      setState(() => _hasDraft = saved != null);
      await _open();
      if (mounted && viewCampaign != null) {
        await _openCampaign(viewCampaign);
        if (mounted) await _open();
      }
    }
  }

  Future<void> _resumeBurst({String? campaignId}) async {
    final api = _api;
    final identity = _openedIdentity;
    if (api == null || identity == null) return;
    final chain = context.read<BlockchainService>().activeChain;
    try {
      var saved = await readRecoverableBurstDraft(
        api: api,
        store: _drafts,
        profileId: identity.profileId,
        wallet: identity.address,
        chainId: chain.chainId,
      );
      if (campaignId != null) {
        final existingPrepared = saved?['prepared'];
        final existingCampaign = existingPrepared is Map
            ? existingPrepared['campaign']
            : null;
        final existingId = existingCampaign is Map
            ? existingCampaign['id']
            : null;
        if (saved != null && existingId != campaignId) {
          throw StateError(
            'Finish or delete your existing pending Burst before editing another.',
          );
        }
        if (saved == null) {
          final response = await api.draft(campaignId);
          saved = {
            'request': response['request'],
            'prepared': response['prepared'],
          };
        }
      }
      if (saved == null) {
        if (mounted) setState(() => _hasDraft = false);
        return;
      }
      if (saved['pendingUpdate'] is Map) {
        if (!mounted) return;
        await _startBurst(initialDraft: saved);
        return;
      }
      final request = Map<String, dynamic>.from(saved['request'] as Map);
      final Map<String, dynamic> prepared;
      try {
        prepared = await recoverBurstDraft(
          saved: saved,
          api: api,
          store: _drafts,
          profileId: identity.profileId,
          wallet: identity.address,
          chainId: chain.chainId,
        );
      } on BurstApiException catch (error) {
        if (saved['prepared'] is! Map && error.statusCode == 400 && mounted) {
          setState(() => _hasDraft = false);
        }
        rethrow;
      }
      BurstPreparedCampaign.parse(
        prepared,
        request,
        factoryAddress: _config?['factoryAddress']?.toString() ?? '',
        wallet: identity.address,
        proxyInitCodeHash: _config?['proxyInitCodeHash']?.toString(),
      );
      if (!_recoveryOnly && await _canEditPrepared(prepared)) {
        final current = await api.draft(
          (prepared['campaign'] as Map)['id'] as String,
        );
        final next = <String, dynamic>{
          'request': current['request'],
          'prepared': current['prepared'],
        };
        if (current['editable'] != true) {
          throw StateError(
            'Submission has started. Reopen this Burst to recover it.',
          );
        }
        BurstPreparedCampaign.parse(
          Map<String, dynamic>.from(next['prepared'] as Map),
          Map<String, dynamic>.from(next['request'] as Map),
          factoryAddress: _config?['factoryAddress']?.toString() ?? '',
          wallet: identity.address,
          proxyInitCodeHash: _config?['proxyInitCodeHash']?.toString(),
        );
        await _drafts.write(
          identity.profileId,
          identity.address,
          chain.chainId,
          next,
        );
        if (!mounted) return;
        await _startBurst(initialDraft: next);
        return;
      }
      await _drafts.write(identity.profileId, identity.address, chain.chainId, {
        'request': request,
        'prepared': prepared,
      });
      if (!mounted) return;
      final completed = await showModalBottomSheet<bool>(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (_) => BurstReviewSheet(
          prepared: prepared,
          loadNetworkFee: () => _estimateReviewFee(prepared, identity),
          executor: _executor(api, identity),
          nativeSymbol: chain.symbol,
          chainName: chain.name,
          onCompleted: () async {
            await _drafts.clear(
              identity.profileId,
              identity.address,
              chain.chainId,
            );
            if (mounted) setState(() => _hasDraft = false);
          },
        ),
      );
      if (completed != null) {
        await _drafts.clear(
          identity.profileId,
          identity.address,
          chain.chainId,
        );
        if (!mounted) return;
        setState(() => _hasDraft = false);
      }
      if (!mounted) return;
      if (completed == true) {
        final viewCampaign = await Navigator.of(context).push<bool>(
          BurstPageRoute(
            builder: (_) => BurstCreatedSuccessScreen(
              campaign: Map<String, dynamic>.from(prepared['campaign'] as Map),
              joinCode: prepared['joinCode'] as String? ?? '',
              nativeSymbol: chain.symbol,
              chainName: chain.name,
              onViewBurst: () => Navigator.of(context).pop(true),
            ),
          ),
        );
        if (mounted) await _open();
        if (mounted && viewCampaign == true) {
          await _openCampaign(
            Map<String, dynamic>.from(prepared['campaign'] as Map),
          );
          if (mounted) await _open();
        }
      } else if (mounted) {
        await _open();
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
    }
  }

  Future<void> _openCampaign(Map<String, dynamic> campaign) async {
    final api = _api;
    final identity = _openedIdentity;
    final id = campaign['id'];
    if (api == null || identity == null || id is! String) return;
    final host = campaign['hostWalletAddress'];
    final chain = campaign['chainId'];
    final selectedChain = context.read<BlockchainService>().activeChain.chainId;
    if (host is! String || chain is! int) {
      setState(
        () => _error = 'Unable to verify this Burst’s wallet and network.',
      );
      return;
    }
    if (host.toLowerCase() != identity.address.toLowerCase() ||
        chain != selectedChain) {
      final view = await showDialog<bool>(
        context: context,
        builder: (dialog) => AlertDialog(
          title: const Text('Switch wallet or network'),
          content: Text(
            'To manage this Burst, select its creator wallet and network in Owllet. You can still view it now.\n\nWallet: $host\nNetwork ID: $chain',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialog, false),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(dialog, true),
              child: const Text('View Burst'),
            ),
          ],
        ),
      );
      if (view != true || !mounted) return;
    } else if (campaign['status'] == 'draft' ||
        campaign['status'] == 'pending_chain') {
      await _resumeBurst(campaignId: id);
      return;
    }
    await Navigator.of(context).push(
      BurstPageRoute<void>(
        builder: (_) => BurstCampaignScreen(
          api: api,
          executor: _executor(api, identity),
          campaignId: id,
          wallet: identity.address,
          chainId: selectedChain,
        ),
      ),
    );
  }

  Future<void> _confirmDeleteDraft(String id) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: const Color(0xff141414),
        title: const Text('Delete draft?'),
        content: const Text(
          'This draft Burst will be removed. This cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Keep'),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    final api = _api;
    if (api == null) return;
    try {
      await api.deleteCampaign(id);
      final identity = _openedIdentity;
      final chainId = identity == null
          ? null
          : int.tryParse(identity.networkKey.substring(4));
      if (identity != null && chainId != null) {
        await _drafts.clearCampaign(
          identity.profileId,
          identity.address,
          chainId,
          id,
        );
        final saved = await _drafts.read(
          identity.profileId,
          identity.address,
          chainId,
        );
        if (mounted) setState(() => _hasDraft = saved != null);
      }
      if (!mounted) return;
      await _open();
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not delete the draft: $error')),
      );
    }
  }

  Future<void> _openListedCampaign(Map<String, dynamic> campaign) async {
    if (campaign['_isParticipation'] != true) {
      await _openCampaign(campaign);
      return;
    }
    final api = _api;
    final id = campaign['id'];
    if (api == null || id is! String) return;
    await Navigator.of(context).push(
      BurstPageRoute<void>(
        builder: (_) => BurstWaitingScreen(
          api: api,
          campaignId: id,
          title: campaign['title']?.toString() ?? 'Burst',
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final api = _api;
    final visibleCampaigns =
        [
          for (final item in _campaigns.whereType<Map>())
            {...Map<String, dynamic>.from(item), '_isParticipation': false},
          for (final item in _participations.whereType<Map>())
            {...Map<String, dynamic>.from(item), '_isParticipation': true},
        ]..sort(
          (a, b) => (b['createdAt']?.toString() ?? '').compareTo(
            a['createdAt']?.toString() ?? '',
          ),
        );
    return Scaffold(
      backgroundColor: const Color(0xff0a0a0a),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        foregroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        title: const Text('Burst'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SafeArea(
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : _availableNetworks != null
            ? Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: SingleChildScrollView(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          'Burst is coming soon to ${context.watch<BlockchainService>().activeNetworkName}.',
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 20),
                        const Text('Available networks'),
                        for (final network in _availableNetworks!)
                          if (network['chainId'] is int &&
                              network['name'] is String)
                            TextButton(
                              onPressed:
                                  !context
                                      .read<BlockchainService>()
                                      .allChains
                                      .any(
                                        (chain) =>
                                            chain.chainId == network['chainId'],
                                      )
                                  ? null
                                  : () {
                                      final blockchain = context
                                          .read<BlockchainService>();
                                      final matches = blockchain.allChains
                                          .where(
                                            (chain) =>
                                                chain.chainId ==
                                                network['chainId'],
                                          );
                                      if (matches.isNotEmpty) {
                                        blockchain.setActiveChain(
                                          matches.first,
                                        );
                                        _open();
                                      }
                                    },
                              child: Text(network['name'] as String),
                            ),
                      ],
                    ),
                  ),
                ),
              )
            : _error != null
            ? Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        _error!,
                        textAlign: TextAlign.center,
                        style: const TextStyle(color: Colors.white70),
                      ),
                      const SizedBox(height: 20),
                      FilledButton(
                        onPressed: _open,
                        child: const Text('Try again'),
                      ),
                    ],
                  ),
                ),
              )
            : api == null
            ? const SizedBox()
            : _recoveryOnly
            ? Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        _hasDraft
                            ? 'Burst is temporarily unavailable. You can resume your pending transaction.'
                            : 'Burst is temporarily unavailable.',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: Colors.white70),
                      ),
                      const SizedBox(height: 20),
                      if (_hasDraft)
                        FilledButton(
                          onPressed: _resumeBurst,
                          child: const Text('Resume pending Burst'),
                        ),
                      TextButton(
                        onPressed: _open,
                        child: const Text('Refresh'),
                      ),
                    ],
                  ),
                ),
              )
            : RefreshIndicator(
                onRefresh: _open,
                child: ListView(
                  padding: const EdgeInsets.all(24),
                  children: [
                    const BurstHomeHero(),
                    if (_hasDraft)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 20),
                        child: OutlinedButton(
                          onPressed: _resumeBurst,
                          child: const Text('Resume pending Burst'),
                        ),
                      ),
                    Row(
                      children: [
                        Expanded(
                          child: BurstHomeAction(
                            iconAsset: 'assets/burst/create_icon.png',
                            title: 'Start Burst',
                            subtitle: 'Start a new Burst',
                            onTap: _startBurst,
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: BurstHomeAction(
                            iconAsset: 'assets/burst/join_icon.png',
                            title: 'Join Burst',
                            subtitle: 'Enter code to join',
                            onTap: () async {
                              await Navigator.of(context).push(
                                BurstPageRoute<void>(
                                  builder: (_) => BurstJoinScreen(
                                    api: api,
                                    walletAddress: _address!,
                                    chainId: int.parse(
                                      _openedIdentity!.networkKey.substring(4),
                                    ),
                                  ),
                                ),
                              );
                              if (mounted) await _open();
                            },
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 36),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'My Burst',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        TextButton(
                          onPressed: () async {
                            await Navigator.of(context).push(
                              BurstPageRoute<void>(
                                builder: (_) => BurstHistoryScreen(
                                  api: api,
                                  initialCampaigns: visibleCampaigns,
                                  includeParticipations: true,
                                  openCampaign: _openListedCampaign,
                                ),
                              ),
                            );
                            if (mounted) await _open();
                          },
                          child: const Text('See all'),
                        ),
                      ],
                    ),
                    if (visibleCampaigns.isEmpty)
                      const Padding(
                        padding: EdgeInsets.only(top: 20),
                        child: Text(
                          'No Bursts yet.',
                          style: TextStyle(color: Colors.white70),
                        ),
                      )
                    else
                      SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: visibleCampaigns
                              .take(3)
                              .map(
                                (campaign) => Padding(
                                  padding: const EdgeInsets.only(right: 12),
                                  child: BurstHomeCampaignCard(
                                    campaign: Map<String, dynamic>.from(
                                      campaign,
                                    ),
                                    onDelete:
                                        campaign['_isParticipation'] != true &&
                                            campaign['status']?.toString() ==
                                                'draft' &&
                                            campaign['id'] is String
                                        ? () => _confirmDeleteDraft(
                                            campaign['id'] as String,
                                          )
                                        : null,
                                    onTap: campaign['id'] is! String
                                        ? null
                                        : () async {
                                            await _openListedCampaign(
                                              Map<String, dynamic>.from(
                                                campaign,
                                              ),
                                            );
                                            if (mounted) await _open();
                                          },
                                  ),
                                ),
                              )
                              .toList(),
                        ),
                      ),
                  ],
                ),
              ),
      ),
    );
  }
}
