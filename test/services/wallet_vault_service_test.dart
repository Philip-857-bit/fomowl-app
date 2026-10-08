@Tags(['ffi'])
library;

import 'dart:typed_data';
import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:fomowl_wallet/models/chain.dart';
import 'package:fomowl_wallet/services/native_crypto.dart';
import 'package:fomowl_wallet/services/wallet_vault_service.dart';
import 'package:fomowl_wallet/src/rust/frb_generated.dart';

class _Store implements WalletVaultStore {
  final values = <String, String>{};
  bool failWrites = false;
  bool dropWrites = false;
  String slot(ChainFamily family, String address) => '${family.name}:$address';
  @override
  Future<String?> readVaultRecord(ChainFamily family, String address) async =>
      values[slot(family, address)];
  @override
  Future<void> writeVaultRecord(
    ChainFamily family,
    String address,
    String value,
  ) async {
    if (failWrites) throw StateError('Protected storage unavailable');
    if (!dropWrites) values[slot(family, address)] = value;
  }
}

void main() {
  setUp(WalletVaultService.unlock);
  tearDown(() async {
    await WalletVaultService.lockAll();
    WalletVaultService.unlock();
  });
  setUpAll(() async {
    await RustLib.init();
  });
  for (final family in const [
    ChainFamily.evm,
    ChainFamily.solana,
    ChainFamily.tron,
  ]) {
    test(
      '${family.name} migration verifies persistence, keeps identity and never reloads legacy keys',
      () async {
        final secret = '07' * 32;
        final address = switch (family) {
          ChainFamily.bitcoin => throw UnsupportedError(
            'Bitcoin is unavailable for this operation.',
          ),
          ChainFamily.evm => await NativeCrypto.deriveEvmAddressFromPrivateKey(
            secret,
          ),
          ChainFamily.solana =>
            await NativeCrypto.deriveSolanaAddressFromPrivateKey(
              Uint8List.fromList(List.filled(32, 7)),
            ),
          ChainFamily.tron =>
            await NativeCrypto.deriveTronAddressFromPrivateKey(secret),
        };
        final store = _Store();
        final service = WalletVaultService(store);
        var reads = 0;
        var removed = false;
        Future<String?> load() async {
          reads++;
          return secret;
        }

        Future<void> remove() async {
          expect(store.values, isNotEmpty);
          removed = true;
        }

        final signer = await service.open(
          family: family,
          address: address,
          loadLegacyKey: load,
          removeVerifiedLegacyKey: remove,
        );
        expect(await signer.address(), address);
        expect(removed, isTrue);
        expect(reads, 1);
        await WalletVaultService.close(signer);
        final reopened = await WalletVaultService(store).open(
          family: family,
          address: address,
          loadLegacyKey: () => throw StateError('Legacy key was removed'),
          removeVerifiedLegacyKey: remove,
        );
        expect(await reopened.address(), address);
        expect(await service.exportKey(family, address), secret);
        await WalletVaultService.close(reopened);
      },
    );
  }
  for (final dropped in [false, true]) {
    test(
      'failed ${dropped ? 'readback' : 'write'} preserves legacy material',
      () async {
        final secret = '07' * 32;
        final address = await NativeCrypto.deriveEvmAddressFromPrivateKey(
          secret,
        );
        final store = _Store()
          ..failWrites = !dropped
          ..dropWrites = dropped;
        var removed = false;
        await expectLater(
          WalletVaultService(store).open(
            family: ChainFamily.evm,
            address: address,
            loadLegacyKey: () async => secret,
            removeVerifiedLegacyKey: () async {
              removed = true;
            },
          ),
          throwsStateError,
        );
        expect(removed, isFalse);
        expect(store.values, isEmpty);
      },
    );
  }
  test(
    'existing corrupt record fails closed without legacy fallback or cleanup',
    () async {
      final store = _Store();
      final address = await NativeCrypto.deriveEvmAddressFromPrivateKey(
        '07' * 32,
      );
      store.values[store.slot(ChainFamily.evm, address)] = '{}';
      var read = false;
      var removed = false;
      await expectLater(
        WalletVaultService(store).open(
          family: ChainFamily.evm,
          address: address,
          loadLegacyKey: () async {
            read = true;
            return '07' * 32;
          },
          removeVerifiedLegacyKey: () async {
            removed = true;
          },
        ),
        throwsFormatException,
      );
      expect(read, isFalse);
      expect(removed, isFalse);
    },
  );
  test(
    'concurrent migration uses one legacy load and independent signing contexts',
    () async {
      final address = await NativeCrypto.deriveEvmAddressFromPrivateKey(
        '07' * 32,
      );
      final service = WalletVaultService(_Store());
      var reads = 0;
      final accounts = await Future.wait(
        List.generate(
          3,
          (_) => service.open(
            family: ChainFamily.evm,
            address: address,
            loadLegacyKey: () async {
              reads++;
              return '07' * 32;
            },
            removeVerifiedLegacyKey: () async {},
          ),
        ),
      );
      expect(reads, 1);
      await WalletVaultService.close(accounts.first);
      expect(await accounts.last.address(), address);
      for (final account in accounts) {
        await WalletVaultService.close(account);
      }
    },
  );
  test('protected record formatting redacts wrapping material', () {
    final record = WalletVaultRecord('encrypted', Uint8List(32));
    expect(record.toString(), 'WalletVaultRecord(REDACTED)');
    expect(
      WalletVaultRecord.decode(record.encode()).encryptedVault,
      'encrypted',
    );
    record.dispose();
  });

  test(
    'locking while legacy loading is pending cannot return custody or remove recovery material',
    () async {
      final address = await NativeCrypto.deriveEvmAddressFromPrivateKey(
        '07' * 32,
      );
      final loaded = Completer<void>();
      final secret = Completer<String?>();
      var removed = false;
      final account = WalletVaultService(_Store()).open(
        family: ChainFamily.evm,
        address: address,
        loadLegacyKey: () {
          loaded.complete();
          return secret.future;
        },
        removeVerifiedLegacyKey: () async {
          removed = true;
        },
      );
      final rejected = expectLater(account, throwsStateError);
      await loaded.future;
      await WalletVaultService.lockAll();
      secret.complete('07' * 32);
      await rejected;
      expect(removed, isFalse);
      WalletVaultService.unlock();
    },
  );
}
