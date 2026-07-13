import 'package:flutter_test/flutter_test.dart';
import 'package:fomowl_wallet/services/app_release_checker.dart';

void main() {
  group('compareAppVersions', () {
    test('compares ordinary semantic versions', () {
      expect(compareAppVersions('1.6.2', '1.6.1'), greaterThan(0));
      expect(compareAppVersions('1.6.1', '1.6.2'), lessThan(0));
      expect(compareAppVersions('1.6.1', '1.6.1'), 0);
    });

    test('accepts admin-friendly v prefixes', () {
      expect(compareAppVersions('v1.6.2', '1.6.1'), greaterThan(0));
    });

    test('ignores build metadata and prerelease labels', () {
      expect(compareAppVersions('1.6.2+31', '1.6.1+30'), greaterThan(0));
      expect(compareAppVersions('1.6.2-beta', '1.6.2'), 0);
    });

    test('treats missing version components as zero', () {
      expect(compareAppVersions('1.6', '1.6.0'), 0);
      expect(compareAppVersions('2', '1.99.99'), greaterThan(0));
    });
  });
}
