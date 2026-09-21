import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('Firefox limits CanvasKit to one surface without forcing CPU rendering', () {
    final bootstrap = File('web/flutter_bootstrap.js');
    final index = File('web/index.html');

    expect(bootstrap.existsSync(), isTrue);
    expect(index.existsSync(), isTrue);

    final source = bootstrap.readAsStringSync();
    expect(source, contains('{{flutter_js}}'));
    expect(source, contains('{{flutter_build_config}}'));
    expect(source, contains("navigator.userAgent.includes('Firefox')"));
    expect(source, contains('canvasKitMaximumSurfaces'));
    expect(source, contains('1'));
    expect(source, isNot(contains('canvasKitForceCpuOnly')));
    expect('_flutter.loader.load('.allMatches(source), hasLength(1));
    expect(
      index.readAsStringSync(),
      contains('<script src="flutter_bootstrap.js" async></script>'),
    );
  });
}
