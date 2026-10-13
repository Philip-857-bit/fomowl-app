import '../../models/bitcoin_account_state.dart';
import '../../models/bitcoin_network_data.dart';
import '../../src/rust/api/bitcoin_account.dart';
import '../../src/rust/api/bitcoin_transaction.dart';
import 'bitcoin_native_crypto.dart';

/// Protected public signing metadata. It is not an authorization or chain proof.
/// Every replacement revalidates the saved plan and signed bytes through Rust.
class BitcoinSavedTransaction {
  final BitcoinTransactionPlanDto plan;
  final SignedBitcoinTransactionDto signed;
  BitcoinSavedTransaction(BitcoinTransactionPlanDto plan, this.signed)
    : plan = BitcoinTransactionPlanDto(
        account: plan.account,
        unsignedTxHex: plan.unsignedTxHex,
        selectedUtxos: List.unmodifiable(plan.selectedUtxos),
        recipients: List.unmodifiable(plan.recipients),
        changeIndex: plan.changeIndex,
        rbf: plan.rbf,
        feeRateSatVb: plan.feeRateSatVb,
        recipientTotalSat: plan.recipientTotalSat,
        changeSat: plan.changeSat,
        feeSat: plan.feeSat,
        estimatedVbytes: plan.estimatedVbytes,
      );

  BitcoinHdAccountMetadata get account =>
      NativeBitcoinCrypto.metadata(plan.account);
  int get outputCount =>
      plan.recipients.length + (plan.changeSat > BigInt.zero ? 1 : 0);
  Map<String, Object?> get planJson => planToJson(plan);
  static Map<String, Object?> planToJson(BitcoinTransactionPlanDto plan) => {
    'account': NativeBitcoinCrypto.metadata(plan.account).toJson(),
    'unsignedTxHex': plan.unsignedTxHex,
    'selectedUtxos': [
      for (final u in plan.selectedUtxos)
        {
          'txid': u.txid,
          'vout': u.vout,
          'valueSat': u.valueSat.toString(),
          'scriptPubkeyHex': u.scriptPubkeyHex,
          'keychain': u.keychain == BitcoinKeychainDto.external_
              ? 'external'
              : 'internal',
          'addressIndex': u.addressIndex,
        },
    ],
    'recipients': [
      for (final r in plan.recipients)
        {'address': r.address, 'amountSat': r.amountSat.toString()},
    ],
    'changeIndex': plan.changeIndex,
    'rbf': plan.rbf,
    'feeRateSatVb': plan.feeRateSatVb.toString(),
    'recipientTotalSat': plan.recipientTotalSat.toString(),
    'changeSat': plan.changeSat.toString(),
    'feeSat': plan.feeSat.toString(),
    'estimatedVbytes': plan.estimatedVbytes.toString(),
  };
  Map<String, Object?> toJson() => {
    'plan': planJson,
    'signed': {
      'rawTransactionHex': signed.rawTransactionHex,
      'txid': signed.txid,
      'wtxid': signed.wtxid,
      'feeSat': signed.feeSat.toString(),
      'vbytes': signed.vbytes.toString(),
    },
  };

  static Map<String, dynamic> _shape(Object? value, List<String> keys) {
    final object = bitcoinJsonObject(value);
    if (object.length != keys.length ||
        !object.keys.toSet().containsAll(keys)) {
      throw const FormatException('Invalid saved Bitcoin transaction');
    }
    return object;
  }

  static BigInt _number(Object? value, {bool money = false}) {
    if (value is! String ||
        value.length > 20 ||
        !RegExp(r'^(0|[1-9][0-9]*)$').hasMatch(value)) {
      throw const FormatException('Invalid saved Bitcoin integer');
    }
    final number = BigInt.parse(value);
    if (number >
        (money ? bitcoinMaxMoneySats : (BigInt.one << 64) - BigInt.one)) {
      throw const FormatException('Invalid saved Bitcoin integer');
    }
    return number;
  }

