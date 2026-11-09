import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:http/http.dart' as http;

import '../../config/app_environment.dart';

int? _readInt(dynamic value) {
  if (value is int) return value;
  if (value is num) return value.toInt();
  if (value is String) return int.tryParse(value.trim());
  return null;
}

/// Configured token for Asset Chain Bridge.
class AssetChainBridgeToken {
  final String id;
  final String tokenAddress;
  final int decimal;
  final String symbol;
  final String name;
  final String chainId;
  final String? maxClaimAmount;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  const AssetChainBridgeToken({
    required this.id,
    required this.tokenAddress,
    required this.decimal,
    required this.symbol,
    required this.name,
    required this.chainId,
    this.maxClaimAmount,
    this.createdAt,
    this.updatedAt,
  });

  factory AssetChainBridgeToken.fromJson(Map<String, dynamic> json) {
    return AssetChainBridgeToken(
      id: json['id']?.toString() ?? '',
      tokenAddress: json['tokenAddress']?.toString() ?? '',
      decimal: (json['decimal'] as num?)?.toInt() ?? 18,
      symbol: json['symbol']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
      chainId: json['chainId']?.toString() ?? '',
      maxClaimAmount: json['maxClaimAmount']?.toString(),
      createdAt: json['createdAt'] != null
          ? DateTime.tryParse(json['createdAt'].toString())
          : null,
      updatedAt: json['updatedAt'] != null
          ? DateTime.tryParse(json['updatedAt'].toString())
          : null,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'tokenAddress': tokenAddress,
    'decimal': decimal,
    'symbol': symbol,
    'name': name,
    'chainId': chainId,
    if (maxClaimAmount != null) 'maxClaimAmount': maxClaimAmount,
    if (createdAt != null) 'createdAt': createdAt!.toIso8601String(),
    if (updatedAt != null) 'updatedAt': updatedAt!.toIso8601String(),
  };
}

/// Fee structure for an Asset Chain Bridge contract.
class AssetChainBridgeFees {
  final num feeFulfill;
  final num feeSend;

  const AssetChainBridgeFees({
    required this.feeFulfill,
    required this.feeSend,
  });

  factory AssetChainBridgeFees.fromJson(Map<String, dynamic> json) {
    return AssetChainBridgeFees(
      feeFulfill: (json['feeFulfill'] as num?) ?? 0,
      feeSend: (json['feeSend'] as num?) ?? 0,
    );
  }

  Map<String, dynamic> toJson() => {
    'feeFulfill': feeFulfill,
    'feeSend': feeSend,
  };
}

/// Deployed bridge contract and associated limits.
class AssetChainBridgeDeployment {
  final String id;
  final String bridgeAddress;
  final String chainId;
  final AssetChainBridgeFees fees;
  final String tokenId;
  final String limitPerSend;
  final int tokenDecimal;
  final AssetChainBridgeToken? token;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  const AssetChainBridgeDeployment({
    required this.id,
    required this.bridgeAddress,
    required this.chainId,
    required this.fees,
    required this.tokenId,
    required this.limitPerSend,
    required this.tokenDecimal,
    this.token,
    this.createdAt,
    this.updatedAt,
  });

