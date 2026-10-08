@Tags(['ffi'])
library;

import 'dart:convert';
import 'dart:async';
import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:hex/hex.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:eth_sig_util/eth_sig_util.dart';
import 'package:web3dart/web3dart.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:fomowl_wallet/models/chain.dart';
import 'package:fomowl_wallet/models/wallet_account.dart';
import 'package:fomowl_wallet/services/native_crypto.dart';
import 'package:fomowl_wallet/services/secure_store.dart';
import 'package:fomowl_wallet/services/storage_service.dart';
import 'package:fomowl_wallet/services/wallet_service.dart';
import 'package:fomowl_wallet/services/wallet_vault_service.dart';
import 'package:fomowl_wallet/src/rust/frb_generated.dart';

const _mnemonic =
    'abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon about';

class _Store implements SecureStore {
  final values = <String, String>{};
  final reads = <String>[];
  bool dropVaultWrites = false;
  bool failVaultWrites = false;
  @override
  Future<String?> read({required String key}) async {
    reads.add(key);
    return values[key];
  }

  @override
  Future<void> write({required String key, required String value}) async {
    if (key.startsWith('wallet_vault_')) {
      if (failVaultWrites) throw StateError('Protected store write failed');
      if (dropVaultWrites) return;
    }
    values[key] = value;
  }

  @override
  Future<void> delete({required String key}) async {
    values.remove(key);
  }

  @override
  Future<void> deleteAll() async {
    values.clear();
  }
}

