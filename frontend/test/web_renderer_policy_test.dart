import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('Firefox web startup forces CanvasKit CPU rendering', () {
    final bootstrap = File('web/flutter_bootstrap.js');

    expect(bootstrap.existsSync(), isTrue);

    final source = bootstrap.readAsStringSync();
    expect(source, contains('{{flutter_js}}'));
    expect(source, contains('{{flutter_build_config}}'));
    expect(source, contains("navigator.userAgent.includes('Firefox')"));
    expect(source, contains('canvasKitForceCpuOnly: isFirefox'));
    expect('_flutter.loader.load('.allMatches(source), hasLength(1));
  });
}
