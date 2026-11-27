import 'package:flutter_test/flutter_test.dart';

import 'package:touchin_flutter/core/config/app_config.dart';

void main() {
  test('uses the local API by default; Android release sets its URL at build time', () {
    expect(
      AppConfig.apiBaseUrl,
      'http://localhost:8071/api/v1',
    );
  });
}
