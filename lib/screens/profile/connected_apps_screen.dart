import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../constants/app_colors.dart';
import '../../features/discover/permissions/dapp_permission_record.dart';
import '../../features/discover/permissions/dapp_permission_service.dart';
import '../../services/wallet_service.dart';
import '../../utils/toast_utils.dart';

class ConnectedAppsScreen extends StatefulWidget {
  const ConnectedAppsScreen({super.key});

  @override
  State<ConnectedAppsScreen> createState() => _ConnectedAppsScreenState();
}

class _ConnectedAppsScreenState extends State<ConnectedAppsScreen> {
  final DappPermissionService _permissionService = DappPermissionService();
  final WalletService _walletService = WalletService();

  bool _loading = true;
  bool _busy = false;
  String? _walletAddress;
  String? _error;
  List<DappPermissionRecord> _connections = const <DappPermissionRecord>[];

  @override
  void initState() {
    super.initState();
    _loadConnections();
  }

  Future<void> _loadConnections() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final walletAddress = await _walletService.getCurrentWalletAddress();
      if (walletAddress == null || walletAddress.trim().isEmpty) {
        if (!mounted) return;
        setState(() {
          _walletAddress = null;
          _connections = const <DappPermissionRecord>[];
          _loading = false;
          _error = 'No active wallet found.';
        });
        return;
      }

      final records = await _permissionService.loadPermissionsForWallet(
        walletAddress,
      );

