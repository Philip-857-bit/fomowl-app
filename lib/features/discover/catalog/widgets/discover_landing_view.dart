import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

import '../../../../constants/app_colors.dart';
import '../../../../l10n/app_localizations.dart';
import '../../market/discover_trending_token.dart';
import '../discover_dapp_entry.dart';

class DiscoverLandingView extends StatelessWidget {
  const DiscoverLandingView({
    super.key,
    required this.featuredDapps,
    required this.trendingDapps,
    required this.filteredDapps,
    required this.categories,
    required this.trendingTokens,
    required this.loadingTrendingTokens,
    required this.trendingTokensError,
    required this.loading,
    required this.error,
    required this.onRefresh,
    required this.onOpenDapp,
  });

  final List<DiscoverDappEntry> featuredDapps;
  final List<DiscoverDappEntry> trendingDapps;
  final List<DiscoverDappEntry> filteredDapps;
  final List<String> categories;
  final List<DiscoverTrendingToken> trendingTokens;
  final bool loadingTrendingTokens;
  final String? trendingTokensError;
  final bool loading;
  final String? error;
  final Future<void> Function() onRefresh;
  final ValueChanged<DiscoverDappEntry> onOpenDapp;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    if (loading && featuredDapps.isEmpty && filteredDapps.isEmpty) {
      return const Center(
        child: CircularProgressIndicator(color: AppColors.accentRed),
      );
    }

    return RefreshIndicator(
      color: AppColors.accentRed,
      onRefresh: onRefresh,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
        children: [
          const _CashInCard(),
          const SizedBox(height: 20),
          if (error != null && error!.trim().isNotEmpty) ...[
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: AppColors.warning.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(18),
                border: Border.all(
                  color: AppColors.warning.withValues(alpha: 0.35),
                ),
              ),
              child: Text(
                error!,
                style: GoogleFonts.outfit(color: Colors.white70),
              ),
            ),
            const SizedBox(height: 16),
          ],
          _SectionHeader(
            title: l.discoverTrendingTokensTitle,
            subtitle: l.discoverTrendingTokensSubtitle,
          ),
          const SizedBox(height: 12),
          _TrendingTokenSection(
            tokens: trendingTokens,
            loading: loadingTrendingTokens,
            error: trendingTokensError,
          ),
          const SizedBox(height: 20),
          if (featuredDapps.isNotEmpty) ...[
            _SectionHeader(
              title: l.discoverFeaturedDappsTitle,
              subtitle: l.discoverFeaturedDappsSubtitle,
            ),
            const SizedBox(height: 14),
            ...featuredDapps
                .take(3)
                .map(
                  (entry) => Padding(
                    padding: const EdgeInsets.only(bottom: 14),
                    child: _FeaturedDappCard(
                      key: ValueKey('discover-featured-${entry.id}'),
                      entry: entry,
                      onTap: () => onOpenDapp(entry),
                    ),
                  ),
                ),
            const SizedBox(height: 12),
          ],
          if (trendingDapps.isNotEmpty) ...[
            _SectionHeader(
              title: l.discoverTrendingDappsTitle,
              subtitle: l.discoverTrendingDappsSubtitle,
            ),
            const SizedBox(height: 12),
            SizedBox(
              height: 210,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: trendingDapps.length.clamp(0, 10),
                separatorBuilder: (_, _) => const SizedBox(width: 12),
                itemBuilder: (context, index) {
                  final entry = trendingDapps[index];
                  return SizedBox(
                    width: 220,
                    child: _CompactDappCard(
                      key: ValueKey('discover-trending-${entry.id}'),
                      entry: entry,
                      onTap: () => onOpenDapp(entry),
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 20),
          ],
          if (categories.isNotEmpty) ...[
            _SectionHeader(
              title: l.discoverCategoriesTitle,
              subtitle: l.discoverCategoriesSubtitle,
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: categories
                  .map(
                    (category) => Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 10,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.cardDark,
                        borderRadius: BorderRadius.circular(999),
                        border: Border.all(color: AppColors.divider),
                      ),
                      child: Text(
                        _localizedCategoryLabel(context, category),
                        style: GoogleFonts.outfit(color: Colors.white70),
                      ),
                    ),
                  )
                  .toList(growable: false),
            ),
            const SizedBox(height: 20),
          ],
          _SectionHeader(
            title: l.discoverAllApprovedDappsTitle,
            subtitle: filteredDapps.isEmpty
                ? l.discoverAllApprovedDappsNoMatches
                : l.discoverAllApprovedDappsCount(filteredDapps.length),
          ),
          const SizedBox(height: 12),
          ...filteredDapps.map(
            (entry) => Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: _CompactDappCard(
                key: ValueKey('discover-all-${entry.id}'),
                entry: entry,
                onTap: () => onOpenDapp(entry),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

String _localizedCategoryLabel(BuildContext context, String category) {
  final l = AppLocalizations.of(context);
  switch (category.trim().toLowerCase()) {
    case 'dex':
      return l.discoverCategoryDex;
    case 'defi':
      return l.discoverCategoryDefi;
    case 'swap':
      return l.discoverCategorySwap;
    case 'lending':
      return l.discoverCategoryLending;
    case 'nft':
      return l.discoverCategoryNft;
    case 'marketplace':
      return l.discoverCategoryMarketplace;
    case 'collectibles':
      return l.discoverCategoryCollectibles;
    default:
      return category;
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.title, required this.subtitle});

  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: GoogleFonts.outfit(
            color: Colors.white,
            fontSize: 22,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          subtitle,
          style: GoogleFonts.outfit(
            color: AppColors.textSecondary,
            fontSize: 13,
          ),
        ),
      ],
    );
  }
}

