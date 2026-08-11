import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

class PendingBridgeOperation {
  final String walletAddress;
  final String requestId;
  final String originTxHash;
  final int originChainId;
  final int destinationChainId;
  final String? sellToken;
  final String? buyToken;
  final double? amount;
  final double? amountUsd;
  final DateTime createdAt;
  final DateTime? deadline;

  const PendingBridgeOperation({
    required this.walletAddress,
    required this.requestId,
    required this.originTxHash,
    required this.originChainId,
    required this.destinationChainId,
    this.sellToken,
    this.buyToken,
    this.amount,
    this.amountUsd,
    required this.createdAt,
    this.deadline,
  });

  Map<String, Object?> toJson() => {
    'walletAddress': walletAddress,
    'requestId': requestId,
    'originTxHash': originTxHash,
    'originChainId': originChainId,
    'destinationChainId': destinationChainId,
    'sellToken': sellToken,
    'buyToken': buyToken,
    'amount': amount,
    'amountUsd': amountUsd,
    'createdAt': createdAt.toUtc().toIso8601String(),
    'deadline': deadline?.toUtc().toIso8601String(),
  };

  factory PendingBridgeOperation.fromJson(Map<String, dynamic> json) {
    return PendingBridgeOperation(
      walletAddress: json['walletAddress']?.toString() ?? '',
      requestId: json['requestId']?.toString() ?? '',
      originTxHash: json['originTxHash']?.toString() ?? '',
      originChainId: (json['originChainId'] as num?)?.toInt() ?? 0,
      destinationChainId: (json['destinationChainId'] as num?)?.toInt() ?? 0,
      sellToken: json['sellToken']?.toString(),
      buyToken: json['buyToken']?.toString(),
      amount: (json['amount'] as num?)?.toDouble(),
      amountUsd: (json['amountUsd'] as num?)?.toDouble(),
      createdAt:
          DateTime.tryParse(json['createdAt']?.toString() ?? '') ??
          DateTime.now().toUtc(),
      deadline: DateTime.tryParse(json['deadline']?.toString() ?? ''),
    );
  }
}

class BridgeOperationStore {
  static const _prefix = 'pending_bridge_v1_';

  String _key(String walletAddress) {
    final address = walletAddress.trim();
    final isEvmAddress = RegExp(r'^0x[0-9a-fA-F]{40}$').hasMatch(address);
    return '$_prefix${isEvmAddress ? address.toLowerCase() : address}';
  }

  Future<void> save(PendingBridgeOperation operation) async {
    if (operation.walletAddress.trim().isEmpty ||
        operation.requestId.trim().isEmpty ||
        operation.originTxHash.trim().isEmpty) {
      throw ArgumentError('Pending bridge operation is incomplete.');
    }
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key(operation.walletAddress), jsonEncode(operation));
  }

  Future<PendingBridgeOperation?> load(String walletAddress) async {
    if (walletAddress.trim().isEmpty) return null;
    final prefs = await SharedPreferences.getInstance();
    final encoded = prefs.getString(_key(walletAddress));
    if (encoded == null || encoded.isEmpty) return null;
    try {
      final raw = jsonDecode(encoded);
      if (raw is! Map) return null;
      final operation = PendingBridgeOperation.fromJson(
        Map<String, dynamic>.from(raw),
      );
      if (operation.requestId.isEmpty || operation.originTxHash.isEmpty) {
        await clear(walletAddress);
        return null;
      }
      return operation;
    } catch (_) {
      await clear(walletAddress);
      return null;
    }
  }

  Future<void> clear(String walletAddress) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_key(walletAddress));
  }
}
