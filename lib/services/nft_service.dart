import 'dart:convert';

import 'package:http/http.dart' as http;

import '../config/app_environment.dart';
import '../models/chain.dart';

class NftAsset {
  final String name;
  final String collection;
  final String description;
  final int count;
  final String chainName;
  final int chainId;
  final String imageUrl;
  final String contractAddress;
  final String tokenId;
  final String tokenType;
  final bool isProjectNft;
  final String rarity;
  final int? rarityRank;

  const NftAsset({
    required this.name,
    required this.collection,
    required this.description,
    required this.count,
    required this.chainName,
    this.chainId = 0,
    required this.imageUrl,
    required this.contractAddress,
    required this.tokenId,
    this.tokenType = 'ERC721',
    required this.isProjectNft,
    this.rarity = '',
    this.rarityRank,
  });

  bool get isErc1155 => tokenType.toUpperCase().contains('1155');
  bool get hasRarity => rarity.trim().isNotEmpty;
}

/// A collection-level view of the NFTs owned by a wallet.
class NftCollectionGroup {
  const NftCollectionGroup({
    required this.key,
    required this.name,
    required this.chainName,
    required this.chainId,
    required this.contractAddress,
    required this.assets,
  });

  final String key;
  final String name;
  final String chainName;
  final int chainId;
  final String contractAddress;
  final List<NftAsset> assets;

  int get totalCount => assets.fold(0, (sum, asset) => sum + asset.count);
  NftAsset get coverAsset => assets.first;
}

List<NftCollectionGroup> groupNftsByCollection(Iterable<NftAsset> nfts) {
  final groups = <String, List<NftAsset>>{};
  for (final nft in nfts) {
    final key = nftCollectionKey(nft);
    groups.putIfAbsent(key, () => <NftAsset>[]).add(nft);
  }
  return groups.entries.map((entry) {
    final first = entry.value.first;
    return NftCollectionGroup(
      key: entry.key,
      name: first.collection,
      chainName: first.chainName,
      chainId: first.chainId,
      contractAddress: first.contractAddress,
      assets: List.unmodifiable(entry.value),
    );
  }).toList();
}

String nftCollectionKey(NftAsset nft) {
  final contract = nft.contractAddress.trim().toLowerCase();
  if (contract.isNotEmpty) {
    return '${nft.chainId}:$contract';
  }
  return '${nft.chainId}:collection:${nft.collection.trim().toLowerCase()}';
}

class NftService {
  static const String _projectNftAddress =
      '0x09A3Dc6ceB95D741E6445B0227B0939C27E5Dd52';
  static const Set<int> supportedChainIds = {1, 56, 137, 10, 42161, 8453};

  bool isSupportedChain(int chainId) => supportedChainIds.contains(chainId);

  Future<List<NftAsset>> fetchOwnedNftsAcrossChains({
    required Iterable<EvmChain> chains,
    required String walletAddress,
  }) async {
    if (walletAddress.isEmpty) {
      return const [];
    }

    final seenChainIds = <int>{};
    final supportedChains = chains
        .where((chain) {
          return isSupportedChain(chain.chainId) &&
              seenChainIds.add(chain.chainId);
        })
        .toList(growable: false);
    if (supportedChains.isEmpty) {
      return const [];
    }

    final results = await Future.wait(
      supportedChains.map((chain) async {
        try {
          final nfts = await fetchOwnedNfts(
            chainId: chain.chainId,
            chainName: chain.name,
            walletAddress: walletAddress,
          );
          return (nfts: nfts, failed: false);
        } catch (_) {
          return (nfts: const <NftAsset>[], failed: true);
        }
      }),
    );

    final aggregated = <NftAsset>[];
    final seenAssetKeys = <String>{};
    var successCount = 0;
    for (final result in results) {
      if (!result.failed) {
        successCount += 1;
      }
      for (final nft in result.nfts) {
        final key = [
          nft.chainName.toLowerCase(),
          nft.contractAddress.toLowerCase(),
          nft.tokenId,
        ].join(':');
        if (seenAssetKeys.add(key)) {
          aggregated.add(nft);
        }
      }
    }

    if (successCount == 0) {
      throw Exception('NFT API error across supported chains');
    }

    return aggregated;
  }

