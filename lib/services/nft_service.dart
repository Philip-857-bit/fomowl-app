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
  });

  bool get isErc1155 => tokenType.toUpperCase().contains('1155');
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

          return NftAsset(
            name:
                nft['name']?.toString() ??
                contract['name']?.toString() ??
                'Unknown Token',
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
            tokenId: normalizeTokenId(id['tokenId']?.toString()),
            tokenType: normalizeTokenType(
              nft['tokenType']?.toString() ?? contract['tokenType']?.toString(),
              balance: int.tryParse(nft['balance']?.toString() ?? '1') ?? 1,
            ),
            isProjectNft:
                contractAddress.toLowerCase() ==
                _projectNftAddress.toLowerCase(),
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
}
