import 'dart:convert';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:web3dart/web3dart.dart';

import '../../config/app_environment.dart';
import '../../constants/app_colors.dart';
import '../../l10n/app_localizations.dart';
import '../../models/chain.dart';
import '../../services/blockchain_service.dart';
import '../../services/etherscan_v2_service.dart';
import '../../services/http_client_service.dart';
import '../../services/wallet_history_service.dart';
import '../../services/wallet_service.dart';
import '../../utils/in_app_link_router.dart';

class TransactionsScreen extends StatefulWidget {
  const TransactionsScreen({super.key});

  @override
  State<TransactionsScreen> createState() => _TransactionsScreenState();
}

class _HistoryTransactionDetailsSheet extends StatefulWidget {
  const _HistoryTransactionDetailsSheet({
    required this.entry,
    required this.chain,
    required this.explorerUrl,
    required this.walletService,
    required this.titleText,
    required this.messageText,
    required this.amountText,
    required this.timestampText,
    required this.networkText,
    required this.onOpenExplorer,
  });

  final WalletHistoryEntry entry;
  final EvmChain? chain;
  final String? explorerUrl;
  final WalletService walletService;
  final String titleText;
  final String messageText;
  final String amountText;
  final String timestampText;
  final String networkText;
  final Future<void> Function(String url) onOpenExplorer;

  @override
  State<_HistoryTransactionDetailsSheet> createState() =>
      _HistoryTransactionDetailsSheetState();
}

