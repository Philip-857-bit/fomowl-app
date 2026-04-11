import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../constants/app_colors.dart';
import '../../../l10n/app_localizations.dart';
import '../../../models/chain.dart';
import 'admin_dashboard_common.dart';

class AdminMaintainersSection extends StatelessWidget {
  const AdminMaintainersSection({
    super.key,
    required this.l10n,
    required this.isSubmitting,
    required this.addressController,
    required this.nameController,
    required this.maintainers,
    required this.onSubmit,
    required this.onDeactivate,
  });

  final AppLocalizations l10n;
  final bool isSubmitting;
  final TextEditingController addressController;
  final TextEditingController nameController;
  final List<Map<String, dynamic>> maintainers;
  final VoidCallback onSubmit;
  final ValueChanged<String> onDeactivate;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        AdminSectionHeading(
          title: l10n.adminMaintainers,
          subtitle:
            'Manage privileged wallets for admin actions. Added maintainers can use the panel immediately.',
        ),
        AdminCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextField(
                controller: addressController,
                style: const TextStyle(color: Colors.white),
                decoration: adminInputDecoration(
                  label: l10n.adminWalletAddressHint,
                  hint: '0x...',
                  icon: Icons.account_balance_wallet_outlined,
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: nameController,
                style: const TextStyle(color: Colors.white),
                decoration: adminInputDecoration(
                  label: l10n.adminNameOptionalHint,
                  hint: 'Display name',
                  icon: Icons.badge_outlined,
                ),
              ),
              const SizedBox(height: 14),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: isSubmitting ? null : onSubmit,
                  icon: const Icon(Icons.person_add_alt_1_rounded),
                  label: Text(
                    isSubmitting ? 'Saving...' : l10n.adminAddMaintainer,
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        if (maintainers.isEmpty)
          const AdminEmptyState(
            title: 'No maintainers loaded',
            message:
                'No maintainer records were returned yet. Try refreshing this section.',
          )
        else
          ...maintainers.map(
            (maintainer) => Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: AdminMaintainerCard(
                maintainer: maintainer,
                busy: isSubmitting,
                onDeactivate: () => onDeactivate(
                  (maintainer['walletAddress'] ?? '').toString(),
                ),
              ),
            ),
          ),
      ],
    );
  }
}

class AdminRegistrySection extends StatelessWidget {
  const AdminRegistrySection({
    super.key,
    required this.activeChain,
    required this.isLoading,
    required this.registryUpdatingContracts,
    required this.searchController,
    required this.registryTokens,
    required this.registryPage,
    required this.registryTotal,
    required this.registryHasNext,
    required this.onSearch,
    required this.onRefresh,
    required this.onPreviousPage,
    required this.onNextPage,
    required this.onToggleCertification,
  });

  final EvmChain activeChain;
  final bool isLoading;
  final Set<String> registryUpdatingContracts;
  final TextEditingController searchController;
  final List<Map<String, dynamic>> registryTokens;
  final int registryPage;
  final int registryTotal;
  final bool registryHasNext;
  final VoidCallback onSearch;
  final VoidCallback onRefresh;
  final VoidCallback? onPreviousPage;
  final VoidCallback? onNextPage;
  final void Function(Map<String, dynamic> token, bool value)
  onToggleCertification;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const AdminSectionHeading(
          title: 'Token registry',
          subtitle:
            'Search discovered tokens and approve trusted assets for wallet display.',
        ),
        AdminCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextField(
                controller: searchController,
                style: const TextStyle(color: Colors.white),
                decoration: adminInputDecoration(
                  label: 'Search registry',
                  hint: 'Symbol, name, or contract',
                  icon: Icons.search_rounded,
                ),
                onSubmitted: (_) => onSearch(),
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 10,
                runSpacing: 10,
                children: [
                  ElevatedButton.icon(
                    onPressed: onSearch,
                    icon: const Icon(Icons.search_rounded),
                    label: const Text('Search'),
                  ),
                  OutlinedButton.icon(
                    onPressed: isLoading ? null : onRefresh,
                    icon: const Icon(Icons.refresh_rounded),
                    label: const Text('Refresh'),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Text(
                'Showing ${registryTokens.length} of $registryTotal tokens · Page $registryPage',
                style: GoogleFonts.outfit(
                  color: AppColors.textSecondary,
                  fontSize: 13,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        if (registryTokens.isEmpty)
          const AdminEmptyState(
            title: 'No registry tokens found',
            message:
                'No tokens matched the current filter. Clear search or refresh the list.',
          )
        else
          ...registryTokens.map(
            (token) => Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: AdminRegistryTokenCard(
                token: token,
                chainId: activeChain.chainId,
                busy: registryUpdatingContracts.contains(
                  (token['contractAddress'] ?? '').toString().toLowerCase(),
                ),
                onChanged: (value) => onToggleCertification(token, value),
              ),
            ),
          ),
        const SizedBox(height: 6),
        Row(
          children: [
            OutlinedButton.icon(
              onPressed: onPreviousPage,
              icon: const Icon(Icons.chevron_left_rounded),
              label: const Text('Previous'),
            ),
            const SizedBox(width: 10),
            OutlinedButton.icon(
              onPressed: registryHasNext ? onNextPage : null,
              icon: const Icon(Icons.chevron_right_rounded),
              label: const Text('Next'),
            ),
          ],
        ),
      ],
    );
  }
}
