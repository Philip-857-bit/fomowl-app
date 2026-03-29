import 'package:flutter_test/flutter_test.dart';
import 'package:fomowl_wallet/features/discover/permissions/dapp_permission_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('DappPermissionService', () {
    late DappPermissionService service;

    setUp(() {
      SharedPreferences.setMockInitialValues({});
      service = DappPermissionService();
    });

    test(
      'grantConnectionApproval persists normalized wallet approval',
      () async {
        await service.grantConnectionApproval(
          'https://app.uniswap.org',
          '0xABCDEF1234567890',
        );

        expect(
          await service.hasConnectionApproval(
            'https://app.uniswap.org',
            '0xabcdef1234567890',
          ),
          isTrue,
        );
        final permissions = await service.loadPermissions();
        expect(permissions, hasLength(1));
        expect(permissions.first.walletAddress, '0xabcdef1234567890');
      },
    );

    test('revokeConnectionApproval removes stored approval', () async {
      await service.grantConnectionApproval('https://app.aave.com', '0xabc');
      await service.revokeConnectionApproval('https://app.aave.com', '0xabc');

      expect(
        await service.hasConnectionApproval('https://app.aave.com', '0xabc'),
        isFalse,
      );
      expect(await service.loadPermissions(), isEmpty);
    });
  });
}