class _CashInCard extends StatelessWidget {
  const _CashInCard();

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(28),
        gradient: const LinearGradient(
          colors: [Color(0xFF0E5C46), Color(0xFF1A7C66), Color(0xFF275E4B)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF0E5C46).withValues(alpha: 0.22),
            blurRadius: 24,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(999),
            ),
            child: Text(
              l.discoverCashInBadge,
              style: GoogleFonts.outfit(
                color: Colors.white,
                fontSize: 11,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.5,
              ),
            ),
          ),
          const SizedBox(height: 22),
          Text(
            l.discoverCashInTitle,
            style: GoogleFonts.outfit(
              color: Colors.white,
              fontSize: 34,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            l.discoverCashInDescription,
            style: GoogleFonts.outfit(
              color: Colors.white.withValues(alpha: 0.82),
              fontSize: 15,
              height: 1.45,
            ),
          ),
          const SizedBox(height: 22),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(18),
            ),
            child: Text(
              l.discoverGoLabel,
              style: GoogleFonts.outfit(
                color: const Color(0xFF0E5C46),
                fontSize: 18,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _TrendingTokenSection extends StatelessWidget {
  const _TrendingTokenSection({
    required this.tokens,
    required this.loading,
    required this.error,
  });

  final List<DiscoverTrendingToken> tokens;
  final bool loading;
  final String? error;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    if (loading && tokens.isEmpty) {
      return Container(
        height: 150,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: AppColors.cardDark,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: AppColors.divider),
        ),
        child: const CircularProgressIndicator(color: AppColors.accentRed),
      );
    }

    if (error != null && error!.trim().isNotEmpty && tokens.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.cardDark,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: AppColors.divider),
        ),
        child: Text(error!, style: GoogleFonts.outfit(color: Colors.white70)),
      );
    }

    if (tokens.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.cardDark,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: AppColors.divider),
        ),
        child: Text(
          l.discoverNoTrendingTokens,
          style: GoogleFonts.outfit(color: Colors.white70),
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.cardDark,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppColors.divider),
      ),
      child: Column(
        children: tokens
            .map(
              (token) => Padding(
                padding: EdgeInsets.only(bottom: token == tokens.last ? 0 : 14),
                child: _TrendingTokenRow(token: token),
              ),
            )
            .toList(growable: false),
      ),
    );
  }
}

class _TrendingTokenRow extends StatelessWidget {
  const _TrendingTokenRow({required this.token});

  final DiscoverTrendingToken token;