  static String _hex(Object? value, int maximum) {
    final text = bitcoinJsonString(value, maxLength: maximum);
    if (text.length.isOdd || !RegExp(r'^[0-9a-fA-F]+$').hasMatch(text)) {
      throw const FormatException('Invalid saved Bitcoin transaction hex');
    }
    return text;
  }

  static List<dynamic> _items(Object? value, int maximum) {
    if (value is! List || value.isEmpty || value.length > maximum) {
      throw const FormatException('Invalid saved Bitcoin transaction items');
    }
    return value;
  }

  factory BitcoinSavedTransaction.fromJson(Object? value) {
    final json = _shape(value, ['plan', 'signed']);
    final p = _shape(json['plan'], [
      'account',
      'unsignedTxHex',
      'selectedUtxos',
      'recipients',
      'changeIndex',
      'rbf',
      'feeRateSatVb',
      'recipientTotalSat',
      'changeSat',
      'feeSat',
      'estimatedVbytes',
    ]);
    final s = _shape(json['signed'], [
      'rawTransactionHex',
      'txid',
      'wtxid',
      'feeSat',
      'vbytes',
    ]);
    final metadata = BitcoinHdAccountMetadata.fromJson(
      _shape(p['account'], [
        'network',
        'purpose',
        'accountIndex',
        'masterFingerprint',
        'accountXpub',
      ]),
    );
    final plan = BitcoinTransactionPlanDto(
      account: NativeBitcoinCrypto.accountDto(metadata),
      unsignedTxHex: _hex(p['unsignedTxHex'], 2_000_000),
      selectedUtxos: [
        for (final raw in _items(p['selectedUtxos'], 1000))
          (() {
            final u = _shape(raw, [
              'txid',
              'vout',
              'valueSat',
              'scriptPubkeyHex',
              'keychain',
              'addressIndex',
            ]);
            return BitcoinUtxoDto(
              txid: bitcoinTxid(u['txid']),
              vout: bitcoinJsonInt(u['vout'], maximum: 0xffffffff),
              valueSat: _number(u['valueSat'], money: true),
              scriptPubkeyHex: _hex(u['scriptPubkeyHex'], 128),
              keychain: switch (u['keychain']) {
                'external' => BitcoinKeychainDto.external_,
                'internal' => BitcoinKeychainDto.internal,
                _ => throw const FormatException(
                  'Invalid saved Bitcoin keychain',
                ),
              },
              addressIndex: bitcoinJsonInt(u['addressIndex']),
            );
          })(),
      ],
      recipients: [
        for (final raw in _items(p['recipients'], 10000))
          (() {
            final r = _shape(raw, ['address', 'amountSat']);
            return BitcoinRecipientDto(
              address: bitcoinJsonString(r['address'], maxLength: 100),
              amountSat: _number(r['amountSat'], money: true),
            );
          })(),
      ],
      changeIndex: bitcoinJsonInt(p['changeIndex']),
      rbf: bitcoinJsonBool(p['rbf']),
      feeRateSatVb: _number(p['feeRateSatVb']),
      recipientTotalSat: _number(p['recipientTotalSat'], money: true),
      changeSat: _number(p['changeSat'], money: true),
      feeSat: _number(p['feeSat'], money: true),
      estimatedVbytes: _number(p['estimatedVbytes']),
    );
    final signed = SignedBitcoinTransactionDto(
      rawTransactionHex: _hex(s['rawTransactionHex'], 2_000_000),
      txid: bitcoinTxid(s['txid']),
      wtxid: bitcoinTxid(s['wtxid']),
      feeSat: _number(s['feeSat'], money: true),
      vbytes: _number(s['vbytes']),
    );
    if (signed.feeSat != plan.feeSat ||
        signed.vbytes <= BigInt.zero ||
        signed.vbytes > plan.estimatedVbytes) {
      throw const FormatException('Inconsistent saved Bitcoin transaction');
    }
    return BitcoinSavedTransaction(plan, signed);
  }
  @override
  String toString() => 'BitcoinSavedTransaction';
}
