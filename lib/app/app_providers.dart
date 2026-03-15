import 'package:provider/provider.dart';
import 'package:provider/single_child_widget.dart';

import '../services/blockchain_service.dart';
import '../services/currency_controller.dart';
import '../services/language_controller.dart';
import '../services/rpc_service.dart';
import '../services/token_price_service.dart';
import '../services/http_client_service.dart';

List<SingleChildWidget> buildAppProviders() {
  return [
    Provider(create: (_) => HttpClientService()),
    ChangeNotifierProvider(create: (_) => RpcService()),
    ChangeNotifierProvider(create: (_) => TokenPriceService()),
    ChangeNotifierProvider(create: (_) => CurrencyController()..init()),
    ChangeNotifierProvider(create: (_) => LanguageController()..init()),
    ChangeNotifierProxyProvider2<
      RpcService,
      TokenPriceService,
      BlockchainService
    >(
      create: (_) => BlockchainService()..init(),
      update: (_, rpc, price, blockchain) =>
          blockchain!..updateDependencies(rpc, price),
    ),
  ];
}
