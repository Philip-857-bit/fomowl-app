import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'burst_api_client.dart';
import 'burst_review_screen.dart' show burstAssetAmount;
import 'burst_theme.dart';

/// The creator's actual campaigns across connected networks.
class BurstHistoryScreen extends StatefulWidget {
  const BurstHistoryScreen({
    super.key,
    required this.api,
    required this.openCampaign,
    required this.initialCampaigns,
    this.includeParticipations = false,
  });
  final BurstApiClient api;
  final Future<void> Function(Map<String, dynamic> campaign) openCampaign;
  final List<dynamic> initialCampaigns;
  final bool includeParticipations;

  @override
  State<BurstHistoryScreen> createState() => _BurstHistoryScreenState();
}

class _BurstHistoryScreenState extends State<BurstHistoryScreen> {
  late List<dynamic> _campaigns = widget.initialCampaigns;
  String _filter = 'All';
  String? _error;

  Future<void> _refresh() async {
    try {
      final response = await widget.api.campaigns();
      if (response['campaigns'] is! List) {
        throw const BurstApiException('Unable to load your Bursts.');
      }
      final created = response['campaigns'] as List;
      var campaigns = created;
      if (widget.includeParticipations) {
        final joined = await widget.api.participations();
        if (joined['campaigns'] is! List) {
          throw const BurstApiException('Unable to load joined Bursts.');
        }
        campaigns =
            [
              for (final item in created.whereType<Map>())
                {...Map<String, dynamic>.from(item), '_isParticipation': false},
              for (final item in (joined['campaigns'] as List).whereType<Map>())
                {...Map<String, dynamic>.from(item), '_isParticipation': true},
            ]..sort(
              (a, b) => (b['createdAt']?.toString() ?? '').compareTo(
                a['createdAt']?.toString() ?? '',
              ),
            );
      }
      if (mounted) {
        setState(() {
          _campaigns = campaigns;
          _error = null;
        });
      }
    } catch (error) {
      if (mounted) {
        setState(
          () => _error = error is BurstApiException
              ? error.message
              : 'Unable to load your Bursts.',
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final campaigns = _campaigns
        .whereType<Map>()
        .map((value) => Map<String, dynamic>.from(value))
        .toList();
    final created = campaigns.where((item) => item['_isParticipation'] != true);
    final createdCount = created.length;
    final guestEntries = created.fold<int>(
      0,
      (total, item) =>
          total +
          (item['participantCount'] is int
              ? math.max(0, item['participantCount'] as int)
              : 0),
    );
    final visible = campaigns.where((campaign) {
      final status = campaign['status']?.toString().toLowerCase();
      return switch (_filter) {
        'Active' => const {
          'active',
          'root_pending',
          'claiming',
        }.contains(status),
        'Completed' => status == 'completed',
        'Cancelled' => status == 'cancelled',
        'Tokens' => const {'native', 'erc20'}.contains(campaign['assetKind']),
        'NFTs' => const {'erc721', 'erc1155'}.contains(campaign['assetKind']),
        _ => true,
      };
    }).toList();
    return Scaffold(
      backgroundColor: const Color(0xFF050505),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        foregroundColor: Colors.white,
        title: const Text('My Burst'),
      ),
      body: RefreshIndicator(
        onRefresh: _refresh,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(24),
          children: [
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  for (final filter in const [
                    'All',
                    'Active',
                    'Completed',
                    'Cancelled',
                    'Tokens',
                    'NFTs',
                  ])
                    Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: ChoiceChip(
                        label: Text(filter),
                        selected: _filter == filter,
                        onSelected: (_) => setState(() => _filter = filter),
                        showCheckmark: false,
                        backgroundColor: const Color(0xFF202020),
                        selectedColor: burstAccent(context),
                        side: BorderSide.none,
                        shape: const StadiumBorder(),
                        labelStyle: TextStyle(
                          color: _filter == filter
                              ? burstOnAccent(context)
                              : Colors.white,
                          fontWeight: _filter == filter
                              ? FontWeight.w600
                              : FontWeight.normal,
                        ),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            Row(
              children: [
                Expanded(
                  child: _HistoryMetric(
                    label: 'TOTAL BURSTS',
                    value: '$createdCount',
                    valueKey: const ValueKey('burst-history-created-count'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _HistoryMetric(
                    label: 'GUEST ENTRIES',
                    value: '$guestEntries',
                    valueKey: const ValueKey('burst-history-guest-entries'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            if (_error != null)
              Padding(
                padding: const EdgeInsets.only(top: 16),
                child: Text(
                  _error!,
                  style: const TextStyle(color: Color(0xFFFF8B91)),
                ),
              ),
            if (visible.isEmpty)
              Builder(
                builder: (context) {
                  final isDark =
                      Theme.of(context).brightness == Brightness.dark;
                  final cardColor = isDark
                      ? const Color(0xff0e0e0e)
                      : const Color(0xfff5f5f5);
                  final borderColor = isDark
                      ? const Color(0xff1f1f1f)
                      : const Color(0xffe0e0e0);
                  final titleColor = isDark
                      ? const Color(0xffe2e2e2)
                      : Colors.black87;
                  final subtitleColor = isDark
                      ? const Color(0xffc8c6c8)
                      : Colors.black54;

                  return Container(
                    margin: const EdgeInsets.only(top: 24),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 24,
                      vertical: 36,
                    ),
                    constraints: const BoxConstraints(minHeight: 240),
                    decoration: BoxDecoration(
                      color: cardColor,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: borderColor),
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        // Illustration tray with flame accent badge
                        SizedBox(
                          width: 56,
                          height: 50,
                          child: Stack(
                            alignment: Alignment.center,
                            clipBehavior: Clip.none,
                            children: [
                              Icon(
                                Icons.inventory_2_outlined,
                                size: 44,
                                color: isDark
                                    ? const Color(0xff353535)
                                    : const Color(0xffb0b0b0),
                              ),
                              const Positioned(
                                top: -2,
                                right: -2,
                                child: Icon(
                                  Icons.local_fire_department,
                                  size: 18,
                                  color: Color(0xffffb3ad),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 20),
                        Text(
                          'No bursts yet.',
                          style: TextStyle(
                            color: titleColor,
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'No Bursts in this view.',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: subtitleColor,
                            fontSize: 14,
                            height: 1.4,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Join or create a burst to get started.',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: subtitleColor,
                            fontSize: 13,
                            height: 1.4,
                          ),
                        ),
                      ],
                    ),
                  );
                },
              )
            else
              for (final campaign in visible)
                _HistoryCard(
                  campaign: campaign,
                  onTap: campaign['id'] is! String
                      ? null
                      : () async {
                          await widget.openCampaign(campaign);
                          if (mounted) await _refresh();
                        },
                ),
          ],
        ),
      ),
    );
  }
}

class _HistoryMetric extends StatelessWidget {
  const _HistoryMetric({
    required this.label,
    required this.value,
    this.valueKey,
  });
  final String label;
  final String value;
  final Key? valueKey;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: const Color(0xFF121212),
      borderRadius: BorderRadius.circular(8),
      border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            color: Colors.white70,
            fontSize: 10,
            letterSpacing: 1,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          value,
          key: valueKey,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 24,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    ),
  );
}

class _HistoryCard extends StatelessWidget {
  const _HistoryCard({required this.campaign, required this.onTap});
  final Map<String, dynamic> campaign;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final accent = burstAccent(context);
    final status = campaign['status']?.toString() ?? '';
    final normalized = status.toLowerCase();
    final isActive = normalized == 'active' || normalized == 'root_pending';
    final isHostActive = isActive && campaign['_isParticipation'] != true;
    final joined = campaign['participantCount'] is int
        ? campaign['participantCount'] as int
        : 0;
    final maximum = campaign['maxParticipants'] is int
        ? campaign['maxParticipants'] as int
        : 0;
    final percent = maximum > 0
        ? ((joined / maximum).clamp(0.0, 1.0) * 100).round()
        : 0;
    final decimals = campaign['assetDecimals'];
    final raw = campaign['amountPerParticipantBaseUnits'];
    final isNft = const {'erc721', 'erc1155'}.contains(campaign['assetKind']);
    final reward = isNft
        ? 'NFT distribution'
        : decimals is int && raw is String
        ? '${burstAssetAmount(raw, decimals, campaign['assetSymbol']?.toString() ?? '')} each'
        : null;
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Material(
        color: const Color(0xFF141414),
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              gradient: isActive
                  ? LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        accent.withValues(alpha: 0.14),
                        const Color(0xFF141414),
                      ],
                    )
                  : null,
              border: Border.all(
                color: isActive
                    ? accent.withValues(alpha: 0.35)
                    : Colors.white.withValues(alpha: 0.08),
              ),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        campaign['title']?.toString() ?? 'Burst',
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    BurstStatusBadge(status: status, showDot: isActive),
                  ],
                ),
                if (reward != null || isHostActive) ...[
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      if (reward != null)
                        Expanded(
                          child: Text(
                            reward,
                            style: const TextStyle(color: Colors.white70),
                          ),
                        )
                      else
                        const Spacer(),
                      if (isHostActive)
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 5,
                          ),
                          decoration: BoxDecoration(
                            color: accent,
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            normalized == 'root_pending'
                                ? 'Resume'
                                : 'Trigger Burst',
                            style: TextStyle(
                              color: burstOnAccent(context),
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                    ],
                  ),
                ],
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      '$joined / $maximum guests',
                      style: const TextStyle(color: Colors.white70),
                    ),
                    if (maximum > 0)
                      Text(
                        '$percent%',
                        style: TextStyle(
                          color: accent,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                  ],
                ),
                if (maximum > 0) ...[
                  const SizedBox(height: 10),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: LinearProgressIndicator(
                      value: (joined / maximum).clamp(0.0, 1.0).toDouble(),
                      minHeight: 4,
                      color: accent,
                      backgroundColor: const Color(0xFF393939),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
