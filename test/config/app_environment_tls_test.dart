import 'package:flutter_test/flutter_test.dart';
import 'package:fomowl_wallet/config/app_environment.dart';

void main() {
  group('resolveBackendCertificatePins', () {
    test('ignores stale pin material unless pinning is explicitly enabled', () {
      expect(
        resolveBackendCertificatePins(
          rawPins: 'stale-primary,stale-backup',
          pinningEnabled: false,
        ),
        isEmpty,
      );
    });

    test('loads configured pins when pinning is explicitly enabled', () {
      expect(
        resolveBackendCertificatePins(
          rawPins: ' primary, backup ',
          pinningEnabled: true,
        ),
        ['primary', 'backup'],
      );
    });
  });
}
