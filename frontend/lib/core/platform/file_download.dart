import 'dart:typed_data';

import 'file_download_web.dart'
    if (dart.library.io) 'file_download_stub.dart'
    as platform;

/// Triggers a browser download of [bytes] on web and reports unsupported
/// platforms through [UnsupportedError].
Future<void> downloadFileBytes({
  required String filename,
  required Uint8List bytes,
}) {
  return platform.downloadFileBytes(filename: filename, bytes: bytes);
}
