import 'dart:io';

import 'package:play_install_referrer/play_install_referrer.dart';

Future<String?> readPlayInstallReferrer() async {
  if (!Platform.isAndroid) return null;
  final details = await PlayInstallReferrer.installReferrer;
  return details.installReferrer;
}
