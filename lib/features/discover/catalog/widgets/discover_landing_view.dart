import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../constants/app_colors.dart';
import '../../../../l10n/app_localizations.dart';
import '../discover_dapp_entry.dart';
import '../discover_product_entry.dart';

class DiscoverLandingView extends StatefulWidget {
  const DiscoverLandingView({
    super.key,
    required this.query,
    required this.products,
    required this.dapps,
    required this.filteredDapps,
    required this.categories,
    required this.loading,
    required this.error,
    required this.onRefresh,
    required this.onOpenProduct,
    required this.onOpenDapp,
    required this.onOpenOwlletPay,
  });

  final String query;
  final List<DiscoverProductEntry> products;
  final List<DiscoverDappEntry> dapps;
  final List<DiscoverDappEntry> filteredDapps;
  final List<String> categories;
  final bool loading;
  final String? error;
  final Future<void> Function() onRefresh;
  final ValueChanged<DiscoverProductEntry> onOpenProduct;
  final ValueChanged<DiscoverDappEntry> onOpenDapp;
  final VoidCallback onOpenOwlletPay;

  @override
  State<DiscoverLandingView> createState() => _DiscoverLandingViewState();
}

class _DiscoverLandingViewState extends State<DiscoverLandingView> {
  final ScrollController _scrollController = ScrollController();
  final GlobalKey _exploreKey = GlobalKey();
  String _selectedCategory = 'Featured';
  bool _showAllDapps = false;

  bool get _isSearching => widget.query.trim().isNotEmpty;

  @override
  void didUpdateWidget(covariant DiscoverLandingView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!widget.categories.contains(_selectedCategory)) {
      _selectedCategory = 'Featured';
    }
    if (oldWidget.query != widget.query && _isSearching) {
      _showAllDapps = true;
    }
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  List<DiscoverDappEntry> get _categoryDapps {
    if (_isSearching) {
      return widget.filteredDapps;
    }
    final matches = widget.dapps
        .where(
          (dapp) =>
              DiscoverProductEntry.matchesCategory(dapp, _selectedCategory),
        )
        .toList(growable: false);
    if (_selectedCategory == 'Featured' && matches.isEmpty) {
      return widget.dapps;
    }
    return matches;
  }

  List<DiscoverDappEntry> get _visibleDapps {
    final dapps = _categoryDapps;
    if (_isSearching || _showAllDapps) {
      return dapps;
    }
    return dapps.take(4).toList(growable: false);
  }

