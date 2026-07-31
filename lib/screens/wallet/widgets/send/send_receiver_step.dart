import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:share_plus/share_plus.dart';

import '../../../../constants/app_colors.dart';
import '../../../../services/recipient_book_service.dart';
import '../../../../utils/toast_utils.dart';

class SendReceiverStep extends StatefulWidget {
  const SendReceiverStep({
    super.key,
    required this.networkKey,
    required this.walletScope,
    required this.controller,
    required this.isValidAddress,
    required this.onSelected,
    required this.onBack,
    required this.onQrTap,
  });

  final String networkKey;
  final String walletScope;
  final TextEditingController controller;
  final bool Function(String address) isValidAddress;
  final void Function(WalletRecipient recipient) onSelected;
  final VoidCallback onBack;
  final Future<String?> Function() onQrTap;

  @override
  State<SendReceiverStep> createState() => _SendReceiverStepState();
}

class _SendReceiverStepState extends State<SendReceiverStep> {
  static const _assetRoot = 'assets/images/receiver_flow';
  final RecipientBookService _book = RecipientBookService();
  List<WalletRecipient> _recent = const [];
  List<WalletRecipient> _saved = const [];
  bool _savedTab = false;
  bool _showAll = false;

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_handleAddressChanged);
    _reload();
  }

  @override
  void didUpdateWidget(covariant SendReceiverStep oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!identical(oldWidget.controller, widget.controller)) {
      oldWidget.controller.removeListener(_handleAddressChanged);
      widget.controller.addListener(_handleAddressChanged);
    }
    if (oldWidget.networkKey != widget.networkKey ||
        oldWidget.walletScope != widget.walletScope) {
      _recent = const [];
      _saved = const [];
      _showAll = false;
      _reload();
    }
  }

  @override
  void dispose() {
    widget.controller.removeListener(_handleAddressChanged);
    super.dispose();
  }

  void _handleAddressChanged() {
    if (mounted) {
      setState(() {});
    }
  }

  Future<void> _reload() async {
    final values = await Future.wait([
      _book.recent(widget.networkKey, walletScope: widget.walletScope),
      _book.saved(widget.networkKey, walletScope: widget.walletScope),
    ]);
    if (!mounted) return;
    setState(() {
      _recent = values[0];
      _saved = values[1];
    });
  }

  void _submitAddress(String address) {
    final value = address.trim();
    if (!widget.isValidAddress(value)) {
      ToastUtils.showError('Enter a valid address for the selected network.');
      return;
    }
    widget.onSelected(
      WalletRecipient(
        address: value,
        walletScope: widget.walletScope,
        networkKey: widget.networkKey,
        label: '',
        lastUsedAt: DateTime.now(),
      ),
    );
  }

  Future<void> _paste() async {
    final value = (await Clipboard.getData(Clipboard.kTextPlain))?.text?.trim();
    if (value == null || value.isEmpty) return;
    widget.controller.text = value;
    widget.controller.selection = TextSelection.collapsed(offset: value.length);
  }

  Future<void> _scan() async {
    final value = await widget.onQrTap();
    if (value == null || value.trim().isEmpty) return;
    widget.controller.text = value.trim();
    widget.controller.selection = TextSelection.collapsed(
      offset: widget.controller.text.length,
    );
  }

  Future<void> _saveCurrentAddress() async {
    final address = widget.controller.text.trim();
    if (!widget.isValidAddress(address)) {
      ToastUtils.showError('Enter a valid address before saving.');
      return;
    }
    final label = await _askLabel('');
    if (label == null || label.isEmpty) {
      return;
    }
    await _book.save(
      networkKey: widget.networkKey,
      walletScope: widget.walletScope,
      address: address,
      label: label,
    );
    await _reload();
    if (!mounted) return;
    setState(() {
      _savedTab = true;
      _showAll = false;
    });
    ToastUtils.showSuccess('Receiver saved.');
  }

  String _short(String address) {
    if (address.length < 13) return address;
    return '${address.substring(0, 6)}...${address.substring(address.length - 5)}';
  }

  Future<String?> _askLabel(String initial) async {
    final controller = TextEditingController(text: initial);
    final value = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF13161B),
        title: Text(
          initial.isEmpty ? 'Save receiver' : 'Edit receiver name',
          style: GoogleFonts.inter(color: Colors.white),
        ),
        content: TextField(
          controller: controller,
          autofocus: true,
          style: GoogleFonts.inter(color: Colors.white),
          decoration: const InputDecoration(
            hintText: 'Address name',
            hintStyle: TextStyle(color: Color(0xFF94A3B8)),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, controller.text.trim()),
            child: const Text('Save'),
          ),
        ],
      ),
    );
    // The dialog route still builds during its closing animation.
    WidgetsBinding.instance.addPostFrameCallback((_) => controller.dispose());
    return value;
  }

  Future<void> _showActions(WalletRecipient recipient) async {
    final action = await showGeneralDialog<String>(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'Receiver actions',
      barrierColor: Colors.black54,
      pageBuilder: (context, _, _) => SafeArea(
        child: Align(
          alignment: const Alignment(0.82, -0.28),
          child: Material(
            color: Colors.transparent,
            child: Container(
              width: 230,
              decoration: BoxDecoration(
                color: const Color(0xFF13161B),
                borderRadius: BorderRadius.circular(16),
                boxShadow: const [
                  BoxShadow(
                    color: Colors.black54,
                    blurRadius: 24,
                    offset: Offset(0, 12),
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _ActionRow(
                    label: 'Share',
                    asset: '$_assetRoot/figma_icon_8.svg',
                    onTap: () => Navigator.pop(context, 'share'),
                  ),
                  _ActionRow(
                    label: 'Edit name',
                    asset: '$_assetRoot/figma_icon_9.svg',
                    onTap: () => Navigator.pop(context, 'edit'),
                  ),
                  _ActionRow(
                    label: 'Delete Address',
                    asset: '$_assetRoot/figma_icon_10.svg',
                    destructive: true,
                    onTap: () => Navigator.pop(context, 'delete'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
    if (action == 'share') {
      await SharePlus.instance.share(
        ShareParams(
          text: recipient.address,
          subject: recipient.label.isEmpty ? 'Wallet address' : recipient.label,
        ),
      );
    } else if (action == 'edit') {
      final label = await _askLabel(recipient.label);
      if (label != null && label.isNotEmpty) {
        await _book.save(
          networkKey: widget.networkKey,
          walletScope: widget.walletScope,
          address: recipient.address,
          label: label,
        );
        await _reload();
      }
    } else if (action == 'delete') {
      await _book.remove(
        widget.networkKey,
        recipient.address,
        walletScope: widget.walletScope,
      );
      await _reload();
    }
  }

  @override
  Widget build(BuildContext context) {
    final entries = _savedTab ? _saved : _recent;
    final shown = _showAll ? entries : entries.take(4).toList();
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          children: [
            SizedBox(
              height: 68,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Row(
                  children: [
                    SizedBox(
                      key: const ValueKey('send-receiver-back'),
                      width: 40,
                      height: 40,
                      child: Semantics(
                        button: true,
                        label: 'Back',
                        child: Material(
                          color: const Color(0xFF13161B),
                          shape: const CircleBorder(),
                          child: InkWell(
                            onTap: widget.onBack,
                            customBorder: const CircleBorder(),
                            child: Icon(
                              Icons.arrow_back_ios_new_rounded,
                              color: Colors.white,
                              size: 18,
                            ),
                          ),
                        ),
                      ),
                    ),
                    Expanded(
                      child: Center(
                        child: Text(
                          'Select Receiver',
                          style: GoogleFonts.inter(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 40),
                  ],
                ),
              ),
            ),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 28),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Send To:',
                      style: GoogleFonts.inter(
                        color: const Color(0xFF94A3B8),
                        fontSize: 14,
                        fontWeight: FontWeight.w400,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Container(
                      height: 48,
                      decoration: BoxDecoration(
                        color: const Color(0xFF13161B),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: const Color(0xFF2A333D)),
                      ),
                      child: TextField(
                        controller: widget.controller,
                        onSubmitted: _submitAddress,
                        textInputAction: TextInputAction.next,
                        style: GoogleFonts.inter(
                          color: Colors.white,
                          fontSize: 13,
                        ),
                        decoration: InputDecoration(
                          hintText: 'Wallet address',
                          hintStyle: GoogleFonts.inter(
                            color: const Color(0xFF64748B),
                            fontSize: 13,
                          ),
                          border: InputBorder.none,
                          contentPadding: const EdgeInsets.fromLTRB(
                            14,
                            14,
                            4,
                            12,
                          ),
                          suffixIconConstraints: const BoxConstraints(
                            minWidth: 116,
                          ),
                          suffixIcon: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              _FieldIcon(
                                asset: '$_assetRoot/figma_icon_4.svg',
                                onTap: widget.controller.clear,
                              ),
                              Tooltip(
                                message: 'Scan QR code',
                                child: Semantics(
                                  button: true,
                                  label: 'Scan QR code',
                                  child: InkWell(
                                    key: const ValueKey(
                                      'send-receiver-qr-scan',
                                    ),
                                    onTap: _scan,
                                    child: const SizedBox(
                                      width: 38,
                                      height: 42,
                                      child: Icon(
                                        Icons.qr_code_scanner_rounded,
                                        color: Colors.white,
                                        size: 21,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                              InkWell(
                                key: const ValueKey('send-receiver-paste'),
                                onTap: _paste,
                                child: SizedBox(
                                  width: 52,
                                  child: Center(
                                    child: Text(
                                      'Paste',
                                      style: GoogleFonts.inter(
                                        color: const Color(0xFFEA2A33),
                                        fontSize: 12,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            key: const ValueKey('send-receiver-save'),
                            onPressed:
                                widget.isValidAddress(
                                  widget.controller.text.trim(),
                                )
                                ? _saveCurrentAddress
                                : null,
                            style: OutlinedButton.styleFrom(
                              minimumSize: const Size.fromHeight(44),
                              foregroundColor: Colors.white,
                              side: const BorderSide(color: Color(0xFF2A333D)),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(11),
                              ),
                            ),
                            child: const Text('Save receiver'),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: FilledButton(
                            key: const ValueKey('send-receiver-continue'),
                            onPressed:
                                widget.isValidAddress(
                                  widget.controller.text.trim(),
                                )
                                ? () => _submitAddress(widget.controller.text)
                                : null,
                            style: FilledButton.styleFrom(
                              minimumSize: const Size.fromHeight(44),
                              backgroundColor: const Color(0xFFEA2A33),
                              disabledBackgroundColor: const Color(0xFF3A2023),
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(11),
                              ),
                            ),
                            child: const Text('Continue'),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 28),
                    Row(
                      children: [
                        Container(
                          width: 194,
                          height: 44,
                          padding: const EdgeInsets.all(4),
                          decoration: BoxDecoration(
                            color: const Color(0xFF13161B),
                            borderRadius: BorderRadius.circular(11),
                          ),
                          child: Row(
                            children: [
                              _Tab(
                                label: 'Recent',
                                selected: !_savedTab,
                                onTap: () => setState(() => _savedTab = false),
                              ),
                              _Tab(
                                label: 'Saved',
                                selected: _savedTab,
                                onTap: () => setState(() => _savedTab = true),
                              ),
                            ],
                          ),
                        ),
                        const Spacer(),
                        TextButton(
                          onPressed: () => setState(() => _showAll = !_showAll),
                          child: Text(
                            _showAll ? 'Show less' : 'See all',
                            style: GoogleFonts.inter(
                              color: Colors.white,
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 26),
                    if (shown.isEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 38),
                        child: Center(
                          child: Text(
                            _savedTab
                                ? 'Saved receivers will appear here.'
                                : 'Completed transfers will appear here.',
                            style: GoogleFonts.inter(
                              color: const Color(0xFF64748B),
                              fontSize: 13,
                            ),
                          ),
                        ),
                      )
                    else
                      ...shown.map(
                        (recipient) => _ReceiverRow(
                          recipient: recipient,
                          shortAddress: _short(recipient.address),
                          onTap: () => widget.onSelected(recipient),
                          onMenu: () => _showActions(recipient),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Tab extends StatelessWidget {
  const _Tab({
    required this.label,
    required this.selected,
    required this.onTap,
  });
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: selected ? const Color(0xFFEA2A33) : Colors.transparent,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(
            label,
            style: GoogleFonts.inter(
              color: selected ? Colors.white : const Color(0xFF94A3B8),
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ),
    );
  }
}

class _ReceiverRow extends StatelessWidget {
  const _ReceiverRow({
    required this.recipient,
    required this.shortAddress,
    required this.onTap,
    required this.onMenu,
  });
  final WalletRecipient recipient;
  final String shortAddress;
  final VoidCallback onTap;
  final VoidCallback onMenu;

  @override
  Widget build(BuildContext context) {
    final title = recipient.label.isEmpty ? 'Unknown Address' : recipient.label;
    return InkWell(
      onTap: onTap,
      child: Container(
        height: 61,
        margin: const EdgeInsets.only(bottom: 16),
        padding: const EdgeInsets.symmetric(horizontal: 12),
        decoration: BoxDecoration(
          border: Border.all(color: const Color(0xFF202832)),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          children: [
            Container(
              width: 48,
              height: 48,
              alignment: Alignment.center,
              decoration: const BoxDecoration(
                color: Color(0xFF1E293B),
                shape: BoxShape.circle,
              ),
              child: Text(
                title.substring(0, 1).toUpperCase(),
                style: GoogleFonts.inter(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          title,
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.inter(
                            color: Colors.white,
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      if (recipient.saved) ...[
                        const SizedBox(width: 7),
                        const CircleAvatar(
                          radius: 3,
                          backgroundColor: Color(0xFF22C55E),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    shortAddress,
                    style: GoogleFonts.inter(
                      color: const Color(0xFF94A3B8),
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
            IconButton(
              onPressed: onMenu,
              icon: SvgPicture.asset(
                'assets/images/receiver_flow/figma_icon_7.svg',
                width: 4,
                height: 16,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _FieldIcon extends StatelessWidget {
  const _FieldIcon({required this.asset, required this.onTap});
  final String asset;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: SizedBox(
        width: 30,
        height: 42,
        child: Center(child: SvgPicture.asset(asset, width: 17, height: 18)),
      ),
    );
  }
}

class _ActionRow extends StatelessWidget {
  const _ActionRow({
    required this.label,
    required this.asset,
    required this.onTap,
    this.destructive = false,
  });
  final String label;
  final String asset;
  final VoidCallback onTap;
  final bool destructive;

  @override
  Widget build(BuildContext context) {
    final color = destructive ? const Color(0xFFEA2A33) : Colors.white;
    return InkWell(
      onTap: onTap,
      child: SizedBox(
        height: 61,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 18),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  label,
                  style: GoogleFonts.inter(
                    color: color,
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
              SvgPicture.asset(
                asset,
                width: 16,
                height: 16,
                colorFilter: ColorFilter.mode(color, BlendMode.srcIn),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
