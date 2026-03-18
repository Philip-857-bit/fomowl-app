import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../constants/app_colors.dart';

class AdminActionsSection extends StatefulWidget {
  final VoidCallback onSendTestPush;
  final TextEditingController walletController;
  final TextEditingController titleController;
  final TextEditingController messageController;
  final bool isLoading;

  const AdminActionsSection({
    Key? key,
    required this.onSendTestPush,
    required this.walletController,
    required this.titleController,
    required this.messageController,
    this.isLoading = false,
  }) : super(key: key);

  @override
  State<AdminActionsSection> createState() => _AdminActionsSectionState();
}

class _AdminActionsSectionState extends State<AdminActionsSection> {
  @override
  Widget build(BuildContext context) {
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
            'Administrative Actions',
            style: GoogleFonts.outfit(
              color: Colors.white,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: widget.walletController,
            style: const TextStyle(color: Colors.white),
            decoration: InputDecoration(
              hintText: 'Wallet for test push',
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
            controller: widget.titleController,
            style: const TextStyle(color: Colors.white),
            decoration: InputDecoration(
              hintText: 'Push title',
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
            decoration: InputDecoration(
              hintText: 'Push message',
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
            child: ElevatedButton.icon(
              onPressed: widget.isLoading ? null : widget.onSendTestPush,
              icon: const Icon(Icons.send),
              label: Text(widget.isLoading ? 'Sending...' : 'Send Test Push'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.accentRed,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
