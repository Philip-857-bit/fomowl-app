import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../../constants/app_colors.dart';
import '../../services/wallet_service.dart';

/// My Transactions Screen
/// Shows transaction history with All / Deposit / Withdrawal filter tabs
class TransactionsScreen extends StatefulWidget {
  const TransactionsScreen({super.key});

  @override
  State<TransactionsScreen> createState() => _TransactionsScreenState();
}

class _TransactionsScreenState extends State<TransactionsScreen> {
  String _selectedFilter = 'All';
  final List<String> _filters = ['All', 'Deposit', 'Withdrawal'];

  bool _isLoading = true;
  String? _errorMessage;
  List<_Transaction> _allTransactions = [];

  @override
  void initState() {
    super.initState();
    _fetchHistory();
  }

  Future<void> _fetchHistory() async {
    try {
      final walletService = context.read<WalletService>();
      final address = await walletService.getCurrentWalletAddress();
      if (address == null) {
        setState(() {
          _isLoading = false;
          _errorMessage = "No wallet connected";
        });
        return;
      }

      final url = Uri.parse('https://fomowl-backend.onrender.com/api/history/$address');
      final response = await http.get(url).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final historyList = data['history'] as List<dynamic>? ?? [];
        
        final parsedTx = historyList.map((jsonTx) {
          // Parse date
          final dateStr = jsonTx['created_at'] as String? ?? '';
          DateTime? dt;
          try {
            dt = DateTime.parse(dateStr);
          } catch (_) {}
          final formattedDate = dt != null ? DateFormat('MM.dd.yyyy').format(dt) : dateStr;

          // Parse Type
          final rawType = jsonTx['tx_type'] as String? ?? 'receive';
          _TxType type;
          if (rawType == 'send') {
            type = _TxType.send;
          } else if (rawType == 'swap') {
            type = _TxType.swap;
          } else {
            type = _TxType.receive;
          }

          return _Transaction(
            type: type,
            tokenName: jsonTx['token_name'] ?? 'Unknown',
            tokenSymbol: jsonTx['token_symbol'] ?? 'UNK',
            address: jsonTx['wallet_address'] ?? '',
            amount: (jsonTx['amount'] ?? 0.0).toDouble(),
            date: formattedDate,
            isIncoming: jsonTx['is_incoming'] ?? true,
          );
        }).toList();

        setState(() {
          _allTransactions = parsedTx;
          _isLoading = false;
        });
      } else {
        setState(() {
          _isLoading = false;
          _errorMessage = "Failed to load history (${response.statusCode})";
        });
      }
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
                          color: isSelected
                              ? Colors.white
                              : Colors.transparent,
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
                  ? const Center(child: CircularProgressIndicator(color: Colors.white))
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
                  color: tx.isIncoming ? AppColors.success : AppColors.accentRed,
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

  const _Transaction({
    required this.type,
    required this.tokenName,
    required this.tokenSymbol,
    required this.address,
    required this.amount,
    required this.date,
    required this.isIncoming,
  });
}