  factory AssetChainBridgeDeployment.fromJson(Map<String, dynamic> json) {
    return AssetChainBridgeDeployment(
      id: json['id']?.toString() ?? '',
      bridgeAddress: json['bridgeAddress']?.toString() ?? '',
      chainId: json['chainId']?.toString() ?? '',
      fees: json['fees'] is Map<String, dynamic>
          ? AssetChainBridgeFees.fromJson(json['fees'] as Map<String, dynamic>)
          : const AssetChainBridgeFees(feeFulfill: 0, feeSend: 0),
      tokenId: json['tokenId']?.toString() ?? '',
      limitPerSend: json['limitPerSend']?.toString() ?? '0',
      tokenDecimal: (json['tokenDecimal'] as num?)?.toInt() ?? 18,
      token: json['token'] is Map<String, dynamic>
          ? AssetChainBridgeToken.fromJson(
              json['token'] as Map<String, dynamic>,
            )
          : null,
      createdAt: json['createdAt'] != null
          ? DateTime.tryParse(json['createdAt'].toString())
          : null,
      updatedAt: json['updatedAt'] != null
          ? DateTime.tryParse(json['updatedAt'].toString())
          : null,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'bridgeAddress': bridgeAddress,
    'chainId': chainId,
    'fees': fees.toJson(),
    'tokenId': tokenId,
    'limitPerSend': limitPerSend,
    'tokenDecimal': tokenDecimal,
    if (token != null) 'token': token!.toJson(),
    if (createdAt != null) 'createdAt': createdAt!.toIso8601String(),
    if (updatedAt != null) 'updatedAt': updatedAt!.toIso8601String(),
  };
}

/// Detailed bridge transfer record.
class AssetChainBridgeTransaction {
  final String id;
  final String amount;
  final String timestamp;
  final String fromUser;
  final String toUser;
  final String fromChain;
  final String toChain;
  final int? nonce;
  final String symbol;
  final String? fulfillAmount;
  final String? fulfillFromChain;
  final int? fulfillNonce;
  final String? fulfillFromUser;
  final String? fulfillToUser;
  final String? txBlock;
  final int? confirmations;
  final bool fulfilled;
  final int index;
  final String userAddress;
  final String chainId;
  final String transactionHash;
  final String? claimTransactionHash;
  final DateTime? transactionDate;
  final bool claimApproved;
  final String? approvedByAdminId;
  final DateTime? approvedAt;
  final String? bridgeInfoId;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  const AssetChainBridgeTransaction({
    required this.id,
    required this.amount,
    required this.timestamp,
    required this.fromUser,
    required this.toUser,
    required this.fromChain,
    required this.toChain,
    this.nonce,
    required this.symbol,
    this.fulfillAmount,
    this.fulfillFromChain,
    this.fulfillNonce,
    this.fulfillFromUser,
    this.fulfillToUser,
    this.txBlock,
    this.confirmations,
    required this.fulfilled,
    required this.index,
    required this.userAddress,
    required this.chainId,
    required this.transactionHash,
    this.claimTransactionHash,
    this.transactionDate,
    this.claimApproved = false,
    this.approvedByAdminId,
    this.approvedAt,
    this.bridgeInfoId,
    this.createdAt,
    this.updatedAt,
  });

  factory AssetChainBridgeTransaction.fromJson(Map<String, dynamic> json) {
    return AssetChainBridgeTransaction(
      id: json['id']?.toString() ?? '',
      amount: json['amount']?.toString() ?? '0',
      timestamp: json['timestamp']?.toString() ?? '',
      fromUser: json['fromUser']?.toString() ?? '',
      toUser: json['toUser']?.toString() ?? '',
      fromChain: json['fromChain']?.toString() ?? '',
      toChain: json['toChain']?.toString() ?? '',
      nonce: _readInt(json['nonce']),
      symbol: json['symbol']?.toString() ?? '',
      fulfillAmount: json['fulfillAmount']?.toString(),
      fulfillFromChain: json['fulfillFromChain']?.toString(),
      fulfillNonce: _readInt(json['fulfillNonce']),
      fulfillFromUser: json['fulfillFromUser']?.toString(),
      fulfillToUser: json['fulfillToUser']?.toString(),
      txBlock: json['txBlock']?.toString(),
      confirmations: (json['confirmations'] as num?)?.toInt(),
      fulfilled: json['fulfilled'] == true,
      index: _readInt(json['index']) ?? 0,
      userAddress: json['userAddress']?.toString() ?? '',
      chainId: json['chainId']?.toString() ?? '',
      transactionHash: json['transactionHash']?.toString() ?? '',
      claimTransactionHash: json['claimTransactionHash']?.toString(),
      transactionDate: json['transactionDate'] != null
          ? DateTime.tryParse(json['transactionDate'].toString())
          : null,
      claimApproved: json['claimApproved'] == true,
      approvedByAdminId: json['approvedByAdminId']?.toString(),
      approvedAt: json['approvedAt'] != null
          ? DateTime.tryParse(json['approvedAt'].toString())
          : null,
      bridgeInfoId: json['bridgeInfoId']?.toString(),
      createdAt: json['createdAt'] != null
          ? DateTime.tryParse(json['createdAt'].toString())
          : null,
      updatedAt: json['updatedAt'] != null
          ? DateTime.tryParse(json['updatedAt'].toString())
          : null,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'amount': amount,
    'timestamp': timestamp,
    'fromUser': fromUser,
    'toUser': toUser,
    'fromChain': fromChain,
    'toChain': toChain,
    if (nonce != null) 'nonce': nonce,
    'symbol': symbol,
    if (fulfillAmount != null) 'fulfillAmount': fulfillAmount,
    if (fulfillFromChain != null) 'fulfillFromChain': fulfillFromChain,
    if (fulfillNonce != null) 'fulfillNonce': fulfillNonce,
    if (fulfillFromUser != null) 'fulfillFromUser': fulfillFromUser,
    if (fulfillToUser != null) 'fulfillToUser': fulfillToUser,
    if (txBlock != null) 'txBlock': txBlock,
    if (confirmations != null) 'confirmations': confirmations,
    'fulfilled': fulfilled,
    'index': index,
    'userAddress': userAddress,
    'chainId': chainId,
    'transactionHash': transactionHash,
    if (claimTransactionHash != null)
      'claimTransactionHash': claimTransactionHash,
    if (transactionDate != null)
      'transactionDate': transactionDate!.toIso8601String(),
    'claimApproved': claimApproved,
    if (approvedByAdminId != null) 'approvedByAdminId': approvedByAdminId,
    if (approvedAt != null) 'approvedAt': approvedAt!.toIso8601String(),
    if (bridgeInfoId != null) 'bridgeInfoId': bridgeInfoId,
    if (createdAt != null) 'createdAt': createdAt!.toIso8601String(),
    if (updatedAt != null) 'updatedAt': updatedAt!.toIso8601String(),
  };
}

/// Pagination metadata.
class AssetChainBridgePagination {
  final int page;
  final int limit;
  final int totalCount;
  final int totalPages;
  final bool hasNextPage;
  final bool hasPreviousPage;
  final int? nextPage;
  final int? previousPage;

