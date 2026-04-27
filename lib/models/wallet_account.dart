import 'chain.dart';

enum WalletOrigin { derived, imported }

class WalletAccount {
  final String address;
  final String name;
  final WalletOrigin origin;
  final int? derivationIndex;
  final DateTime createdAt;
  final Map<ChainFamily, String> addressesByFamily;

  WalletAccount({
    required this.address,
    required this.name,
    required this.origin,
    this.derivationIndex,
    required this.createdAt,
    Map<ChainFamily, String>? addressesByFamily,
  }) : addressesByFamily = Map.unmodifiable(
         _normalizeAddressesByFamily(address, addressesByFamily),
       );

  factory WalletAccount.fromJson(Map<String, dynamic> json) {
    final address = json['address'] as String? ?? '';
    return WalletAccount(
      address: address,
      name: json['name'] as String? ?? 'Wallet',
      origin: WalletOrigin.values.firstWhere(
        (o) =>
            o.name == (json['origin'] as String? ?? WalletOrigin.derived.name),
        orElse: () => WalletOrigin.derived,
      ),
      derivationIndex: json['derivationIndex'] as int?,
      createdAt:
          DateTime.tryParse(json['createdAt'] as String? ?? '') ??
          DateTime.now(),
      addressesByFamily: _parseAddressesByFamily(
        json['addressesByFamily'],
        address,
      ),
    );
  }

  String? getWalletAddressForFamily(ChainFamily family) {
    final mapped = addressesByFamily[family]?.trim();
    if (mapped != null && mapped.isNotEmpty) {
      return mapped;
    }
    if (family == ChainFamily.evm && address.trim().isNotEmpty) {
      return address;
    }
    return null;
  }

  Map<String, dynamic> toJson() => {
    'address': address,
    'addressesByFamily': addressesByFamily.map(
      (family, familyAddress) => MapEntry(family.wireValue, familyAddress),
    ),
    'name': name,
    'origin': origin.name,
    'derivationIndex': derivationIndex,
    'createdAt': createdAt.toIso8601String(),
  };

  static Map<ChainFamily, String> _normalizeAddressesByFamily(
    String address,
    Map<ChainFamily, String>? addressesByFamily,
  ) {
    final normalized = <ChainFamily, String>{};
    addressesByFamily?.forEach((family, familyAddress) {
      final trimmed = familyAddress.trim();
      if (trimmed.isNotEmpty) {
        normalized[family] = trimmed;
      }
    });
    final evmAddress = address.trim();
    if (evmAddress.isNotEmpty) {
      normalized.putIfAbsent(ChainFamily.evm, () => evmAddress);
    }
    return normalized;
  }

  static Map<ChainFamily, String> _parseAddressesByFamily(
    Object? raw,
    String legacyAddress,
  ) {
    final parsed = <ChainFamily, String>{};
    if (raw is Map) {
      raw.forEach((key, value) {
        final family = ChainFamilyCodec.fromWireValue(key?.toString());
        final address = value?.toString().trim();
        if (address != null && address.isNotEmpty) {
          parsed[family] = address;
        }
      });
    }
    return _normalizeAddressesByFamily(legacyAddress, parsed);
  }
}
