// Same compile-time boundary as Flutter's kDebugMode, kept Dart-only so the
// product/profile rejection can also be executed in separate compiled probes.
const developerPreviewAvailable = !bool.fromEnvironment('dart.vm.product') &&
    !bool.fromEnvironment('dart.vm.profile');

void requireDeveloperPreview() {
  if (!developerPreviewAvailable) {
    throw UnsupportedError('Developer preview requires a Flutter debug build.');
  }
}
