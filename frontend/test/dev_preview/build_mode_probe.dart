import 'dart:io';
import 'package:touchin_flutter/dev_preview/preview_build_mode.dart';

void main() {
  var allowed = true;
  try {
    requireDeveloperPreview();
  } on UnsupportedError {
    allowed = false;
  }
  if (developerPreviewAvailable != allowed) {
    throw StateError('Preview entry and activation guard disagree');
  }
  stdout.writeln(allowed ? 'PREVIEW_ALLOWED' : 'PREVIEW_BLOCKED');
}
