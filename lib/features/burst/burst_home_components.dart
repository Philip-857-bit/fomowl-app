import 'package:flutter/material.dart';

import 'burst_theme.dart';
import 'burst_review_screen.dart' show burstAssetAmount;

class BurstHomeHero extends StatelessWidget {
  const BurstHomeHero({super.key});

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          const Text(
            'Burst',
            style: TextStyle(
              color: Colors.white,
              fontSize: 48,
              fontWeight: FontWeight.bold,
            ),
          ),
          Container(
            width: 48,
            height: 5,
            margin: const EdgeInsets.only(bottom: 8),
            color: burstAccent(context),
          ),
        ],
      ),
      const SizedBox(height: 12),
      const Text(
        'Send tokens and NFTs to your community with a non-custodial Burst.',
        style: TextStyle(color: Colors.white70),
      ),
      const SizedBox(height: 12),
      Center(
        child: Image.asset(
          'assets/burst/home_illustration.png',
          height: 215,
          fit: BoxFit.contain,
          excludeFromSemantics: true,
        ),
      ),
      const SizedBox(height: 12),
      const Center(
        child: Text(
          'Ready to make it rain?',
          textAlign: TextAlign.center,
          style: TextStyle(
            color: Colors.white,
            fontSize: 20,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      const SizedBox(height: 24),
    ],
  );
}

class BurstHomeAction extends StatelessWidget {
  const BurstHomeAction({
    super.key,
    required this.iconAsset,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });
  final String iconAsset;
  final String title;
  final String subtitle;
  final VoidCallback? onTap;
  @override
  Widget build(BuildContext context) => Material(
    color: const Color(0xff1b1b1b),
    borderRadius: BorderRadius.circular(12),
    child: InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Image.asset(
              iconAsset,
              width: 24,
              height: 24,
              color: burstAccent(context),
              colorBlendMode: BlendMode.srcIn,
              excludeFromSemantics: true,
            ),
            const SizedBox(height: 14),
            Text(
              title,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 5),
            Text(
              subtitle,
              style: const TextStyle(color: Colors.white70, fontSize: 12),
            ),
          ],
        ),
      ),
    ),
  );
}

class BurstHomeCampaignCard extends StatelessWidget {
  const BurstHomeCampaignCard({
    super.key,
    required this.campaign,
    required this.onTap,
  });
  final Map<String, dynamic> campaign;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final joined = campaign['participantCount'] is int
        ? campaign['participantCount'] as int
        : 0;
    final maximum = campaign['maxParticipants'] is int
        ? campaign['maxParticipants'] as int
        : 0;
    final nft = const {'erc721', 'erc1155'}.contains(campaign['assetKind']);
    final decimals = campaign['assetDecimals'];
    final amount = nft
        ? 'NFT distribution'
        : decimals is int
        ? '${burstAssetAmount(campaign['amountPerParticipantBaseUnits']?.toString() ?? '', decimals, campaign['assetSymbol']?.toString() ?? '')} each'
        : 'Amount unavailable';
    final status = campaign['status']?.toString() ?? '';
    return SizedBox(
      width: 280,
      child: Material(
        color: const Color(0xff191919),
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        campaign['title']?.toString() ?? 'Burst',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      status.toUpperCase(),
                      style: TextStyle(
                        color: burstAccent(context),
                        fontSize: 10,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  amount,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: Colors.white70),
                ),
                const SizedBox(height: 20),
                Text(
                  '$joined / $maximum guests',
                  style: const TextStyle(color: Colors.white70, fontSize: 12),
                ),
                const SizedBox(height: 10),
                ClipRRect(
                  borderRadius: BorderRadius.circular(20),
                  child: LinearProgressIndicator(
                    value: maximum > 0
                        ? (joined / maximum).clamp(0.0, 1.0).toDouble()
                        : 0,
                    minHeight: 4,
                    color: burstAccent(context),
                    backgroundColor: const Color(0xff393939),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
