import 'package:flutter/material.dart';

import 'burst_theme.dart';

import '../../services/nft_service.dart';
import 'burst_campaign_draft.dart';

class BurstNftSelection {
  const BurstNftSelection({required this.allocations, required this.randomize});

  final List<BurstNftAllocation> allocations;
  final bool randomize;
}

/// Selects one allocation for each guest; all assets share a collection.
class BurstNftGalleryScreen extends StatefulWidget {
  const BurstNftGalleryScreen({
    super.key,
    required this.inventory,
    required this.selected,
    this.randomize = false,
  });
  final List<NftAsset> inventory;
  final List<BurstNftAllocation> selected;
  final bool randomize;

  @override
  State<BurstNftGalleryScreen> createState() => _BurstNftGalleryScreenState();
}

class _BurstNftGalleryScreenState extends State<BurstNftGalleryScreen> {
  late final List<BurstNftAllocation> _selected = List.of(widget.selected);
  late bool _randomize = widget.randomize;
  String? _error;

  bool _same(NftAsset a, NftAsset b) =>
      a.contractAddress.toLowerCase() == b.contractAddress.toLowerCase() &&
      a.tokenId == b.tokenId;

  void _select(NftAsset asset) {
    if (_selected.isNotEmpty &&
        (_selected.first.asset.contractAddress.toLowerCase() !=
                asset.contractAddress.toLowerCase() ||
            _selected.first.asset.isErc1155 != asset.isErc1155)) {
      setState(() => _error = 'Choose NFTs from the same collection.');
      return;
    }
    final matching = _selected
        .where((entry) => _same(entry.asset, asset))
        .toList();
    if (!asset.isErc1155 && matching.isNotEmpty) {
      setState(() {
        _selected.remove(matching.first);
        _error = null;
      });
      return;
    }
    final used = matching.fold<int>(0, (sum, entry) => sum + entry.quantity);
    if (used >= asset.count) {
      setState(() => _error = 'All available copies are already selected.');
      return;
    }
    setState(() {
      _selected.add(BurstNftAllocation(asset: asset, quantity: 1));
      _error = null;
    });
  }

  void _removeAllocation(NftAsset asset) {
    final index = _selected.lastIndexWhere(
      (entry) => _same(entry.asset, asset),
    );
    if (index < 0) return;
    setState(() {
      _selected.removeAt(index);
      _error = null;
    });
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: const Color(0xff0f0f0f),
    appBar: AppBar(
      backgroundColor: Colors.transparent,
      foregroundColor: Colors.white,
      title: const BurstHeader(),
      centerTitle: true,
    ),
    body: SafeArea(
      child: Column(
        children: [
          const Padding(
            padding: EdgeInsets.fromLTRB(20, 16, 20, 0),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'Select NFTs',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
          const Padding(
            padding: EdgeInsets.fromLTRB(20, 8, 20, 12),
            child: Text(
              'Choose one allocation for each guest. For multiple copies, tap an NFT again.',
              style: TextStyle(color: Colors.white70),
            ),
          ),
          SwitchListTile(
            contentPadding: const EdgeInsets.symmetric(horizontal: 20),
            title: const Text(
              'Auto-assign randomly',
              style: TextStyle(color: Colors.white),
            ),
            subtitle: const Text(
              'Shuffle the selected NFT allocations before guests join.',
              style: TextStyle(color: Colors.white70),
            ),
            value: _randomize,
            activeThumbColor: burstAccent(context),
            onChanged: (value) => setState(() => _randomize = value),
          ),
          if (_error != null)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Text(
                _error!,
                style: const TextStyle(color: Color(0xffff8b91)),
              ),
            ),
          Expanded(
            child: widget.inventory.isEmpty
                ? const Center(
                    child: Text(
                      'No supported NFTs found on this network.',
                      style: TextStyle(color: Colors.white70),
                    ),
                  )
                : GridView.builder(
                    padding: const EdgeInsets.all(20),
                    gridDelegate:
                        const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 2,
                          crossAxisSpacing: 12,
                          mainAxisSpacing: 12,
                          childAspectRatio: 0.78,
                        ),
                    itemCount: widget.inventory.length,
                    itemBuilder: (context, index) {
                      final asset = widget.inventory[index];
                      final count = _selected
                          .where((item) => _same(item.asset, asset))
                          .length;
                      return InkWell(
                        onTap: () => _select(asset),
                        borderRadius: BorderRadius.circular(10),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              child: Stack(
                                fit: StackFit.expand,
                                children: [
                                  ClipRRect(
                                    borderRadius: BorderRadius.circular(10),
                                    child: asset.imageUrl.isEmpty
                                        ? const ColoredBox(
                                            color: Color(0xff292929),
                                            child: Icon(
                                              Icons.image_outlined,
                                              color: Colors.white54,
                                            ),
                                          )
                                        : Image.network(
                                            asset.imageUrl,
                                            fit: BoxFit.cover,
                                            errorBuilder: (_, _, _) =>
                                                const ColoredBox(
                                                  color: Color(0xff292929),
                                                  child: Icon(
                                                    Icons.image_outlined,
                                                    color: Colors.white54,
                                                  ),
                                                ),
                                          ),
                                  ),
                                  if (count > 0)
                                    Positioned(
                                      top: 8,
                                      right: 8,
                                      child: CircleAvatar(
                                        radius: 14,
                                        backgroundColor: burstAccent(context),
                                        foregroundColor: burstOnAccent(context),
                                        child: Text(
                                          '$count',
                                          style: TextStyle(
                                            color: burstOnAccent(context),
                                            fontSize: 12,
                                          ),
                                        ),
                                      ),
                                    ),
                                  if (asset.isErc1155 && count > 0)
                                    Positioned(
                                      top: 4,
                                      left: 4,
                                      child: IconButton.filled(
                                        tooltip: 'Remove NFT allocation',
                                        onPressed: () =>
                                            _removeAllocation(asset),
                                        style: IconButton.styleFrom(
                                          backgroundColor: const Color(
                                            0xff343434,
                                          ),
                                          foregroundColor: Colors.white,
                                          minimumSize: const Size(36, 36),
                                        ),
                                        icon: const Icon(
                                          Icons.remove,
                                          size: 18,
                                        ),
                                      ),
                                    ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              asset.name,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(color: Colors.white),
                            ),
                            Text(
                              '${asset.collection} · #${asset.tokenId}',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: Colors.white70,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
          ),
          Padding(
            padding: const EdgeInsets.all(20),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    '${_selected.length} selected',
                    style: const TextStyle(color: Colors.white),
                  ),
                ),
                FilledButton(
                  onPressed: () => Navigator.pop(
                    context,
                    BurstNftSelection(
                      allocations: List.of(_selected),
                      randomize: _randomize,
                    ),
                  ),
                  style: FilledButton.styleFrom(
                    shape: burstButtonShape,
                    backgroundColor: burstAccent(context),
                    foregroundColor: burstOnAccent(context),
                  ),
                  child: const Text('Confirm selection'),
                ),
              ],
            ),
          ),
        ],
      ),
    ),
  );
}