class _HistoryTransactionDetailsSheetState
    extends State<_HistoryTransactionDetailsSheet> {
  Future<TransactionReceipt?>? _receiptFuture;

  @override
  void initState() {
    super.initState();
    final txHash = widget.entry.txHash?.trim();
    final rpcUrl = widget.chain?.rpcUrl.trim();
    if (txHash != null &&
        txHash.isNotEmpty &&
        rpcUrl != null &&
        rpcUrl.isNotEmpty) {
      _receiptFuture = widget.walletService.getTransactionReceipt(
        txHash: txHash,
        rpcUrl: rpcUrl,
      );
    }
  }

  String _statusLabel(AppLocalizations l, bool? status) {
    if (status == null) {
      return l.pendingLabel;
    }
    return status ? l.confirmedLabel : l.failedLabel;
  }

  String _formatGasPrice(TransactionReceipt receipt) {
    final gasPrice = receipt.effectiveGasPrice;
    if (gasPrice == null) {
      return '-';
    }
    return '${gasPrice.getValueInUnit(EtherUnit.gwei).toStringAsFixed(3)} Gwei';
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final themeText = GoogleFonts.outfit(color: Colors.white);

    return SafeArea(
      top: false,
      child: Container(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.88,
        ),
        decoration: const BoxDecoration(
          color: AppColors.cardDark,
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 12),
            Container(
              width: 44,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.18),
                borderRadius: BorderRadius.circular(999),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 18, 12, 10),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      l.transactionDetails,
                      style: GoogleFonts.outfit(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                      ),
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close, color: Colors.white),
                  ),
                ],
              ),
            ),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.titleText,
                      style: GoogleFonts.outfit(
                        fontSize: 22,
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      widget.messageText,
                      style: GoogleFonts.outfit(
                        fontSize: 14,
                        height: 1.4,
                        color: Colors.white.withValues(alpha: 0.68),
                      ),
                    ),
                    const SizedBox(height: 18),
                    _HistoryDetailSection(
                      children: [
                        _HistoryDetailRow(
                          label: l.network,
                          value: widget.networkText,
                        ),
                        _HistoryDetailRow(
                          label: l.historyTimestampLabel,
                          value: widget.timestampText,
                        ),
                        if (widget.amountText.isNotEmpty)
                          _HistoryDetailRow(
                            label: l.amount,
                            value: widget.amountText,
                          ),
                        if (widget.entry.tokenName?.trim().isNotEmpty == true)
                          _HistoryDetailRow(
                            label: l.tokenLabel,
                            value:
                                '${widget.entry.tokenName} (${widget.entry.tokenSymbol ?? '-'})',
                          ),
                        if (widget.entry.txHash?.trim().isNotEmpty == true)
                          _HistoryDetailRow(
                            label: l.historyTransactionHashLabel,
                            value: widget.entry.txHash!,
                            monospace: true,
                          ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    if (_receiptFuture == null)
                      _HistoryInfoBanner(message: l.historyReceiptUnavailable)
                    else
                      FutureBuilder<TransactionReceipt?>(
                        future: _receiptFuture,
                        builder: (context, snapshot) {
                          if (snapshot.connectionState ==
                              ConnectionState.waiting) {
                            return _HistoryInfoBanner(
                              message: l.historyLoadingReceipt,
                              loading: true,
                            );
                          }
                          if (snapshot.hasError) {
                            return _HistoryInfoBanner(
                              message: l.historyReceiptLoadError,
                            );
                          }
                          final receipt = snapshot.data;
                          if (receipt == null) {
                            return _HistoryInfoBanner(
                              message: l.historyReceiptPending,
                            );
                          }

                          return _HistoryDetailSection(
                            children: [
                              _HistoryDetailRow(
                                label: l.historyStatusLabel,
                                value: _statusLabel(l, receipt.status),
                                valueColor: receipt.status == null
                                    ? Colors.white
                                    : (receipt.status!
                                          ? AppColors.success
                                          : AppColors.accentRed),
                              ),
                              _HistoryDetailRow(
                                label: l.historyBlockNumberLabel,
                                value: receipt.blockNumber.isPending
                                    ? l.pendingLabel
                                    : receipt.blockNumber.blockNum.toString(),
                              ),
                              _HistoryDetailRow(
                                label: l.historyFromLabel,
                                value: receipt.from?.hexEip55 ?? '-',
                                monospace: true,
                              ),
                              _HistoryDetailRow(
                                label: l.historyToLabel,
                                value: receipt.to?.hexEip55 ?? '-',
                                monospace: true,
                              ),
                              if (receipt.gasUsed != null)
                                _HistoryDetailRow(
                                  label: l.historyGasUsedLabel,
                                  value: receipt.gasUsed.toString(),
                                ),
                              _HistoryDetailRow(
                                label: l.historyGasPriceLabel,
                                value: _formatGasPrice(receipt),
                              ),
                              if (receipt.contractAddress != null)
                                _HistoryDetailRow(
                                  label: l.historyContractAddressLabel,
                                  value: receipt.contractAddress!.hexEip55,
                                  monospace: true,
                                ),
                              _HistoryDetailRow(
                                label: l.historyLogCountLabel,
                                value: receipt.logs.length.toString(),
                              ),
                            ],
                          );
                        },
                      ),
                    if (widget.explorerUrl != null &&
                        widget.explorerUrl!.trim().isNotEmpty) ...[
                      const SizedBox(height: 18),
                      GestureDetector(
                        onTap: () => widget.onOpenExplorer(widget.explorerUrl!),
                        child: Container(
                          width: double.infinity,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          decoration: BoxDecoration(
                            gradient: AppColors.primaryGradient,
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Center(
                            child: Text(
                              l.viewOnExplorer,
                              style: themeText.copyWith(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _HistoryDetailSection extends StatelessWidget {
  const _HistoryDetailSection({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: Column(children: children),
    );
  }
}

class _HistoryDetailRow extends StatelessWidget {
  const _HistoryDetailRow({
    required this.label,
    required this.value,
    this.valueColor,
    this.monospace = false,
  });

  final String label;
  final String value;
  final Color? valueColor;
  final bool monospace;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Text(
              label,
              style: GoogleFonts.outfit(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: Colors.white.withValues(alpha: 0.55),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Flexible(
            flex: 2,
            child: SelectableText(
              value,
              style:
                  (monospace ? GoogleFonts.robotoMono() : GoogleFonts.outfit())
                      .copyWith(
                        fontSize: monospace ? 12.5 : 13.5,
                        fontWeight: FontWeight.w500,
                        color: valueColor ?? Colors.white,
                      ),
            ),
          ),
        ],
      ),
    );
  }
}

class _HistoryInfoBanner extends StatelessWidget {
  const _HistoryInfoBanner({required this.message, this.loading = false});

  final String message;
  final bool loading;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: Row(
        children: [
          if (loading)
            const SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: AppColors.accentRed,
              ),
            )
          else
            Icon(
              Icons.receipt_long_rounded,
              color: Colors.white.withValues(alpha: 0.75),
              size: 18,
            ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              message,
              style: GoogleFonts.outfit(
                fontSize: 13,
                height: 1.4,
                color: Colors.white.withValues(alpha: 0.74),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _TransactionsScreenState extends State<TransactionsScreen> {
  final WalletService _walletService = WalletService();
  final WalletHistoryService _walletHistoryService = WalletHistoryService();
  final EtherscanV2Service _etherscanService = EtherscanV2Service(
    HttpClientService(),
  );

  static const List<String> _typeFilters = ['all', 'receive', 'send', 'swap'];

  bool _isLoading = true;
  bool _isPartial = false;
  String? _errorMessage;
  String? _partialMessage;
  List<WalletHistoryEntry> _allHistory = [];
  String _selectedType = 'all';
  int? _selectedChainId;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _fetchHistory();
      }
    });
  }

  Future<void> _fetchHistory() async {
    final blockchain = Provider.of<BlockchainService>(context, listen: false);
    final l = AppLocalizations.of(context);
    try {
      final family = blockchain.activeFamily;
      final String? address;
      if (family == ChainFamily.evm) {
        address = await _walletService.getCurrentWalletAddress();
      } else {
        address = await _walletService.getWalletAddressForFamily(family);
      }
      if (!mounted) return;
      if (address == null || address.trim().isEmpty) {
        setState(() {
          _isLoading = false;
          _errorMessage = l.noActiveWalletFound;
          _allHistory = [];
          _isPartial = false;
          _partialMessage = null;
        });
        return;
      }

      WalletHistoryResponse? response;
      String? fallbackWarning;
      try {
        response = await _walletHistoryService.fetchWalletHistory(
          walletAddress: address,
          limit: 120,
        );
      } catch (_) {
        fallbackWarning = l.walletHistoryFallbackWarning;
      }

      final explorerHistory = await _loadExplorerHistory(
        blockchain: blockchain,
        walletAddress: address,
      );
      final mergedHistory = _mergeHistory(
        preferred: response?.history ?? const [],
        fallback: explorerHistory,
        limit: 120,
      );

      if (response == null && mergedHistory.isEmpty) {
        throw Exception('Unable to load wallet history');
      }

      if (!mounted) return;
      setState(() {
        _allHistory = mergedHistory;
        _isPartial = (response?.partial ?? false) || fallbackWarning != null;
        _partialMessage = _composeHistoryWarning(
          response?.message,
          fallbackWarning,
        );
        _isLoading = false;
        _errorMessage = null;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _errorMessage = l.walletHistoryLoadError;
      });
    }
  }

  Future<List<WalletHistoryEntry>> _loadExplorerHistory({
    required BlockchainService blockchain,
    required String walletAddress,
  }) async {
    final family = blockchain.activeFamily;
    if (family == ChainFamily.solana) {
      return _loadSolanaHistory(walletAddress);
    }
    if (family == ChainFamily.tron) {
      return _loadTronHistory(walletAddress);
    }

    // EVM: use Etherscan
    final chain = blockchain.activeChain;
    final items = await _etherscanService.getUnifiedHistory(
      chain.chainId,
      walletAddress,
    );
    final history = <WalletHistoryEntry>[];

    for (final item in items) {
      if (item is! Map<String, dynamic>) {
        continue;
      }
      final entry = _mapExplorerHistoryEntry(
        item,
        walletAddress: walletAddress,
        blockchain: blockchain,
      );
      if (entry != null) {
        history.add(entry);
      }
    }

    history.sort((left, right) => right.createdAt.compareTo(left.createdAt));
    return history;
  }

  Future<List<WalletHistoryEntry>> _loadSolanaHistory(
    String walletAddress,
  ) async {
    try {
      final uri = AppEnvironment.blockchain(
        '/networks/solana:mainnet/history/$walletAddress',
        {'limit': '50'},
      );
      final resp = await http
          .get(uri, headers: const {'Accept': 'application/json'})
          .timeout(const Duration(seconds: 15));
      if (resp.statusCode < 200 || resp.statusCode >= 300) return const [];
      final data = jsonDecode(resp.body) as Map<String, dynamic>;
      final txs = (data['transactions'] as List<dynamic>?) ?? const [];
      final history = <WalletHistoryEntry>[];
      for (final item in txs) {
        if (item is! Map<String, dynamic>) continue;
        final sig = item['txHash']?.toString() ?? '';
        if (sig.isEmpty) continue;
        final blockTime = item['blockTime'];
        final ts = blockTime is int && blockTime > 0
            ? DateTime.fromMillisecondsSinceEpoch(blockTime * 1000)
            : DateTime.now();
        final failed = item['status']?.toString() == 'failed';
        final memo = item['memo']?.toString() ?? '';
        history.add(
          WalletHistoryEntry(
            id: 'solana:$sig',
            walletAddress: walletAddress,
            networkName: 'Solana',
            networkKey: 'solana:mainnet',
            txHash: sig,
            eventType: failed ? 'failed' : 'send',
            title: failed ? 'Failed transaction' : 'Transaction',
            message: failed
                ? 'Transaction failed on Solana.'
                : 'Transaction on Solana.${memo.isNotEmpty ? ' Memo: $memo' : ''}',
            tokenName: 'Solana',
            tokenSymbol: 'SOL',
            amount: 0,
            isIncoming: false,
            createdAt: ts,
            source: 'explorer',
          ),
        );
      }
      return history;
    } catch (_) {
      return const [];
    }
  }

  Future<List<WalletHistoryEntry>> _loadTronHistory(
    String walletAddress,
  ) async {
    try {
      final uri = AppEnvironment.blockchain(
        '/networks/tron:mainnet/history/$walletAddress',
        {'limit': '50'},
      );
      final resp = await http
          .get(uri, headers: const {'Accept': 'application/json'})
          .timeout(const Duration(seconds: 15));
      if (resp.statusCode < 200 || resp.statusCode >= 300) return const [];
      final data = jsonDecode(resp.body) as Map<String, dynamic>;
      final txs = (data['transactions'] as List<dynamic>?) ?? const [];
      final history = <WalletHistoryEntry>[];
      for (final item in txs) {
        if (item is! Map<String, dynamic>) continue;
        final txId = item['txHash']?.toString() ?? '';
        if (txId.isEmpty) continue;
        final blockTime = item['blockTime'];
        final ts = blockTime is int && blockTime > 0
            ? DateTime.fromMillisecondsSinceEpoch(blockTime * 1000)
            : DateTime.now();
        final from = item['from']?.toString() ?? '';
        final to = item['to']?.toString() ?? '';
        final symbol = item['symbol']?.toString() ?? 'TRX';
        final amount = (item['amount'] as num?)?.toDouble() ?? 0.0;
        final tokenStandard = item['tokenStandard']?.toString() ?? 'native';
        final isIncoming = to.toLowerCase() == walletAddress.toLowerCase();
        final counterparty = isIncoming ? from : to;
        final direction = isIncoming ? 'from' : 'to';
        final action = isIncoming ? 'Received' : 'Sent';
        final tokenName = tokenStandard == 'trc20' ? symbol : 'Tron';
        history.add(
          WalletHistoryEntry(
            id: 'tron:${tokenStandard == 'trc20' ? 'trc20:' : ''}$txId',
            walletAddress: walletAddress,
            networkName: 'Tron',
            networkKey: 'tron:mainnet',
            txHash: txId,
            eventType: isIncoming ? 'receive' : 'send',
            title: isIncoming ? 'Transfer received' : 'Transfer sent',
            message:
                '$action ${_trimAmount(amount)} $symbol $direction ${_shortAddress(counterparty)} on Tron.',
            tokenName: tokenName,
            tokenSymbol: symbol,
            amount: amount,
            isIncoming: isIncoming,
            createdAt: ts,
            source: 'explorer',
          ),
        );
      }
      history.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      return history;
    } catch (_) {
      return const [];
    }
  }

  WalletHistoryEntry? _mapExplorerHistoryEntry(
    Map<String, dynamic> item, {
    required String walletAddress,
    required BlockchainService blockchain,
  }) {
    final txHash = item['hash']?.toString().trim() ?? '';
    if (txHash.isEmpty) {
      return null;
    }

    final chain = blockchain.activeChain;
    final normalizedWallet = walletAddress.trim().toLowerCase();
    final toAddress = item['to']?.toString().trim() ?? '';
    final fromAddress = item['from']?.toString().trim() ?? '';
    final isIncoming = toAddress.toLowerCase() == normalizedWallet;
    final tokenSymbol = item['tokenSymbol']?.toString().trim();
    final tokenName = item['tokenName']?.toString().trim();
    final decimals = _parseInt(item['tokenDecimal']) ?? 18;
    final amount = _rawAmountToDouble(
      item['value']?.toString() ?? '0',
      decimals: decimals,
    );
    final eventType = isIncoming ? 'receive' : 'send';
    final networkName = chain.name;
    final displaySymbol = (tokenSymbol != null && tokenSymbol.isNotEmpty)
        ? tokenSymbol
        : chain.symbol;
    final displayName = (tokenName != null && tokenName.isNotEmpty)
        ? tokenName
        : networkName;
    final createdAt =
        _parseExplorerTimestamp(item['timeStamp']) ?? DateTime.now();
    final counterparty = isIncoming ? fromAddress : toAddress;
    final direction = isIncoming ? 'from' : 'to';
    final action = isIncoming ? 'Received' : 'Sent';

    return WalletHistoryEntry(
      id: 'explorer:${chain.chainId}:$txHash',
      walletAddress: walletAddress,
      chainId: chain.chainId,
      networkName: networkName,
      txHash: txHash,
      eventType: eventType,
      title: isIncoming ? 'Transfer received' : 'Transfer sent',
      message:
          '$action ${_trimAmount(amount)} $displaySymbol $direction ${_shortAddress(counterparty)} on $networkName.',
      tokenName: displayName,
      tokenSymbol: displaySymbol,
      amount: amount,
      isIncoming: isIncoming,
      createdAt: createdAt,
      source: 'explorer',
    );
  }

  List<WalletHistoryEntry> _mergeHistory({
    required List<WalletHistoryEntry> preferred,
    required List<WalletHistoryEntry> fallback,
    required int limit,
  }) {
    final merged = <String, WalletHistoryEntry>{};
    for (final entry in preferred) {
      merged[_historyKey(entry)] = entry;
    }
    for (final entry in fallback) {
      merged.putIfAbsent(_historyKey(entry), () => entry);
    }

    final history = merged.values.toList()
      ..sort((left, right) => right.createdAt.compareTo(left.createdAt));
    if (history.length > limit) {
      return history.sublist(0, limit);
    }
    return history;
  }

  String _historyKey(WalletHistoryEntry entry) {
    final txHash = entry.txHash?.trim().toLowerCase();
    if (txHash != null && txHash.isNotEmpty) {
      return txHash;
    }
    return '${entry.source}:${entry.id}';
  }

  String? _composeHistoryWarning(String? primary, String? secondary) {
    final messages = <String>[
      if (primary != null && primary.trim().isNotEmpty) primary.trim(),
      if (secondary != null && secondary.trim().isNotEmpty) secondary.trim(),
    ];
    if (messages.isEmpty) {
      return null;
    }
    return messages.join(' ');
  }

  DateTime? _parseExplorerTimestamp(dynamic value) {
    final seconds = int.tryParse(value?.toString() ?? '');
    if (seconds == null || seconds <= 0) {
      return null;
    }
    return DateTime.fromMillisecondsSinceEpoch(seconds * 1000);
  }

  int? _parseInt(dynamic value) {
    if (value is int) {
      return value;
    }
    return int.tryParse(value?.toString() ?? '');
  }

  double _rawAmountToDouble(String rawValue, {required int decimals}) {
    final value = BigInt.tryParse(rawValue.trim()) ?? BigInt.zero;
    final divisor = pow(10, decimals).toDouble();
    if (divisor == 0) {
      return 0;
    }
    return value.toDouble() / divisor;
  }

  List<WalletHistoryEntry> get _filteredHistory {
    return _allHistory.where((entry) {
      final matchesType =
          _selectedType == 'all' ||
          entry.eventType == _selectedType ||
          (_selectedType == 'swap' && entry.eventType == 'limit');
      final matchesChain =
          _selectedChainId == null || entry.chainId == _selectedChainId;
      return matchesType && matchesChain;
    }).toList();
  }

  Map<int, String> _availableChains(BlockchainService blockchain) {
    final chains = <int, String>{};
    for (final entry in _allHistory) {
      final chainId = entry.chainId;
      if (chainId == null) {
        continue;
      }
      final chain = blockchain.allChains.where(
        (item) => item.chainId == chainId,
      );
      if (chain.isNotEmpty) {
        chains[chainId] = chain.first.name;
      } else {
        chains[chainId] = entry.networkName;
      }
    }
    final sortedKeys = chains.keys.toList()..sort();
    return {for (final chainId in sortedKeys) chainId: chains[chainId]!};
  }

  EvmChain? _historyChain(
    BlockchainService blockchain,
    WalletHistoryEntry entry,
  ) {
    final chainId = entry.chainId;
    if (chainId == null) {
      return null;
    }
    for (final chain in blockchain.allChains) {
      if (chain.chainId == chainId) {
        return chain;
      }
    }
    return null;
  }

  String? _txExplorerUrl(
    WalletHistoryEntry entry,
    BlockchainService blockchain,
  ) {
    final txHash = entry.txHash;
    if (txHash == null || txHash.isEmpty) return null;

    // Solana
    final networkKey = entry.networkKey;
    if (networkKey == 'solana:mainnet') {
      return 'https://solscan.io/tx/$txHash';
    }
    // Tron
    if (networkKey == 'tron:mainnet') {
      return 'https://tronscan.org/#/transaction/$txHash';
    }

    // EVM — look up by chainId
    final chainId = entry.chainId;
    if (chainId == null) return null;
    final matching = blockchain.allChains.where(
      (chain) => chain.chainId == chainId,
    );
    if (matching.isEmpty) return null;
    final explorer = matching.first.explorerUrl?.trim();
    if (explorer == null || explorer.isEmpty) return null;
    final normalized = explorer.endsWith('/')
        ? explorer.substring(0, explorer.length - 1)
        : explorer;
    return '$normalized/tx/$txHash';
  }

  Future<void> _openExplorer(String url) async {
    await InAppLinkRouter.open(context, url);
  }

  String _typeLabel(String type, AppLocalizations l) {
    switch (type) {
      case 'receive':
        return l.receive;
      case 'send':
        return l.send;
      case 'swap':
        return l.swap;
      default:
        return l.allLabel;
    }
  }

  String _networkLabel(WalletHistoryEntry entry, AppLocalizations l) {
    final networkName = entry.networkName.trim();
    if (networkName.isEmpty || networkName == 'Unknown network') {
      return l.unknownNetwork;
    }
    return networkName;
  }

  String _entryTitle(WalletHistoryEntry entry, AppLocalizations l) {
    switch (entry.eventType) {
      case 'receive':
        return l.historyTransferReceived;
      case 'send':
        return l.historyTransferSent;
      case 'swap':
        return l.swapCompletedTitle;
      case 'limit':
        final title = entry.title.trim();
        return title.isNotEmpty ? title : l.swapCompletedTitle;
      default:
        final title = entry.title.trim();
        return title.isNotEmpty ? title : l.transactionDetails;
    }
  }

  String _entryDescription(WalletHistoryEntry entry, AppLocalizations l) {
    final networkName = _networkLabel(entry, l);
    final amount = entry.amount;
    final tokenSymbol = entry.tokenSymbol?.trim();
    final amountText = amount == null
        ? ''
        : [
            _trimAmount(amount),
            if (tokenSymbol != null && tokenSymbol.isNotEmpty) tokenSymbol,
          ].join(' ');

    switch (entry.eventType) {
      case 'receive':
        if (amountText.isNotEmpty) {
          return l.historyReceivedAmountOnNetwork(amountText, networkName);
        }
        return l.historyActivityOnNetwork(networkName);
      case 'send':
        if (amountText.isNotEmpty) {
          return l.historySentAmountOnNetwork(amountText, networkName);
        }
        return l.historyActivityOnNetwork(networkName);
      case 'swap':
        return l.historySwapOnNetwork(networkName);
      case 'limit':
        final message = entry.message.trim();
        return message.isNotEmpty
            ? message
            : l.historyActivityOnNetwork(networkName);
      default:
        final message = entry.message.trim();
        return message.isNotEmpty
            ? message
            : l.historyActivityOnNetwork(networkName);
    }
  }

  Future<void> _showHistoryDetails(
    WalletHistoryEntry entry,
    BlockchainService blockchain,
  ) async {
    final chain = _historyChain(blockchain, entry);
    final explorerUrl = _txExplorerUrl(entry, blockchain);
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _HistoryTransactionDetailsSheet(
        entry: entry,
        chain: chain,
        explorerUrl: explorerUrl,
        walletService: _walletService,
        titleText: _entryTitle(entry, AppLocalizations.of(context)),
        messageText: _entryDescription(entry, AppLocalizations.of(context)),
        amountText: _formattedAmount(entry).trim(),
        timestampText: DateFormat('MMM d, yyyy - HH:mm')
            .format(entry.createdAt),
        networkText: _networkLabel(entry, AppLocalizations.of(context)),
        onOpenExplorer: _openExplorer,
      ),
    );
  }

  IconData _entryIcon(WalletHistoryEntry entry) {
    switch (entry.eventType) {
      case 'swap':
      case 'limit':
        return Icons.compare_arrows;
      case 'send':
        return Icons.arrow_upward;
      default:
        return Icons.arrow_downward;
    }
  }

  Color _entryColor(WalletHistoryEntry entry) {
    switch (entry.eventType) {
      case 'swap':
      case 'limit':
        return Colors.white;
      case 'send':
        return AppColors.accentRed;
      default:
        return AppColors.success;
    }
  }

  String _formattedAmount(WalletHistoryEntry entry) {
    final amount = entry.amount;
    final tokenSymbol = entry.tokenSymbol;
    if (amount == null || tokenSymbol == null || tokenSymbol.isEmpty) {
      return '';
    }
    final prefix = entry.eventType == 'swap' || entry.eventType == 'limit'
        ? ''
        : (entry.isIncoming ? '+' : '-');
    return '$prefix ${_trimAmount(amount)} $tokenSymbol';
  }

  String _trimAmount(double amount) {
    var value = amount.toStringAsFixed(6);
    while (value.contains('.') && value.endsWith('0')) {
      value = value.substring(0, value.length - 1);
    }
    if (value.endsWith('.')) {
      value = value.substring(0, value.length - 1);
    }
    return value;
  }

  String _shortHash(String hash) {
    if (hash.length <= 12) {
      return hash;
    }
    return '${hash.substring(0, 6)}...${hash.substring(hash.length - 4)}';
  }

  String _shortAddress(String address) {
    final trimmed = address.trim();
    if (trimmed.length <= 12) {
      return trimmed;
    }
    return '${trimmed.substring(0, 6)}...${trimmed.substring(trimmed.length - 4)}';
  }

  @override
  Widget build(BuildContext context) {
    final blockchain = Provider.of<BlockchainService>(context);
    final chainFilters = _availableChains(blockchain);
    final l = AppLocalizations.of(context);

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(4, 8, 16, 0),
              child: Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.arrow_back, color: Colors.white),
                    onPressed: () => Navigator.pop(context),
                  ),
                  Expanded(
                    child: Text(
                      l.transactionHistory,
                      style: GoogleFonts.outfit(
                        fontSize: 20,
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                  PopupMenuButton<int?>(
                    color: AppColors.cardDark,
                    initialValue: _selectedChainId,
                    onSelected: (value) {
                      setState(() => _selectedChainId = value);
                    },
                    itemBuilder: (context) => [
                      PopupMenuItem<int?>(
                        value: null,
                        child: Text(
                          l.allChains,
                          style: GoogleFonts.outfit(color: Colors.white),
                        ),
                      ),
                      ...chainFilters.entries.map(
                        (entry) => PopupMenuItem<int?>(
                          value: entry.key,
                          child: Text(
                            entry.value,
                            style: GoogleFonts.outfit(color: Colors.white),
                          ),
                        ),
                      ),
                    ],
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.cardDark,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color: Colors.white.withValues(alpha: 0.08),
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.filter_list_rounded,
                            size: 16,
                            color: Colors.white.withValues(alpha: 0.85),
                          ),
                          const SizedBox(width: 6),
                          Text(
                            _selectedChainId == null
                                ? l.allChains
                                : (chainFilters[_selectedChainId] ??
                                      l.unknownNetwork),
                            style: GoogleFonts.outfit(
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                              color: Colors.white,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              height: 40,
              child: ListView.separated(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                scrollDirection: Axis.horizontal,
                itemBuilder: (context, index) {
                  final type = _typeFilters[index];
                  final selected = _selectedType == type;
                  return GestureDetector(
                    onTap: () => setState(() => _selectedType = type),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 18,
                        vertical: 9,
                      ),
                      decoration: BoxDecoration(
                        color: selected ? Colors.white : Colors.transparent,
                        borderRadius: BorderRadius.circular(20),
                        border: selected
                            ? null
                            : Border.all(
                                color: Colors.white.withValues(alpha: 0.15),
                              ),
                      ),
                      child: Text(
                        _typeLabel(type, l),
                        style: GoogleFonts.outfit(
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                          color: selected
                              ? AppColors.background
                              : Colors.white.withValues(alpha: 0.7),
                        ),
                      ),
                    ),
                  );
                },
                separatorBuilder: (context, index) => const SizedBox(width: 10),
                itemCount: _typeFilters.length,
              ),
            ),
            if (_isPartial && (_partialMessage?.isNotEmpty ?? false))
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0x33F59E0B),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0x66F59E0B)),
                  ),
                  child: Text(
                    _partialMessage!,
                    style: GoogleFonts.outfit(
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      color: const Color(0xFFFFE7C2),
                    ),
                  ),
                ),
              ),
            const SizedBox(height: 16),
            Expanded(
              child: RefreshIndicator(
                color: Colors.white,
                backgroundColor: AppColors.cardDark,
                onRefresh: _fetchHistory,
                child: _buildBody(blockchain, l),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBody(BlockchainService blockchain, AppLocalizations l) {
    if (_isLoading) {
      return const Center(
        child: CircularProgressIndicator(color: Colors.white),
      );
    }

    if (_errorMessage != null) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        children: [
          const SizedBox(height: 140),
          Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Text(
                _errorMessage!,
                textAlign: TextAlign.center,
                style: GoogleFonts.outfit(
                  fontSize: 16,
                  color: AppColors.accentRed,
                ),
              ),
            ),
          ),
        ],
      );
    }

    if (_filteredHistory.isEmpty) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        children: [
          const SizedBox(height: 120),
          Icon(
            Icons.history_rounded,
            size: 40,
            color: Colors.white.withValues(alpha: 0.35),
          ),
          const SizedBox(height: 14),
          Center(
            child: Text(
              l.walletHistoryEmpty,
              style: GoogleFonts.outfit(
                fontSize: 16,
                fontWeight: FontWeight.w500,
                color: Colors.white.withValues(alpha: 0.7),
              ),
            ),
          ),
        ],
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 20),
      physics: const AlwaysScrollableScrollPhysics(),
      itemCount: _filteredHistory.length,
      separatorBuilder: (context, index) => const SizedBox(height: 12),
      itemBuilder: (context, index) {
        return _buildHistoryCard(_filteredHistory[index], blockchain, l);
      },
    );
  }

  Widget _buildHistoryCard(
    WalletHistoryEntry entry,
    BlockchainService blockchain,
    AppLocalizations l,
  ) {
    final explorerUrl = _txExplorerUrl(entry, blockchain);
    final amountText = _formattedAmount(entry);
    final displayTimestamp = DateFormat('MMM d, yyyy - HH:mm')
        .format(entry.createdAt);
    // ignore: unused_local_variable
    final timestamp = DateFormat('MMM d, yyyy • HH:mm').format(entry.createdAt);

    return Material(
      color: AppColors.cardDark,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () => _showHistoryDetails(entry, blockchain),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: AppColors.cardDark,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.06),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  _entryIcon(entry),
                  color: _entryColor(entry),
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            _entryTitle(entry, l),
                            style: GoogleFonts.outfit(
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                              color: Colors.white,
                            ),
                          ),
                        ),
                        if (amountText.isNotEmpty)
                          Text(
                            amountText,
                            style: GoogleFonts.outfit(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color:
                                  entry.eventType == 'swap' ||
                                      entry.eventType == 'limit'
                                  ? Colors.white
                                  : _entryColor(entry),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.05),
                            borderRadius: BorderRadius.circular(999),
                            border: Border.all(
                              color: Colors.white.withValues(alpha: 0.08),
                            ),
                          ),
                          child: Text(
                            _networkLabel(entry, l),
                            style: GoogleFonts.outfit(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: Colors.white.withValues(alpha: 0.85),
                            ),
                          ),
                        ),
                        Text(
                          displayTimestamp,
                          style: GoogleFonts.outfit(
                            fontSize: 12,
                            color: Colors.white.withValues(alpha: 0.5),
                          ),
                        ),
                        if (entry.txHash?.isNotEmpty == true)
                          Text(
                            _shortHash(entry.txHash!),
                            style: GoogleFonts.outfit(
                              fontSize: 12,
                              color: Colors.white.withValues(alpha: 0.5),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      _entryDescription(entry, l),
                      style: GoogleFonts.outfit(
                        fontSize: 13,
                        height: 1.35,
                        color: Colors.white.withValues(alpha: 0.68),
                      ),
                    ),
                  ],
                ),
              ),
              if (explorerUrl != null) ...[
                const SizedBox(width: 10),
                InkWell(
                  onTap: () => _openExplorer(explorerUrl),
                  borderRadius: BorderRadius.circular(12),
                  child: Padding(
                    padding: const EdgeInsets.all(4),
                    child: Icon(
                      Icons.open_in_new_rounded,
                      size: 18,
                      color: Colors.white.withValues(alpha: 0.75),
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
}
