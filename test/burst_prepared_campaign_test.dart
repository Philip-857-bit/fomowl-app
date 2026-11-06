import 'package:flutter_test/flutter_test.dart';
import 'package:fomowl_wallet/features/burst/burst_prepared_campaign.dart';
import 'burst_creation_fixture.dart';

void main() {
  const factory = '0x2222222222222222222222222222222222222222';
  test(
    'ERC-1155 deposit review accepts exact inventory and rejects old encoding',
    () {
      final draft = <String, dynamic>{
        'chainId': 56,
        'title': 'NFT drop',
        'assetKind': 'erc1155',
        'assetAddress': testBurstWallet,
        'assetSymbol': 'NFT',
        'assetDecimals': 0,
        'totalAmountBaseUnits': '0',
        'amountPerParticipantBaseUnits': '0',
        'maxParticipants': 3,
        'startTime': 100,
        'endTime': 200,
        'nftAllocations': [
          {'tokenId': '4', 'amount': '2'},
          {'tokenId': '7', 'amount': '1'},
          {'tokenId': '4', 'amount': '1'},
        ],
      };
      final fixture = burstFixture(draft);
      final transactions =
          fixture['transactions'] as List<Map<String, dynamic>>;
      final response = <String, dynamic>{
        'campaign': {
          ...draft,
          'amountPerParticipantBaseUnits': null,
          'id': 'one',
          'campaignId': fixture['campaignId'],
          'platformFeeBaseUnits': '0',
          'gasSponsorshipFeeBaseUnits': '0',
        },
        'joinCode': 'ABC',
        'transactions': transactions,
      };
      BurstPreparedCampaign validate() => BurstPreparedCampaign.parse(
        response,
        draft,
        factoryAddress: factory,
        wallet: testBurstWallet,
        proxyInitCodeHash: testBurstInitHash,
      );
      expect(validate().id, 'one');
      final deposit = transactions.singleWhere(
        (item) => item['operation'] == 'push',
      );
      final current = deposit['calldata'] as String;
      deposit['calldata'] =
          '${current.substring(0, 10)}${'20'.padLeft(64, '0')}${current.substring(10)}';
      expect(validate, throwsFormatException);
    },
  );
  test('verifies fees against native creation value', () {
    final draft = {
      'chainId': 56,
      'title': 'Drop',
      'assetKind': 'native',
      'assetSymbol': 'BNB',
      'assetDecimals': 18,
      'totalAmountBaseUnits': '100',
      'amountPerParticipantBaseUnits': '50',
      'maxParticipants': 2,
      'startTime': 100,
      'endTime': 200,
    };
    final fixture = burstFixture(draft);
    final transactions = fixture['transactions'] as List<Map<String, dynamic>>;
    transactions.single['valueBaseUnits'] = '108';
    final response = {
      'campaign': {
        ...draft,
        'id': 'one',
        'campaignId': fixture['campaignId'],
        'platformFeeBaseUnits': '5',
        'gasSponsorshipFeeBaseUnits': '3',
      },
      'joinCode': 'ABC',
      'transactions': transactions,
    };
    expect(
      BurstPreparedCampaign.parse(
        response,
        draft,
        factoryAddress: factory,
        wallet: testBurstWallet,
      ).platformFee,
      BigInt.from(5),
    );
    (response['campaign'] as Map)['endTime'] = 201;
    expect(
      () => BurstPreparedCampaign.parse(
        response,
        draft,
        factoryAddress: factory,
        wallet: testBurstWallet,
      ),
      throwsFormatException,
    );
    (response['campaign'] as Map)['endTime'] = 200;
    expect(
      () => BurstPreparedCampaign.parse(
        response,
        draft,
        factoryAddress: '0x3333333333333333333333333333333333333333',
        wallet: testBurstWallet,
      ),
      throwsFormatException,
    );
    (response['transactions'] as List).first['valueBaseUnits'] = '109';
    expect(
      () => BurstPreparedCampaign.parse(
        response,
        draft,
        factoryAddress: factory,
        wallet: testBurstWallet,
      ),
      throwsFormatException,
    );
  });

  test('accepts NFT campaigns with no fungible amount per participant', () {
    final draft = {
      'chainId': 56,
      'title': 'Drop',
      'assetKind': 'erc721',
      'assetAddress': '0x1111111111111111111111111111111111111111',
      'assetSymbol': 'NFT',
      'assetDecimals': 0,
      'totalAmountBaseUnits': '0',
      'amountPerParticipantBaseUnits': '0',
      'maxParticipants': 1,
      'nftAllocations': [
        {'tokenId': '1', 'amount': '1'},
      ],
      'startTime': 100,
      'endTime': 200,
    };
    final fixture = burstFixture(draft);
    final transactions = fixture['transactions'] as List<Map<String, dynamic>>;
    transactions.firstWhere(
      (tx) => tx['operation'] == 'create',
    )['valueBaseUnits'] = '8';
    final response = {
      'campaign': {
        ...draft,
        'amountPerParticipantBaseUnits': null,
        'id': 'one',
        'campaignId': fixture['campaignId'],
        'platformFeeBaseUnits': '5',
        'gasSponsorshipFeeBaseUnits': '3',
      },
      'joinCode': 'ABC',
      'transactions': transactions,
    };
    expect(
      BurstPreparedCampaign.parse(
        response,
        draft,
        factoryAddress: factory,
        wallet: testBurstWallet,
        proxyInitCodeHash: testBurstInitHash,
      ).id,
      'one',
    );
    final approval = transactions.firstWhere(
      (tx) => tx['operation'] == 'approve',
    );
    final original = approval['calldata'];
    approval['calldata'] = (original as String).replaceRange(34, 74, '3' * 40);
    expect(
      () => BurstPreparedCampaign.parse(
        response,
        draft,
        factoryAddress: factory,
        wallet: testBurstWallet,
        proxyInitCodeHash: testBurstInitHash,
      ),
      throwsFormatException,
    );
    approval['calldata'] = original;
    transactions.last['calldata'] = '0x9ad88796';
    expect(
      () => BurstPreparedCampaign.parse(
        response,
        draft,
        factoryAddress: factory,
        wallet: testBurstWallet,
        proxyInitCodeHash: testBurstInitHash,
      ),
      throwsFormatException,
    );
  });

  test('ERC1155 deposits aggregate quantities and reject tampering', () {
    final draft = {
      'chainId': 56,
      'title': 'Drop',
      'assetKind': 'erc1155',
      'assetAddress': testBurstWallet,
      'assetSymbol': 'NFT',
      'assetDecimals': 0,
      'totalAmountBaseUnits': '0',
      'amountPerParticipantBaseUnits': '0',
      'maxParticipants': 2,
      'startTime': 100,
      'endTime': 200,
      'nftAllocations': [
        {'tokenId': '5', 'amount': '2'},
        {'tokenId': '5', 'amount': '3'},
      ],
    };
    final fixture = burstFixture(draft);
    final transactions = fixture['transactions'] as List<Map<String, dynamic>>;
    final response = {
      'campaign': {
        ...draft,
        'amountPerParticipantBaseUnits': null,
        'id': 'one',
        'campaignId': fixture['campaignId'],
        'platformFeeBaseUnits': '0',
        'gasSponsorshipFeeBaseUnits': '0',
      },
      'joinCode': 'ABC',
      'transactions': transactions,
    };
    expect(
      BurstPreparedCampaign.parse(
        response,
        draft,
        factoryAddress: factory,
        wallet: testBurstWallet,
        proxyInitCodeHash: testBurstInitHash,
      ).id,
      'one',
    );
    transactions.last['calldata'] = (transactions.last['calldata'] as String)
        .replaceRange(
          (transactions.last['calldata'] as String).length - 1,
          (transactions.last['calldata'] as String).length,
          '6',
        );
    expect(
      () => BurstPreparedCampaign.parse(
        response,
        draft,
        factoryAddress: factory,
        wallet: testBurstWallet,
        proxyInitCodeHash: testBurstInitHash,
      ),
      throwsFormatException,
    );
  });
}