  const AssetChainBridgePagination({
    required this.page,
    required this.limit,
    required this.totalCount,
    required this.totalPages,
    required this.hasNextPage,
    required this.hasPreviousPage,
    this.nextPage,
    this.previousPage,
  });

  factory AssetChainBridgePagination.fromJson(Map<String, dynamic> json) {
    return AssetChainBridgePagination(
      page: (json['page'] as num?)?.toInt() ?? 1,
      limit: (json['limit'] as num?)?.toInt() ?? 10,
      totalCount: (json['totalCount'] as num?)?.toInt() ?? 0,
      totalPages: (json['totalPages'] as num?)?.toInt() ?? 1,
      hasNextPage: json['hasNextPage'] == true,
      hasPreviousPage: json['hasPreviousPage'] == true,
      nextPage: (json['nextPage'] as num?)?.toInt(),
      previousPage: (json['previousPage'] as num?)?.toInt(),
    );
  }

  Map<String, dynamic> toJson() => {
    'page': page,
    'limit': limit,
    'totalCount': totalCount,
    'totalPages': totalPages,
    'hasNextPage': hasNextPage,
    'hasPreviousPage': hasPreviousPage,
    if (nextPage != null) 'nextPage': nextPage,
    if (previousPage != null) 'previousPage': previousPage,
  };
}

/// Paginated bridge transaction list.
class AssetChainBridgeTransactionList {
  final List<AssetChainBridgeTransaction> items;
  final AssetChainBridgePagination pagination;

  const AssetChainBridgeTransactionList({
    required this.items,
    required this.pagination,
  });

  factory AssetChainBridgeTransactionList.fromJson(Map<String, dynamic> json) {
    final rawItems = json['items'] as List<dynamic>? ?? const [];
    final items = rawItems
        .whereType<Map<String, dynamic>>()
        .map(AssetChainBridgeTransaction.fromJson)
        .toList();
    final pagination = json['pagination'] is Map<String, dynamic>
        ? AssetChainBridgePagination.fromJson(
            json['pagination'] as Map<String, dynamic>,
          )
        : const AssetChainBridgePagination(
            page: 1,
            limit: 10,
            totalCount: 0,
            totalPages: 1,
            hasNextPage: false,
            hasPreviousPage: false,
          );
    return AssetChainBridgeTransactionList(
      items: items,
      pagination: pagination,
    );
  }

  Map<String, dynamic> toJson() => {
    'items': items.map((i) => i.toJson()).toList(),
    'pagination': pagination.toJson(),
  };
}

/// Relayer signatures response from GET /blockchain/sign.
class AssetChainBridgeSignatures {
  final List<String> signatures;

  const AssetChainBridgeSignatures({
    required this.signatures,
  });

  factory AssetChainBridgeSignatures.fromJson(Map<String, dynamic> json) {
    final rawList = json['signature'] as List<dynamic>? ??
        json['signatures'] as List<dynamic>? ??
        const [];
    return AssetChainBridgeSignatures(
      signatures: rawList.map((e) => e.toString()).toList(),
    );
  }

  Map<String, dynamic> toJson() => {
    'signature': signatures,
  };
}

/// Result of a PUT /transactions claim notification.
class AssetChainBridgeClaimResult {
  final bool success;
  final String message;
  final String transactionId;
  final bool fulfilled;
  final String? claimTransactionHash;
  final String? amount;
  final String? fromChain;
  final String? toChain;
  final int? index;
  final String? userAddress;
  final String? bridgeInfoId;

  const AssetChainBridgeClaimResult({
    required this.success,
    required this.message,
    required this.transactionId,
    required this.fulfilled,
    this.claimTransactionHash,
    this.amount,
    this.fromChain,
    this.toChain,
    this.index,
    this.userAddress,
    this.bridgeInfoId,
  });

