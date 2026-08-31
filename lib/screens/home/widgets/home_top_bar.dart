import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../constants/app_colors.dart';
import '../../../l10n/app_localizations.dart';
import '../../../theme/app_chain_theme.dart';
import '../../../widgets/chain_logo_image.dart';

/// Wallet selector + actions row displayed at the top of the home screen.
class HomeTopBar extends StatelessWidget {
  final String walletName;
  final VoidCallback onWalletTap;
  final String chainSymbol;
  final int? chainId;
  final String? chainLogoUrl;
  final VoidCallback onNetworkTap;
  final VoidCallback onSettingsTap;
  final VoidCallback onNotificationsTap;
  final bool showNotificationDot;

  const HomeTopBar({
    super.key,
    required this.walletName,
    required this.onWalletTap,
    required this.chainSymbol,
    this.chainId,
    this.chainLogoUrl,
    required this.onNetworkTap,
    required this.onSettingsTap,
    required this.onNotificationsTap,
    this.showNotificationDot = false,
  });

  @override
  Widget build(BuildContext context) {
    final theme = context.chainTheme;
    final l = AppLocalizations.of(context);

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 0),
      child: Row(
        children: [
          Expanded(
            child: Row(
              children: [
                Flexible(
                  child: _WalletSelector(
                    walletName: walletName,
                    onTap: onWalletTap,
                  ),
                ),
                const SizedBox(width: 8),
                _NetworkChip(
                  chainSymbol: chainSymbol,
                  chainId: chainId,
                  chainLogoUrl: chainLogoUrl,
                  onTap: onNetworkTap,
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          _SettingsButton(onTap: onSettingsTap),
          const SizedBox(width: 4),
          Stack(
            clipBehavior: Clip.none,
            children: [
              SizedBox(
                width: 44,
                height: 44,
                child: IconButton(
                  tooltip: l.notifications,
                  icon: const Icon(
                    Icons.notifications_none_rounded,
                    color: Color(0xFFCBD5E1),
                    size: 20,
                  ),
                  onPressed: onNotificationsTap,
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(
                    minWidth: 44,
                    minHeight: 44,
                  ),
                ),
              ),
              if (showNotificationDot)
                Positioned(
                  right: 6,
                  top: 6,
                  child: Container(
                    width: 10,
                    height: 10,
                    decoration: BoxDecoration(
                      color: theme.accentColor,
                      shape: BoxShape.circle,
                      border: Border.all(width: 2, color: AppColors.canvasDark),
                    ),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _WalletSelector extends StatelessWidget {
  const _WalletSelector({required this.walletName, required this.onTap});

  final String walletName;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = context.chainTheme;
    final isClassic = theme.id == 'fomowl_signature';

    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: const Color(0xFF1C1C1C),
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: isClassic ? 16 : 24,
              height: isClassic ? 16 : 24,
              decoration: BoxDecoration(
                color: isClassic
                    ? const Color(0xFFD31C31)
                    : AppColors.canvasDark,
                borderRadius: BorderRadius.circular(isClassic ? 4 : 999),
                border: isClassic
                    ? null
                    : Border.all(color: Colors.white.withValues(alpha: 0.06)),
              ),
              child: Icon(
                Icons.account_balance_wallet,
                size: isClassic ? 10 : 14,
                color: isClassic ? Colors.white : theme.accentColor,
              ),
            ),
            const SizedBox(width: 8),
            Flexible(
              child: Text(
                walletName,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.inter(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: Colors.white,
                ),
              ),
            ),
            const SizedBox(width: 6),
            const Icon(
              Icons.keyboard_arrow_down,
              color: Colors.white,
              size: 16,
            ),
          ],
        ),
      ),
    );
  }
}

class _NetworkChip extends StatelessWidget {
  const _NetworkChip({
    required this.chainSymbol,
    required this.chainId,
    required this.chainLogoUrl,
    required this.onTap,
  });

  final String chainSymbol;
  final int? chainId;
  final String? chainLogoUrl;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = context.chainTheme;

    return Semantics(
      label: 'Switch blockchain network',
      button: true,
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          height: 32,
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: const Color(0xFF1C1C1C),
            borderRadius: BorderRadius.circular(999),
            border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 16,
                height: 16,
                alignment: Alignment.center,
                decoration: const BoxDecoration(shape: BoxShape.circle),
                clipBehavior: Clip.antiAlias,
                child: ChainLogoImage(
                  chainId: chainId,
                  logoUrl: chainLogoUrl,
                  width: 16,
                  height: 16,
                  fit: BoxFit.contain,
                  fallback: _symbolFallback(theme.accentColor),
                ),
              ),
              const SizedBox(width: 6),
              Text(
                chainSymbol.toUpperCase(),
                style: GoogleFonts.inter(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(width: 4),
              const Icon(
                Icons.keyboard_arrow_down,
                color: Color(0xFFB3B3B3),
                size: 14,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _symbolFallback(Color accentColor) {
    final symbol = chainSymbol.trim();
    return Center(
      child: Text(
        symbol.isEmpty ? '?' : symbol.substring(0, 1).toUpperCase(),
        style: GoogleFonts.inter(
          fontSize: 9,
          fontWeight: FontWeight.w700,
          color: accentColor,
        ),
      ),
    );
  }
}

class _SettingsButton extends StatelessWidget {
  const _SettingsButton({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return SizedBox(
      width: 44,
      height: 44,
      child: IconButton(
        key: const ValueKey('home-settings-button'),
        tooltip: l.settings,
        onPressed: onTap,
        padding: EdgeInsets.zero,
        constraints: const BoxConstraints(minWidth: 44, minHeight: 44),
        icon: const Icon(
          Icons.settings_outlined,
          color: Color(0xFFCBD5E1),
          size: 22,
        ),
      ),
    );
  }
}
