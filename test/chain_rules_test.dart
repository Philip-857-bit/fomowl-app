@Tags(['ffi'])
library;

import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:web3dart/web3dart.dart';
import 'package:web3dart/crypto.dart' as legacy;
import 'package:hex/hex.dart';
import 'package:fomowl_wallet/services/native_crypto.dart';
import 'package:fomowl_wallet/src/rust/frb_generated.dart';

const _from = '0x1111111111111111111111111111111111111111';
const _to = '0x3535353535353535353535353535353535353535';

Uint8List _reference(String name, List<String> types, List<Object> values) {
  final abi = ContractAbi.fromJson(
    jsonEncode([
      {
        'type': 'function',
        'name': name,
        'inputs': types.indexed
            .map((e) => {'name': 'arg${e.$1}', 'type': e.$2})
            .toList(),
        'outputs': [],
      },
    ]),
    'IndependentReference',
  );
  return abi.functions.single.encodeCall(values);
}

void main() {
  setUpAll(() async {
    await RustLib.init();
  });
  test(
    'Rust token and NFT calldata matches independent web3dart encoding',
    () async {
      final from = EthereumAddress.fromHex(_from);
      final to = EthereumAddress.fromHex(_to);
      final amount = BigInt.from(42);
      expect(
        await NativeCrypto.encodeErc20Transfer(toAddress: _to, amount: amount),
        _reference('transfer', ['address', 'uint256'], [to, amount]),
      );
      expect(
        await NativeCrypto.encodeErc20Approve(
          spenderAddress: _to,
          amount: amount,
        ),
        _reference('approve', ['address', 'uint256'], [to, amount]),
      );
      expect(
        await NativeCrypto.encodeErc20Allowance(
          ownerAddress: _from,
          spenderAddress: _to,
        ),
        _reference('allowance', ['address', 'address'], [from, to]),
      );
      expect(
        await NativeCrypto.encodeNftTransfer(
          fromAddress: _from,
          toAddress: _to,
          tokenId: amount,
          amount: BigInt.from(3),
          isErc1155: false,
        ),
        _reference(
          'safeTransferFrom',
          ['address', 'address', 'uint256'],
          [from, to, amount],
        ),
      );
      expect(
        await NativeCrypto.encodeNftTransfer(
          fromAddress: _from,
          toAddress: _to,
          tokenId: amount,
          amount: BigInt.from(3),
          isErc1155: true,
        ),
        _reference(
          'safeTransferFrom',
          ['address', 'address', 'uint256', 'uint256', 'bytes'],
          [from, to, amount, BigInt.from(3), Uint8List(0)],
        ),
      );
    },
  );
  test(
    'TRON Rust prefix digest matches canonical vector and independent UTF-8 reference',
    () async {
      expect(
        HEX.encode(await NativeCrypto.tronPersonalMessageDigest('hello')),
        'a07d8e5b946cc0416662f5420751673680809e5f10313e20c7c5badb0ef4226d',
      );
      for (final message in ['', '🦉 Owllet', 'é']) {
        final bytes = utf8.encode(message);
        final prefixed = Uint8List.fromList([
          ...utf8.encode('\x19TRON Signed Message:\n${bytes.length}'),
          ...bytes,
        ]);
        expect(
          await NativeCrypto.tronPersonalMessageDigest(message),
          legacy.keccak256(prefixed),
        );
      }
    },
  );
  test(
    'ABI uint256 limits and malformed results fail closed through FFI',
    () async {
      final maximum = BigInt.two.pow(256) - BigInt.one;
      expect(
        await NativeCrypto.decodeAbiUint256Result('0x${'ff' * 32}'),
        maximum,
      );
      await expectLater(
        NativeCrypto.encodeErc20Approve(
          spenderAddress: _to,
          amount: maximum + BigInt.one,
        ),
        throwsA(anything),
      );
      await expectLater(
        NativeCrypto.encodeErc20Transfer(
          toAddress: _to,
          amount: BigInt.from(-1),
        ),
        throwsA(anything),
      );
      await expectLater(
        NativeCrypto.decodeAbiUint256Result('0x00'),
        throwsA(anything),
      );
      await expectLater(
        NativeCrypto.decodeAbiUint256Result('0xzz'),
        throwsA(anything),
      );
    },
  );
}