  Future<List<NftAsset>> fetchOwnedNfts({
    required int chainId,
    required String chainName,
    required String walletAddress,
  }) async {
    if (!isSupportedChain(chainId) || walletAddress.isEmpty) {
      return const [];
    }

    final url = AppEnvironment.blockchain('/$chainId/nfts/$walletAddress');
    final response = await http.get(url).timeout(const Duration(seconds: 60));
    if (response.statusCode != 200) {
      throw Exception('NFT API error: ${response.statusCode}');
    }

    final data = jsonDecode(response.body) as Map<String, dynamic>;
    final ownedNfts = data['ownedNfts'] as List<dynamic>? ?? const [];
    return ownedNfts
        .whereType<Map<String, dynamic>>()
        .where((nft) => !_isLikelySpamNft(nft))
        .map<NftAsset>((nft) {
          final contract = nft['contract'] as Map<String, dynamic>? ?? const {};
          final image = nft['image'] as Map<String, dynamic>? ?? const {};
          final id = nft['id'] as Map<String, dynamic>? ?? const {};
          final contractAddress = contract['address']?.toString() ?? '';
          final name =
              nft['name']?.toString() ??
              contract['name']?.toString() ??
              'Unknown Token';

          return NftAsset(
            name: name,
            collection: contract['name']?.toString() ?? 'Unknown Collection',
            description: nft['description']?.toString().trim() ?? '',
            count: int.tryParse(nft['balance']?.toString() ?? '1') ?? 1,
            chainName: chainName,
            chainId: chainId,
            imageUrl: normalizeImageUrl(
              image['cachedUrl']?.toString() ??
                  image['originalUrl']?.toString(),
            ),
            contractAddress: contractAddress,
            tokenId: resolveTokenId(nft, id, name),
            tokenType: normalizeTokenType(
              nft['tokenType']?.toString() ?? contract['tokenType']?.toString(),
              balance: int.tryParse(nft['balance']?.toString() ?? '1') ?? 1,
            ),
            isProjectNft:
                contractAddress.toLowerCase() ==
                _projectNftAddress.toLowerCase(),
            rarity: resolveRarity(nft),
            rarityRank: resolveRarityRank(nft),
          );
        })
        .toList();
  }

  bool _isLikelySpamNft(Map<String, dynamic> nft) {
    // Never filter the project's own NFTs.
    final contract = nft['contract'];
    if (contract is Map<String, dynamic>) {
      final address = contract['address']?.toString() ?? '';
      if (address.toLowerCase() == _projectNftAddress.toLowerCase()) {
        return false;
      }
    }

    bool isTrue(dynamic value) => value == true;

    final spamInfo = nft['spamInfo'];
    if (spamInfo is Map<String, dynamic>) {
      if (isTrue(spamInfo['isSpam'])) {
        return true;
      }
    }

    if (contract is Map<String, dynamic>) {
      if (isTrue(contract['isSpam']) || isTrue(contract['isSpamContract'])) {
        return true;
      }
    }

    final collection = nft['collection'];
    if (collection is Map<String, dynamic>) {
      if (isTrue(collection['isSpam']) ||
          isTrue(collection['isSpamContract'])) {
        return true;
      }
    }

    return isTrue(nft['isSpam']);
  }

  String normalizeImageUrl(String? url) {
    if (url == null || url.trim().isEmpty) return '';
    var parsed = url.trim();
    if (parsed.startsWith('ipfs://')) {
      parsed = parsed.replaceFirst('ipfs://', 'https://ipfs.io/ipfs/');
    } else if (parsed.startsWith('ar://')) {
      parsed = parsed.replaceFirst('ar://', 'https://arweave.net/');
    }
    return parsed;
  }

