import 'dart:math';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../constants/app_colors.dart';
import '../../services/blockchain_service.dart';
import '../../services/etherscan_v2_service.dart';
import '../../services/http_client_service.dart';
import '../../services/wallet_history_service.dart';
import '../../services/wallet_service.dart';

class TransactionsScreen extends StatefulWidget {
  const TransactionsScreen({super.key});

  @override
  State<TransactionsScreen> createState() => _TransactionsScreenState();
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
    _fetchHistory();
  }

  Future<void> _fetchHistory() async {
    final blockchain = Provider.of<BlockchainService>(context, listen: false);
    try {
      final address = await _walletService.getCurrentWalletAddress();
      if (!mounted) return;
      if (address == null || address.trim().isEmpty) {
        setState(() {
          _isLoading = false;
          _errorMessage = 'No wallet connected';
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
        fallbackWarning =
            'Showing explorer history for the active chain while wallet history is unavailable.';
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
        _errorMessage = 'Unable to load wallet history right now.';
      });
    }
  }

  Future<List<WalletHistoryEntry>> _loadExplorerHistory({
    required BlockchainService blockchain,
    required String walletAddress,
  }) async {
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
          _selectedType == 'all' || entry.eventType == _selectedType;
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

  String? _txExplorerUrl(
    WalletHistoryEntry entry,
    BlockchainService blockchain,
  ) {
    final txHash = entry.txHash;
    final chainId = entry.chainId;
    if (txHash == null || txHash.isEmpty || chainId == null) {
      return null;
    }
    final matching = blockchain.allChains.where(
      (chain) => chain.chainId == chainId,
    );
    if (matching.isEmpty) {
      return null;
    }
    final explorer = matching.first.explorerUrl?.trim();
    if (explorer == null || explorer.isEmpty) {
      return null;
    }
    final normalized = explorer.endsWith('/')
        ? explorer.substring(0, explorer.length - 1)
        : explorer;
    return '$normalized/tx/$txHash';
  }

  Future<void> _openExplorer(String url) async {
    final uri = Uri.tryParse(url);
    if (uri == null) {
      return;
    }
    final opened = await launchUrl(uri, mode: LaunchMode.inAppBrowserView);
    if (!opened) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  String _typeLabel(String type) {
    switch (type) {
      case 'receive':
        return 'Receive';
      case 'send':
        return 'Send';
      case 'swap':
        return 'Swap';
      default:
        return 'All';
    }
  }

  IconData _entryIcon(WalletHistoryEntry entry) {
    switch (entry.eventType) {
      case 'swap':
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
    final prefix = entry.eventType == 'swap'
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
                      'Wallet History',
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
                          'All Chains',
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
                                ? 'All Chains'
                                : (chainFilters[_selectedChainId] ??
                                      'Unknown network'),
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
                        _typeLabel(type),
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
                child: _buildBody(blockchain),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBody(BlockchainService blockchain) {
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
              'No wallet history yet',
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
        return _buildHistoryCard(_filteredHistory[index], blockchain);
      },
    );
  }

  Widget _buildHistoryCard(
    WalletHistoryEntry entry,
    BlockchainService blockchain,
  ) {
    final explorerUrl = _txExplorerUrl(entry, blockchain);
    final amountText = _formattedAmount(entry);
    final timestamp = DateFormat('MMM d, yyyy • HH:mm').format(entry.createdAt);

    return Container(
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
            child: Icon(_entryIcon(entry), color: _entryColor(entry), size: 20),
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
                        entry.title,
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
                          color: entry.eventType == 'swap'
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
                        entry.networkName,
                        style: GoogleFonts.outfit(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: Colors.white.withValues(alpha: 0.85),
                        ),
                      ),
                    ),
                    Text(
                      timestamp,
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
                  entry.message,
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
    );
  }
}
