import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Slippage tolerance picker for the Swap screen.
/// Presets: 0.1% (10 bps), 0.5% (50 bps), 1% (100 bps), 3% (300 bps).
/// Custom: free-form text input clamped to [1, 5000] bps (0.01%–50%).
class SwapSlippageSection extends StatefulWidget {
  final int slippageBps;
  final ValueChanged<int> onChanged;

  const SwapSlippageSection({
    super.key,
    required this.slippageBps,
    required this.onChanged,
  });

  @override
  State<SwapSlippageSection> createState() => _SwapSlippageSectionState();
}

class _SwapSlippageSectionState extends State<SwapSlippageSection> {
  static const List<int> _presets = [10, 50, 100, 300];

  final TextEditingController _customController = TextEditingController();

  bool get _isCustom => !_presets.contains(widget.slippageBps);

  @override
  void initState() {
    super.initState();
    if (_isCustom) {
      _customController.text = (widget.slippageBps / 100.0).toStringAsFixed(2);
    }
  }

  @override
  void dispose() {
    _customController.dispose();
    super.dispose();
  }

  String _bpsLabel(int bps) {
    final pct = bps / 100.0;
    if (pct == pct.floorToDouble()) return '${pct.toInt()}%';
    return '$pct%';
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              'SLIPPAGE TOLERANCE',
              style: GoogleFonts.inter(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                letterSpacing: 1.0,
                color: const Color(0xFF8894A0),
              ),
            ),
            const SizedBox(width: 6),
            const Icon(
              Icons.info_outline_rounded,
              size: 14,
              color: Color(0xFF8894A0),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            for (int i = 0; i < _presets.length; i++) ...[
              if (i > 0) const SizedBox(width: 8),
              Expanded(
                child: _SlippageChip(
                  label: _bpsLabel(_presets[i]),
                  isSelected: widget.slippageBps == _presets[i] && !_isCustom,
                  onTap: () {
                    _customController.clear();
                    widget.onChanged(_presets[i]);
                  },
                ),
              ),
            ],
          ],
        ),
        const SizedBox(height: 10),
        Container(
          height: 48,
          decoration: BoxDecoration(
            color: const Color(0xFF151C24),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: _isCustom
                  ? const Color(0xFFEA2A33)
                  : const Color(0xFF2A333D),
            ),
          ),
          child: Row(
            children: [
              const SizedBox(width: 14),
              Expanded(
                child: TextField(
                  controller: _customController,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    color: const Color(0xFFE2E2E2),
                  ),
                  decoration: InputDecoration(
                    border: InputBorder.none,
                    hintText: 'Custom',
                    hintStyle: GoogleFonts.inter(
                      fontSize: 14,
                      color: const Color(0xFF848E9C),
                    ),
                    isDense: true,
                    contentPadding: EdgeInsets.zero,
                  ),
                  onChanged: (v) {
                    final pct = double.tryParse(v);
                    if (pct != null && pct > 0 && pct <= 50) {
                      final bps = (pct * 100).round().clamp(1, 5000);
                      widget.onChanged(bps);
                    }
                  },
                ),
              ),
              Padding(
                padding: const EdgeInsets.only(right: 14),
                child: Text(
                  '%',
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    color: const Color(0xFF848E9C),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _SlippageChip extends StatelessWidget {
  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  const _SlippageChip({
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 140),
        height: 40,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFFEA2A33) : const Color(0xFF151C24),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isSelected
                ? const Color(0xFFEA2A33)
                : const Color(0xFF2A333D),
          ),
        ),
        child: Text(
          label,
          style: GoogleFonts.inter(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: isSelected ? Colors.white : const Color(0xFF8894A0),
          ),
        ),
      ),
    );
  }
}
