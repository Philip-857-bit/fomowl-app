import 'dart:convert';
import 'dart:io';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

/// Supply the SDK's test font for requested UI fonts, while delegating every
/// other asset to Flutter. Widget tests must not depend on HTTP or device caches.
Future<void> installTestFonts({ByteData? fontBytes}) async {
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  if (fontBytes == null) {
    final configFile = File('.dart_tool/package_config.json');
    final config =
        jsonDecode(await configFile.readAsString()) as Map<String, dynamic>;
    final flutter = (config['packages'] as List)
        .cast<Map<String, dynamic>>()
        .singleWhere((entry) => entry['name'] == 'flutter');
    final flutterPackage = Directory.fromUri(
      configFile.absolute.uri.resolve(flutter['rootUri'] as String),
    );
    final bytes = await File(
      '${flutterPackage.parent.path}/flutter_tools/static/Ahem.ttf',
    ).readAsBytes();
    fontBytes = ByteData.sublistView(bytes);
  }
  const codec = StandardMessageCodec();
  final original = await messenger.delegate.send(
    'flutter/assets',
    ByteData.sublistView(Uint8List.fromList(utf8.encode('AssetManifest.bin'))),
  );
  final manifest = Map<Object?, Object?>.from(
    codec.decodeMessage(original) as Map,
  );
  final fonts = <String>{
    for (final family in ['Outfit', 'Inter', 'RobotoMono'])
      for (final weight in ['Regular', 'Medium', 'SemiBold', 'Bold'])
        'test-fonts/$family-$weight.ttf',
  };
  for (final font in fonts) {
    manifest[font] = <Object?>[
      <String, Object?>{'asset': font},
    ];
  }
  final encodedManifest = codec.encodeMessage(manifest);
  messenger.setMockMessageHandler('flutter/assets', (message) {
    final key = utf8.decode(
      message!.buffer.asUint8List(message.offsetInBytes, message.lengthInBytes),
    );
    if (key == 'AssetManifest.bin') return Future.value(encodedManifest);
    if (fonts.contains(key)) return Future.value(fontBytes);
    return messenger.delegate.send('flutter/assets', message);
  });
  rootBundle.evict('AssetManifest.bin');
}