  String normalizeTokenId(String? value) {
    if (value == null || value.trim().isEmpty) {
      return '';
    }
    final trimmed = value.trim();
    if (trimmed.startsWith('0x')) {
      try {
        return BigInt.parse(trimmed.substring(2), radix: 16).toString();
      } catch (_) {
        return trimmed;
      }
    }
    return trimmed;
  }

  String resolveTokenId(
    Map<String, dynamic> nft,
    Map<String, dynamic> id,
    String name,
  ) {
    for (final value in [
      nft['tokenId'],
      nft['token_id'],
      nft['tokenID'],
      id['tokenId'],
      id['token_id'],
      id['tokenID'],
    ]) {
      final normalized = normalizeTokenId(value?.toString());
      if (normalized.isNotEmpty) {
        return normalized;
      }
    }

    final nameMatch = RegExp(r'#\s*([0-9]+)\s*$').firstMatch(name.trim());
    if (nameMatch != null) {
      return nameMatch.group(1) ?? '';
    }
    return '';
  }

  String normalizeTokenType(String? value, {int balance = 1}) {
    final normalized = value?.trim().toUpperCase() ?? '';
    if (normalized.contains('1155')) {
      return 'ERC1155';
    }
    if (normalized.contains('721')) {
      return 'ERC721';
    }
    return balance > 1 ? 'ERC1155' : 'ERC721';
  }

  String resolveRarity(Map<String, dynamic> nft) {
    for (final container in _metadataContainers(nft)) {
      for (final key in const ['rarity', 'rarityTier', 'rarity_tier', 'tier']) {
        final resolved = _rarityValue(container[key]);
        if (resolved.isNotEmpty) {
          return resolved;
        }
      }

      final attributes = container['attributes'];
      if (attributes is! List) {
        continue;
      }
      for (final attribute in attributes.whereType<Map>()) {
        final traitName =
            [
                  attribute['trait_type'],
                  attribute['traitType'],
                  attribute['type'],
                  attribute['name'],
                ]
                .whereType<Object>()
                .map((value) => value.toString().trim())
                .firstWhere((value) => value.isNotEmpty, orElse: () => '');
        final normalizedTrait = traitName.toLowerCase().replaceAll(
          RegExp(r'[_-]+'),
          ' ',
        );
        if (normalizedTrait == 'rarity' ||
            normalizedTrait == 'rarity tier' ||
            normalizedTrait == 'tier') {
          final resolved = _rarityValue(attribute['value']);
          if (resolved.isNotEmpty) {
            return resolved;
          }
        }
      }
    }
    return '';
  }

  int? resolveRarityRank(Map<String, dynamic> nft) {
    for (final container in _metadataContainers(nft)) {
      for (final key in const ['rarityRank', 'rarity_rank', 'rank']) {
        final rank = _positiveInt(container[key]);
        if (rank != null) {
          return rank;
        }
      }
      final rarity = container['rarity'];
      if (rarity is Map) {
        final rank = _positiveInt(
          rarity['rank'] ?? rarity['rarityRank'] ?? rarity['rarity_rank'],
        );
        if (rank != null) {
          return rank;
        }
      }
    }
    return null;
  }

  Iterable<Map<String, dynamic>> _metadataContainers(
    Map<String, dynamic> nft,
  ) sync* {
    yield nft;

    final metadata = nft['metadata'];
    if (metadata is Map<String, dynamic>) {
      yield metadata;
    }

    final raw = nft['raw'];
    if (raw is Map<String, dynamic>) {
      yield raw;
      final rawMetadata = raw['metadata'];
      if (rawMetadata is Map<String, dynamic>) {
        yield rawMetadata;
      }
    }
  }

  String _rarityValue(dynamic value) {
    if (value is Map) {
      return _rarityValue(
        value['label'] ?? value['tier'] ?? value['name'] ?? value['value'],
      );
    }
    if (value == null || value is num || value is bool) {
      return '';
    }
    final resolved = value.toString().trim();
    return resolved.length <= 32 ? resolved : '';
  }

  int? _positiveInt(dynamic value) {
    final parsed = value is int ? value : int.tryParse(value?.toString() ?? '');
    return parsed != null && parsed > 0 ? parsed : null;
  }
}
