import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../constants/app_colors.dart';
import '../../models/token.dart';

class TokenSelectorDialog extends StatelessWidget {
  final List<Token> tokens;
  const TokenSelectorDialog({super.key, required this.tokens});

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
                style: GoogleFonts.outfit(color: Colors.white),
                decoration: InputDecoration(
                  border: InputBorder.none,
                  hintText: 'Search receiving token',
                  hintStyle: GoogleFonts.outfit(
                    color: Colors.white.withValues(alpha: 0.5),
                  ),
                  icon: Icon(Icons.search, color: Colors.white.withValues(alpha: 0.5)),
                ),
              ),
            ),
            const SizedBox(height: 24),
            
            // Token Options
            ConstrainedBox(
              constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.4),
              child: tokens.isEmpty 
                ? Center(
                    child: Text('No tokens found', style: GoogleFonts.outfit(color: Colors.white54)),
                  )
                : ListView.builder(
                    shrinkWrap: true,
                    itemCount: tokens.length,
                    itemBuilder: (context, index) {
                      final token = tokens[index];
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
              width: 32, height: 32,
              decoration: const BoxDecoration(
                color: AppColors.accentRed,
                shape: BoxShape.circle,
              ),
              child: token.imageUrl != null
                  ? ClipOval(child: Image.network(token.imageUrl!, fit: BoxFit.cover, errorBuilder: (context, error, stackTrace) => _defaultIcon(token)))
                  : _defaultIcon(token),
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

  Widget _defaultIcon(Token token) {
    return Center(
      child: Text(
        token.symbol.isNotEmpty ? token.symbol[0] : '?',
        style: GoogleFonts.outfit(fontSize: 14, fontWeight: FontWeight.w600, color: Colors.white),
      ),
    );
  }
}
