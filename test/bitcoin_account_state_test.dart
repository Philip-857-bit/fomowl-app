import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:fomowl_wallet/models/bitcoin_account_state.dart';
import 'package:fomowl_wallet/models/chain.dart';
import 'package:fomowl_wallet/models/wallet_account.dart';

BitcoinHdAccountMetadata metadata(
  BitcoinPurpose purpose, {
  int index = 0,
  BitcoinProductNetwork network = BitcoinProductNetwork.mainnet,
}) => BitcoinHdAccountMetadata(
  network: network,
  purpose: purpose,
  accountIndex: index,
  masterFingerprint: '73c5da0a',
  accountXpub:
      '${network == BitcoinProductNetwork.mainnet ? 'xpub' : 'tpub'}-public-fixture-${purpose.number}',
);
void main() {
  test('Bitcoin capability does not become a permanent family address', () {
    final wallet = WalletAccount(
      address: '0xabc',
      name: 'Seed wallet',
      origin: WalletOrigin.derived,
      derivationIndex: 0,
      supportsBitcoin: true,
      createdAt: DateTime.utc(2026),
      addressesByFamily: {ChainFamily.bitcoin: 'must-not-be-a-wallet-identity'},
    );
    expect(wallet.supportsBitcoin, isTrue);
    expect(wallet.supportsFamily(ChainFamily.bitcoin), isTrue);
    expect(wallet.getWalletAddressForFamily(ChainFamily.bitcoin), isNull);
    expect(wallet.addressesByFamily.containsKey(ChainFamily.bitcoin), isFalse);
    final restored = WalletAccount.fromJson(wallet.toJson());
    expect(restored.address, '0xabc');
    expect(restored.supportsFamily(ChainFamily.evm), isTrue);
    expect(restored.supportsFamily(ChainFamily.bitcoin), isTrue);
    final imported = WalletAccount(
      address: '0xabc',
      name: 'Private key',
      origin: WalletOrigin.imported,
      supportsBitcoin: true,
      createdAt: DateTime.utc(2026),
    );
    expect(imported.supportsBitcoin, isFalse);
    expect(imported.supportsFamily(ChainFamily.bitcoin), isFalse);
    expect(
      WalletAccount.fromJson({'address': '0xabc'}).supportsBitcoin,
      isFalse,
    );
  });
  test(
    'HD state roundtrips both purposes without a static address or private fields',
    () {
      final state = BitcoinWalletAccountState(
        walletIdentity: '0xabc',
        network: BitcoinProductNetwork.mainnet,
        accountIndex: 0,
        accounts: {
          for (final purpose in BitcoinPurpose.values)
            purpose: BitcoinPurposeAccountState(metadata: metadata(purpose)),
        },
      );
      final encoded = jsonEncode(state.toJson());
      expect(encoded.contains('xprv'), isFalse);
      expect(encoded.contains('privateKey'), isFalse);
      final restored = BitcoinWalletAccountState.fromJson(
        jsonDecode(encoded) as Map<String, dynamic>,
      );
      expect(
        restored.accounts[BitcoinPurpose.bip84]!.metadata,
        state.accounts[BitcoinPurpose.bip84]!.metadata,
      );
      expect(restored.accounts[BitcoinPurpose.bip86]!.nextInternal, 0);
      expect(() => restored.accounts.clear(), throwsUnsupportedError);
      expect(restored.toString().contains('xpub'), isFalse);
    },
  );
  test('receive and change indices cannot move backwards', () {
    final initial = BitcoinPurposeAccountState(
      metadata: metadata(BitcoinPurpose.bip84),
    );
    final advanced = initial.advance(
      lastUsedExternal: 3,
      nextExternal: 4,
      lastUsedInternal: 1,
      nextInternal: 7,
      lastScan: DateTime.utc(2026, 10, 8),
    );
    expect(advanced.nextExternal, 4);
    expect(advanced.nextInternal, 7);
    expect(() => advanced.advance(nextExternal: 3), throwsStateError);
    expect(() => advanced.advance(nextInternal: 6), throwsStateError);
    expect(() => advanced.advance(lastUsedExternal: 2), throwsStateError);
    expect(
      () => advanced.advance(lastScan: DateTime.utc(2026, 10, 7)),
      throwsStateError,
    );
    expect(
      () => BitcoinPurposeAccountState(
        metadata: metadata(BitcoinPurpose.bip84),
        lastUsedExternal: 3,
        nextExternal: 3,
      ),
      throwsFormatException,
    );
  });
  test(
    'network, purpose, index and malformed state errors are bounded and redacted',
    () {
      expect(
        () => BitcoinProductNetwork.fromId('signet'),
        throwsFormatException,
      );
      expect(() => BitcoinPurpose.fromNumber(84.0), throwsFormatException);
      expect(
        () => metadata(BitcoinPurpose.bip84, index: 0x80000000),
        throwsFormatException,
      );
      expect(
        () => BitcoinWalletAccountState(
          walletIdentity: '0xabc',
          network: BitcoinProductNetwork.mainnet,
          accountIndex: 1,
          accounts: {
            BitcoinPurpose.bip84: BitcoinPurposeAccountState(
              metadata: metadata(BitcoinPurpose.bip84),
            ),
          },
        ),
        throwsFormatException,
      );
      final valid = BitcoinPurposeAccountState(
        metadata: metadata(BitcoinPurpose.bip84),
      ).toJson();
      expect(
        () => BitcoinPurposeAccountState.fromJson({
          ...valid,
          'lastScan': 'invalid',
        }),
        throwsFormatException,
      );
      expect(
        () => BitcoinHdAccountMetadata(
          network: BitcoinProductNetwork.mainnet,
          purpose: BitcoinPurpose.bip84,
          accountIndex: 0,
          masterFingerprint: '73c5da0a',
          accountXpub: 'xprv-do-not-log',
        ),
        throwsA(
          isA<FormatException>().having(
            (error) => error.toString(),
            'redacted',
            isNot(contains('xprv-do-not-log')),
          ),
        ),
      );
    },
  );
}
