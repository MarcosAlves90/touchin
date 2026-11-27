import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
      'Android release keeps the installed package and required permissions',
      () {
    final manifest =
        File('android/app/src/main/AndroidManifest.xml').readAsStringSync();
    final gradle = File('android/app/build.gradle.kts').readAsStringSync();
    final activity = File(
      'android/app/src/main/kotlin/com/bunchin/app/MainActivity.kt',
    ).readAsStringSync();

    expect(gradle, contains('namespace = "com.bunchin.app"'));
    expect(gradle, contains('applicationId = "com.bunchin.app"'));
    expect(gradle, isNot(contains('com.example.bunchin_flutter')));
    expect(manifest, contains('android:label="Bunchin"'));
    expect(
      manifest,
      contains(
          '<uses-permission android:name="android.permission.INTERNET" />'),
    );
    expect(manifest, contains('android.permission.ACCESS_COARSE_LOCATION'));
    expect(manifest, contains('android.permission.ACCESS_FINE_LOCATION'));
    expect(activity, contains('package com.bunchin.app'));
  });
}
