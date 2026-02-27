import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../../constants/app_colors.dart';
import '../../models/token.dart';
import '../../widgets/token_icon.dart';

import '../../services/blockchain_service.dart';
import '../../services/wallet_service.dart';

/// Select Token Screen
/// Search and filter tokens by network, tap to select
class SelectTokenScreen extends StatefulWidget {
  const SelectTokenScreen({super.key});

  @override
  State<SelectTokenScreen> createState() => _SelectTokenScreenState();
}

class _SelectTokenScreenState extends State<SelectTokenScreen> {
  final TextEditingController _searchController = TextEditingController();

  final WalletService _walletService = WalletService();

  List<Token> _allTokens = [];
  List<Token> _filteredTokens = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadTokens();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadTokens() async {
    setState(() => _isLoading = true);
    try {
      final address = await _walletService.getCurrentWalletAddress();
      if (address != null) {
        if (!mounted) return;
        final tokens = await Provider.of<BlockchainService>(
          context,
          listen: false,
        ).fetchWalletTokens(address);
        if (mounted) {
          setState(() {
            _allTokens = tokens;
            _filteredTokens = tokens;
            _isLoading = false;
          });
        }
      } else {
        // Show default token list even without wallet
        if (mounted) {
          setState(() {
            _allTokens = _getDefaultTokens();
            _filteredTokens = _allTokens;
            _isLoading = false;
          });
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _allTokens = _getDefaultTokens();
          _filteredTokens = _allTokens;
          _isLoading = false;
        });
      }
    }
  }

  List<Token> _getDefaultTokens() {
    return [
      Token(
        symbol: 'ETH',
        name: 'Ethereum',
        balance: 0,
        valueUsd: 0,
        changePercent24h: 0,
        contractAddress: '',
        decimals: 18,
        coinGeckoId: 'ethereum',
      ),
      Token(
        symbol: 'BNB',
        name: 'BNB',
        balance: 0,
        valueUsd: 0,
        changePercent24h: 0,
        contractAddress: '',
        decimals: 18,
        coinGeckoId: 'binancecoin',
      ),
      Token(
        symbol: 'MATIC',
        name: 'Polygon',
        balance: 0,
        valueUsd: 0,
        changePercent24h: 0,
        contractAddress: '',
        decimals: 18,
        coinGeckoId: 'matic-network',
      ),
      Token(
        symbol: 'USDC',
        name: 'USD Coin',
        balance: 0,
        valueUsd: 0,
        changePercent24h: 0,
        contractAddress: '',
        decimals: 6,
        coinGeckoId: 'usd-coin',
      ),
    ];
  }

  void _filterTokens(String query) {
    setState(() {
      _filteredTokens = _allTokens.where((token) {
        final matchesSearch =
            query.isEmpty ||
            token.name.toLowerCase().contains(query.toLowerCase()) ||
            token.symbol.toLowerCase().contains(query.toLowerCase()) ||
            token.contractAddress?.toLowerCase().contains(
                  query.toLowerCase(),
                ) ==
                true;
        return matchesSearch;
      }).toList();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
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
                      'Select Token',
                      style: GoogleFonts.outfit(
                        fontSize: 20,
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                  const SizedBox(width: 48), // Balance the back button
                ],
              ),
            ),
            const SizedBox(height: 12),

            // Search bar
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: AppColors.cardDark,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: TextField(
                  controller: _searchController,
                  onChanged: _filterTokens,
                  style: GoogleFonts.outfit(color: Colors.white, fontSize: 14),
                  decoration: InputDecoration(
                    icon: Icon(
                      Icons.search,
                      color: Colors.white.withValues(alpha: 0.5),
                    ),
                    hintText: 'Search token or paste contract address',
                    hintStyle: GoogleFonts.outfit(
                      fontSize: 14,
                      color: Colors.white.withValues(alpha: 0.4),
                    ),
                    border: InputBorder.none,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 14),

            // Token list
            Expanded(
              child: _isLoading
                  ? const Center(
                      child: CircularProgressIndicator(
                        color: AppColors.accentRed,
                      ),
                    )
                  : _filteredTokens.isEmpty
                  ? Center(
                      child: Text(
                        'No tokens found',
                        style: GoogleFonts.outfit(
                          fontSize: 16,
                          color: Colors.white54,
                        ),
                      ),
                    )
                  : ListView.separated(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      separatorBuilder: (_, a) => const SizedBox(height: 8),
                      itemCount: _filteredTokens.length,
                      itemBuilder: (context, index) =>
                          _buildTokenItem(_filteredTokens[index]),
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTokenItem(Token token) {
    return GestureDetector(
      onTap: () => Navigator.pop(context, token),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppColors.cardDark,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Row(
          children: [
            TokenIcon(
              tokenSymbol: token.symbol,
              tokenAddress: token.contractAddress,
              tokenImageUrl: token.imageUrl,
              size: 42,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    token.name,
                    style: GoogleFonts.outfit(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    token.symbol,
                    style: GoogleFonts.outfit(
                      fontSize: 12,
                      color: Colors.white.withValues(alpha: 0.5),
                    ),
                  ),
                ],
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  token.balance.toStringAsFixed(2),
                  style: GoogleFonts.outfit(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  token.formattedValue,
                  style: GoogleFonts.outfit(
                    fontSize: 12,
                    color: Colors.white.withValues(alpha: 0.5),
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