  @override
  Widget build(BuildContext context) {
    final isPositiveChange = token.changePercent24h > 0;
    final isNegativeChange = token.changePercent24h < 0;
    final currencyFormatter = NumberFormat.currency(
      symbol: '\$',
      decimalDigits: token.priceUsd >= 100
          ? 2
          : token.priceUsd >= 1
          ? 2
          : 4,
    );

    return Row(
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(999),
          child: Image.network(
            token.imageUrl,
            width: 44,
            height: 44,
            fit: BoxFit.cover,
            errorBuilder: (_, _, _) => Container(
              width: 44,
              height: 44,
              decoration: const BoxDecoration(
                color: AppColors.inputBackground,
                shape: BoxShape.circle,
              ),
              alignment: Alignment.center,
              child: Text(
                token.symbol.substring(0, 1),
                style: GoogleFonts.outfit(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                token.name,
                style: GoogleFonts.outfit(
                  color: Colors.white,
                  fontSize: 17,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                token.symbol,
                style: GoogleFonts.outfit(
                  color: AppColors.textSecondary,
                  fontSize: 13,
                ),
              ),
            ],
          ),
        ),
        Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              currencyFormatter.format(token.priceUsd),
              style: GoogleFonts.outfit(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              '${isPositiveChange ? '+' : ''}${token.changePercent24h.toStringAsFixed(2)}%',
              style: GoogleFonts.outfit(
                color: isPositiveChange
                    ? AppColors.success
                    : isNegativeChange
                    ? AppColors.error
                    : AppColors.textSecondary,
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _FeaturedDappCard extends StatelessWidget {
  const _FeaturedDappCard({
    super.key,
    required this.entry,
    required this.onTap,
  });

  final DiscoverDappEntry entry;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(28),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(28),
          gradient: LinearGradient(
            colors: [
              const Color(0xFF0B523C),
              const Color(0xFF114E73),
              const Color(0xFF191228),
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          border: Border.all(color: AppColors.divider),
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if ((entry.badgeText ?? '').trim().isNotEmpty) ...[
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 7,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Text(
                        entry.badgeText!,
                        style: GoogleFonts.outfit(
                          color: Colors.white,
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],
                  Text(
                    entry.title,
                    style: GoogleFonts.outfit(
                      color: Colors.white,
                      fontSize: 28,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  if ((entry.subtitle ?? '').trim().isNotEmpty) ...[
                    const SizedBox(height: 10),
                    Text(
                      entry.subtitle!,
                      style: GoogleFonts.outfit(
                        color: Colors.white70,
                        fontSize: 15,
                        height: 1.45,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(width: 16),
            _DappArtwork(entry: entry, size: 72),
          ],
        ),
      ),
    );
  }
}

class _CompactDappCard extends StatelessWidget {
  const _CompactDappCard({super.key, required this.entry, required this.onTap});

  final DiscoverDappEntry entry;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(22),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.cardDark,
          borderRadius: BorderRadius.circular(22),
          border: Border.all(color: AppColors.divider),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                _DappArtwork(entry: entry, size: 48),
                const Spacer(),
                if ((entry.badgeText ?? '').trim().isNotEmpty)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(
                      entry.badgeText!,
                      style: GoogleFonts.outfit(
                        color: Colors.white70,
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.3,
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 16),
            Text(
              entry.title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: GoogleFonts.outfit(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              entry.subtitle?.trim().isNotEmpty == true
                  ? entry.subtitle!
                  : entry.origin,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: GoogleFonts.outfit(
                color: Colors.white70,
                fontSize: 13,
                height: 1.4,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DappArtwork extends StatelessWidget {
  const _DappArtwork({required this.entry, required this.size});

  final DiscoverDappEntry entry;
  final double size;

  @override
  Widget build(BuildContext context) {
    final imageUrl = (entry.logoUrl?.trim().isNotEmpty == true)
        ? entry.logoUrl
        : entry.heroImageUrl;
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(size * 0.32),
      ),
      clipBehavior: Clip.antiAlias,
      child: imageUrl == null
          ? Center(
              child: Text(
                entry.title.isEmpty
                    ? '?'
                    : entry.title.characters.first.toUpperCase(),
                style: GoogleFonts.outfit(
                  color: Colors.white,
                  fontSize: size * 0.34,
                  fontWeight: FontWeight.w700,
                ),
              ),
            )
          : Image.network(
              imageUrl,
              fit: BoxFit.cover,
              errorBuilder: (_, _, _) => Center(
                child: Text(
                  entry.title.isEmpty
                      ? '?'
                      : entry.title.characters.first.toUpperCase(),
                  style: GoogleFonts.outfit(
                    color: Colors.white,
                    fontSize: size * 0.34,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
    );
  }
}
