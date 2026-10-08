@Tags(["ffi"])
library;

import 'dart:typed_data';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:hex/hex.dart';
import 'package:http/testing.dart';
import 'package:web3dart/web3dart.dart';

import 'package:fomowl_wallet/models/chain.dart';
import 'package:fomowl_wallet/models/wallet_account.dart';
import 'package:fomowl_wallet/services/native_crypto.dart';
import 'package:fomowl_wallet/services/secure_store.dart';
import 'package:fomowl_wallet/services/storage_service.dart';
import 'package:fomowl_wallet/services/wallet_service.dart';
import 'package:fomowl_wallet/src/rust/frb_generated.dart';

void main() {
  setUpAll(() async {
    await RustLib.init();
  });

  test(
    'Solana v0 building and signer-slot round trip through the shared core',
    () async {
      final key = Uint8List.fromList(List.filled(32, 7));
      final payer = await NativeCrypto.deriveSolanaAddressFromPrivateKey(key);
      final receiver = WalletService.encodeBase58Bytes(
        Uint8List.fromList(List.filled(32, 8)),
      );
      final blockhash = WalletService.encodeBase58Bytes(
        Uint8List.fromList(List.filled(32, 4)),
      );
      final signed = await NativeCrypto.buildAndSignSolanaTransaction(
        payer: payer,
        recentBlockhash: blockhash,
        instructionsJson: jsonEncode([
          {
            'programId': '11111111111111111111111111111111',
            'data': '020000000100000000000000',
            'keys': [
              {'pubkey': payer, 'isSigner': true, 'isWritable': true},
              {'pubkey': receiver, 'isSigner': false, 'isWritable': true},
            ],
          },
        ]),
        lookupTablesJson: '[]',
        privateKeyBytes: key,
      );
      final bytes = base64Decode(signed);
      expect(bytes[0], 1); // One required signature.
      expect(bytes[65], 0x80); // v0 message after the 64-byte signature.
      final resigned = await NativeCrypto.signSerializedSolanaTransaction(
        serializedTxBase64: signed,
        expectedSigner: payer,
        privateKeyBytes: key,
      );
      expect(resigned, signed);
      final excessSignatures = Uint8List.fromList([
        2,
        ...bytes.sublist(1, 65),
        ...List.filled(64, 0),
        ...bytes.sublist(65),
      ]);
      await expectLater(
        NativeCrypto.signSerializedSolanaTransaction(
          serializedTxBase64: base64Encode(excessSignatures),
          expectedSigner: payer,
          privateKeyBytes: key,
        ),
        throwsA(
          predicate<Object>(
            (error) => error.toString().contains('signature count'),
          ),
        ),
      );
      await expectLater(
        NativeCrypto.buildAndSignSolanaTransaction(
          payer: payer,
          recentBlockhash: blockhash,
          instructionsJson: jsonEncode([
            {
              'programId': '11111111111111111111111111111111',
              'data': '00',
              'keys': [
                {'pubkey': payer, 'isSigner': true, 'isWritable': true},
                {'pubkey': receiver, 'isSigner': true, 'isWritable': false},
              ],
            },
          ]),
          lookupTablesJson: '[]',
          privateKeyBytes: key,
        ),
        throwsA(
          predicate<Object>(
            (error) => error.toString().contains('unavailable signers'),
          ),
        ),
      );
    },
  );

  test('normalizeMnemonic collapses whitespace and lowercases', () {
    final walletService = WalletService();
    final normalized = walletService.normalizeMnemonic(
      '  Abandon   ability\nable\tabout  above absent absorb abstract absurd abuse access accident  ',
    );

    expect(
      normalized,
      'abandon ability able about above absent absorb abstract absurd abuse access accident',
    );
  });

  test('normalizeMnemonic handles numbered and punctuated phrase pastes', () {
    final walletService = WalletService();
    final normalized = walletService.normalizeMnemonic(
      '1. Abandon, 2) abandon; 3: abandon\n4 - abandon 5. abandon '
      '6) abandon 7: abandon 8. abandon 9) abandon 10: abandon '
      '11. abandon 12) about',
    );

    expect(
      normalized,
      'abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon about',
    );
  });

  test(
    'validateMnemonic accepts valid phrases pasted with irregular spacing',
    () async {
      const pasted =
          ' abandon   abandon\nabandon\tabandon abandon abandon abandon abandon abandon abandon abandon about ';

      expect(await WalletService().validateMnemonic(pasted), isTrue);
    },
  );

  group('Solana base58 helpers', () {
    test('decodeBase58Bytes accepts 32-byte seed material', () {
      final bytes = Uint8List.fromList(List<int>.generate(32, (i) => i));
      final encoded = WalletService.encodeBase58Bytes(bytes);

      expect(WalletService.decodeBase58Bytes(encoded), orderedEquals(bytes));
      expect(
        () => WalletService.decodeBase58Signature(encoded),
        throwsFormatException,
      );
    });

    test('decodeBase58Signature still requires a 64-byte signature', () {
      final bytes = Uint8List.fromList(List<int>.generate(64, (i) => i));
      final encoded = WalletService.encodeBase58Bytes(bytes);

      expect(
        WalletService.decodeBase58Signature(encoded),
        orderedEquals(bytes),
      );
    });
  });

  group('importWalletFromPrivateKey validation', () {
    late WalletService walletService;

    setUp(() async {
      TestWidgetsFlutterBinding.ensureInitialized();
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      walletService = WalletService(
        storageService: StorageService(
          secureStore: _InMemorySecureStore(),
          sharedPreferences: prefs,
        ),
      );
    });

    test('rejects key that is too short', () {
      expect(
        () => walletService.importWalletFromPrivateKey('abc123'),
        throwsA(
          isA<Exception>().having(
            (e) => e.toString(),
            'message',
            contains('Invalid private key'),
          ),
        ),
      );
    });

    test('rejects key containing non-hex characters', () {
      // 64 characters but contains 'g' which is not a valid hex character
      const nonHexKey =
          'gggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggg';
      expect(
        () => walletService.importWalletFromPrivateKey(nonHexKey),
        throwsA(
          isA<Exception>().having(
            (e) => e.toString(),
            'message',
            contains('Invalid private key'),
          ),
        ),
      );
    });

    test('rejects key that is too long', () {
      // 66 characters (valid hex but wrong length)
      const longKey =
          'aabbccddeeff00112233445566778899aabbccddeeff00112233445566778899aabb';
      expect(
        () => walletService.importWalletFromPrivateKey(longKey),
        throwsA(
          isA<Exception>().having(
            (e) => e.toString(),
            'message',
            contains('Invalid private key'),
          ),
        ),
      );
    });

    test(
      'accepts a valid 64-character hex key and derives EIP-55 address',
      () async {
        // Hardhat default account #0 — well-known test key, safe to use in tests
        const validKey =
            'ac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80';
        final result = await walletService.importWalletFromPrivateKey(validKey);
        expect(result['address'], isNotEmpty);
        // Ethereum addresses are 42 chars including 0x prefix
        expect(result['address']!.length, 42);
        expect(result['address'], startsWith('0x'));
      },
    );
  });

  group('active family addresses', () {
    late WalletService walletService;
    late StorageService storage;

    setUp(() async {
      TestWidgetsFlutterBinding.ensureInitialized();
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      storage = StorageService(
        secureStore: _InMemorySecureStore(),
        sharedPreferences: prefs,
      );
      walletService = WalletService(storageService: storage);
    });

    test('returns EVM, Solana, and Tron addresses for a seed wallet', () async {
      await storage.saveWallet(
        address: '0x1234567890123456789012345678901234567890',
        privateKey: 'private-key',
        walletName: 'Wallet 1',
        origin: WalletOrigin.derived,
        derivationIndex: 0,
        seedGroupId: 'seed_alpha',
        addressesByFamily: const {
          ChainFamily.solana: 'solanaAddress',
          ChainFamily.tron: 'tronAddress',
        },
      );

      expect(
        await walletService.getActiveAddressForFamily(ChainFamily.evm),
        '0x1234567890123456789012345678901234567890',
      );
      expect(
        await walletService.getActiveAddressForFamily(ChainFamily.solana),
        'solanaAddress',
      );
      expect(
        await walletService.getActiveAddressForFamily(ChainFamily.tron),
        'tronAddress',
      );
    });

    test(
      'returns null for unsupported families on private-key imports',
      () async {
        await storage.saveWallet(
          address: 'solanaAddress',
          privateKey: 'solana-private-key',
          walletName: 'Imported Solana',
          origin: WalletOrigin.imported,
          addressesByFamily: const {ChainFamily.solana: 'solanaAddress'},
        );

        expect(
          await walletService.getActiveAddressForFamily(ChainFamily.solana),
          'solanaAddress',
        );
        expect(
          await walletService.getActiveAddressForFamily(ChainFamily.evm),
          isNull,
        );
        expect(
          await walletService.getActiveAddressForFamily(ChainFamily.tron),
          isNull,
        );
      },
    );
  });

  group('chain-specific private-key export', () {
    const mnemonic =
        'abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon about';

    test(
      'exports distinct EVM, Solana, and Tron keys that reproduce each address',
      () async {
        TestWidgetsFlutterBinding.ensureInitialized();
        SharedPreferences.setMockInitialValues({});
        final prefs = await SharedPreferences.getInstance();
        final storage = StorageService(
          secureStore: _InMemorySecureStore(),
          sharedPreferences: prefs,
        );
        final walletService = WalletService(storageService: storage);

        await walletService.createWalletFromMnemonic(mnemonic);
        final account = await walletService.getActiveWalletAccount();
        expect(account, isNotNull);

        final evmKey = await walletService.exportPrivateKeyForFamily(
          account!,
          ChainFamily.evm,
        );
        final solanaKey = await walletService.exportPrivateKeyForFamily(
          account,
          ChainFamily.solana,
        );
        final tronKey = await walletService.exportPrivateKeyForFamily(
          account,
          ChainFamily.tron,
        );

        expect(evmKey, matches(RegExp(r'^[0-9a-fA-F]{64}$')));
        expect(tronKey, matches(RegExp(r'^[0-9a-fA-F]{64}$')));
        expect(tronKey, isNot(evmKey));
        expect(WalletService.decodeBase58Bytes(solanaKey), hasLength(64));

        SharedPreferences.setMockInitialValues({});
        final importPrefs = await SharedPreferences.getInstance();
        final importedWalletService = WalletService(
          storageService: StorageService(
            secureStore: _InMemorySecureStore(),
            sharedPreferences: importPrefs,
          ),
        );
        final imported = await importedWalletService.importWalletFromSolanaKey(
          solanaKey,
        );
        expect(
          imported['address'],
          account.getWalletAddressForFamily(ChainFamily.solana),
        );
      },
    );

    test('duplicate EVM import cannot replace a seed-backed account', () async {
      TestWidgetsFlutterBinding.ensureInitialized();
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final storage = StorageService(
        secureStore: _InMemorySecureStore(),
        sharedPreferences: prefs,
      );
      final walletService = WalletService(storageService: storage);

      await walletService.createWalletFromMnemonic(mnemonic);
      final original = (await walletService.getActiveWalletAccount())!;
      final evmKey = await walletService.exportPrivateKeyForFamily(
        original,
        ChainFamily.evm,
      );

      await expectLater(
        walletService.importWalletFromPrivateKey(
          evmKey,
          walletName: 'Duplicate import',
        ),
        throwsA(
          isA<Exception>().having(
            (error) => error.toString(),
            'message',
            contains('already in Owllet'),
          ),
        ),
      );

      final accounts = await walletService.getWalletAccounts();
      expect(accounts, hasLength(1));
      expect(accounts.single.origin, WalletOrigin.derived);
      expect(accounts.single.seedGroupId, original.seedGroupId);
      expect(accounts.single.addressesByFamily.keys, {
        ChainFamily.evm,
        ChainFamily.solana,
        ChainFamily.tron,
      });
      expect(await walletService.getCurrentWalletAddress(), original.address);
    });
  });

  group('EVM Transaction Signing (Rust / Alloy)', () {
    for (final typed in [false, true]) {
      test(
        'signs ${typed ? 'EIP-1559' : 'legacy'} creation through nullable FRB destination',
        () async {
          final client = Web3Client(
            'https://rpc.invalid',
            MockClient((_) => throw StateError('Reference must stay offline')),
          );
          addTearDown(client.dispose);
          final gas = BigInt.from(30000000000);
          final priority = BigInt.from(1000000000);
          final expected = await client.signTransaction(
            EthPrivateKey.fromHex('46' * 32),
            Transaction(
              nonce: 0,
              maxGas: 55000,
              value: EtherAmount.zero(),
              data: Uint8List.fromList(HEX.decode('60006000')),
              gasPrice: typed ? null : EtherAmount.inWei(gas),
              maxFeePerGas: typed ? EtherAmount.inWei(gas) : null,
              maxPriorityFeePerGas: typed ? EtherAmount.inWei(priority) : null,
            ),
            chainId: 1,
            fetchChainIdFromNetworkId: false,
          );
          final raw = await NativeCrypto.signEvmTransaction(
            privateKeyHex: '46' * 32,
            chainId: 1,
            nonce: 0,
            gasLimit: 55000,
            valueWei: BigInt.zero,
            dataHex: '0x60006000',
            gasPriceWei: typed ? null : gas,
            maxFeePerGasWei: typed ? gas : null,
            maxPriorityFeePerGasWei: typed ? priority : null,
          );
          expect(raw, '0x${typed ? '02' : ''}${HEX.encode(expected)}');
        },
      );
    }

    test('signs an independent EIP-1559 fixture through FRB', () async {
      final raw = await NativeCrypto.signEvmTransaction(
        privateKeyHex:
            '8f2a55949038a9610f50fb23b5883af3b4ecb3c3bb792cbcefbd1542c692be63',
        chainId: 4,
        nonce: 819,
        gasLimit: 35552,
        toAddress: '0x000000000000000000000000000000000000aaaa',
        valueWei: BigInt.from(43203529),
        maxFeePerGasWei: BigInt.from(121212),
        maxPriorityFeePerGasWei: BigInt.from(75853),
      );
      expect(
        raw,
        '0x02f86e048203338301284d8301d97c828ae094000000000000000000000000000000000000aaaa8402933bc980c080a00f924cb68412c8f1cfd74d9b581c71eeaf94fff6abdde3e5b02ca6b2931dcf47a07dd1c50027c3e31f8b565e25ce68a5072110f61fce5eee81b195dd51273c2f83',
      );
    });

    test('Rust adapter rejects incomplete and mixed fee policies', () async {
      for (final legacyGas in [null, BigInt.one]) {
        await expectLater(
          NativeCrypto.signEvmTransaction(
            privateKeyHex: '46' * 32,
            chainId: 1,
            nonce: 0,
            gasLimit: 21000,
            toAddress: '0x3535353535353535353535353535353535353535',
            valueWei: BigInt.zero,
            gasPriceWei: legacyGas,
            maxFeePerGasWei: BigInt.two,
          ),
          throwsA(anything),
        );
      }
    });

    test('signs official EIP-155 vector via NativeCrypto end-to-end', () async {
      const privateKey =
          '4646464646464646464646464646464646464646464646464646464646464646';
      const toAddress = '0x3535353535353535353535353535353535353535';
      const expectedRawTx =
          '0xf86c098504a817c800825208943535353535353535353535353535353535353535880de0b6b3a76400008025a028ef61340bd939bc2195fe537567866003e1a15d3c71ff63e1590620aa636276a067cbe9d8997f761aecb703304b3800ccf555c9f3dc64214b297fb1966a3b6d83';

      final rawTx = await NativeCrypto.signLegacyEvmTransaction(
        privateKeyHex: privateKey,
        chainId: 1,
        nonce: 9,
        gasPriceWei: BigInt.from(20000000000),
        gasLimit: 21000,
        toAddress: toAddress,
        valueWei: BigInt.parse('1000000000000000000'),
        dataHex: '',
      );

      expect(rawTx, expectedRawTx);
    });

    test(
      'encodes ERC-20 transfer calldata with selector a9059cbb and signs legacy transaction',
      () async {
        const tokenAddress = '0xdAC17F958D2ee523a2206206994597C13D831ec7';
        const recipientAddress = '0x3535353535353535353535353535353535353535';
        final amount = BigInt.parse('1000000');
        const privateKey =
            '4646464646464646464646464646464646464646464646464646464646464646';

        final contract = DeployedContract(
          WalletService.erc20Abi,
          EthereumAddress.fromHex(tokenAddress),
        );
        final transferFunction = contract.function('transfer');
        expect(HEX.encode(transferFunction.selector), 'a9059cbb');

        final data = transferFunction.encodeCall([
          EthereumAddress.fromHex(recipientAddress),
          amount,
        ]);
        final dataHex = '0x${HEX.encode(data)}';

        const expectedDataHex =
            '0xa9059cbb'
            '0000000000000000000000003535353535353535353535353535353535353535'
            '00000000000000000000000000000000000000000000000000000000000f4240';
        expect(dataHex, expectedDataHex);

        final rawTx = await NativeCrypto.signLegacyEvmTransaction(
          privateKeyHex: privateKey,
          chainId: 1,
          nonce: 0,
          gasPriceWei: BigInt.from(20000000000),
          gasLimit: 60000,
          toAddress: tokenAddress,
          valueWei: BigInt.zero,
          dataHex: dataHex,
        );

        // Independent legacy signer, using fixed calldata rather than the
        // encoder output under test. All fields are supplied; RPC is forbidden.
        final referenceClient = Web3Client(
          'https://rpc.invalid',
          MockClient((_) => throw StateError('This test must not use RPC')),
        );
        addTearDown(referenceClient.dispose);
        final referenceBytes = await referenceClient.signTransaction(
          EthPrivateKey.fromHex(privateKey),
          Transaction(
            nonce: 0,
            gasPrice: EtherAmount.inWei(BigInt.from(20000000000)),
            maxGas: 60000,
            to: EthereumAddress.fromHex(tokenAddress),
            value: EtherAmount.zero(),
            data: Uint8List.fromList(HEX.decode(expectedDataHex.substring(2))),
          ),
          chainId: 1,
          fetchChainIdFromNetworkId: false,
        );
        expect(rawTx, '0x${HEX.encode(referenceBytes)}');
      },
    );
  });
}

class _InMemorySecureStore implements SecureStore {
  final Map<String, String> _values = {};

  @override
  Future<void> delete({required String key}) async {
    _values.remove(key);
  }

  @override
  Future<void> deleteAll() async {
    _values.clear();
  }

  @override
  Future<String?> read({required String key}) async {
    return _values[key];
  }

  @override
  Future<void> write({required String key, required String value}) async {
    _values[key] = value;
  }
}
