import 'dart:async';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../../services/api_client.dart';
import '../../config/app_environment.dart';
import '../../constants/app_colors.dart';
import '../../l10n/app_localizations.dart';
import '../../services/wallet_service.dart';
import '../../utils/app_error_utils.dart';

/// Notifications Screen
/// Lists withdrawal/transfer receipts, KYC status, etc.
class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  final WalletService _walletService = WalletService();
  final ApiClient _apiClient = ApiClient();
  bool _isLoading = true;
  String? _errorMessage;
  List<_Notification> _notifications = [];

  static const Duration _cacheTtl = Duration(minutes: 5);
  static final Map<String, _NotificationCacheEntry> _cacheByWallet = {};

  @override
  void initState() {
    super.initState();
    _bootstrap();
  }

  Future<void> _bootstrap() async {
    final l = AppLocalizations.of(context);
    final address = await _walletService.getCurrentWalletAddress();
    if (!mounted) return;

    if (address == null || address.isEmpty) {
      setState(() {
        _isLoading = false;
        _errorMessage = l.noActiveWalletFound;
      });
      return;
    }

    final entry = _cacheByWallet[address.toLowerCase()];
    if (entry != null &&
        DateTime.now().difference(entry.fetchedAt) < _cacheTtl) {
      setState(() {
        _notifications = entry.notifications;
        _isLoading = false;
      });
      unawaited(_fetchNotifications(isRefresh: true));
      return;
    }

    await _fetchNotifications();
  }

  Future<void> _fetchNotifications({bool isRefresh = false}) async {
    final l = AppLocalizations.of(context);
    if (!mounted) return;
    setState(() {
      _errorMessage = null;
      if (!isRefresh) {
        _isLoading = true;
      }
    });

    try {
      final address = await _walletService.getCurrentWalletAddress();
      if (!mounted) return;
      if (address == null) {
        setState(() {
          _isLoading = false;
          _errorMessage = l.noActiveWalletFound;
        });
        return;
      }

      final path = AppEnvironment.notifications('/$address').toString();
      final response = await _apiClient.get(path);

      if (response.statusCode == 200) {
        final rawData = response.data;
        if (rawData is! Map<String, dynamic>) {
          if (!mounted) return;
          setState(() {
            _isLoading = false;
            _errorMessage = l.networkError;
          });
          return;
        }
        final data = rawData;
        final rawList = data['notifications'];
        final notifList = rawList is List ? rawList : const <dynamic>[];

        final parsed = notifList.map((j) {
          final item = j is Map<String, dynamic>
              ? j
              : const <String, dynamic>{};
          final dtStr = item['created_at']?.toString() ?? '';
          DateTime? dt;
          try {
            dt = DateTime.parse(dtStr);
          } catch (e) {
            debugPrint('Error parsing notification date: $e');
          }
          final formatted = dt != null
              ? DateFormat('MM.dd.yyyy HH:mm').format(dt)
              : dtStr;

          return _Notification(
            id: item['id']?.toString() ?? '',
            title: item['title']?.toString() ?? l.notifications,
            message: item['message']?.toString() ?? '',
            isRead: item['is_read'] == 1 || item['is_read'] == true,
            date: formatted,
          );
        }).toList();

        if (!mounted) return;
        final unreadIds = parsed
            .where((notification) => !notification.isRead)
            .map((notification) => notification.id)
            .where((id) => id.isNotEmpty)
            .toList();
        final visibleNotifications = unreadIds.isEmpty
            ? parsed
            : parsed
                  .map(
                    (notification) => unreadIds.contains(notification.id)
                        ? notification.copyWith(isRead: true)
                        : notification,
                  )
                  .toList();
        setState(() {
          _notifications = visibleNotifications;
          _isLoading = false;
          _errorMessage = null;
          _cacheByWallet[address.toLowerCase()] = _NotificationCacheEntry(
            notifications: visibleNotifications,
            fetchedAt: DateTime.now(),
          );
        });
        if (unreadIds.isNotEmpty) {
          unawaited(_markNotificationsAsRead(unreadIds));
        }
      } else {
        if (!mounted) return;
        setState(() {
          _isLoading = false;
          _errorMessage = '${l.networkError} (${response.statusCode})';
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _errorMessage = AppErrorUtils.userMessage(
            e,
            fallback: l.networkError,
          );
        });
      }
    }
  }

  Future<void> _markNotificationsAsRead(List<String> ids) async {
    if (ids.isEmpty) {
      return;
    }
    try {
      await _apiClient.post(
        AppEnvironment.notifications('/read').toString(),
        data: {'ids': ids},
      );
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          children: [
            // Header
            Padding(
              padding: const EdgeInsets.fromLTRB(4, 8, 16, 0),
              child: Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.arrow_back, color: Colors.white),
                    onPressed: () => Navigator.pop(context),
                  ),
                  Expanded(
                    child: Text(
                      l.notifications,
                      style: GoogleFonts.outfit(
                        fontSize: 20,
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                  const SizedBox(width: 48),
                ],
              ),
            ),
            const SizedBox(height: 8),

            // List State
            Expanded(
              child: _isLoading
                  ? const Center(
                      child: CircularProgressIndicator(color: Colors.white),
                    )
                  : _errorMessage != null
                  ? Center(
                      child: Text(
                        _errorMessage!,
                        style: GoogleFonts.outfit(
                          fontSize: 16,
                          color: AppColors.accentRed,
                        ),
                      ),
                    )
                  : RefreshIndicator(
                      color: Colors.white,
                      backgroundColor: AppColors.background,
                      onRefresh: () => _fetchNotifications(isRefresh: true),
                      child: _notifications.isEmpty
                          ? SingleChildScrollView(
                              physics: const AlwaysScrollableScrollPhysics(),
                              child: Container(
                                height:
                                    MediaQuery.of(context).size.height * 0.7,
                                alignment: Alignment.center,
                                child: Padding(
                                  padding: const EdgeInsets.all(40),
                                  child: Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Container(
                                        width: 100,
                                        height: 100,
                                        decoration: BoxDecoration(
                                          color: Colors.white.withValues(
                                            alpha: 0.04,
                                          ),
                                          shape: BoxShape.circle,
                                        ),
                                        child: Icon(
                                          Icons.notifications_off_outlined,
                                          size: 48,
                                          color: Colors.white.withValues(
                                            alpha: 0.15,
                                          ),
                                        ),
                                      ),
                                      const SizedBox(height: 24),
                                      Text(
                                        l.noNotificationsYet,
                                        style: GoogleFonts.outfit(
                                          fontSize: 22,
                                          fontWeight: FontWeight.w600,
                                          color: Colors.white,
                                        ),
                                      ),
                                      const SizedBox(height: 8),
                                      Text(
                                        l.pushNotificationsDesc,
                                        style: GoogleFonts.outfit(
                                          fontSize: 14,
                                          color: Colors.white54,
                                          height: 1.5,
                                        ),
                                        textAlign: TextAlign.center,
                                      ),
                                      const SizedBox(height: 16),
                                      Text(
                                        l.refresh,
                                        style: GoogleFonts.outfit(
                                          fontSize: 12,
                                          color: Colors.white24,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            )
                          : ListView.separated(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16,
                              ),
                              separatorBuilder: (_, a) =>
                                  const SizedBox(height: 10),
                              itemCount: _notifications.length,
                              itemBuilder: (context, index) {
                                final n = _notifications[index];
                                return Container(
                                  padding: const EdgeInsets.all(14),
                                  decoration: BoxDecoration(
                                    color: n.isRead
                                        ? Colors.transparent
                                        : AppColors.cardDark,
                                    border: Border.all(
                                      color: Colors.white.withValues(
                                        alpha: 0.1,
                                      ),
                                    ),
                                    borderRadius: BorderRadius.circular(14),
                                  ),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        mainAxisAlignment:
                                            MainAxisAlignment.spaceBetween,
                                        children: [
                                          Text(
                                            n.title,
                                            style: GoogleFonts.outfit(
                                              fontSize: 16,
                                              fontWeight: n.isRead
                                                  ? FontWeight.w500
                                                  : FontWeight.w700,
                                              color: Colors.white,
                                            ),
                                          ),
                                          Text(
                                            n.date,
                                            style: GoogleFonts.outfit(
                                              fontSize: 12,
                                              color: Colors.white.withValues(
                                                alpha: n.isRead ? 0.4 : 0.7,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 6),
                                      Text(
                                        n.message,
                                        style: GoogleFonts.outfit(
                                          fontSize: 14,
                                          color: Colors.white.withValues(
                                            alpha: 0.6,
                                          ),
                                          height: 1.4,
                                        ),
                                      ),
                                    ],
                                  ),
                                );
                              },
                            ),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Notification {
  final String id;
  final String title;
  final String message;
  final bool isRead;
  final String date;

  _Notification({
    required this.id,
    required this.title,
    required this.message,
    required this.isRead,
    required this.date,
  });

  _Notification copyWith({
    String? id,
    String? title,
    String? message,
    bool? isRead,
    String? date,
  }) {
    return _Notification(
      id: id ?? this.id,
      title: title ?? this.title,
      message: message ?? this.message,
      isRead: isRead ?? this.isRead,
      date: date ?? this.date,
    );
  }
}

class _NotificationCacheEntry {
  const _NotificationCacheEntry({
    required this.notifications,
    required this.fetchedAt,
  });

  final List<_Notification> notifications;
  final DateTime fetchedAt;
}