  factory AssetChainBridgeClaimResult.fromJson(Map<String, dynamic> json) {
    final data = json['data'] is Map<String, dynamic>
        ? json['data'] as Map<String, dynamic>
        : json;
    final nestedData = data['data'] is Map<String, dynamic>
        ? data['data'] as Map<String, dynamic>
        : data;

    return AssetChainBridgeClaimResult(
      success: json['success'] == true,
      message: json['message']?.toString() ??
          data['message']?.toString() ??
          '',
      transactionId: nestedData['id']?.toString() ??
          nestedData['transactionId']?.toString() ??
          '',
      fulfilled: nestedData['fulfilled'] == true,
      claimTransactionHash: nestedData['claimTransactionHash']?.toString(),
      amount: nestedData['amount']?.toString(),
      fromChain: nestedData['fromChain']?.toString(),
      toChain: nestedData['toChain']?.toString(),
      index: _readInt(nestedData['index']),
      userAddress: nestedData['userAddress']?.toString(),
      bridgeInfoId: nestedData['bridgeInfoId']?.toString() ??
          nestedData['toBridgeId']?.toString(),
    );
  }

  Map<String, dynamic> toJson() => {
    'success': success,
    'message': message,
    'data': {
      'id': transactionId,
      'fulfilled': fulfilled,
      if (claimTransactionHash != null)
        'claimTransactionHash': claimTransactionHash,
      if (amount != null) 'amount': amount,
      if (fromChain != null) 'fromChain': fromChain,
      if (toChain != null) 'toChain': toChain,
      if (index != null) 'index': index,
      if (userAddress != null) 'userAddress': userAddress,
      if (bridgeInfoId != null) 'bridgeInfoId': bridgeInfoId,
    },
  };
}

/// Exception thrown on Asset Chain Bridge HTTP errors or guard rejections.
class AssetChainBridgeException implements Exception {
  final int statusCode;
  final String message;
  final String? errorCode;
  final dynamic responseBody;

  const AssetChainBridgeException({
    required this.statusCode,
    required this.message,
    this.errorCode,
    this.responseBody,
  });

  bool get isUnauthorized => statusCode == 401;
  bool get isBadRequest => statusCode == 400;
  bool get isAdminApprovalRequired =>
      message.toLowerCase().contains('claim requires admin approval');
  bool get isExpired => message.toLowerCase().contains('request expired');
  bool get isNotFound =>
      message.toLowerCase().contains('not found') || statusCode == 404;

  @override
  String toString() =>
      'AssetChainBridgeException(status: $statusCode, code: $errorCode, message: "$message")';
}

/// Cryptographic API Guard signature generator for Asset Chain Bridge.
class AssetChainApiGuardSigner {
  static const String emptyBodySha256 =
      'e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855';

  /// Builds the deterministic 4-line canonical string.
  /// Strictly strips query parameters from path and ensures a leading slash.
  static String buildCanonicalString({
    required String method,
    required String path,
    required String timestamp,
    String? body,
  }) {
    final cleanMethod = method.trim().toUpperCase();
    final cleanPath = path.contains('?') ? path.split('?').first : path;
    final normalizedPath = cleanPath.startsWith('/') ? cleanPath : '/$cleanPath';
    final bodyHash = (body == null || body.isEmpty)
        ? emptyBodySha256
        : sha256.convert(utf8.encode(body)).toString().toLowerCase();

    return '$cleanMethod\n$normalizedPath\n${timestamp.trim()}\n$bodyHash';
  }

  /// Computes HMAC-SHA256 signature in lowercase hexadecimal string format.
  static String calculateSignature({
    required String canonicalString,
    required String clientSecret,
  }) {
    final keyBytes = utf8.encode(clientSecret);
    final messageBytes = utf8.encode(canonicalString);
    final hmac = Hmac(sha256, keyBytes);
    return hmac.convert(messageBytes).toString().toLowerCase();
  }

  /// Generates the full set of required API Guard headers.
  static Map<String, String> generateHeaders({
    required String method,
    required String path,
    required String clientName,
    required String clientSecret,
    String? body,
    int? customTimestampSeconds,
    String? customTimestamp,
  }) {
    final timestamp = customTimestamp ??
        (customTimestampSeconds != null
            ? customTimestampSeconds.toString()
            : (DateTime.now().millisecondsSinceEpoch ~/ 1000).toString());
    final canonicalString = buildCanonicalString(
      method: method,
      path: path,
      timestamp: timestamp,
      body: body,
    );
    final signature = calculateSignature(
      canonicalString: canonicalString,
      clientSecret: clientSecret,
    );

    return <String, String>{
      'x-client-name': clientName,
      'x-timestamp': timestamp,
      'x-signature': signature,
      if (body != null && body.isNotEmpty) 'Content-Type': 'application/json',
      'Accept': 'application/json',
    };
  }
}

/// In-memory mock store embedding verified fixtures for offline execution.
class AssetChainBridgeMockStore {
  AssetChainBridgeMockStore._();

