import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../constants/app_colors.dart';
import '../../../l10n/app_localizations.dart';

class AdminPushSection extends StatefulWidget {
  final VoidCallback onSendBroadcast;
  final TextEditingController titleController;
  final TextEditingController messageController;
  final bool isLoading;

  const AdminPushSection({
    Key? key,
    required this.onSendBroadcast,
    required this.titleController,
    required this.messageController,
    this.isLoading = false,
  }) : super(key: key);

  @override
  State<AdminPushSection> createState() => _AdminPushSectionState();
}

class _AdminPushSectionState extends State<AdminPushSection> {
  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.cardDark,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            l.adminGlobalBroadcast,
            style: GoogleFonts.outfit(
              color: Colors.white,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: widget.titleController,
            style: const TextStyle(color: Colors.white),
            decoration: InputDecoration(
              hintText: l.adminNotificationTitleHint,
              hintStyle: const TextStyle(color: Colors.white38),
              filled: true,
              fillColor: Colors.black26,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide.none,
              ),
            ),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: widget.messageController,
            style: const TextStyle(color: Colors.white),
            maxLines: 2,
            decoration: InputDecoration(
              hintText: l.adminMessageBodyHint,
              hintStyle: const TextStyle(color: Colors.white38),
              filled: true,
              fillColor: Colors.black26,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide.none,
              ),
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: widget.isLoading ? null : widget.onSendBroadcast,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.accentRed,
              ),
              child: Text(
                widget.isLoading ? 'Sending...' : l.adminSendToAllUsers,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
