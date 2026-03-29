import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../constants/app_colors.dart';
import 'admin_dashboard_common.dart';

class AdminDiscoverDappsSection extends StatelessWidget {
  const AdminDiscoverDappsSection({
    super.key,
    required this.isLoading,
    required this.isSubmitting,
    required this.isEditing,
    required this.slugController,
    required this.launchUrlController,
    required this.titleController,
    required this.subtitleController,
    required this.logoUrlController,
    required this.heroImageUrlController,
    required this.badgeController,
    required this.categoriesController,
    required this.chainIdsController,
    required this.featuredRankController,
    required this.trendingRankController,
    required this.isActive,
    required this.onActiveChanged,
    required this.onSubmit,
    required this.onReset,
    required this.dapps,
    required this.onEdit,
    required this.onToggleActive,
  });

  final bool isLoading;
  final bool isSubmitting;
  final bool isEditing;
  final TextEditingController slugController;
  final TextEditingController launchUrlController;
  final TextEditingController titleController;
  final TextEditingController subtitleController;
  final TextEditingController logoUrlController;
  final TextEditingController heroImageUrlController;
  final TextEditingController badgeController;
  final TextEditingController categoriesController;
  final TextEditingController chainIdsController;
  final TextEditingController featuredRankController;
  final TextEditingController trendingRankController;
  final bool isActive;
  final ValueChanged<bool> onActiveChanged;
  final VoidCallback onSubmit;
  final VoidCallback onReset;
  final List<Map<String, dynamic>> dapps;
  final ValueChanged<Map<String, dynamic>> onEdit;
  final void Function(Map<String, dynamic>, bool) onToggleActive;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const AdminSectionHeading(
          title: 'Discover DApps',
          subtitle:
              'Manage the global Discover allowlist. Launch URL is required; slug, title, and artwork can autofill from the site.',
        ),
        AdminCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                isEditing ? 'Edit allowlisted DApp' : 'Create allowlisted DApp',
                style: GoogleFonts.outfit(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 14),
              TextField(
                controller: slugController,
                decoration: adminInputDecoration(
                  label: 'Slug',
                  hint: 'uniswap (optional, auto when blank)',
                  icon: Icons.tag_rounded,
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: launchUrlController,
                decoration: adminInputDecoration(
                  label: 'Launch URL',
                  hint: 'https://app.uniswap.org',
                  icon: Icons.link_rounded,
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: titleController,
                decoration: adminInputDecoration(
                  label: 'Title',
                  hint: 'Uniswap (optional, auto when blank)',
                  icon: Icons.title_rounded,
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: subtitleController,
                decoration: adminInputDecoration(
                  label: 'Subtitle',
                  hint: 'Swap tokens across supported chains',
                  icon: Icons.short_text_rounded,
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: logoUrlController,
                decoration: adminInputDecoration(
                  label: 'Logo URL',
                  hint: 'Optional; fetched from site icon when blank',
                  icon: Icons.image_outlined,
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: heroImageUrlController,
                decoration: adminInputDecoration(
                  label: 'Hero image URL',
                  hint: 'Optional; fetched from OG/Twitter image when blank',
                  icon: Icons.landscape_outlined,
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: badgeController,
                decoration: adminInputDecoration(
                  label: 'Badge',
                  hint: 'FEATURED',
                  icon: Icons.sell_outlined,
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: categoriesController,
                decoration: adminInputDecoration(
                  label: 'Categories',
                  hint: 'dex, defi, swaps',
                  icon: Icons.grid_view_rounded,
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: chainIdsController,
                decoration: adminInputDecoration(
                  label: 'Supported chain IDs',
                  hint: '1, 56, 8453',
                  icon: Icons.hub_outlined,
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: featuredRankController,
                      decoration: adminInputDecoration(
                        label: 'Featured rank',
                        hint: '1',
                        icon: Icons.star_outline_rounded,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextField(
                      controller: trendingRankController,
                      decoration: adminInputDecoration(
                        label: 'Trending rank',
                        hint: '2',
                        icon: Icons.local_fire_department_outlined,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  Text(
                    'Active',
                    style: GoogleFonts.outfit(
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const Spacer(),
                  Switch.adaptive(
                    value: isActive,
                    activeThumbColor: AppColors.success,
                    onChanged: onActiveChanged,
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: isSubmitting ? null : onReset,
                      child: Text(isEditing ? 'Cancel edit' : 'Reset'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: isSubmitting ? null : onSubmit,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.accentRed,
                        foregroundColor: Colors.white,
                      ),
                      child: isSubmitting
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : Text(isEditing ? 'Save DApp' : 'Create DApp'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 18),
        Row(
          children: [
            Text(
              'Allowlisted DApps',
              style: GoogleFonts.outfit(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.w700,
              ),
            ),
            const Spacer(),
            if (isLoading)
              const SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: AppColors.accentRed,
                ),
              ),
          ],
        ),
        const SizedBox(height: 12),
        if (dapps.isEmpty)
          const AdminEmptyState(
            title: 'No Discover DApps yet',
            message:
                'Create the first allowlisted DApp above and it will start appearing in the in-app Discover browser.',
          )
        else
          ...dapps.map(
            (dapp) => Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: AdminDiscoverDappCard(
                dapp: dapp,
                onEdit: () => onEdit(dapp),
                onToggleActive: (value) => onToggleActive(dapp, value),
              ),
            ),
          ),
      ],
    );
  }
}

class AdminDiscoverDappCard extends StatelessWidget {
  const AdminDiscoverDappCard({
    super.key,
    required this.dapp,
    required this.onEdit,
    required this.onToggleActive,
  });

  final Map<String, dynamic> dapp;
  final VoidCallback onEdit;
  final ValueChanged<bool> onToggleActive;

  @override
  Widget build(BuildContext context) {
    final title = (dapp['title'] ?? 'Untitled DApp').toString();
    final origin = (dapp['origin'] ?? '--').toString();
    final launchUrl = (dapp['launchUrl'] ?? '--').toString();
    final categories =
        (dapp['categories'] as List<dynamic>? ?? const <dynamic>[])
            .map((value) => value.toString())
            .toList(growable: false);
    final chains =
        (dapp['supportedChainIds'] as List<dynamic>? ?? const <dynamic>[])
            .map((value) => value.toString())
            .join(', ');
    final isActive = dapp['isActive'] != false;

    return AdminCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  title,
                  style: GoogleFonts.outfit(
                    color: Colors.white,
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              AdminStatusPill(
                label: isActive ? 'Active' : 'Inactive',
                color: isActive ? AppColors.success : AppColors.warning,
              ),
            ],
          ),
          const SizedBox(height: 10),
          AdminInfoRow(label: 'Origin', value: origin),
          AdminInfoRow(label: 'Launch URL', value: launchUrl),
          AdminInfoRow(
            label: 'Categories',
            value: categories.isEmpty ? '--' : categories.join(', '),
          ),
          AdminInfoRow(
            label: 'Supported chains',
            value: chains.isEmpty ? '--' : chains,
          ),
          AdminInfoRow(
            label: 'Featured / Trending',
            value:
                '${dapp['featuredRank']?.toString() ?? '--'} / ${dapp['trendingRank']?.toString() ?? '--'}',
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: onEdit,
                  icon: const Icon(Icons.edit_outlined),
                  label: const Text('Edit'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Row(
                  children: [
                    const Text('Live', style: TextStyle(color: Colors.white70)),
                    const Spacer(),
                    Switch.adaptive(
                      value: isActive,
                      activeThumbColor: AppColors.success,
                      onChanged: onToggleActive,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
