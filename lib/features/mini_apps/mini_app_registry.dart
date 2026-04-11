import '../../config/app_environment.dart';
import 'mini_app_definition.dart';

class OwlletMiniApps {
  OwlletMiniApps._();

  static MiniAppDefinition get cashIn => MiniAppDefinition(
    id: 'cash_in',
    title: 'Cash in',
    description:
        'Hosted Owllet mini app for on-ramp, off-ramp, bills, and future fiat services.',
    launchUrl: AppEnvironment.cashInMiniAppUrl,
    allowedOrigins: AppEnvironment.cashInMiniAppAllowedOrigins,
  );

  static MiniAppDefinition? byId(String id) {
    switch (id.trim().toLowerCase()) {
      case 'cash_in':
      case 'cash-in':
        return cashIn;
      default:
        return null;
    }
  }
}
