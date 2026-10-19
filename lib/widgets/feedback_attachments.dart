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
    if (widget.disabled || _busy || _files.length >= 3) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    widget.onBusyChanged(true);
    try {
      SystemPickerGuard.arm();
      final files = await FilePicker.pickFiles(
        type: FileType.custom,
        allowedExtensions: feedbackFileTypes.keys.toList(),
      );
      SystemPickerGuard.clear();
      if (!mounted || files.isEmpty) return;
      final remaining = 3 - _files.length;
      if (files.length > remaining) {
        throw FormatException(
          'You can attach up to 3 files. Choose up to $remaining more.',
        );
      }
      // Validate the entire selection before starting any upload.
      for (final file in files) {
        validateFeedbackFile(file.name, await file.length());
      }
      final wallet = await WalletService().getCurrentWalletAddress();
      if (wallet == null || wallet.isEmpty) {
        throw Exception('Connect your wallet to attach files.');
      }
      final errors = <String>[];
      for (final file in files) {
        if (!mounted) return;
        try {
          final uploaded = await _service.uploadAttachment(
            walletAddress: wallet,
            name: file.name,
            bytes: await file.readAsBytes(),
          );
          if (!mounted) return;
          setState(() => _files.add(uploaded));
          widget.onChanged(List.unmodifiable(_files));
        } catch (_) {
          errors.add('${file.name}: unable to upload. Please try again.');
        }
      }
      if (mounted && errors.isNotEmpty) {
        setState(() => _error = errors.join('\n'));
      }
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
          _busy ? 'Uploading attachments...' : 'Attach screenshots or files',
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
