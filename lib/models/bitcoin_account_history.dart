import 'bitcoin_account_state.dart';
import 'bitcoin_network_data.dart';

class BitcoinAccountHistoryEntry {
  final BitcoinProductNetwork network;
  final BitcoinHistoryTransaction transaction;
  final List<BitcoinHistoryObservation> ownedInputs;
  final List<BitcoinHistoryObservation> ownedOutputs;
  BitcoinAccountHistoryEntry(
    this.network,
    this.transaction,
    Set<String> ownedAddresses,
  ) : ownedInputs = List.unmodifiable(
        transaction.inputs.where(
          (input) => ownedAddresses.contains(input.address),
        ),
      ),
      ownedOutputs = List.unmodifiable(
        transaction.outputs.where(
          (output) => ownedAddresses.contains(output.address),
        ),
      );
  BigInt get deltaSats =>
      ownedOutputs.fold(BigInt.zero, (sum, output) => sum + output.valueSats) -
      ownedInputs.fold(BigInt.zero, (sum, input) => sum + input.valueSats);
  bool get incoming => deltaSats > BigInt.zero;
  bool get confirmed => transaction.confirmations >= 1;
}
