const String cowZeroAppDataHash =
    '0x0000000000000000000000000000000000000000000000000000000000000000';

const String cowDomainName = 'Gnosis Protocol';
const String cowDomainVersion = 'v2';

const Set<int> cowSupportedLimitChainIds = {
  1,
  56,
  100,
  137,
  8453,
  42161,
  43114,
  59144,
};

const Map<int, String> cowSettlementContracts = {
  1: '0x9008D19f58AAbD9eD0D60971565AA8510560ab41',
  56: '0x9008D19f58AAbD9eD0D60971565AA8510560ab41',
  100: '0x9008D19f58AAbD9eD0D60971565AA8510560ab41',
  137: '0x9008D19f58AAbD9eD0D60971565AA8510560ab41',
  8453: '0x9008D19f58AAbD9eD0D60971565AA8510560ab41',
  42161: '0x9008D19f58AAbD9eD0D60971565AA8510560ab41',
  43114: '0x9008D19f58AAbD9eD0D60971565AA8510560ab41',
  59144: '0x9008D19f58AAbD9eD0D60971565AA8510560ab41',
};

const String cowVaultRelayerAddress =
    '0xC92E8bdf79f0507f65a392b0ab4667716BFE0110';

const Set<int> openOceanSupportedLimitChainIds = {
  1,
  10,
  56,
  100,
  137,
  250,
  324,
  8453,
  42161,
  43114,
  59144,
  146,
  80094,
};

const Map<int, String> openOceanLimitContracts = {
  1: '0xcC8d695603ce0b43D352891892FcC716c6a7C9f4',
  10: '0xc0A62DDCd284020dC883C642A3Ed5D2A1770eb91',
  56: '0xA8A0213bb2ce671E457Ec14D08EB9d40E6DA8e2d',
  100: '0xc0A62DDCd284020dC883C642A3Ed5D2A1770eb91',
  137: '0xFA9B584Bc9543B66BeFdc41fb1DA8636edD7a697',
  250: '0x44A632dC8ee03ad2cF5d530280a044DaED3E1ec0',
  324: '0x6a9115a77598cb9897347a6c31E6a164Ea06F870',
  8453: '0xb5486f71c902fe0844bb07221fa8f47834d90b1b',
  42161: '0x23C78B3d85b45BfA6DC8e09b517ba2d9b0ECCA8C',
  43114: '0x99b3488Ee3432bB60256140b4BD2488E3b6A705f',
  59144: '0x4045734fe21c7B7E0cE516BE009780Cc2BA39A8f',
  146: '0xb45373129b4220160b92bd2320869f44d48ecd01',
  80094: '0x8D2B7e5501Eb6D92F8e349f2FEbe785DD070bE74',
};

const List<Map<String, String>> _eip712DomainFields = [
  {'name': 'name', 'type': 'string'},
  {'name': 'version', 'type': 'string'},
  {'name': 'chainId', 'type': 'uint256'},
  {'name': 'verifyingContract', 'type': 'address'},
];

const List<Map<String, String>> cowOrderFields = [
  {'name': 'sellToken', 'type': 'address'},
  {'name': 'buyToken', 'type': 'address'},
  {'name': 'receiver', 'type': 'address'},
  {'name': 'sellAmount', 'type': 'uint256'},
  {'name': 'buyAmount', 'type': 'uint256'},
  {'name': 'validTo', 'type': 'uint32'},
  {'name': 'appData', 'type': 'bytes32'},
  {'name': 'feeAmount', 'type': 'uint256'},
  {'name': 'kind', 'type': 'string'},
  {'name': 'partiallyFillable', 'type': 'bool'},
  {'name': 'sellTokenBalance', 'type': 'string'},
  {'name': 'buyTokenBalance', 'type': 'string'},
];

const List<Map<String, String>> cowOrderCancellationsFields = [
  {'name': 'orderUids', 'type': 'bytes[]'},
];