  static List<AssetChainBridgeToken> getTokens({String? chainId}) {
    final all = <AssetChainBridgeToken>[
      AssetChainBridgeToken(
        id: '8b1c0c2e-1d2a-4c3b-9f10-0a1b2c3d4e5f',
        tokenAddress: '0x036CbD53842c5426634e7929541eC2318f3dCF7e',
        decimal: 6,
        symbol: 'USDC',
        name: 'USD Coin',
        chainId: '84532',
        maxClaimAmount: '50000000000',
        createdAt: DateTime.parse('2026-01-01T00:00:00.000Z'),
        updatedAt: DateTime.parse('2026-01-01T00:00:00.000Z'),
      ),
      AssetChainBridgeToken(
        id: '9c2d1e3f-2e3b-5d4c-a021-1b2c3d4e5f60',
        tokenAddress: '0x7b79995e5f793A07Bc00c21412e50Ecae098E7f9',
        decimal: 6,
        symbol: 'USDC',
        name: 'USD Coin',
        chainId: '421614',
        maxClaimAmount: '50000000000',
        createdAt: DateTime.parse('2026-01-01T00:00:00.000Z'),
        updatedAt: DateTime.parse('2026-01-01T00:00:00.000Z'),
      ),
      AssetChainBridgeToken(
        id: 'ad3e2f40-3f4c-6e5d-b132-2c3d4e5f6071',
        tokenAddress: '0x0000000000000000000000000000000000000000',
        decimal: 18,
        symbol: 'RWA',
        name: 'Asset Chain Native RWA',
        chainId: '42420',
        maxClaimAmount: null,
        createdAt: DateTime.parse('2026-01-01T00:00:00.000Z'),
        updatedAt: DateTime.parse('2026-01-01T00:00:00.000Z'),
      ),
      AssetChainBridgeToken(
        id: 'be4f3051-405d-7f6e-c243-3d4e5f607182',
        tokenAddress: '0x0000000000000000000000000000000000000000',
        decimal: 18,
        symbol: 'RWA',
        name: 'Asset Chain Testnet RWA',
        chainId: '42421',
        maxClaimAmount: null,
        createdAt: DateTime.parse('2026-01-01T00:00:00.000Z'),
        updatedAt: DateTime.parse('2026-01-01T00:00:00.000Z'),
      ),
    ];

    if (chainId != null && chainId.isNotEmpty) {
      return all.where((t) => t.chainId == chainId).toList();
    }
    return all;
  }

  static List<AssetChainBridgeDeployment> getBridges({String? chainId}) {
    final tokens = getTokens();
    final tokenArbitrum = tokens[1];
    final tokenBase = tokens[0];
    final tokenTestnet = tokens[3];

    final all = <AssetChainBridgeDeployment>[
      AssetChainBridgeDeployment(
        id: 'c3d4e5f6-a7b8-4901-8234-567890abcdef',
        bridgeAddress: '0xEC91dd5f2048DB18C32e15Ca75a59e1e72E5E267',
        chainId: '421614',
        fees: const AssetChainBridgeFees(feeFulfill: 0, feeSend: 0),
        tokenId: '9c2d1e3f-2e3b-5d4c-a021-1b2c3d4e5f60',
        limitPerSend: '10000000000',
        tokenDecimal: 6,
        token: tokenArbitrum,
        createdAt: DateTime.parse('2026-01-01T00:00:00.000Z'),
        updatedAt: DateTime.parse('2026-01-01T00:00:00.000Z'),
      ),
      AssetChainBridgeDeployment(
        id: 'd4e5f607-b8c9-5012-9345-678901bcdef0',
        bridgeAddress: '0x436c841A8eA85F237976e82845c0f993d6b05Ec7',
        chainId: '84532',
        fees: const AssetChainBridgeFees(feeFulfill: 0, feeSend: 0),
        tokenId: '8b1c0c2e-1d2a-4c3b-9f10-0a1b2c3d4e5f',
        limitPerSend: '10000000000',
        tokenDecimal: 6,
        token: tokenBase,
        createdAt: DateTime.parse('2026-01-01T00:00:00.000Z'),
        updatedAt: DateTime.parse('2026-01-01T00:00:00.000Z'),
      ),
      AssetChainBridgeDeployment(
        id: 'e5f60718-c9da-6123-a456-789012cdef01',
        bridgeAddress: '0x892a0d13Da7f311f95dcfb95eD448c5aFd86F90E',
        chainId: '42421',
        fees: const AssetChainBridgeFees(feeFulfill: 0, feeSend: 0),
        tokenId: 'be4f3051-405d-7f6e-c243-3d4e5f607182',
        limitPerSend: '500000000000000000000',
        tokenDecimal: 18,
        token: tokenTestnet,
        createdAt: DateTime.parse('2026-01-01T00:00:00.000Z'),
        updatedAt: DateTime.parse('2026-01-01T00:00:00.000Z'),
      ),
    ];

    if (chainId != null && chainId.isNotEmpty) {
      return all.where((b) => b.chainId == chainId).toList();
    }
    return all;
  }

