import 'package:flutter_test/flutter_test.dart';
import 'package:fomowl_wallet/models/chain.dart';
import 'package:fomowl_wallet/models/wallet_account.dart';

void main() {
  group('WalletAccount family addresses', () {
    test('migrates legacy address into the EVM family map', () {
      final account = WalletAccount.fromJson({
        'address': '0xabc',
        'name': 'Wallet',
        'origin': 'derived',
        'derivationIndex': 0,
        'createdAt': '2026-04-24T00:00:00.000Z',
      });

      expect(account.address, '0xabc');
      expect(account.getWalletAddressForFamily(ChainFamily.evm), '0xabc');
      expect(account.getWalletAddressForFamily(ChainFamily.solana), isNull);
      expect(account.toJson()['addressesByFamily']['evm'], '0xabc');
    });

    test('preserves explicitly stored Solana and TRON addresses', () {
      final account = WalletAccount(
        address: '0xabc',
        name: 'Wallet 1',
        origin: WalletOrigin.derived,
        derivationIndex: 0,
        createdAt: DateTime.utc(2026, 4, 24),
        addressesByFamily: const {
          ChainFamily.solana: 'solanaAddress',
          ChainFamily.tron: 'tronAddress',
        },
      );

      expect(account.getWalletAddressForFamily(ChainFamily.evm), '0xabc');
      expect(
        account.getWalletAddressForFamily(ChainFamily.solana),
        'solanaAddress',
      );
      expect(
        account.getWalletAddressForFamily(ChainFamily.tron),
        'tronAddress',
      );

      final json = account.toJson();
      expect(json['addressesByFamily']['evm'], '0xabc');
      expect(json['addressesByFamily']['solana'], 'solanaAddress');
      expect(json['addressesByFamily']['tron'], 'tronAddress');
    });
  });
}
