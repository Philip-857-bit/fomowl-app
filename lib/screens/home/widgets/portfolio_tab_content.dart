import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../constants/app_colors.dart';
import '../../../l10n/app_localizations.dart';
import '../../../models/token.dart';
import '../../../utils/value_formatter.dart';
import '../home_portfolio_data.dart';
import 'home_token_list_item.dart';

class PortfolioTabContent extends StatefulWidget {
  const PortfolioTabContent({
    super.key,
    required this.sections,
    required this.isLoading,
    required this.localization,
    required this.onSelectToken,
  });

  final List<HomePortfolioSection> sections;
  final bool isLoading;
  final AppLocalizations localization;
  final void Function(Token token) onSelectToken;

  @override
  State<PortfolioTabContent> createState() => _PortfolioTabContentState();
}

class _PortfolioTabContentState extends State<PortfolioTabContent> {
  Set<int> _expandedChainIds = <int>{};

  @override
  void initState() {
    super.initState();
    _syncExpandedChainIds();
  }

  @override
  void didUpdateWidget(covariant PortfolioTabContent oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.sections != widget.sections) {
      _syncExpandedChainIds();
    }
  }

  void _syncExpandedChainIds() {
    final availableIds = widget.sections.map(
      (section) => section.chain.chainId,
    );
    final nextIds = _expandedChainIds
        .where((chainId) => availableIds.contains(chainId))
        .toSet();
    for (final chainId in availableIds) {
      nextIds.add(chainId);
    }
    _expandedChainIds = nextIds;
  }

  @override
  Widget build(BuildContext context) {
    if (widget.isLoading && widget.sections.isEmpty) {
      return const Padding(
        padding: EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        child: LinearProgressIndicator(
          minHeight: 3,
          color: AppColors.accentRed,
          backgroundColor: Color(0x22111111),
        ),
      );
    }

    if (widget.sections.isEmpty) {
      return Padding(
        padding: const EdgeInsets.all(40),
        child: Center(
          child: Column(
            children: [
              Icon(
                Icons.pie_chart_outline,
                size: 60,
                color: Colors.white.withValues(alpha: 0.2),
              ),
              const SizedBox(height: 16),
              Text(
                widget.localization.noTokensYet,
                style: GoogleFonts.outfit(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                widget.localization.depositTokens,
                style: GoogleFonts.outfit(fontSize: 14, color: Colors.white54),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      );
    }

    return Column(children: widget.sections.map(_buildChainSection).toList());
  }

  Widget _buildChainSection(HomePortfolioSection section) {
    final isExpanded = _expandedChainIds.contains(section.chain.chainId);
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 6, 16, 6),
            child: InkWell(
              borderRadius: BorderRadius.circular(18),
              onTap: () {
                setState(() {
                  if (isExpanded) {
                    _expandedChainIds.remove(section.chain.chainId);
                  } else {
                    _expandedChainIds.add(section.chain.chainId);
                  }
                });
              },
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(
                  children: [
                    _ChainMarker(chainLogoUrl: section.chain.logoUrl),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        section.chain.name.toUpperCase(),
                        style: GoogleFonts.outfit(
                          fontSize: 17,
                          fontWeight: FontWeight.w600,
                          color: Colors.white.withValues(alpha: 0.82),
                          letterSpacing: 0.7,
                        ),
                      ),
                    ),
                    Text(
                      ValueFormatter.formatCurrencyWithGrouping(
                        section.totalBalanceUsd,
                      ),
                      style: GoogleFonts.outfit(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Icon(
                      isExpanded
                          ? Icons.keyboard_arrow_up
                          : Icons.keyboard_arrow_down,
                      color: Colors.white.withValues(alpha: 0.7),
                    ),
                  ],
                ),
              ),
            ),
          ),
          if (isExpanded)
            ...section.tokens.map(
              (token) => HomeTokenListItem(
                token: token,
                chainId: section.chain.chainId,
                onTap: () => widget.onSelectToken(token),
              ),
            ),
          if (isExpanded) const SizedBox(height: 4),
        ],
      ),
    );
  }
}

class _ChainMarker extends StatelessWidget {
  const _ChainMarker({required this.chainLogoUrl});

  final String? chainLogoUrl;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 22,
      height: 22,
      decoration: const BoxDecoration(
        color: Color(0x14FFFFFF),
        shape: BoxShape.circle,
      ),
      child: ClipOval(
        child: chainLogoUrl != null && chainLogoUrl!.isNotEmpty
            ? Image.network(
                chainLogoUrl!,
                fit: BoxFit.cover,
                errorBuilder: (_, _, _) =>
                    const Icon(Icons.blur_on, color: Colors.white, size: 14),
              )
            : const Icon(Icons.blur_on, color: Colors.white, size: 14),
      ),
    );
  }
}