  void _showFeaturedExplore() {
    setState(() {
      _selectedCategory = 'Featured';
      _showAllDapps = false;
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final exploreContext = _exploreKey.currentContext;
      if (exploreContext == null) {
        return;
      }
      Scrollable.ensureVisible(
        exploreContext,
        duration: const Duration(milliseconds: 320),
        curve: Curves.easeOutCubic,
        alignment: 0.08,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    if (widget.loading &&
        widget.products.isEmpty &&
        widget.dapps.isEmpty &&
        widget.filteredDapps.isEmpty) {
      return const Center(
        child: CircularProgressIndicator(color: AppColors.accentRed),
      );
    }

    return RefreshIndicator(
      color: AppColors.accentRed,
      onRefresh: widget.onRefresh,
      child: ListView(
        key: const ValueKey('discover-landing-list'),
        controller: _scrollController,
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 28),
        children: [
          if (_isSearching)
            _buildSearchResults(context)
          else ...[
            _OwlletPayBanner(onTap: widget.onOpenOwlletPay),
            const SizedBox(height: 24),
            _SectionTitle(
              title: l.discoverProductsTitle,
              actionLabel: l.viewAll,
              onAction: _showFeaturedExplore,
            ),
            const SizedBox(height: 12),
            _ProductsCarousel(
              products: widget.products,
              onOpenProduct: widget.onOpenProduct,
            ),
            const SizedBox(height: 28),
            _buildExplore(context),
          ],
        ],
      ),
    );
  }

  Widget _buildSearchResults(BuildContext context) {
    final l = AppLocalizations.of(context);
    final matches = widget.filteredDapps;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _SectionTitle(
          title: l.discoverSearchResultsTitle,
          subtitle: matches.isEmpty
              ? l.discoverAllApprovedDappsNoMatches
              : l.discoverAllApprovedDappsCount(matches.length),
        ),
        const SizedBox(height: 14),
        if (matches.isEmpty)
          _EmptyCatalogCard(message: l.discoverAllApprovedDappsNoMatches)
        else
          ...matches.map(
            (entry) => Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: _CompactDappCard(
                key: ValueKey('discover-search-${entry.id}'),
                entry: entry,
                onTap: () => widget.onOpenDapp(entry),
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildExplore(BuildContext context) {
    final l = AppLocalizations.of(context);
    final visibleDapps = _visibleDapps;
    final hasMore =
        !_showAllDapps && _categoryDapps.length > visibleDapps.length;
    final hasError = widget.error?.trim().isNotEmpty == true;

    return Column(
      key: _exploreKey,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _SectionTitle(
          title: l.discoverExploreTitle,
          actionLabel: hasMore ? l.viewAll : null,
          onAction: hasMore ? () => setState(() => _showAllDapps = true) : null,
        ),
        const SizedBox(height: 14),
        SizedBox(
          height: 38,
          child: ListView.separated(
            key: const ValueKey('discover-category-chips'),
            scrollDirection: Axis.horizontal,
            itemCount: widget.categories.length,
            separatorBuilder: (_, _) => const SizedBox(width: 8),
            itemBuilder: (context, index) {
              final category = widget.categories[index];
              return _CategoryChip(
                label: category,
                selected: category == _selectedCategory,
                onTap: () {
                  setState(() {
                    _selectedCategory = category;
                    _showAllDapps = false;
                  });
                },
              );
            },
          ),
        ),
        const SizedBox(height: 14),
        if (hasError) ...[
          _CatalogNotice(message: widget.error!),
          const SizedBox(height: 12),
        ],
        if (widget.loading && widget.dapps.isEmpty)
          const _CatalogLoadingCard()
        else if (visibleDapps.isEmpty)
          _EmptyCatalogCard(message: l.discoverAllApprovedDappsNoMatches)
        else
          ...visibleDapps.map(
            (entry) => Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: _CompactDappCard(
                key: ValueKey('discover-dapp-${entry.id}'),
                entry: entry,
                onTap: () => widget.onOpenDapp(entry),
              ),
            ),
          ),
      ],
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle({
    required this.title,
    this.subtitle,
    this.actionLabel,
    this.onAction,
  });

  final String title;
  final String? subtitle;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: GoogleFonts.inter(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  letterSpacing: -0.2,
                ),
              ),
              if (subtitle != null) ...[
                const SizedBox(height: 2),
                Text(
                  subtitle!,
                  style: GoogleFonts.inter(
                    color: const Color(0xFFA0A0A0),
                    fontSize: 12,
                  ),
                ),
              ],
            ],
          ),
        ),
        if (actionLabel != null && onAction != null)
          TextButton(
            key: ValueKey('view-all-${title.toLowerCase()}'),
            onPressed: onAction,
            style: TextButton.styleFrom(
              foregroundColor: const Color(0xFFA0A0A0),
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
              minimumSize: Size.zero,
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  actionLabel!,
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: const Color(0xFFA0A0A0),
                  ),
                ),
                const SizedBox(width: 2),
                const Icon(
                  Icons.chevron_right_rounded,
                  size: 16,
                  color: Color(0xFFA0A0A0),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

class _OwlletPayBanner extends StatelessWidget {
  const _OwlletPayBanner({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        key: const ValueKey('discover-owllet-pay-banner'),
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Ink(
          height: 99,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            gradient: const LinearGradient(
              colors: [Color(0xFF121212), Color(0xFF3E0103)],
              begin: Alignment.centerLeft,
              end: Alignment.centerRight,
              stops: [0.49, 1.0],
            ),
          ),
          child: Stack(
            clipBehavior: Clip.antiAlias,
            children: [
              Positioned(
                right: 0,
                bottom: 0,
                child: Image.asset(
                  'assets/images/discover/promo_banner_mascot.png',
                  width: 77,
                  height: 89,
                  fit: BoxFit.cover,
                  errorBuilder: (_, _, _) => Image.asset(
                    'assets/images/owl_wallet.png',
                    width: 77,
                    height: 89,
                    fit: BoxFit.contain,
                  ),
                ),
              ),
              Positioned.fill(
                child: Padding(
                  padding: const EdgeInsets.only(
                    left: 13,
                    right: 84,
                    top: 11,
                    bottom: 11,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Flexible(
                        child: Text(
                          'Pay Bills & Buy Crypto',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.inter(
                            color: const Color(0xFFEA2A33),
                            fontSize: 19,
                            fontWeight: FontWeight.w700,
                            height: 1.07,
                          ),
                        ),
                      ),
                      const SizedBox(height: 9),
                      Flexible(
                        child: Text(
                          'Try OwlletPay - Fast & Easy',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.inter(
                            color: Colors.white,
                            fontSize: 8,
                            fontWeight: FontWeight.w500,
                            height: 1.07,
                          ),
                        ),
                      ),
                      const SizedBox(height: 9),
                      FittedBox(
                        fit: BoxFit.scaleDown,
                        alignment: Alignment.centerLeft,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 5,
                            vertical: 3,
                          ),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(6),
                            gradient: const LinearGradient(
                              colors: [Color(0xFF006C4B), Color(0xFF00D292)],
                              begin: Alignment.bottomCenter,
                              end: Alignment.topCenter,
                              stops: [0.10, 1.0],
                            ),
                          ),
                          child: Text(
                            'Open OwlletPay',
                            style: GoogleFonts.inter(
                              color: Colors.white,
                              fontSize: 10.5,
                              fontWeight: FontWeight.w600,
                              height: 1.07,
                            ),
                          ),
                        ),
                      ),
                    ],
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

class _ProductsCarousel extends StatelessWidget {
  const _ProductsCarousel({
    required this.products,
    required this.onOpenProduct,
  });

  final List<DiscoverProductEntry> products;
  final ValueChanged<DiscoverProductEntry> onOpenProduct;

  @override
  Widget build(BuildContext context) {
    if (products.isEmpty) {
      return const _EmptyProductsCard();
    }
    return SizedBox(
      height: 242,
      child: ListView.separated(
        key: const ValueKey('discover-products-carousel'),
        scrollDirection: Axis.horizontal,
        itemCount: products.length,
        separatorBuilder: (_, _) => const SizedBox(width: 14),
        itemBuilder: (context, index) {
          final product = products[index];
          return SizedBox(
            width: 160,
            child: _ProductCard(
              key: ValueKey('discover-product-${product.id}'),
              product: product,
              index: index,
              onTap: () => onOpenProduct(product),
            ),
          );
        },
      ),
    );
  }
}

class _ProductCard extends StatelessWidget {
  const _ProductCard({
    super.key,
    required this.product,
    required this.index,
    required this.onTap,
  });

  final DiscoverProductEntry product;
  final int index;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 160,
            height: 156,
            decoration: BoxDecoration(
              color: const Color(0xFF1E1E1E),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: Colors.white.withValues(alpha: 0.08),
              ),
            ),
            alignment: Alignment.center,
            child: _ProductArtwork(product: product),
          ),
          const SizedBox(height: 6),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  product.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.inter(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    letterSpacing: -0.2,
                  ),
                ),
                const SizedBox(height: 2),
                Expanded(
                  child: Text(
                    product.description,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.inter(
                      color: const Color(0xFFA0A0A0),
                      fontSize: 12,
                      fontWeight: FontWeight.w400,
                      height: 1.25,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ProductArtwork extends StatelessWidget {
  const _ProductArtwork({required this.product});

  final DiscoverProductEntry product;

  @override
  Widget build(BuildContext context) {
    final asset = product.artworkAssetPath;
    final network = product.networkArtworkUrl;
    if (asset != null) {
      return Image.asset(asset, width: 140, height: 140, fit: BoxFit.contain);
    }
    if (network != null && network.trim().isNotEmpty) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(10),
        child: Image.network(
          network,
          width: 140,
          height: 140,
          fit: BoxFit.cover,
          errorBuilder: (_, _, _) => _BrandedArtwork(title: product.title),
        ),
      );
    }
    return _BrandedArtwork(title: product.title);
  }
}

class _BrandedArtwork extends StatelessWidget {
  const _BrandedArtwork({required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 104,
      height: 104,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: Colors.black.withValues(alpha: 0.24),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: Stack(
        alignment: Alignment.center,
        children: [
          Opacity(
            opacity: 0.35,
            child: Image.asset(
              'assets/images/logo.png',
              width: 66,
              height: 66,
              fit: BoxFit.contain,
            ),
          ),
          Text(
            title.trim().isEmpty ? '?' : title.trim()[0].toUpperCase(),
            style: GoogleFonts.inter(
              color: Colors.white,
              fontSize: 28,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}

class _CategoryChip extends StatelessWidget {
  const _CategoryChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      key: ValueKey('discover-category-$label'),
      onTap: onTap,
      borderRadius: BorderRadius.circular(999),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 7),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: const Color(0xFF1E1E1E),
          borderRadius: BorderRadius.circular(999),
          border: Border.all(
            color: selected ? const Color(0xFFEF4444) : Colors.transparent,
            width: 1,
          ),
        ),
        child: Text(
          label,
          style: GoogleFonts.inter(
            color: selected ? const Color(0xFFEF4444) : const Color(0xFFA0A0A0),
            fontSize: 13,
            fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
          ),
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
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: Row(
            children: [
              _DappLogo(entry: entry),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      entry.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.inter(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        letterSpacing: -0.2,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      entry.subtitle ?? entry.origin,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.inter(
                        color: const Color(0xFFA0A0A0),
                        fontSize: 13,
                        fontWeight: FontWeight.w400,
                      ),
                    ),
                  ],
                ),
              ),
              if (entry.badgeText?.trim().isNotEmpty == true) ...[
                const SizedBox(width: 10),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.accentRed.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    entry.badgeText!,
                    style: GoogleFonts.inter(
                      color: AppColors.accentRed,
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _DappLogo extends StatelessWidget {
  const _DappLogo({required this.entry});

  final DiscoverDappEntry entry;

  String? get _localAssetPath {
    final slug = entry.slug.toLowerCase();
    final id = entry.id.toLowerCase();
    if (slug.contains('pancake') || id.contains('pancake')) {
      return 'assets/images/discover/pancakeswap_dapp_logo.png';
    }
    if (slug.contains('owllet') || id.contains('owllet')) {
      return 'assets/images/discover/owlletpay_dapp_logo.png';
    }
    if (slug.contains('nft') || id.contains('nft')) {
      return 'assets/images/discover/fomowl_nfts_dapp_logo.png';
    }
    if (slug.contains('prince') || id.contains('prince')) {
      return 'assets/images/discover/princewill_logo.png';
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final localAsset = _localAssetPath;
    final logoUrl = entry.logoUrl?.trim();

    Widget imageWidget;
    if (localAsset != null) {
      imageWidget = Image.asset(
        localAsset,
        width: 48,
        height: 48,
        fit: BoxFit.contain,
        errorBuilder: (_, _, _) => _fallbackLetter(entry.title),
      );
    } else if (logoUrl != null && logoUrl.isNotEmpty) {
      imageWidget = Image.network(
        logoUrl,
        width: 48,
        height: 48,
        fit: BoxFit.cover,
        errorBuilder: (_, _, _) => _fallbackLetter(entry.title),
      );
    } else {
      imageWidget = _fallbackLetter(entry.title);
    }

    return Container(
      width: 64,
      height: 64,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: const Color(0xFF1E1E1E),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.08),
        ),
      ),
      child: imageWidget,
    );
  }

  Widget _fallbackLetter(String title) {
    return Text(
      title.trim().isEmpty ? '?' : title.trim()[0].toUpperCase(),
      style: GoogleFonts.inter(
        color: Colors.white,
        fontSize: 22,
        fontWeight: FontWeight.w700,
      ),
    );
  }
}

class _CatalogNotice extends StatelessWidget {
  const _CatalogNotice({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.warning.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.warning.withValues(alpha: 0.26)),
      ),
      child: Text(
        message,
        style: GoogleFonts.inter(color: Colors.white70, fontSize: 11),
      ),
    );
  }
}

class _CatalogLoadingCard extends StatelessWidget {
  const _CatalogLoadingCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 92,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: AppColors.cardDark,
        borderRadius: BorderRadius.circular(18),
      ),
      child: const CircularProgressIndicator(color: AppColors.accentRed),
    );
  }
}

class _EmptyCatalogCard extends StatelessWidget {
  const _EmptyCatalogCard({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: AppColors.cardDark,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
      ),
      child: Text(
        message,
        textAlign: TextAlign.center,
        style: GoogleFonts.inter(color: AppColors.textSecondary, fontSize: 12),
      ),
    );
  }
}

class _EmptyProductsCard extends StatelessWidget {
  const _EmptyProductsCard();

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return Container(
      height: 112,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.cardDark,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
      ),
      child: Row(
        children: [
          Image.asset(
            'assets/images/logo.png',
            width: 48,
            height: 48,
            fit: BoxFit.contain,
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Text(
              l.discoverProductsEmpty,
              style: GoogleFonts.inter(
                color: AppColors.textSecondary,
                fontSize: 12,
                height: 1.35,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
