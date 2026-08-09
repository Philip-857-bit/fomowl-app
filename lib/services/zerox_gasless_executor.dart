import 'dart:convert';

import 'wallet_service.dart';

/// Signs the approval/trade EIP-712 objects returned by 0x Gasless v2 and
/// packages their signatures for `/gasless/submit`.
class ZeroXGaslessExecutor {
  static const int _eip712SignatureType = 2;

  final WalletService _walletService;

  ZeroXGaslessExecutor({WalletService? walletService})
    : _walletService = walletService ?? WalletService();

  Future<Map<String, dynamic>> signAndBuildSubmitPayload({
    required Map<String, dynamic> quoteData,
    required int chainId,
  }) async {
    return (await signOrder(quoteData: quoteData, chainId: chainId)).payload;
  }

  /// Signs a complete gasless order once and exposes the individual signatures
  /// so a provider-neutral saga can acknowledge each ordered backend step
  /// without ever sending signatures through the mini-app web page.
  Future<ZeroXGaslessSignedOrder> signOrder({
    required Map<String, dynamic> quoteData,
    required int chainId,
  }) async {
    final trade = _asMap(quoteData['trade']);
    final tradeTypedData = _asMap(trade?['eip712']);
    if (trade == null || tradeTypedData == null) {
      throw const FormatException(
        'The gasless quote is missing its trade EIP-712 payload.',
      );
    }

    final approval = _asMap(quoteData['approval']);
    final approvalTypedData = _asMap(approval?['eip712']);
    final approvalSignature = approvalTypedData == null
        ? null
        : await _walletService.signTypedData(jsonEncode(approvalTypedData));
    final tradeSignature = await _walletService.signTypedData(
      jsonEncode(tradeTypedData),
    );

    final payload = <String, dynamic>{
      'chainId': '$chainId',
      'trade': _signedObject(trade, tradeSignature),
    };
    if (approval != null && approvalSignature != null) {
      payload['approval'] = _signedObject(approval, approvalSignature);
    }
    return ZeroXGaslessSignedOrder(
      payload: payload,
      approvalSignature: approvalSignature,
      tradeSignature: tradeSignature,
    );
  }

  Map<String, dynamic> _signedObject(
    Map<String, dynamic> source,
    String signature,
  ) {
    final payload = <String, dynamic>{};
    final type = source['type']?.toString();
    if (type != null && type.isNotEmpty) {
      payload['type'] = type;
    }
    final eip712 = _asMap(source['eip712']);
    if (eip712 != null) {
      payload['eip712'] = eip712;
    }
    payload['signature'] = splitSignature(signature);
    return payload;
  }

  static Map<String, dynamic> splitSignature(String signature) {
    final normalized = signature.startsWith('0x') ? signature : '0x$signature';
    final hex = normalized.substring(2);
    if (hex.length != 130) {
      throw FormatException(
        'Expected 65-byte signature, received ${hex.length ~/ 2} bytes.',
      );
    }
    final r = hex.substring(0, 64).padLeft(64, '0');
    final s = hex.substring(64, 128).padLeft(64, '0');
    final v = int.parse(hex.substring(128, 130), radix: 16);
    return <String, dynamic>{
      'r': '0x$r',
      's': '0x$s',
      'v': v,
      'signatureType': _eip712SignatureType,
    };
  }

  static Map<String, dynamic>? _asMap(dynamic value) {
    if (value is Map<String, dynamic>) return value;
    if (value is Map) {
      return value.map(
        (key, entryValue) => MapEntry(key.toString(), entryValue),
      );
    }
    return null;
  }
}

class ZeroXGaslessSignedOrder {
  const ZeroXGaslessSignedOrder({
    required this.payload,
    required this.tradeSignature,
    this.approvalSignature,
  });

  final Map<String, dynamic> payload;
  final String? approvalSignature;
  final String tradeSignature;
}
