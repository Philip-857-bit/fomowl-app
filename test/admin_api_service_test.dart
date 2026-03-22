import 'package:flutter_test/flutter_test.dart';

import 'package:fomowl_wallet/screens/admin/admin_api_service.dart';

void main() {
  test('buildHeaders includes admin secret and optional json content type', () {
    final service = AdminApiService(adminSecret: 'top-secret');

    expect(service.buildHeaders(), {'X-Admin-Secret': 'top-secret'});
    expect(service.buildHeaders(json: true), {
      'X-Admin-Secret': 'top-secret',
      'Content-Type': 'application/json',
    });

    service.dispose();
  });
}