      if (!mounted) return;
      setState(() {
        _walletAddress = walletAddress;
        _connections = records;
        _loading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = 'Unable to load connected apps right now.';
      });
      debugPrint('Connected apps load failed: $error');
    }
  }

  Future<void> _disconnect(DappPermissionRecord record) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.cardDark,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          'Disconnect app?',
          style: GoogleFonts.outfit(
            color: AppColors.textPrimary,
            fontWeight: FontWeight.w700,
          ),
        ),
        content: Text(
          'This removes wallet access for ${_displayOrigin(record.origin)}.',
          style: GoogleFonts.outfit(color: AppColors.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(
              'Cancel',
              style: GoogleFonts.outfit(color: AppColors.textSecondary),
            ),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppColors.accentRed),
            onPressed: () => Navigator.of(context).pop(true),
            child: Text('Disconnect', style: GoogleFonts.outfit()),
          ),
        ],
      ),
    );

    if (confirm != true || _busy) {
      return;
    }

    setState(() => _busy = true);
    try {
      await _permissionService.revokeConnectionApproval(
        record.origin,
        record.walletAddress,
      );
      await _loadConnections();
      ToastUtils.showSuccess('App disconnected.');
    } catch (error) {
      ToastUtils.showError('Unable to disconnect app right now.');
      debugPrint('Failed to disconnect app: $error');
    } finally {
      if (mounted) {
        setState(() => _busy = false);
      }
    }
  }

  Future<void> _disconnectAll() async {
    final walletAddress = _walletAddress;
    if (walletAddress == null || walletAddress.isEmpty || _busy) {
      return;
    }

    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.cardDark,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          'Disconnect all apps?',
          style: GoogleFonts.outfit(
            color: AppColors.textPrimary,
            fontWeight: FontWeight.w700,
          ),
        ),
        content: Text(
          'This removes wallet access for every connected dapp.',
          style: GoogleFonts.outfit(color: AppColors.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(
              'Cancel',
              style: GoogleFonts.outfit(color: AppColors.textSecondary),
            ),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppColors.accentRed),
            onPressed: () => Navigator.of(context).pop(true),
            child: Text('Disconnect all', style: GoogleFonts.outfit()),
          ),
        ],
      ),
    );

    if (confirm != true) {
      return;
    }

    setState(() => _busy = true);
    try {
      await _permissionService.revokeAllForWallet(walletAddress);
      await _loadConnections();
      ToastUtils.showSuccess('All connected apps removed.');
    } catch (error) {
      ToastUtils.showError('Unable to disconnect apps right now.');
      debugPrint('Failed to disconnect all apps: $error');
    } finally {
      if (mounted) {
        setState(() => _busy = false);
      }
    }
  }

  String _displayOrigin(String origin) {
    final parsed = Uri.tryParse(origin);
    if (parsed == null || parsed.host.isEmpty) {
      return origin;
    }
    return parsed.host;
  }

  String _shortAddress(String address) {
    if (address.length < 10) {
      return address;
    }
    return '${address.substring(0, 6)}...${address.substring(address.length - 4)}';
  }

  String _formatDate(DateTime dateTime) {
    final local = dateTime.toLocal();
    String two(int value) => value.toString().padLeft(2, '0');
    return '${local.year}-${two(local.month)}-${two(local.day)} ${two(local.hour)}:${two(local.minute)}';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        foregroundColor: AppColors.textPrimary,
        title: Text(
          'Connected Apps',
          style: GoogleFonts.outfit(fontWeight: FontWeight.w700),
        ),
      ),
      body: _loading
          ? const Center(
              child: CircularProgressIndicator(color: AppColors.accentRed),
            )
          : RefreshIndicator(
              color: AppColors.accentRed,
              onRefresh: _loadConnections,
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                children: [
                  if (_walletAddress != null)
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: AppColors.cardDark,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: Colors.white.withValues(alpha: 0.06),
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Active wallet',
                            style: GoogleFonts.outfit(
                              color: AppColors.textSecondary,
                              fontSize: 13,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            _shortAddress(_walletAddress!),
                            style: GoogleFonts.robotoMono(
                              color: AppColors.textPrimary,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 10),
                          Text(
                            '${_connections.length} connected app${_connections.length == 1 ? '' : 's'}',
                            style: GoogleFonts.outfit(
                              color: AppColors.textSecondary,
                              fontSize: 13,
                            ),
                          ),
                          if (_connections.isNotEmpty) ...[
                            const SizedBox(height: 12),
                            OutlinedButton.icon(
                              onPressed: _busy ? null : _disconnectAll,
                              style: OutlinedButton.styleFrom(
                                foregroundColor: AppColors.accentRed,
                                side: BorderSide(
                                  color: AppColors.accentRed.withValues(
                                    alpha: 0.7,
                                  ),
                                ),
                              ),
                              icon: const Icon(Icons.link_off_rounded),
                              label: Text(
                                'Disconnect all',
                                style: GoogleFonts.outfit(
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  if (_error != null) ...[
                    const SizedBox(height: 14),
                    Text(
                      _error!,
                      style: GoogleFonts.outfit(color: AppColors.accentRed),
                    ),
                  ],
                  const SizedBox(height: 14),
                  if (_connections.isEmpty)
                    Container(
                      padding: const EdgeInsets.all(18),
                      decoration: BoxDecoration(
                        color: AppColors.cardDark,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: Colors.white.withValues(alpha: 0.06),
                        ),
                      ),
                      child: Text(
                        'No dapp is currently connected to this wallet.',
                        style: GoogleFonts.outfit(
                          color: AppColors.textSecondary,
                          height: 1.4,
                        ),
                      ),
                    )
                  else
                    for (final record in _connections)
                      Container(
                        margin: const EdgeInsets.only(bottom: 10),
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: AppColors.cardDark,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                            color: Colors.white.withValues(alpha: 0.06),
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    _displayOrigin(record.origin),
                                    style: GoogleFonts.outfit(
                                      color: AppColors.textPrimary,
                                      fontSize: 16,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                                TextButton.icon(
                                  onPressed: _busy
                                      ? null
                                      : () => _disconnect(record),
                                  icon: const Icon(
                                    Icons.link_off_rounded,
                                    size: 16,
                                    color: AppColors.accentRed,
                                  ),
                                  label: Text(
                                    'Disconnect',
                                    style: GoogleFonts.outfit(
                                      color: AppColors.accentRed,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 4),
                            Text(
                              record.origin,
                              style: GoogleFonts.outfit(
                                color: AppColors.textSecondary,
                                fontSize: 12,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Connected ${_formatDate(record.connectedAt)}',
                              style: GoogleFonts.outfit(
                                color: AppColors.textSecondary,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ),
                ],
              ),
            ),
    );
  }
}
