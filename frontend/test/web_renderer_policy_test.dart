import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('web startup uses the Flutter-generated bootstrap', () {
    final bootstrap = File('web/flutter_bootstrap.js');
    final index = File('web/index.html');

    expect(bootstrap.existsSync(), isFalse);
    expect(index.existsSync(), isTrue);
    expect(
      index.readAsStringSync(),
      contains('<script src="flutter_bootstrap.js" async></script>'),
    );
  });
}
