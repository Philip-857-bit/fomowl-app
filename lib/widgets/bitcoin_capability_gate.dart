import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/chain.dart';
import '../services/blockchain_service.dart';

/// Defers unsupported screen construction, including its legacy network init.
class BitcoinCapabilityGate extends StatelessWidget {
  final String feature;
  final WidgetBuilder builder;
  const BitcoinCapabilityGate({
    super.key,
    required this.feature,
    required this.builder,
  });
  @override
  Widget build(BuildContext context) {
    final family = context.watch<BlockchainService>().activeFamily;
    if (family == ChainFamily.bitcoin) {
      return Scaffold(
        appBar: AppBar(title: Text(feature)),
        body: const Center(
          child: Padding(
            padding: EdgeInsets.all(24),
            child: Text('This feature is not available for Bitcoin yet.'),
          ),
        ),
      );
    }
    return builder(context);
  }
}