void main() {
  setUpAll(() async {
    await RustLib.init();
  });
  late _Store store;
  late StorageService storage;
  late WalletService wallet;
  setUp(() async {
    WalletVaultService.unlock();
    SharedPreferences.setMockInitialValues({});
    store = _Store();
    storage = StorageService(
      secureStore: store,
      sharedPreferences: await SharedPreferences.getInstance(),
    );
    wallet = WalletService(storageService: storage);
  });
  tearDown(() async {
    await WalletVaultService.lockAll();
    WalletVaultService.unlock();
  });

  test(
    'seed creation completes all-family migration and ordinary signing never reads raw keys or seed',
    () async {
      final created = await wallet.createWalletFromMnemonic(_mnemonic);
      final account = (await wallet.getWalletAccounts()).single;
      expect(account.address, '0x9858EfFD232B4033E47d90003D41EC34EcaEda94');
      expect(
        store.values.keys.where((k) => k.startsWith('wallet_vault_')).length,
        3,
      );
      expect(
        store.values.keys.where(
          (k) =>
              k.startsWith('family_pk_') ||
              k.startsWith('wallet_private_key_') ||
              k == 'wallet_private_key',
        ),
        isEmpty,
      );
      final exports = <ChainFamily, String>{};
      for (final family in ChainFamily.values) {
        exports[family] = await wallet.exportPrivateKeyForFamily(
          account,
          family,
        );
      }
      expect(exports[ChainFamily.evm], created['privateKey']);
      final solanaKeypair = WalletService.decodeBase58Bytes(
        exports[ChainFamily.solana]!,
      );
      final solanaSeed = Uint8List.fromList(solanaKeypair.sublist(0, 32));
      store.reads.clear();
      final evmSignature = await wallet.signMessage('hello');
      expect(
        evmSignature,
        (await NativeCrypto.signPersonalMessage(
          privateKeyHex: exports[ChainFamily.evm]!,
          message: 'hello',
        )).substring(2),
      );
      final solanaAddress = account.getWalletAddressForFamily(
        ChainFamily.solana,
      )!;
      expect(
        await wallet.signSolanaMessageRaw(
          solanaAddress,
          Uint8List.fromList([1, 2, 3]),
        ),
        await NativeCrypto.signSolanaMessage(
          privateKeyBytes: solanaSeed,
          message: Uint8List.fromList([1, 2, 3]),
        ),
      );
      final tronAddress = account.getWalletAddressForFamily(ChainFamily.tron)!;
      expect(
        await wallet.signTronMessageRaw(tronAddress, 'hello'),
        await NativeCrypto.signTronRawHash(
          privateKeyHex: exports[ChainFamily.tron]!,
          rawHashHex: HEX.encode(
            WalletService.tronPersonalMessageDigest('hello'),
          ),
        ),
      );
      expect(
        store.reads.where(
          (k) =>
              k.contains('mnemonic') ||
              k.startsWith('family_pk_') ||
              k.startsWith('wallet_private_key_') ||
              k == 'wallet_private_key',
        ),
        isEmpty,
      );
      solanaSeed.fillRange(0, solanaSeed.length, 0);
    },
  );

  for (final dropped in [false, true]) {
    test(
      'failed ${dropped ? 'readback' : 'write'} keeps old wallet recoverable and retry completes cleanup',
      () async {
        final key = '46' * 32;
        final address = await NativeCrypto.deriveEvmAddressFromPrivateKey(key);
        await storage.saveWallet(
          address: address,
          privateKey: key,
          origin: WalletOrigin.imported,
        );
        store.dropVaultWrites = dropped;
        store.failVaultWrites = !dropped;
        await expectLater(wallet.migrateWalletVaults(), throwsStateError);
        expect(await storage.getLegacyPrivateKeyForAddress(address), key);
        expect(store.values['wallet_private_key'], key);
        store.dropVaultWrites = false;
        store.failVaultWrites = false;
        await wallet.migrateWalletVaults();
        expect(await storage.getLegacyPrivateKeyForAddress(address), isNull);
        expect(await wallet.getPrivateKey(address), key);
        expect(await wallet.signMessage('hello'), isNotEmpty);
      },
    );
  }

  test(
    'corrupt existing vault never falls back to leftover legacy copies',
    () async {
      final created = await wallet.importWalletFromPrivateKey('46' * 32);
      final address = created['address']!;
      store.values['wallet_private_key_${address.toLowerCase()}'] = '46' * 32;
      await storage.writeVaultRecord(ChainFamily.evm, address, '{}');
      await expectLater(wallet.signMessage('hello'), throwsFormatException);
      expect(await storage.getLegacyPrivateKeyForAddress(address), '46' * 32);
      await expectLater(wallet.getPrivateKey(address), throwsFormatException);
    },
  );

  test(
    'restarts, switching, removal and reset preserve vault-only recovery behavior',
    () async {
      final first = await wallet.createWalletFromMnemonic(_mnemonic);
      final second = await wallet.createAdditionalWallet();
      final firstAccount = (await wallet.getWalletAccounts()).firstWhere(
        (a) => a.address == first['address'],
      );
      final reopened = WalletService(
        storageService: StorageService(
          secureStore: store,
          sharedPreferences: await SharedPreferences.getInstance(),
        ),
      );
      await reopened.setActiveWallet(first['address']!);
      expect(await reopened.getPrivateKey(), first['privateKey']);
      expect(store.values.containsKey('wallet_private_key'), isFalse);
      await reopened.removeWalletAccount(first['address']!);
      expect(await reopened.getCurrentWalletAddress(), second['address']);
      for (final family in ChainFamily.values) {
        expect(
          await storage.readVaultRecord(
            family,
            firstAccount.getWalletAddressForFamily(family)!,
          ),
          isNull,
        );
      }
      expect(await reopened.signMessage('hello'), isNotEmpty);
      await reopened.resetAppData();
      expect(store.values, isEmpty);
    },
  );

  test(
    'TRON private-key import retains typed permits and explicit export',
    () async {
      final key = '46' * 32;
      final created = await wallet.importWalletFromTronKey(key);
      final data = jsonEncode({
        'types': {
          'EIP712Domain': [],
          'Permit': [
            {'name': 'amount', 'type': 'uint256'},
          ],
        },
        'primaryType': 'Permit',
        'domain': {},
        'message': {'amount': '123'},
      });
      expect(
        await wallet.signTypedDataForAddress(created['address'], data),
        EthSigUtil.signTypedData(
          privateKey: key,
          jsonData: data,
          version: TypedDataVersion.V4,
        ),
      );
      final account = (await wallet.getWalletAccounts()).single;
      expect(
        await wallet.exportPrivateKeyForFamily(account, ChainFamily.tron),
        key,
      );
      expect(store.values.containsKey('wallet_private_key'), isFalse);
    },
  );

  test(
    'application lock disposes open custody and requires a fresh unlocked context',
    () async {
      await wallet.importWalletFromPrivateKey('46' * 32);
      final signer = await wallet.getEvmSigningAccount();
      await WalletVaultService.lockAll();
      expect(signer.isClosed, isTrue);
      await expectLater(wallet.signMessage('hello'), throwsStateError);
      WalletVaultService.unlock();
      expect(await wallet.signMessage('hello'), isNotEmpty);
      await signer.close();
    },
  );

  test(
    'locking during pending nonce lookup prevents later signing and broadcast',
    () async {
      await wallet.importWalletFromPrivateKey('46' * 32);
      final nonceRequested = Completer<void>();
      final nonceReply = Completer<http.Response>();
      var broadcasts = 0;
      final client = Web3Client(
        'https://rpc.invalid',
        MockClient((request) async {
          final json = jsonDecode(request.body) as Map<String, dynamic>;
          if (json['method'] == 'eth_getTransactionCount') {
            nonceRequested.complete();
            return nonceReply.future;
          }
          broadcasts++;
          throw StateError('A locked wallet must never broadcast');
        }),
      );
      addTearDown(client.dispose);
      final sending =
          WalletService(
            storageService: storage,
            web3ClientFactory: (_) => client,
          ).sendNativeTransaction(
            toAddress: '0x3535353535353535353535353535353535353535',
            amountInBaseUnits: BigInt.one,
            rpcUrl: 'https://rpc.invalid',
            chainId: 1,
            gasPriceWei: BigInt.one,
            gasLimit: 21000,
          );
      final rejected = expectLater(sending, throwsStateError);
      await nonceRequested.future;
      await WalletVaultService.lockAll();
      nonceReply.complete(
        http.Response(
          jsonEncode({'jsonrpc': '2.0', 'id': 1, 'result': '0x7'}),
          200,
        ),
      );
      await rejected;
      expect(broadcasts, 0);
    },
  );

  test(
    'Solana private-key import retains keypair export and scoped serialized signing',
    () async {
      final imported = await wallet.importWalletFromSolanaKey('07' * 32);
      final address = imported['address']!;
      final account = (await wallet.getWalletAccounts()).single;
      final exported = await wallet.exportPrivateKeyForFamily(
        account,
        ChainFamily.solana,
      );
      expect(
        WalletService.decodeBase58Bytes(exported).take(32),
        List.filled(32, 7),
      );
      const blockhash = '11111111111111111111111111111111';
      final transaction = await wallet.buildAndSignSolanaBridgeTransaction(
        address: address,
        recentBlockhash: blockhash,
        instructionsJson: jsonEncode([
          {
            'programId': '11111111111111111111111111111111',
            'data': '020000000100000000000000',
            'keys': [
              {'pubkey': address, 'isSigner': true, 'isWritable': true},
              {
                'pubkey': WalletService.encodeBase58Bytes(
                  Uint8List.fromList(List.filled(32, 8)),
                ),
                'isSigner': false,
                'isWritable': true,
              },
            ],
          },
        ]),
        lookupTablesJson: '[]',
      );
      expect(
        await wallet.signSerializedSolanaTransaction(address, transaction),
        transaction,
      );
      expect(store.values.containsKey('wallet_private_key'), isFalse);
    },
  );

  test(
    'an invalid account preserves recovery data while other managed accounts finish migration',
    () async {
      final firstKey = '46' * 32;
      final first = await NativeCrypto.deriveEvmAddressFromPrivateKey(firstKey);
      final secondKey = '07' * 32;
      final second = await NativeCrypto.deriveEvmAddressFromPrivateKey(
        secondKey,
      );
      await storage.saveWallet(
        address: first,
        privateKey: firstKey,
        origin: WalletOrigin.imported,
      );
      await storage.writeVaultRecord(ChainFamily.evm, first, '{}');
      await storage.saveWallet(
        address: second,
        privateKey: secondKey,
        origin: WalletOrigin.imported,
      );
      await expectLater(wallet.migrateWalletVaults(), throwsStateError);
      expect(await storage.getLegacyPrivateKeyForAddress(first), firstKey);
      expect(await storage.getLegacyPrivateKeyForAddress(second), isNull);
      expect(await storage.readVaultRecord(ChainFamily.evm, second), isNotNull);
      expect(await wallet.signMessage('hello'), isNotEmpty);
    },
  );

  test(
    'legacy Solana keypair storage exports the standard 64-byte keypair after migration',
    () async {
      final seed = Uint8List.fromList(List.filled(32, 7));
      final address = await NativeCrypto.deriveSolanaAddressFromPrivateKey(
        seed,
      );
      final keypair = Uint8List.fromList([
        ...seed,
        ...WalletService.decodeBase58Bytes(address),
      ]);
      await storage.saveWallet(
        address: address,
        privateKey: HEX.encode(keypair),
        origin: WalletOrigin.imported,
        addressesByFamily: {ChainFamily.solana: address},
      );
      await storage.saveFamilyPrivateKey(
        family: ChainFamily.solana,
        address: address,
        privateKey: HEX.encode(keypair),
      );
      await wallet.migrateWalletVaults();
      final account = (await wallet.getWalletAccounts()).single;
      final exported = WalletService.decodeBase58Bytes(
        await wallet.exportPrivateKeyForFamily(account, ChainFamily.solana),
      );
      expect(exported, keypair);
      expect(exported.length, 64);
    },
  );
}
