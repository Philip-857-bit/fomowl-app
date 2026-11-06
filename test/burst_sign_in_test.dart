import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:fomowl_wallet/features/mini_apps/burst_sign_in.dart';

const address = '0x1111111111111111111111111111111111111111';
const identity = BurstSignInIdentity(
  address: address,
  networkKey: 'evm:56',
  origin: 'https://burststaging.owlletapp.com',
  profileId: 'account-a',
);
String challenge() =>
    'Owllet Burst wallet connection\nAccount: account-a\nWallet: $address\n'
    'Challenge: 11111111-1111-4111-8111-111111111111\n\n'
    'Link this wallet to your existing Owllet account for Burst. No transaction or gas fee.'
    '\nExpires At: 2100-01-01T00:00:00+00:00';

class SignInFixture {
  final controller = BurstSignInController();
  BurstSignInIdentity current = identity;
  final calls = <String>[];
  Future<bool> Function()? onConfirm;
  Future<bool> Function()? onAuthenticate;
  String signature = 'a' * 130;

  Future<Map<String, dynamic>> run({
    String app = 'burst',
    Map<String, dynamic>? payload,
  }) => controller.sign(
    miniAppId: app,
    payload: payload ?? {'message': challenge(), 'address': address},
    readIdentity: () async => current,
    confirm: (_, _) async {
      calls.add('confirm');
      return onConfirm == null ? true : onConfirm!();
    },
    authenticate: () async {
      calls.add('authenticate');
      return onAuthenticate == null ? true : onAuthenticate!();
    },
    signMessage: (account, message) async {
      calls.add('sign');
      expect(account, address);
      expect(message, payload?['message'] ?? challenge());
      return signature;
    },
  );
}

void main() {
  test(
    'a backend challenge requires confirmation and device authentication before signing',
    () async {
      final fixture = SignInFixture();
      final result = await fixture.run();
      expect(fixture.calls, ['confirm', 'authenticate', 'sign']);
      expect(result, {
        'ok': true,
        'address': address,
        'signature': '0x${'a' * 130}',
      });
    },
  );

  test(
    'other mini apps retain their existing no-wallet-sign-in policy',
    () async {
      for (final app in ['owllet_pay', 'cash_in', 'affiliate', 'unknown']) {
        final fixture = SignInFixture();
        await expectLater(fixture.run(app: app), throwsFormatException);
        expect(fixture.calls, isEmpty);
      }
    },
  );

  test(
    'arbitrary messages, wrong accounts and unknown payload fields never reach signing',
    () async {
      for (final payload in [
        {'message': 'Authorize a transfer', 'address': address},
        {
          'message': challenge(),
          'address': '0x2222222222222222222222222222222222222222',
        },
        {'message': challenge(), 'address': address, 'transaction': '0x1234'},
        {
          'message': challenge().replaceFirst('Challenge:', 'Command:'),
          'address': address,
        },
        {
          'message': challenge().replaceFirst(
            '2100-01-01T00:00:00+00:00',
            'invalid',
          ),
          'address': address,
        },
      ]) {
        final fixture = SignInFixture();
        await expectLater(fixture.run(payload: payload), throwsFormatException);
        expect(fixture.calls, isEmpty);
      }
    },
  );

  test(
    'an expired challenge throws FormatException and is never signed',
    () async {
      final fixture = SignInFixture();
      final expiredChallenge = challenge().replaceFirst(
        '2100-01-01T00:00:00+00:00',
        '2020-01-01T00:00:00+00:00',
      );
      await expectLater(
        fixture.run(payload: {'message': expiredChallenge, 'address': address}),
        throwsFormatException,
      );
      expect(fixture.calls, isEmpty);
    },
  );

  test('a non-EVM wallet cannot sign a Burst login', () async {
    final fixture = SignInFixture()
      ..current = const BurstSignInIdentity(
        address: address,
        networkKey: 'solana:mainnet',
        origin: 'https://burststaging.owlletapp.com',
        profileId: 'account-a',
      );
    await expectLater(fixture.run(), throwsFormatException);
    expect(fixture.calls, isEmpty);
  });

  test(
    'cancellation and failed device authentication never invoke the signer',
    () async {
      final cancelled = SignInFixture()..onConfirm = () async => false;
      await expectLater(cancelled.run(), throwsFormatException);
      expect(cancelled.calls, ['confirm']);
      final denied = SignInFixture()..onAuthenticate = () async => false;
      await expectLater(denied.run(), throwsFormatException);
      expect(denied.calls, ['confirm', 'authenticate']);
    },
  );

  test(
    'wallet, network and origin changes while confirming invalidate the request',
    () async {
      for (final changed in [
        const BurstSignInIdentity(
          address: '0x2222222222222222222222222222222222222222',
          networkKey: 'evm:56',
          origin: 'https://burststaging.owlletapp.com',
          profileId: 'account-a',
        ),
        const BurstSignInIdentity(
          address: address,
          networkKey: 'evm:1',
          origin: 'https://burststaging.owlletapp.com',
          profileId: 'account-a',
        ),
        const BurstSignInIdentity(
          address: address,
          networkKey: 'evm:56',
          origin: 'https://other.example',
          profileId: 'account-a',
        ),
      ]) {
        final fixture = SignInFixture();
        fixture.onConfirm = () async {
          fixture.current = changed;
          return true;
        };
        await expectLater(fixture.run(), throwsStateError);
        expect(fixture.calls, ['confirm']);
      }
    },
  );

  test('identity is rechecked after device authentication', () async {
    final fixture = SignInFixture();
    fixture.onAuthenticate = () async {
      fixture.current = const BurstSignInIdentity(
        address: address,
        networkKey: 'evm:1',
        origin: 'https://burststaging.owlletapp.com',
        profileId: 'account-a',
      );
      return true;
    };
    await expectLater(fixture.run(), throwsStateError);
    expect(fixture.calls, ['confirm', 'authenticate']);
  });

  test(
    'concurrent requests are blocked and cancellation releases the lock',
    () async {
      final confirmation = Completer<bool>();
      final opened = Completer<void>();
      final fixture = SignInFixture()
        ..onConfirm = () {
          opened.complete();
          return confirmation.future;
        };
      final first = fixture.run();
      await opened.future;
      await expectLater(fixture.run(), throwsStateError);
      confirmation.complete(false);
      await expectLater(first, throwsFormatException);
      fixture.onConfirm = () async => true;
      expect((await fixture.run())['ok'], isTrue);
      expect(fixture.calls.where((call) => call == 'sign'), hasLength(1));
    },
  );

  test('invalid signatures are not returned to the mini app', () async {
    final fixture = SignInFixture()..signature = 'invalid';
    await expectLater(fixture.run(), throwsFormatException);
  });

  test(
    'wallet-first sign-in succeeds with empty profileId and signs valid backend challenge',
    () async {
      final fixture = SignInFixture()
        ..current = const BurstSignInIdentity(
          address: address,
          networkKey: 'evm:56',
          origin: 'https://burststaging.owlletapp.com',
          profileId: '',
        );
      final result = await fixture.run(
        payload: {
          'message':
              'Owllet Burst wallet connection\nAccount: generated-wallet-profile-id\nWallet: $address\n'
              'Challenge: 11111111-1111-4111-8111-111111111111\n\n'
              'Link this wallet to your existing Owllet account for Burst. No transaction or gas fee.'
              '\nExpires At: 2100-01-01T00:00:00+00:00',
          'address': address,
        },
      );
      expect(fixture.calls, ['confirm', 'authenticate', 'sign']);
      expect(result['ok'], isTrue);
      expect(result['address'], address);
    },
  );
}
