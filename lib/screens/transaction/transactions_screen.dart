import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:math';
import 'package:intl/intl.dart';
import '../../config/app_environment.dart';
import '../../constants/app_colors.dart';
import '../../services/wallet_service.dart';
import '../../services/blockchain_service.dart';
import '../../services/etherscan_v2_service.dart';
import '../../services/http_client_service.dart';
import 'package:provider/provider.dart';

/// My Transactions Screen
/// Shows transaction history with All / Deposit / Withdrawal filter tabs
class TransactionsScreen extends StatefulWidget {
  const TransactionsScreen({super.key});

  @override
  State<TransactionsScreen> createState() => _TransactionsScreenState();
}

class _TransactionsScreenState extends State<TransactionsScreen> {
  final WalletService _walletService = WalletService();
  String _selectedFilter = 'All';
  final List<String> _filters = ['All', 'Deposit', 'Withdrawal'];

  bool _isLoading = true;
  String? _errorMessage;
  List<_Transaction> _allTransactions = [];
  late final EtherscanV2Service _etherscanService;

  @override
  void initState() {
    super.initState();
    _etherscanService = EtherscanV2Service(HttpClientService());
    _fetchHistory();
  }

  Future<void> _fetchHistory() async {
    try {
      final address = await _walletService.getCurrentWalletAddress();
      if (!mounted) return;
      if (address == null) {
        setState(() {
          _isLoading = false;
          _errorMessage = "No wallet connected";
        });
        return;
      }

      final blockchain = Provider.of<BlockchainService>(context, listen: false);
      final chainId = blockchain.activeChain.chainId;

      // 1. Fetch from Local Backend
      final backendUrl = AppEnvironment.history('/$address');
      final backendResponse = await http
          .get(backendUrl)
          .timeout(const Duration(seconds: 10));

      final List<_Transaction> localTxs = [];
      if (backendResponse.statusCode == 200) {
        final data = json.decode(backendResponse.body);
        final historyList = data['history'] as List<dynamic>? ?? [];
        localTxs.addAll(
          historyList.map((j) => _Transaction.fromBackendJson(j)),
        );
      }

      // 2. Fetch from Etherscan V2 (Centralized Backend)
      final List<dynamic> onChainData = await _etherscanService
          .getUnifiedHistory(chainId, address);

      final List<_Transaction> onChainTxs = onChainData.map((j) {
        if (j['tokenSymbol'] != null) {
          return _Transaction.fromEtherscanToken(j, address);
        } else {
          return _Transaction.fromEtherscanNormal(
            j,
            address,
            blockchain.activeChain.symbol,
          );
        }
      }).toList();

      // 3. Merge and Deduplicate (by hash)
      final Map<String, _Transaction> merged = {};

      // Local first (often has better 'tx_type' human-readable names like 'swap')
      for (final tx in localTxs) {
        if (tx.hash != null) merged[tx.hash!.toLowerCase()] = tx;
      }

      // On-chain second (adds missing or incoming txs)
      for (final tx in onChainTxs) {
        final key = tx.hash?.toLowerCase();
        if (key != null && !merged.containsKey(key)) {
          merged[key] = tx;
        }
      }

      final sorted = merged.values.toList()
        ..sort((a, b) => b.timestamp.compareTo(a.timestamp));

      setState(() {
        _allTransactions = sorted;
        _isLoading = false;
        _errorMessage = null;
      });
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _errorMessage = "Error connecting to server";
        });
      }
    }
  }

  List<_Transaction> get _filteredTransactions {
    if (_selectedFilter == 'Deposit') {
      return _allTransactions.where((tx) => tx.isIncoming).toList();
    } else if (_selectedFilter == 'Withdrawal') {
      return _allTransactions.where((tx) => !tx.isIncoming).toList();
    }
    return _allTransactions;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          children: [
            // Header
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
                      'My Transactions',
                      style: GoogleFonts.outfit(
                        fontSize: 20,
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                  const SizedBox(width: 48),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Filter tabs
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                children: _filters.map((filter) {
                  final isSelected = _selectedFilter == filter;
                  return Padding(
                    padding: const EdgeInsets.only(right: 10),
                    child: GestureDetector(
                      onTap: () => setState(() => _selectedFilter = filter),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 20,
                          vertical: 9,
                        ),
                        decoration: BoxDecoration(
                          color: isSelected ? Colors.white : Colors.transparent,
                          borderRadius: BorderRadius.circular(20),
                          border: isSelected
                              ? null
                              : Border.all(
                                  color: Colors.white.withValues(alpha: 0.15),
                                ),
                        ),
                        child: Text(
                          filter,
                          style: GoogleFonts.outfit(
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                            color: isSelected
                                ? AppColors.background
                                : Colors.white.withValues(alpha: 0.6),
                          ),
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),
            const SizedBox(height: 20),

            // Transaction list
            Expanded(
              child: _isLoading
                  ? const Center(
                      child: CircularProgressIndicator(color: Colors.white),
                    )
                  : _errorMessage != null
                  ? Center(
                      child: Text(
                        _errorMessage!,
                        style: GoogleFonts.outfit(
                          fontSize: 16,
                          color: AppColors.accentRed,
                        ),
                      ),
                    )
                  : _filteredTransactions.isEmpty
                  ? Center(
                      child: Text(
                        'No transactions yet',
                        style: GoogleFonts.outfit(
                          fontSize: 16,
                          color: Colors.white54,
                        ),
                      ),
                    )
                  : ListView.separated(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      separatorBuilder: (_, a) => const SizedBox(height: 10),
                      itemCount: _filteredTransactions.length,
                      itemBuilder: (context, index) {
                        return _buildTransactionItem(
                          _filteredTransactions[index],
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTransactionItem(_Transaction tx) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.cardDark,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          // Type icon
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.06),
              shape: BoxShape.circle,
            ),
            child: Icon(
              tx.type == _TxType.receive
                  ? Icons.arrow_downward
                  : tx.type == _TxType.send
                  ? Icons.arrow_upward
                  : Icons.compare_arrows,
              color: tx.type == _TxType.receive
                  ? AppColors.success
                  : AppColors.accentRed,
              size: 20,
            ),
          ),
          const SizedBox(width: 12),

          // Token name + address
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${tx.tokenName} (${tx.tokenSymbol})',
                  style: GoogleFonts.outfit(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  '(${tx.isIncoming ? "from" : "to"}) ${tx.address}',
                  style: GoogleFonts.outfit(
                    fontSize: 12,
                    color: Colors.white.withValues(alpha: 0.45),
                  ),
                ),
              ],
            ),
          ),

          // Amount + date
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '${tx.isIncoming ? "+" : "-"} ${tx.amount.toStringAsFixed(2)} \$',
                style: GoogleFonts.outfit(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: tx.isIncoming
                      ? AppColors.success
                      : AppColors.accentRed,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                tx.date,
                style: GoogleFonts.outfit(
                  fontSize: 12,
                  color: Colors.white.withValues(alpha: 0.4),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

enum _TxType { receive, send, swap }

class _Transaction {
  final _TxType type;
  final String tokenName;
  final String tokenSymbol;
  final String address;
  final double amount;
  final String date;
  final bool isIncoming;
  final String? hash;
  final DateTime timestamp;

  const _Transaction({
    required this.type,
    required this.tokenName,
    required this.tokenSymbol,
    required this.address,
    required this.amount,
    required this.date,
    required this.isIncoming,
    this.hash,
    required this.timestamp,
  });

  factory _Transaction.fromBackendJson(Map<String, dynamic> j) {
    final dateStr = j['created_at'] as String? ?? '';
    final dt = DateTime.tryParse(dateStr) ?? DateTime.now();
    final rawType = j['tx_type'] as String? ?? 'receive';

    _TxType type = _TxType.receive;
    if (rawType == 'send') {
      type = _TxType.send;
    } else if (rawType == 'swap') {
      type = _TxType.swap;
    }

    return _Transaction(
      type: type,
      tokenName: j['token_name'] ?? 'Unknown',
      tokenSymbol: j['token_symbol'] ?? 'UNK',
      address: j['wallet_address'] ?? '',
      amount: (j['amount'] ?? 0.0).toDouble(),
      date: DateFormat('MM.dd.yyyy').format(dt),
      isIncoming: j['is_incoming'] ?? true,
      hash: j['tx_hash'],
      timestamp: dt,
    );
  }

  factory _Transaction.fromEtherscanNormal(
    Map<String, dynamic> j,
    String myAddr,
    String nativeSymbol,
  ) {
    final dt = DateTime.fromMillisecondsSinceEpoch(
      int.parse(j['timeStamp']) * 1000,
    );
    final isIncoming =
        (j['to'] as String).toLowerCase() == myAddr.toLowerCase();
    final value = BigInt.parse(j['value']);
    final amount = value.toDouble() / 1e18;

    return _Transaction(
      type: isIncoming ? _TxType.receive : _TxType.send,
      tokenName: 'Native',
      tokenSymbol: nativeSymbol,
      address: isIncoming ? j['from'] : j['to'],
      amount: amount,
      date: DateFormat('MM.dd.yyyy').format(dt),
      isIncoming: isIncoming,
      hash: j['hash'],
      timestamp: dt,
    );
  }

  factory _Transaction.fromEtherscanToken(
    Map<String, dynamic> j,
    String myAddr,
  ) {
    final dt = DateTime.fromMillisecondsSinceEpoch(
      int.parse(j['timeStamp']) * 1000,
    );
    final isIncoming =
        (j['to'] as String).toLowerCase() == myAddr.toLowerCase();
    final decimals = int.tryParse(j['tokenDecimal']) ?? 18;
    final value = BigInt.parse(j['value']);
    final amount = value.toDouble() / pow(10, decimals);

    return _Transaction(
      type: isIncoming ? _TxType.receive : _TxType.send,
      tokenName: j['tokenName'] ?? 'Unknown',
      tokenSymbol: j['tokenSymbol'] ?? 'UNK',
      address: isIncoming ? j['from'] : j['to'],
      amount: amount,
      date: DateFormat('MM.dd.yyyy').format(dt),
      isIncoming: isIncoming,
      hash: j['hash'],
      timestamp: dt,
    );
  }
}
