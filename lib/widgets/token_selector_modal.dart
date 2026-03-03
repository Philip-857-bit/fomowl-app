import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../constants/app_colors.dart';
import '../../models/token.dart';
import 'token_icon.dart';

class TokenSelectorDialog extends StatefulWidget {
  final List<Token> tokens;
  final int? chainId;
  const TokenSelectorDialog({super.key, required this.tokens, this.chainId});

  @override
  State<TokenSelectorDialog> createState() => _TokenSelectorDialogState();
}

class _TokenSelectorDialogState extends State<TokenSelectorDialog> {
  late List<Token> _filteredTokens;
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _filteredTokens = widget.tokens;
    _searchController.addListener(_onSearchChanged);
  }

  @override
  void dispose() {
    _searchController.removeListener(_onSearchChanged);
    _searchController.dispose();
    super.dispose();
  }

  void _onSearchChanged() {
    final query = _searchController.text.toLowerCase();
    setState(() {
      if (query.isEmpty) {
        _filteredTokens = widget.tokens;
      } else {
        _filteredTokens = widget.tokens
            .where(
              (token) =>
                  token.name.toLowerCase().contains(query) ||
                  token.symbol.toLowerCase().contains(query),
            )
            .toList();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: AppColors.background,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                GestureDetector(
                  onTap: () => Navigator.pop(context),
                  child: const Icon(Icons.close, color: Colors.white, size: 24),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Search Bar
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: TextField(
                controller: _searchController,
                style: GoogleFonts.outfit(color: Colors.white),
                decoration: InputDecoration(
                  border: InputBorder.none,
                  hintText: 'Search receiving token',
                  hintStyle: GoogleFonts.outfit(
                    color: Colors.white.withValues(alpha: 0.5),
                  ),
                  icon: Icon(
                    Icons.search,
                    color: Colors.white.withValues(alpha: 0.5),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 24),

            // Token Options
            ConstrainedBox(
              constraints: BoxConstraints(
                maxHeight: MediaQuery.of(context).size.height * 0.4,
              ),
              child: _filteredTokens.isEmpty
                  ? Center(
                      child: Text(
                        _searchController.text.isEmpty
                            ? 'No tokens found'
                            : 'No matching tokens found',
                        style: GoogleFonts.outfit(color: Colors.white54),
                      ),
                    )
                  : ListView.builder(
                      shrinkWrap: true,
                      itemCount: _filteredTokens.length,
                      itemBuilder: (context, index) {
                        final token = _filteredTokens[index];
                        // Use cached network images or default icons
                        return _buildTokenOption(context, token);
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTokenOption(BuildContext context, Token token) {
    return InkWell(
      onTap: () => Navigator.pop(context, token),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.05),
          borderRadius: BorderRadius.circular(12),
        ),
        margin: const EdgeInsets.only(bottom: 12),
        child: Row(
          children: [
            Container(
              width: 32,
              height: 32,
              decoration: const BoxDecoration(shape: BoxShape.circle),
              child: TokenIcon(
                tokenSymbol: token.symbol,
                tokenAddress: token.contractAddress,
                tokenImageUrl: token.imageUrl,
                size: 32,
                chainId: widget.chainId,
              ),
            ),
            const SizedBox(width: 16),
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
                  Text(
                    token.symbol,
                    style: GoogleFonts.outfit(
                      fontSize: 12,
                      color: Colors.white54,
                    ),
                  ),
                ],
              ),
            ),
            Text(
              token.balance.toStringAsFixed(4),
              style: GoogleFonts.outfit(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: Colors.white,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
