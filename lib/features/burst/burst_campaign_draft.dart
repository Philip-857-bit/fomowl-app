import 'dart:math';

import '../../services/nft_service.dart';

/// Amounts are converted using integers only; floating point loses token units.
BigInt burstBaseUnits(String text, int decimals) {
  if (decimals < 0 || decimals > 255) {
    throw const FormatException('Invalid token decimals.');
  }
  final match = RegExp(r'^(0|[1-9]\d*)(?:\.(\d+))?$').firstMatch(text.trim());
  if (match == null) throw const FormatException('Enter a valid amount.');
  final fraction = match.group(2) ?? '';
  if (fraction.length > decimals) {
    throw FormatException(
      'This asset supports at most $decimals decimal places.',
    );
  }
  final amount =
      BigInt.parse(match.group(1)!) * BigInt.from(10).pow(decimals) +
      BigInt.parse(
        fraction.padRight(decimals, '0').isEmpty
            ? '0'
            : fraction.padRight(decimals, '0'),
      );
  if (amount <= BigInt.zero || amount.bitLength > 256) {
    throw const FormatException('Enter a valid positive amount.');
  }
  return amount;
}

/// A preview is shown only when the allocation is exact and non-zero.
BigInt? burstPerParticipant(String amount, int decimals, int participants) {
  if (participants < 1) return null;
  try {
    final total = burstBaseUnits(amount, decimals);
    final count = BigInt.from(participants);
    if (total % count != BigInt.zero || total ~/ count == BigInt.zero) {
      return null;
    }
    return total ~/ count;
  } on FormatException {
    return null;
  }
}

class BurstNftAllocation {
  const BurstNftAllocation({required this.asset, required this.quantity});
  final NftAsset asset;
  final int quantity;
}

class BurstCampaignDraft {
  const BurstCampaignDraft({
    required this.chainId,
    required this.title,
    required this.description,
    required this.kind,
    required this.symbol,
    required this.decimals,
    required this.participants,
    required this.amount,
    this.assetAddress,
    this.nfts = const [],
    this.randomizeNfts = false,
    this.startTime,
    this.endTime,
  });
  final int chainId;
  final String title;
  final String description;
  final String kind;
  final String symbol;
  final int decimals;
  final int participants;
  final String amount;
  final String? assetAddress;
  final List<BurstNftAllocation> nfts;
  final bool randomizeNfts;
  final int? startTime;
  final int? endTime;

  Map<String, dynamic> toRequest({
    required String idempotencyKey,
    required int maxParticipants,
    required DateTime now,
    Random? random,
  }) {
    if (chainId <= 0 ||
        title.trim().isEmpty ||
        title.trim().length > 80 ||
        description.trim().length > 280 ||
        symbol.trim().isEmpty ||
        symbol.trim().length > 16) {
      throw const FormatException(
        'Enter a valid name, description and asset symbol.',
      );
    }
    if (!{'native', 'erc20', 'erc721', 'erc1155'}.contains(kind) ||
        participants < 1 ||
        participants > maxParticipants ||
        decimals < 0 ||
        decimals > 255) {
      throw const FormatException('Invalid asset or participant count.');
    }
    final contract = assetAddress?.trim() ?? '';
    if (kind != 'native' &&
        (!RegExp(r'^0x[0-9a-fA-F]{40}$').hasMatch(contract) ||
            RegExp(r'^0x0{40}$', caseSensitive: false).hasMatch(contract))) {
      throw const FormatException('Select a valid asset contract.');
    }
    final nft = kind == 'erc721' || kind == 'erc1155';
    BigInt total = BigInt.zero;
    BigInt per = BigInt.zero;
    if (nft) {
      if (participants > 250 || nfts.length != participants) {
        throw const FormatException(
          'Choose one NFT allocation per participant, up to 250 participants.',
        );
      }
      final used = <String, int>{};
      for (final allocation in nfts) {
        final asset = allocation.asset;
        final tokenId = BigInt.tryParse(asset.tokenId);
        if (asset.chainId != chainId ||
            asset.contractAddress.toLowerCase() != contract.toLowerCase() ||
            asset.isErc1155 != (kind == 'erc1155') ||
            tokenId == null ||
            tokenId.isNegative ||
            tokenId.bitLength > 256 ||
            allocation.quantity < 1 ||
            (kind == 'erc721' && allocation.quantity != 1)) {
          throw const FormatException(
            'An NFT allocation is invalid for this collection.',
          );
        }
        final key = tokenId.toString();
        used[key] = (used[key] ?? 0) + allocation.quantity;
        if (used[key]! > asset.count || (kind == 'erc721' && used[key]! > 1)) {
          throw const FormatException(
            'NFT allocations exceed the available inventory.',
          );
        }
      }
    } else {
      total = burstBaseUnits(amount, decimals);
      if (total % BigInt.from(participants) != BigInt.zero) {
        throw const FormatException(
          'The total must divide evenly across participants.',
        );
      }
      per = total ~/ BigInt.from(participants);
      if (per == BigInt.zero) {
        throw const FormatException(
          'Each participant must receive at least one base unit.',
        );
      }
    }
    final allocationOrder = List<BurstNftAllocation>.of(nfts);
    if (nft && randomizeNfts) {
      allocationOrder.shuffle(random ?? Random.secure());
    }
    return {
      'chainId': chainId,
      'title': title.trim(),
      'description': description.trim(),
      'assetKind': kind,
      if (kind != 'native') 'assetAddress': contract,
      'assetSymbol': symbol.trim().toUpperCase(),
      'assetDecimals': decimals,
      'totalAmountBaseUnits': total.toString(),
      'amountPerParticipantBaseUnits': per.toString(),
      if (nft)
        'nftAllocations': allocationOrder
            .map(
              (a) => {
                'tokenId': BigInt.parse(a.asset.tokenId).toString(),
                'amount': '${a.quantity}',
              },
            )
            .toList(),
      'maxParticipants': participants,
      if (startTime != null) 'startTime': startTime,
      if (endTime != null) 'endTime': endTime,
      'idempotencyKey': idempotencyKey,
    };
  }
}