String? cowSettlementContractForChain(int chainId) {
  return cowSettlementContracts[chainId];
}

String? cowVaultRelayerForChain(int chainId) {
  return cowSupportedLimitChainIds.contains(chainId)
      ? cowVaultRelayerAddress
      : null;
}

String? openOceanLimitContractForChain(int chainId) {
  return openOceanLimitContracts[chainId];
}

String buildOpenOceanLimitOrderMessage({
  required String makerAsset,
  required String takerAsset,
  required String makerAmount,
  required String takerAmount,
  required int expireTimeMs,
}) {
  return 'makerAsset:\n$makerAsset\n'
      'takerAsset:\n$takerAsset\n'
      'makerAmount:\n$makerAmount\n'
      'takerAmount:\n$takerAmount\n'
      'expireTime:\n$expireTimeMs';
}

Map<String, dynamic> buildOpenOceanLimitOrderPayload({
  required String makerAsset,
  required String takerAsset,
  required String makerAmount,
  required String takerAmount,
  required String orderMaker,
  required int expireTimeMs,
  String kind = 'sell',
}) {
  return {
    'provider': 'openocean',
    'makerAsset': makerAsset,
    'takerAsset': takerAsset,
    'makerAmount': makerAmount,
    'takerAmount': takerAmount,
    'orderMaker': orderMaker,
    'expireTime': expireTimeMs,
    'referrer': '',
    'referrerFee': 0,
    'enabledDexIds': '',
    'disabledDexIds': '',
    'kind': kind,
  };
}

String buildOpenOceanCancelMessage(String orderHash) {
  return 'orderHash:\n$orderHash';
}

int resolveCowNeverValidTo({DateTime? now}) {
  final current = now ?? DateTime.now();
  return current.add(const Duration(days: 365)).millisecondsSinceEpoch ~/ 1000;
}

Map<String, dynamic> buildCowLimitOrderPayload({
  required String sellToken,
  required String buyToken,
  required String receiver,
  required String sellAmount,
  required String buyAmount,
  required int validTo,
  String kind = 'sell',
}) {
  return {
    'sellToken': sellToken,
    'buyToken': buyToken,
    'receiver': receiver,
    'sellAmount': sellAmount,
    'buyAmount': buyAmount,
    'validTo': validTo,
    'appData': cowZeroAppDataHash,
    'feeAmount': '0',
    'kind': kind,
    'partiallyFillable': false,
    'sellTokenBalance': 'erc20',
    'buyTokenBalance': 'erc20',
  };
}

Map<String, dynamic> buildCowOrderTypedData({
  required int chainId,
  required Map<String, dynamic> order,
}) {
  final settlementContract = cowSettlementContractForChain(chainId);
  if (settlementContract == null) {
    throw ArgumentError.value(
      chainId,
      'chainId',
      'Limit orders are not supported on this chain.',
    );
  }

  return {
    'types': {'EIP712Domain': _eip712DomainFields, 'Order': cowOrderFields},
    'primaryType': 'Order',
    'domain': {
      'name': cowDomainName,
      'version': cowDomainVersion,
      'chainId': chainId,
      'verifyingContract': settlementContract,
    },
    'message': order,
  };
}

Map<String, dynamic> buildCowOrderCancellationTypedData({
  required int chainId,
  required List<String> orderUids,
}) {
  final settlementContract = cowSettlementContractForChain(chainId);
  if (settlementContract == null) {
    throw ArgumentError.value(
      chainId,
      'chainId',
      'Limit orders are not supported on this chain.',
    );
  }

  return {
    'types': {
      'EIP712Domain': _eip712DomainFields,
      'OrderCancellations': cowOrderCancellationsFields,
    },
    'primaryType': 'OrderCancellations',
    'domain': {
      'name': cowDomainName,
      'version': cowDomainVersion,
      'chainId': chainId,
      'verifyingContract': settlementContract,
    },
    'message': {'orderUids': orderUids},
  };
}
