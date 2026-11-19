import 'dart:io';
import 'package:touchin_flutter/dev_preview/preview_build_mode.dart';

void main() {
  if (developerPreviewAvailable) {
    throw StateError('Preview unexpectedly enabled');
  }
  try {
    requireDeveloperPreview();
  } on UnsupportedError {
    stdout.writeln('PREVIEW_BLOCKED');
    return;
  }
  throw StateError('Preview activation was not rejected');
}
