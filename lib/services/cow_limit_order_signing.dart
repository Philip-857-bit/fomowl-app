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
