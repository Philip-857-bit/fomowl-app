import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../constants/app_colors.dart';
import '../../../../l10n/app_localizations.dart';
import '../discover_tab_manager.dart';

class DiscoverTabOverview extends StatelessWidget {
  const DiscoverTabOverview({
    super.key,
    required this.manager,
    required this.onDone,
    required this.onLimitReached,
  });

  final DiscoverTabManager manager;
  final VoidCallback onDone;
  final VoidCallback onLimitReached;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return ColoredBox(
      color: AppColors.background,
      child: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 12, 12),
              child: Row(
                children: [
                  Text(
                    l.discoverTabsTitle,
                    style: GoogleFonts.outfit(
                      color: Colors.white,
                      fontSize: 24,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Text(
                    '${manager.tabCount}/${manager.maxTabs}',
                    style: GoogleFonts.outfit(
                      color: Colors.white54,
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const Spacer(),
                  TextButton(onPressed: onDone, child: Text(l.doneLabel)),
                ],
              ),
            ),
            Expanded(
              child: GridView.builder(
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  crossAxisSpacing: 12,
                  mainAxisSpacing: 12,
                  childAspectRatio: 0.82,
                ),
                itemCount: manager.tabs.length + 1,
                itemBuilder: (context, index) {
                  if (index == manager.tabs.length) {
                    return _NewTabCard(
                      enabled: manager.canAddTab,
                      label: manager.canAddTab
                          ? l.discoverNewTab
                          : l.discoverMaxTabsReached,
                      onTap: () async {
                        if (!manager.canAddTab) {
                          onLimitReached();
                          return;
                        }
                        await manager.addTab();
                        onDone();
                      },
                    );
                  }
                  final tab = manager.tabs[index];
                  return _TabCard(
                    tab: tab,
                    active: tab.id == manager.activeTabId,
                    onTap: () {
                      manager.selectTab(tab.id);
                      onDone();
                    },
                    onClose: () => manager.closeTab(tab.id),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TabCard extends StatelessWidget {
  const _TabCard({
    required this.tab,
    required this.active,
    required this.onTap,
    required this.onClose,
  });

  final DiscoverBrowserTab tab;
  final bool active;
  final VoidCallback onTap;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final session = tab.sessionController;
    final uri = session.currentUri;
    final title = session.pageTitle?.trim().isNotEmpty == true
        ? session.pageTitle!.trim()
        : uri?.host ?? l.discoverTitle;
    final subtitle = uri?.host ?? l.discoverHome;
    final faviconUrl = uri?.replace(
      path: '/favicon.ico',
      query: null,
      fragment: null,
    );

    return Semantics(
      button: true,
      selected: active,
      label: '$title, $subtitle',
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(20),
          child: Container(
            clipBehavior: Clip.antiAlias,
            decoration: BoxDecoration(
              color: AppColors.cardDark,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: active
                    ? AppColors.accentRed
                    : Colors.white.withValues(alpha: 0.08),
                width: active ? 2 : 1,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(12, 8, 6, 8),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.outfit(
                            color: Colors.white,
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      Semantics(
                        button: true,
                        label: l.discoverCloseTab,
                        child: IconButton(
                          onPressed: onClose,
                          constraints: const BoxConstraints(
                            minWidth: 44,
                            minHeight: 44,
                          ),
                          icon: const Icon(Icons.close_rounded, size: 19),
                        ),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: Container(
                    width: double.infinity,
                    color: const Color(0xFF0B1018),
                    child: Center(
                      child: Container(
                        width: 64,
                        height: 64,
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.06),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: faviconUrl == null
                            ? Image.asset('assets/images/logo.png')
                            : Image.network(
                                faviconUrl.toString(),
                                fit: BoxFit.contain,
                                errorBuilder: (_, error, stackTrace) => Icon(
                                  Icons.public_rounded,
                                  color: Colors.white.withValues(alpha: 0.65),
                                ),
                              ),
                      ),
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(12),
                  child: Text(
                    subtitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.outfit(
                      color: Colors.white60,
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                    ),
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

class _NewTabCard extends StatelessWidget {
  const _NewTabCard({
    required this.enabled,
    required this.label,
    required this.onTap,
  });

  final bool enabled;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Container(
          decoration: BoxDecoration(
            color: AppColors.cardDark,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: enabled
                  ? AppColors.accentRed.withValues(alpha: 0.45)
                  : Colors.white.withValues(alpha: 0.08),
            ),
          ),
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    enabled ? Icons.add_rounded : Icons.tab_unselected_rounded,
                    size: 38,
                    color: enabled ? AppColors.accentRed : Colors.white38,
                  ),
                  const SizedBox(height: 10),
                  Text(
                    label,
                    textAlign: TextAlign.center,
                    style: GoogleFonts.outfit(
                      color: enabled ? Colors.white : Colors.white54,
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
