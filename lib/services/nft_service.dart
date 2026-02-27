import 'dart:convert';

import 'package:http/http.dart' as http;

class NftAsset {
  final String name;
  final String collection;
  final int count;
  final String chainName;
  final String imageUrl;
  final bool isProjectNft;

  const NftAsset({
    required this.name,
    required this.collection,
    required this.count,
    required this.chainName,
    required this.imageUrl,
    required this.isProjectNft,
  });
}

class NftService {
  static const String _baseUrl =
      'https://fomowl-backend.onrender.com/api/blockchain';
  static const String _projectNftAddress =
      '0x09A3Dc6ceB95D741E6445B0227B0939C27E5Dd52';
  static const Set<int> supportedChainIds = {1, 137, 10, 42161, 8453};

  bool isSupportedChain(int chainId) => supportedChainIds.contains(chainId);

  Future<List<NftAsset>> fetchOwnedNfts({
    required int chainId,
    required String chainName,
    required String walletAddress,
  }) async {
    if (!isSupportedChain(chainId) || walletAddress.isEmpty) {
      return const [];
    }

    final url = Uri.parse('$_baseUrl/$chainId/nfts/$walletAddress');
    final response = await http.get(url).timeout(const Duration(seconds: 60));
    if (response.statusCode != 200) {
      throw Exception('NFT API error: ${response.statusCode}');
    }

    final data = jsonDecode(response.body) as Map<String, dynamic>;
    final ownedNfts = data['ownedNfts'] as List<dynamic>? ?? const [];
    return ownedNfts.map<NftAsset>((dynamic raw) {
      final nft = raw as Map<String, dynamic>;
      final contract = nft['contract'] as Map<String, dynamic>? ?? const {};
      final image = nft['image'] as Map<String, dynamic>? ?? const {};
      final contractAddress = contract['address']?.toString() ?? '';

      return NftAsset(
        name:
            nft['name']?.toString() ??
            contract['name']?.toString() ??
            'Unknown Token',
        collection: contract['name']?.toString() ?? 'Unknown Collection',
        count: int.tryParse(nft['balance']?.toString() ?? '1') ?? 1,
        chainName: chainName,
        imageUrl: normalizeImageUrl(
          image['cachedUrl']?.toString() ?? image['originalUrl']?.toString(),
        ),
        isProjectNft:
            contractAddress.toLowerCase() == _projectNftAddress.toLowerCase(),
      );
    }).toList();
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
}
