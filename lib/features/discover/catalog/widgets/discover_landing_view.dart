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
    required this.query,
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
    this.onOpenCashIn,
  });

  final String query;
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
  final VoidCallback? onOpenCashIn;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final trimmedQuery = query.trim();
    final isSearching = trimmedQuery.isNotEmpty;
    final visibleFeaturedDapps = featuredDapps.isNotEmpty
        ? featuredDapps
        : filteredDapps.take(6).toList(growable: false);
    final shouldShowCatalogError =
        !isSearching &&
        error != null &&
        error!.trim().isNotEmpty &&
        visibleFeaturedDapps.isEmpty;
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
          if (!isSearching) ...[
            _CashInCard(onTap: onOpenCashIn),
            const SizedBox(height: 24),
          ],
          if (shouldShowCatalogError) ...[
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
          if (isSearching) ...[
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
          ] else ...[
            _SectionHeader(
              title: l.discoverFeaturedDappsTitle,
              subtitle: l.discoverFeaturedDappsSubtitle,
            ),
            const SizedBox(height: 14),
            SizedBox(
              height: 210,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: visibleFeaturedDapps.length.clamp(0, 10),
                separatorBuilder: (_, _) => const SizedBox(width: 12),
                itemBuilder: (context, index) {
                  final entry = visibleFeaturedDapps[index];
                  return SizedBox(
                    width: 240,
                    child: _CompactDappCard(
                      key: ValueKey('discover-featured-${entry.id}'),
                      entry: entry,
                      onTap: () => onOpenDapp(entry),
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 24),
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
          ],
        ],
      ),
    );
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
  const _CashInCard({this.onTap});

  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(28),
        child: Container(
          padding: const EdgeInsets.all(16),
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
                padding: const EdgeInsets.symmetric(
                  horizontal: 11,
                  vertical: 6,
                ),
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
              const SizedBox(height: 14),
              Text(
                l.discoverCashInTitle,
                style: GoogleFonts.outfit(
                  color: Colors.white,
                  fontSize: 28,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                l.discoverCashInDescription,
                style: GoogleFonts.outfit(
                  color: Colors.white.withValues(alpha: 0.82),
                  fontSize: 13,
                  height: 1.35,
                ),
              ),
              const SizedBox(height: 14),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 9,
                ),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Text(
                  l.discoverGoLabel,
                  style: GoogleFonts.outfit(
                    color: const Color(0xFF0E5C46),
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
        ),
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

  String? _resolveImageUrl() {
    if (entry.slug.toLowerCase() == 'opensea') {
      return 'https://storage.googleapis.com/opensea-static/Logomark/Logomark-Blue.png';
    }
    final logoUrl = entry.logoUrl?.trim();
    if (logoUrl != null && logoUrl.isNotEmpty) {
      return logoUrl;
    }
    final heroImageUrl = entry.heroImageUrl?.trim();
    if (heroImageUrl != null && heroImageUrl.isNotEmpty) {
      return heroImageUrl;
    }
    final fallbackSource = entry.launchUrl.trim().isNotEmpty
        ? entry.launchUrl.trim()
        : entry.origin.trim();
    if (fallbackSource.isNotEmpty) {
      return 'https://www.google.com/s2/favicons?sz=128&domain_url=${Uri.encodeComponent(fallbackSource)}';
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final imageUrl = _resolveImageUrl();
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