  static AssetChainBridgeTransactionList getTransactions({
    required String userAddress,
    String? secondaryAddress,
    String? chainIds,
    bool? fulfilled,
    bool? forceSync,
    String? symbol,
    int page = 1,
    int limit = 10,
  }) {
    final item = AssetChainBridgeTransaction(
      id: 'a1b2c3d4-e5f6-4789-a012-3456789abcde',
      amount: '1000000',
      timestamp: '1710000000',
      fromUser: userAddress,
      toUser: secondaryAddress ?? '0x2222222222222222222222222222222222222222',
      fromChain: '84532',
      toChain: '421614',
      nonce: 3,
      symbol: symbol != null && symbol.isNotEmpty ? symbol : 'USDC',
      fulfillAmount: '1000000',
      fulfillFromChain: '84532',
      fulfillNonce: 3,
      fulfillFromUser: userAddress,
      fulfillToUser: secondaryAddress ?? '0x2222222222222222222222222222222222222222',
      txBlock: '12345678',
      confirmations: 12,
      fulfilled: fulfilled ?? false,
      index: 3,
      userAddress: userAddress,
      chainId: '84532',
      transactionHash:
          '0xabcdef1234567890abcdef1234567890abcdef1234567890abcdef1234567890',
      claimTransactionHash: null,
      transactionDate: DateTime.parse('2026-03-01T12:00:00.000Z'),
      claimApproved: false,
      bridgeInfoId: 'd4e5f607-b8c9-5012-9345-678901bcdef0',
      createdAt: DateTime.parse('2026-03-01T12:00:05.000Z'),
      updatedAt: DateTime.parse('2026-03-01T12:00:05.000Z'),
    );

    return AssetChainBridgeTransactionList(
      items: [item],
      pagination: AssetChainBridgePagination(
        page: page,
        limit: limit,
        totalCount: 1,
        totalPages: 1,
        hasNextPage: false,
        hasPreviousPage: false,
      ),
    );
  }

  static AssetChainBridgeTransaction recordTransaction({
    required String bridgeId,
    required String index,
    required String userAddress,
    required String transactionHash,
  }) {
    final parsedIndex = int.tryParse(index) ?? 0;
    return AssetChainBridgeTransaction(
      id: 'a1b2c3d4-e5f6-4789-a012-3456789abcde',
      amount: '1000000',
      timestamp: (DateTime.now().millisecondsSinceEpoch ~/ 1000).toString(),
      fromUser: userAddress,
      toUser: '0x2222222222222222222222222222222222222222',
      fromChain: '84532',
      toChain: '421614',
      nonce: parsedIndex,
      symbol: 'USDC',
      fulfillAmount: '1000000',
      fulfillFromChain: '84532',
      fulfillNonce: parsedIndex,
      fulfillFromUser: userAddress,
      fulfillToUser: '0x2222222222222222222222222222222222222222',
      txBlock: '12345678',
      confirmations: 12,
      fulfilled: false,
      index: parsedIndex,
      userAddress: userAddress,
      chainId: '84532',
      transactionHash: transactionHash,
      bridgeInfoId: bridgeId,
      transactionDate: DateTime.now().toUtc(),
      createdAt: DateTime.now().toUtc(),
      updatedAt: DateTime.now().toUtc(),
    );
  }

  static AssetChainBridgeClaimResult updateTransactionFulfillment({
    required String transactionId,
    required String claimTransactionHash,
    required String toBridgeId,
  }) {
    return AssetChainBridgeClaimResult(
      success: true,
      message: 'Transaction marked as claimed',
      transactionId: transactionId,
      fulfilled: true,
      claimTransactionHash: claimTransactionHash,
      amount: '1000000',
      fromChain: '84532',
      toChain: '421614',
      index: 3,
      userAddress: '0x1111111111111111111111111111111111111111',
      bridgeInfoId: toBridgeId,
    );
  }

  static AssetChainBridgeSignatures getRelayerSignatures({
    required String bridgeId,
    required String index,
    required String fromUser,
  }) {
    return const AssetChainBridgeSignatures(
      signatures: [
        '0xaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa1b',
        '0xbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb1c',
      ],
    );
  }
}

/// Primary client for Asset Chain Bridge HTTP API.
class AssetChainBridgeClient {
  final String baseUrl;
  final String? clientName;
  final String? clientSecret;
  final bool mockEnabled;
  final bool useProxy;
  final http.Client httpClient;
  final bool _ownsClient;

