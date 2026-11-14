import 'package:flutter/material.dart';

import 'burst_review_screen.dart' show burstAssetAmount;
import 'burst_theme.dart';

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
      const SizedBox(height: 10),
      const Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: EdgeInsets.only(top: 1),
            child: Icon(
              Icons.info_outline_rounded,
              size: 14,
              color: Color(0xFFFC9915),
            ),
          ),
          SizedBox(width: 6),
          Expanded(
            child: Text(
              'Bursts are optimized smart contract transactions for gas efficiency.',
              style: TextStyle(
                color: Color(0xFFFC9915),
                fontSize: 11,
                height: 1.35,
              ),
            ),
          ),
        ],
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
    color: const Color(0xFF1E1E1E),
    borderRadius: BorderRadius.circular(11),
    child: InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(11),
      child: Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(11),
          border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
        ),
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
    this.onDelete,
  });
  final Map<String, dynamic> campaign;
  final VoidCallback? onTap;
  final VoidCallback? onDelete;

  @override
  Widget build(BuildContext context) {
    final accent = burstAccent(context);
    final joined = campaign['participantCount'] is int
        ? campaign['participantCount'] as int
        : 0;
    final maximum = campaign['maxParticipants'] is int
        ? campaign['maxParticipants'] as int
        : 0;
    final percent = maximum > 0
        ? ((joined / maximum).clamp(0.0, 1.0) * 100).round()
        : 0;
    final nft = const {'erc721', 'erc1155'}.contains(campaign['assetKind']);
    final decimals = campaign['assetDecimals'];
    final amount = nft
        ? 'NFT distribution'
        : decimals is int
        ? '${burstAssetAmount(campaign['amountPerParticipantBaseUnits']?.toString() ?? '', decimals, campaign['assetSymbol']?.toString() ?? '')} each'
        : 'Amount unavailable';
    final status = campaign['status']?.toString() ?? '';
    final isActiveHost =
        (status == 'active' || status == 'root_pending') &&
        campaign['_isParticipation'] != true;
    return SizedBox(
      width: 280,
      child: Material(
        color: const Color(0xFF141414),
        borderRadius: BorderRadius.circular(10),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(10),
          child: Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.03),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: const Color(0x63909090),
              ),
            ),
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
                    BurstStatusBadge(
                      status: status,
                      showDot: status == 'active' || status == 'root_pending',
                    ),
                    if (onDelete != null)
                      IconButton(
                        tooltip: 'Delete draft',
                        visualDensity: VisualDensity.compact,
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                        onPressed: onDelete,
                        icon: const Icon(
                          Icons.delete_outline,
                          size: 16,
                          color: Colors.white54,
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        amount,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(color: Colors.white70),
                      ),
                    ),
                    if (isActiveHost)
                      Container(
                        margin: const EdgeInsets.only(left: 8),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: accent,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          status == 'root_pending' ? 'Resume' : 'Trigger Burst',
                          style: TextStyle(
                            color: burstOnAccent(context),
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 18),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      '$joined / $maximum guests',
                      style: const TextStyle(color: Colors.white70, fontSize: 12),
                    ),
                    Text(
                      '$percent%',
                      style: TextStyle(
                        color: accent,
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                ClipRRect(
                  borderRadius: BorderRadius.circular(20),
                  child: LinearProgressIndicator(
                    value: maximum > 0
                        ? (joined / maximum).clamp(0.0, 1.0).toDouble()
                        : 0,
                    minHeight: 4,
                    color: accent,
                    backgroundColor: const Color(0xFF393939),
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
