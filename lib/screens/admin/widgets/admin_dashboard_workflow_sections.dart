import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../constants/app_colors.dart';
import 'admin_dashboard_common.dart';

class AdminFeedbackSection extends StatelessWidget {
  const AdminFeedbackSection({
    super.key,
    required this.walletController,
    required this.feedbackItems,
    required this.feedbackPage,
    required this.feedbackTotal,
    required this.onSearch,
    required this.onCopyCsv,
    required this.onCopyJson,
    required this.onPreviousPage,
    required this.onNextPage,
  });

  final TextEditingController walletController;
  final List<Map<String, dynamic>> feedbackItems;
  final int feedbackPage;
  final int feedbackTotal;
  final VoidCallback onSearch;
  final VoidCallback onCopyCsv;
  final VoidCallback onCopyJson;
  final VoidCallback? onPreviousPage;
  final VoidCallback? onNextPage;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const AdminSectionHeading(
          title: 'Feedback queue',
          subtitle: 'Review incoming reports, filter by wallet, and export the visible queue.',
        ),
        AdminCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextField(
                controller: walletController,
                style: const TextStyle(color: Colors.white),
                decoration: adminInputDecoration(
                  label: 'Wallet filter',
                  hint: 'Optional wallet address',
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
                    onPressed: onCopyCsv,
                    icon: const Icon(Icons.table_view_outlined),
                    label: const Text('Copy CSV'),
                  ),
                  OutlinedButton.icon(
                    onPressed: onCopyJson,
                    icon: const Icon(Icons.data_object_rounded),
                    label: const Text('Copy JSON'),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Text(
                'Showing ${feedbackItems.length} of $feedbackTotal reports · Page $feedbackPage',
                style: GoogleFonts.outfit(
                  color: AppColors.textSecondary,
                  fontSize: 13,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        if (feedbackItems.isEmpty)
          const AdminEmptyState(
            title: 'No feedback found',
            message: 'Try a different wallet filter or refresh after new feedback arrives.',
          )
        else
          ...feedbackItems.map(
            (item) => Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: AdminFeedbackCard(item: item),
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
              onPressed: onNextPage,
              icon: const Icon(Icons.chevron_right_rounded),
              label: const Text('Next'),
            ),
          ],
        ),
      ],
    );
  }
}

class AdminActionsSection extends StatelessWidget {
  const AdminActionsSection({
    super.key,
    required this.isSending,
    required this.walletController,
    required this.titleController,
    required this.messageController,
    required this.onSend,
    required this.lastResult,
  });

  final bool isSending;
  final TextEditingController walletController;
  final TextEditingController titleController;
  final TextEditingController messageController;
  final VoidCallback onSend;
  final Map<String, dynamic>? lastResult;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const AdminSectionHeading(
          title: 'Manual actions',
          subtitle: 'Run one-off checks and test wallet push delivery from a single place.',
        ),
        AdminCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextField(
                controller: walletController,
                style: const TextStyle(color: Colors.white),
                decoration: adminInputDecoration(
                  label: 'Destination wallet',
                  hint: '0x...',
                  icon: Icons.account_balance_wallet_outlined,
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: titleController,
                style: const TextStyle(color: Colors.white),
                decoration: adminInputDecoration(
                  label: 'Notification title',
                  hint: 'Title',
                  icon: Icons.title_rounded,
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: messageController,
                style: const TextStyle(color: Colors.white),
                maxLines: 3,
                decoration: adminInputDecoration(
                  label: 'Notification message',
                  hint: 'Message body',
                  icon: Icons.message_outlined,
                ),
              ),
              const SizedBox(height: 14),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: isSending ? null : onSend,
                  icon: const Icon(Icons.send_rounded),
                  label: Text(isSending ? 'Sending...' : 'Send test push'),
                ),
              ),
            ],
          ),
        ),
        if (lastResult != null) ...[
          const SizedBox(height: 12),
          AdminResultCard(
            title: 'Last test push result',
            values: {
              'Wallet': (lastResult!['walletAddress'] ?? '--').toString(),
              'Stored notification': (lastResult!['notificationId'] ?? '--')
                  .toString(),
              'Registered devices': adminFormatCount(
                lastResult!['deviceTokens'],
              ),
              'Push sent': adminFormatCount(lastResult!['pushSent']),
              'Push failed': adminFormatCount(lastResult!['pushFailed']),
            },
          ),
        ],
      ],
    );
  }
}

class AdminPushSection extends StatelessWidget {
  const AdminPushSection({
    super.key,
    required this.isSending,
    required this.titleController,
    required this.messageController,
    required this.onSend,
    required this.lastResult,
  });

  final bool isSending;
  final TextEditingController titleController;
  final TextEditingController messageController;
  final VoidCallback onSend;
  final Map<String, dynamic>? lastResult;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const AdminSectionHeading(
          title: 'Broadcast push',
          subtitle: 'Publish one message to all wallets with registered devices in one action.',
        ),
        AdminCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextField(
                controller: titleController,
                style: const TextStyle(color: Colors.white),
                decoration: adminInputDecoration(
                  label: 'Broadcast title',
                  hint: 'Important update',
                  icon: Icons.campaign_outlined,
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: messageController,
                style: const TextStyle(color: Colors.white),
                maxLines: 4,
                decoration: adminInputDecoration(
                  label: 'Broadcast message',
                  hint: 'What should every wallet holder see?',
                  icon: Icons.message_outlined,
                ),
              ),
              const SizedBox(height: 14),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: isSending ? null : onSend,
                  icon: const Icon(Icons.notifications_active_outlined),
                  label: Text(isSending ? 'Sending...' : 'Send broadcast'),
                ),
              ),
            ],
          ),
        ),
        if (lastResult != null) ...[
          const SizedBox(height: 12),
          AdminResultCard(
            title: 'Last broadcast result',
            values: {
              'Wallet recipients': adminFormatCount(
                lastResult!['walletRecipients'],
              ),
              'Registered devices': adminFormatCount(
                lastResult!['estimatedRecipients'],
              ),
              'Notifications stored': adminFormatCount(
                lastResult!['notificationsStored'],
              ),
              'Push sent': adminFormatCount(lastResult!['pushSent']),
              'Push failed': adminFormatCount(lastResult!['pushFailed']),
            },
          ),
        ],
      ],
    );
  }
}
