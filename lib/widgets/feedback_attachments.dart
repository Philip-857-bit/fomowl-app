import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import '../services/feedback_service.dart';
import '../services/system_picker_guard.dart';
import '../services/wallet_service.dart';

class FeedbackAttachments extends StatefulWidget {
  const FeedbackAttachments({
    super.key,
    required this.onChanged,
    required this.onBusyChanged,
    this.disabled = false,
  });
  final ValueChanged<List<FeedbackAttachment>> onChanged;
  final ValueChanged<bool> onBusyChanged;
  final bool disabled;

  @override
  State<FeedbackAttachments> createState() => _FeedbackAttachmentsState();
}

class _FeedbackAttachmentsState extends State<FeedbackAttachments> {
  final _files = <FeedbackAttachment>[];
  final _service = FeedbackService();
  bool _busy = false;
  String? _error;

  Future<void> _pick() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    widget.onBusyChanged(true);
    try {
      SystemPickerGuard.arm();
      final file = await FilePicker.pickFile(
        type: FileType.custom,
        allowedExtensions: feedbackFileTypes.keys.toList(),
      );
      SystemPickerGuard.clear();
      if (!mounted || file == null) return;
      validateFeedbackFile(file.name, await file.length());
      final bytes = await file.readAsBytes();
      final wallet = await WalletService().getCurrentWalletAddress();
      if (wallet == null || wallet.isEmpty) {
        throw Exception('Connect your wallet to attach a file.');
      }
      final uploaded = await _service.uploadAttachment(
        walletAddress: wallet,
        name: file.name,
        bytes: bytes,
      );
      if (!mounted) return;
      setState(() => _files.add(uploaded));
      widget.onChanged(List.unmodifiable(_files));
    } catch (error) {
      if (mounted) {
        setState(
          () => _error = error is FormatException
              ? error.message
              : 'Unable to upload attachment. Please try again.',
        );
      }
    } finally {
      SystemPickerGuard.clear();
      if (mounted) {
        setState(() => _busy = false);
        widget.onBusyChanged(false);
      }
    }
  }

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      OutlinedButton.icon(
        onPressed: widget.disabled || _busy || _files.length >= 3
            ? null
            : _pick,
        icon: _busy
            ? const SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : const Icon(Icons.attach_file),
        label: Text(
          _busy ? 'Uploading attachment...' : 'Attach screenshot or file',
        ),
      ),
      const Text(
        'Optional: up to 3 images, PDFs or videos, 15 MB each.',
        style: TextStyle(fontSize: 12),
      ),
      for (final file in _files)
        Row(
          children: [
            const Icon(Icons.insert_drive_file_outlined, size: 18),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                file.name,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            IconButton(
              tooltip: 'Remove ${file.name}',
              onPressed: widget.disabled || _busy
                  ? null
                  : () {
                      setState(() => _files.remove(file));
                      widget.onChanged(List.unmodifiable(_files));
                    },
              icon: const Icon(Icons.close),
            ),
          ],
        ),
      if (_error != null)
        Text(
          _error!,
          style: TextStyle(color: Theme.of(context).colorScheme.error),
        ),
    ],
  );
}
