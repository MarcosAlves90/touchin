import 'dart:typed_data';

Future<void> downloadFileBytes({
  required String filename,
  required Uint8List bytes,
}) {
  throw UnsupportedError(
    'O download de arquivos está disponível apenas na versão web.',
  );
}
