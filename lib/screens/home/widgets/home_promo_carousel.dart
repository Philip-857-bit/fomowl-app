import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../constants/app_colors.dart';
import '../home_banner_item.dart';
import 'social_banner_card.dart';

class HomePromoCarousel extends StatelessWidget {
  const HomePromoCarousel({
    super.key,
    required this.banners,
    required this.showFallbackSocialBanner,
    required this.activeIndex,
    required this.pageController,
    required this.isLoading,
    required this.onPageChanged,
    required this.onTapBanner,
    required this.onTapFallbackSocialBanner,
  });

  final List<HomeBannerItem> banners;
  final bool showFallbackSocialBanner;
  final int activeIndex;
  final PageController pageController;
  final bool isLoading;
  final ValueChanged<int> onPageChanged;
  final ValueChanged<HomeBannerItem> onTapBanner;
  final VoidCallback onTapFallbackSocialBanner;

  @override
  Widget build(BuildContext context) {
    final shouldShowPager = banners.isNotEmpty;
    final shouldShowFallback = banners.isEmpty && showFallbackSocialBanner;

    return Column(
      children: [
        if (isLoading)
          const SizedBox(height: 72, child: _PromoSkeletonCard())
        else if (shouldShowPager)
          SizedBox(
            height: 72,
            child: PageView.builder(
              controller: pageController,
              itemCount: banners.length,
              onPageChanged: onPageChanged,
              itemBuilder: (context, index) {
                final banner = banners[index];
                return Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: _PromoBannerCard(
                    banner: banner,
                    onTap: () => onTapBanner(banner),
                  ),
                );
              },
            ),
          )
        else if (shouldShowFallback)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: SocialBannerCard(
              margin: EdgeInsets.zero,
              onTap: onTapFallbackSocialBanner,
            ),
          )
        else
          const SizedBox.shrink(),
        if (!isLoading && banners.length > 1) ...[
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List<Widget>.generate(
              banners.length,
              (index) => AnimatedContainer(
                duration: const Duration(milliseconds: 220),
                width: index == activeIndex ? 20 : 7,
                height: 7,
                margin: const EdgeInsets.symmetric(horizontal: 3),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(999),
                  color: index == activeIndex
                      ? AppColors.accentRed
                      : Colors.white.withValues(alpha: 0.14),
                ),
              ),
            ),
          ),
        ],
      ],
    );
  }
}

class _PromoBannerCard extends StatelessWidget {
  const _PromoBannerCard({required this.banner, required this.onTap});

  final HomeBannerItem banner;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final imageUrl = banner.imageUrl;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(15),
        child: Ink(
          decoration: BoxDecoration(
            color: AppColors.cardDark,
            borderRadius: BorderRadius.circular(15),
          ),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: AppColors.accentRed.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: imageUrl != null && imageUrl.isNotEmpty
                      ? ClipRRect(
                          borderRadius: BorderRadius.circular(12),
                          child: Image.network(
                            imageUrl,
                            fit: BoxFit.cover,
                            errorBuilder: (context, error, stackTrace) =>
                                const Icon(
                                  Icons.campaign_rounded,
                                  color: AppColors.accentRed,
                                  size: 22,
                                ),
                          ),
                        )
                      : const Icon(
                          Icons.campaign_rounded,
                          color: AppColors.accentRed,
                          size: 22,
                        ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        banner.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.outfit(
                          color: Colors.white,
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        banner.description,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.outfit(
                          color: Colors.white.withValues(alpha: 0.72),
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
                Icon(
                  Icons.open_in_new,
                  color: Colors.white.withValues(alpha: 0.5),
                  size: 20,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _PromoSkeletonCard extends StatelessWidget {
  const _PromoSkeletonCard();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.cardDark,
          borderRadius: BorderRadius.circular(15),
        ),
        padding: const EdgeInsets.all(14),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: AppColors.accentRed.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    width: 140,
                    height: 16,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Container(
                    width: 176,
                    height: 12,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.05),
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                ],
              ),
            ),
            Container(
              width: 20,
              height: 20,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.05),
                borderRadius: BorderRadius.circular(10),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
