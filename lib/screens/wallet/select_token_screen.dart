import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../../constants/app_colors.dart';
import '../../l10n/app_localizations.dart';
import '../../models/token.dart';
import '../../widgets/token_icon.dart';

import '../../services/blockchain_service.dart';
import '../../services/token_visibility_service.dart';
import '../../services/wallet_service.dart';
import '../../utils/token_visibility_utils.dart';

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
  final TokenVisibilityService _tokenVisibilityService =
      TokenVisibilityService();

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
    final blockchain = Provider.of<BlockchainService>(context, listen: false);
    try {
      final hiddenTokens = await _tokenVisibilityService.loadHiddenTokens(
        blockchain.activeChain.chainId,
      );
      final address = await _walletService.getCurrentWalletAddress();
      if (address != null) {
        if (!mounted) return;
        final tokens = await blockchain.fetchWalletTokens(address);
        final visibleTokens = _applyVisibility(tokens, hiddenTokens);
        if (mounted) {
          setState(() {
            _allTokens = visibleTokens;
            _filteredTokens = visibleTokens;
            _isLoading = false;
          });
        }
      } else {
        // Show default token list even without wallet
        final defaultTokens = _applyVisibility(
          _getDefaultTokens(),
          hiddenTokens,
        );
        if (mounted) {
          setState(() {
            _allTokens = defaultTokens;
            _filteredTokens = defaultTokens;
            _isLoading = false;
          });
        }
      }
    } catch (e) {
      final hiddenTokens = await _tokenVisibilityService.loadHiddenTokens(
        blockchain.activeChain.chainId,
      );
      final defaultTokens = _applyVisibility(_getDefaultTokens(), hiddenTokens);
      if (mounted) {
        setState(() {
          _allTokens = defaultTokens;
          _filteredTokens = defaultTokens;
          _isLoading = false;
        });
      }
    }
  }

  List<Token> _applyVisibility(List<Token> tokens, Set<String> hiddenTokens) {
    return tokens.where((token) {
      final contractAddress = token.contractAddress ?? '';
      if (contractAddress.isEmpty) {
        return true;
      }
      return !hiddenTokens.contains(TokenVisibilityUtils.identifier(token));
    }).toList();
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
    final l = AppLocalizations.of(context);
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
                      l.selectTokenTitle,
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
                    hintText: l.searchTokenOrPasteContract,
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
                        l.noTokensYet,
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
              chainId: Provider.of<BlockchainService>(
                context,
                listen: false,
              ).activeChain.chainId,
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