  AssetChainBridgeClient({
    String? baseUrl,
    this.clientName,
    this.clientSecret,
    this.mockEnabled = false,
    this.useProxy = false,
    http.Client? httpClient,
  })  : baseUrl = baseUrl ??
            (useProxy
                ? AppEnvironment.assetChainBridgeProxyUrl
                : AppEnvironment.assetChainBridgeBaseUrl()),
        httpClient = httpClient ?? http.Client(),
        _ownsClient = httpClient == null;

  factory AssetChainBridgeClient.fromEnvironment({
    bool isTestnet = false,
    http.Client? httpClient,
    bool useProxy = true,
  }) {
    return AssetChainBridgeClient(
      baseUrl: useProxy
          ? AppEnvironment.assetChainBridgeProxyUrl
          : AppEnvironment.assetChainBridgeBaseUrl(testnet: isTestnet),
      clientName: useProxy ? null : AppEnvironment.assetChainBridgeClientName,
      clientSecret:
          useProxy ? null : AppEnvironment.assetChainBridgeClientSecret,
      mockEnabled: AppEnvironment.assetChainBridgeMockEnabled,
      useProxy: useProxy,
      httpClient: httpClient,
    );
  }

  /// Whether the client operates in mock mode.
  bool get isMockMode {
    if (mockEnabled) return true;
    if (useProxy) return false;
    return clientName == null ||
        clientName!.trim().isEmpty ||
        clientSecret == null ||
        clientSecret!.trim().isEmpty;
  }

  void dispose() {
    if (_ownsClient) {
      httpClient.close();
    }
  }

  /// GET /tokens: Lists configured tokens available for bridging.
  Future<List<AssetChainBridgeToken>> getTokens({String? chainId}) async {
    if (isMockMode) {
      return AssetChainBridgeMockStore.getTokens(chainId: chainId);
    }

    final queryParams = <String, String>{
      if (chainId != null && chainId.isNotEmpty) 'chainId': chainId,
    };
    final response = await _send('GET', '/tokens', queryParameters: queryParams);
    final json = jsonDecode(response.body) as Map<String, dynamic>;
    final data = json['data'] as List<dynamic>? ?? const [];
    return data
        .whereType<Map<String, dynamic>>()
        .map(AssetChainBridgeToken.fromJson)
        .toList();
  }

  /// GET /bridges: Lists active bridge deployments.
  Future<List<AssetChainBridgeDeployment>> getBridges({String? chainId}) async {
    if (isMockMode) {
      return AssetChainBridgeMockStore.getBridges(chainId: chainId);
    }

    final queryParams = <String, String>{
      if (chainId != null && chainId.isNotEmpty) 'chainId': chainId,
    };
    final response = await _send('GET', '/bridges', queryParameters: queryParams);
    final json = jsonDecode(response.body) as Map<String, dynamic>;
    final data = json['data'] as List<dynamic>? ?? const [];
    return data
        .whereType<Map<String, dynamic>>()
        .map(AssetChainBridgeDeployment.fromJson)
        .toList();
  }

  /// GET /transactions: Returns stored bridge transfers for a wallet address.
  Future<AssetChainBridgeTransactionList> getTransactions({
    required String userAddress,
    String? secondaryAddress,
    String? chainIds,
    bool? fulfilled,
    bool? forceSync,
    String? symbol,
    int page = 1,
    int limit = 10,
  }) async {
    if (isMockMode) {
      return AssetChainBridgeMockStore.getTransactions(
        userAddress: userAddress,
        secondaryAddress: secondaryAddress,
        chainIds: chainIds,
        fulfilled: fulfilled,
        forceSync: forceSync,
        symbol: symbol,
        page: page,
        limit: limit,
      );
    }

    final queryParams = <String, String>{
      'userAddress': userAddress,
      if (secondaryAddress != null && secondaryAddress.isNotEmpty)
        'secondaryAddress': secondaryAddress,
      if (chainIds != null && chainIds.isNotEmpty) 'chainIds': chainIds,
      if (fulfilled != null) 'fulfilled': fulfilled.toString(),
      if (forceSync != null) 'forceSync': forceSync.toString(),
      if (symbol != null && symbol.isNotEmpty)
        'symbol': symbol == 'XRWA' ? 'RWA' : symbol,
      'page': page.toString(),
      'limit': limit.toString(),
    };

    final response = await _send(
      'GET',
      '/transactions',
      queryParameters: queryParams,
    );
    final json = jsonDecode(response.body) as Map<String, dynamic>;
    final data = json['data'] as Map<String, dynamic>? ?? json;
    return AssetChainBridgeTransactionList.fromJson(data);
  }

