import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../constants/app_colors.dart';
import '../discover_dapp_entry.dart';

class DiscoverLandingView extends StatelessWidget {
  const DiscoverLandingView({
    super.key,
    required this.featuredDapps,
    required this.trendingDapps,
    required this.filteredDapps,
    required this.categories,
    required this.loading,
    required this.error,
    required this.onRefresh,
    required this.onOpenDapp,
  });

  final List<DiscoverDappEntry> featuredDapps;
  final List<DiscoverDappEntry> trendingDapps;
  final List<DiscoverDappEntry> filteredDapps;
  final List<String> categories;
  final bool loading;
  final String? error;
  final Future<void> Function() onRefresh;
  final ValueChanged<DiscoverDappEntry> onOpenDapp;

  @override
  Widget build(BuildContext context) {
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
          if (featuredDapps.isNotEmpty) ...[
            _SectionHeader(
              title: 'Featured DApps',
              subtitle: 'Curated DApps approved for Owllet.',
            ),
            const SizedBox(height: 14),
            ...featuredDapps
                .take(3)
                .map(
                  (entry) => Padding(
                    padding: const EdgeInsets.only(bottom: 14),
                    child: _FeaturedDappCard(
                      entry: entry,
                      onTap: () => onOpenDapp(entry),
                    ),
                  ),
                ),
            const SizedBox(height: 12),
          ],
          if (trendingDapps.isNotEmpty) ...[
            _SectionHeader(
              title: 'Trending',
              subtitle: 'Popular allowlisted destinations.',
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
              title: 'Categories',
              subtitle: 'Search stays inside the Owllet allowlist.',
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
                        category,
                        style: GoogleFonts.outfit(color: Colors.white70),
                      ),
                    ),
                  )
                  .toList(growable: false),
            ),
            const SizedBox(height: 20),
          ],
          _SectionHeader(
            title: 'All approved DApps',
            subtitle: filteredDapps.isEmpty
                ? 'No DApps matched your search.'
                : '${filteredDapps.length} allowlisted destinations.',
          ),
          const SizedBox(height: 12),
          ...filteredDapps.map(
            (entry) => Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: _CompactDappCard(
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

class _FeaturedDappCard extends StatelessWidget {
  const _FeaturedDappCard({required this.entry, required this.onTap});

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
  const _CompactDappCard({required this.entry, required this.onTap});

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
