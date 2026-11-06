import 'package:flutter_test/flutter_test.dart';
import 'package:fomowl_wallet/features/burst/burst_execution_plan.dart';

void main() {
  const wallet = '0x1111111111111111111111111111111111111111';
  const destination = '0x2222222222222222222222222222222222222222';
  final now = DateTime.utc(2026, 11, 2);
  Map<String, dynamic> plan() => {
    'walletAddress': wallet,
    'campaignId': 'campaign',
    'transaction': {
      'reference': 'ref',
      'chainId': 56,
      'operation': 'set_root',
      'toAddress': destination,
      'valueBaseUnits': '0',
      'calldata': '0x7cb6475900',
      'expiresAt': now.add(const Duration(minutes: 5)).toIso8601String(),
    },
  };
  BurstExecutionPlan parse(Map<String, dynamic> value) =>
      BurstExecutionPlan.parse(
        value,
        reference: 'ref',
        wallet: wallet,
        chainId: 56,
        now: now,
      );

  test(
    'matches refreshed transactions only if all approved fields are unchanged',
    () {
      final approved = parse(plan());
      final refreshed = plan();
      expect(approved.sameTransaction(parse(refreshed)), isTrue);
      (refreshed['transaction'] as Map)['valueBaseUnits'] = '1';
      expect(approved.sameTransaction(parse(refreshed)), isFalse);
    },
  );

  test(
    'rejects wrong wallet, wrong chain, unexpected selector, and expiry',
    () {
      final wrongWallet = plan()..['walletAddress'] = destination;
      expect(() => parse(wrongWallet), throwsFormatException);
      final wrongChain = plan();
      (wrongChain['transaction'] as Map)['chainId'] = 1;
      expect(() => parse(wrongChain), throwsFormatException);
      final selector = plan();
      (selector['transaction'] as Map)['calldata'] = '0x095ea7b300';
      expect(() => parse(selector), throwsFormatException);
      final expired = plan();
      (expired['transaction'] as Map)['expiresAt'] = now.toIso8601String();
      expect(() => parse(expired), throwsFormatException);
    },
  );

  test(
    'NFT approval exposes its operator and rejects malformed approval data',
    () {
      final value = plan();
      final transaction = value['transaction'] as Map;
      transaction['operation'] = 'approve';
      transaction['calldata'] = '0xa22cb465${'0' * 24}${'3' * 40}${'0' * 63}1';
      expect(parse(value).approvalDescription, contains('transfer all NFTs'));
      expect(parse(value).approvalDescription, contains('0x${'3' * 40}'));
      transaction['calldata'] = '0xa22cb465${'0' * 128}';
      expect(() => parse(value), throwsFormatException);
    },
  );
}