  /// POST /transactions: Records an on-chain deposit event for tracking.
  Future<AssetChainBridgeTransaction> recordTransaction({
    required String bridgeId,
    required String index,
    required String userAddress,
    required String transactionHash,
  }) async {
    if (isMockMode) {
      return AssetChainBridgeMockStore.recordTransaction(
        bridgeId: bridgeId,
        index: index,
        userAddress: userAddress,
        transactionHash: transactionHash,
      );
    }

    final bodyMap = {
      'bridgeId': bridgeId,
      'index': index,
      'userAddress': userAddress,
      'transactionHash': transactionHash,
    };
    final response = await _send(
      'POST',
      '/transactions',
      body: jsonEncode(bodyMap),
    );
    final json = jsonDecode(response.body) as Map<String, dynamic>;
    final dataWrapper = json['data'] as Map<String, dynamic>? ?? json;
    final itemData = dataWrapper['data'] is Map<String, dynamic>
        ? dataWrapper['data'] as Map<String, dynamic>
        : dataWrapper;
    return AssetChainBridgeTransaction.fromJson(itemData);
  }

  /// PUT /transactions: Checks and marks destination fulfillment.
  Future<AssetChainBridgeClaimResult> updateTransactionFulfillment({
    required String transactionId,
    required String claimTransactionHash,
    required String toBridgeId,
  }) async {
    if (isMockMode) {
      return AssetChainBridgeMockStore.updateTransactionFulfillment(
        transactionId: transactionId,
        claimTransactionHash: claimTransactionHash,
        toBridgeId: toBridgeId,
      );
    }

    final bodyMap = {
      'transactionId': transactionId,
      'claimTransactionHash': claimTransactionHash,
      'toBridgeId': toBridgeId,
    };
    final response = await _send(
      'PUT',
      '/transactions',
      body: jsonEncode(bodyMap),
    );
    final json = jsonDecode(response.body) as Map<String, dynamic>;
    return AssetChainBridgeClaimResult.fromJson(json);
  }

  /// GET /blockchain/sign: Fetches relayer signatures for claiming on destination.
  Future<AssetChainBridgeSignatures> getRelayerSignatures({
    required String bridgeId,
    required String index,
    required String fromUser,
  }) async {
    if (isMockMode) {
      return AssetChainBridgeMockStore.getRelayerSignatures(
        bridgeId: bridgeId,
        index: index,
        fromUser: fromUser,
      );
    }

    final queryParams = <String, String>{
      'bridgeId': bridgeId,
      'index': index,
      'fromUser': fromUser,
    };
    final response = await _send(
      'GET',
      '/blockchain/sign',
      queryParameters: queryParams,
    );
    final json = jsonDecode(response.body) as Map<String, dynamic>;
    return AssetChainBridgeSignatures.fromJson(json);
  }

  Future<http.Response> _send(
    String method,
    String path, {
    Map<String, String>? queryParameters,
    String? body,
  }) async {
    final baseUri = Uri.parse(baseUrl);
    final uri = baseUri.replace(
      path: '${baseUri.path}$path'.replaceAll('//', '/'),
      queryParameters: queryParameters == null || queryParameters.isEmpty
          ? null
          : queryParameters,
    );

    final Map<String, String> headers;
    if (clientName != null &&
        clientName!.isNotEmpty &&
        clientSecret != null &&
        clientSecret!.isNotEmpty) {
      headers = AssetChainApiGuardSigner.generateHeaders(
        method: method,
        path: path,
        clientName: clientName!,
        clientSecret: clientSecret!,
        body: body,
      );
    } else {
      headers = <String, String>{
        if (body != null && body.isNotEmpty) 'Content-Type': 'application/json',
        'Accept': 'application/json',
      };
    }

    final http.Response response;
    switch (method.toUpperCase()) {
      case 'GET':
        response = await httpClient.get(uri, headers: headers);
        break;
      case 'POST':
        response = await httpClient.post(uri, headers: headers, body: body);
        break;
      case 'PUT':
        response = await httpClient.put(uri, headers: headers, body: body);
        break;
      default:
        throw UnsupportedError('Unsupported HTTP method: $method');
    }

    if (response.statusCode >= 200 && response.statusCode < 300) {
      return response;
    }

    String message = 'HTTP ${response.statusCode}';
    String? errorCode;
    try {
      final errJson = jsonDecode(response.body);
      if (errJson is Map) {
        message = errJson['message']?.toString() ??
            errJson['error']?.toString() ??
            message;
        errorCode = errJson['code']?.toString();
      }
    } catch (_) {
      message = response.body.isNotEmpty ? response.body : message;
    }

    throw AssetChainBridgeException(
      statusCode: response.statusCode,
      message: message,
      errorCode: errorCode,
      responseBody: response.body,
    );
  }
}
