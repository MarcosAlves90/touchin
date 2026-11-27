import 'dart:async';
import 'dart:js_interop';
import 'dart:js_interop_unsafe';
import 'dart:typed_data';

@JS('URL.createObjectURL')
external String _createObjectUrl(JSAny blob);

@JS('URL.revokeObjectURL')
external void _revokeObjectUrl(String url);

@JS('document')
external JSObject get _document;

@JS('Blob')
external JSFunction get _blobConstructor;

Future<void> downloadFileBytes({
  required String filename,
  required Uint8List bytes,
}) async {
  final blob = _blobConstructor.callAsConstructor<JSObject>(
    <JSAny>[bytes.toJS].toJS,
    <String, String>{'type': 'text/csv;charset=utf-8'}.jsify()! as JSObject,
  );
  final url = _createObjectUrl(blob);
  final anchor = _document.callMethod<JSObject>(
    'createElement'.toJS,
    'a'.toJS,
  );
  anchor.setProperty('href'.toJS, url.toJS);
  anchor.setProperty('download'.toJS, filename.toJS);
  anchor.callMethod<JSAny?>('click'.toJS);
  anchor.callMethod<JSAny?>('remove'.toJS);
  unawaited(
    Future<void>.delayed(
      const Duration(seconds: 30),
      () => _revokeObjectUrl(url),
    ),
  );
}
