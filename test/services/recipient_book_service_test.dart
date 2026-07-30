import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:fomowl_wallet/services/recipient_book_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late RecipientBookService service;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    service = RecipientBookService(
      preferences: await SharedPreferences.getInstance(),
    );
  });

  test('records recent recipients per network without duplicates', () async {
    await service.recordRecent(
      networkKey: 'evm:56',
      walletScope: '0xAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA',
      address: '0x1111111111111111111111111111111111111111',
    );
    await service.recordRecent(
      networkKey: 'evm:56',
      walletScope: '0xAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA',
      address: '0x1111111111111111111111111111111111111111',
      label: 'Bybit Address',
    );

    final recipients = await service.recent(
      'evm:56',
      walletScope: '0xaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa',
    );

    expect(recipients, hasLength(1));
    expect(recipients.single.label, 'Bybit Address');
  });

  test('saved recipients remain available in the saved tab', () async {
    await service.save(
      networkKey: 'solana:mainnet',
      walletScope: 'Owner1111111111111111111111111111111111111',
      address: '11111111111111111111111111111111',
      label: 'Solana Vault',
    );

    final recipients = await service.saved(
      'solana:mainnet',
      walletScope: 'Owner1111111111111111111111111111111111111',
    );

    expect(recipients, hasLength(1));
    expect(recipients.single.saved, isTrue);
    expect(recipients.single.label, 'Solana Vault');
  });

  test('does not expose recipients from another wallet', () async {
    await service.recordRecent(
      networkKey: 'evm:56',
      walletScope: '0xaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa',
      address: '0x1111111111111111111111111111111111111111',
      label: 'Wallet A recipient',
    );

    final recipients = await service.recent(
      'evm:56',
      walletScope: '0xbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb',
    );

    expect(recipients, isEmpty);
  });
}
