import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:touchin_flutter/core/network/api_client.dart';
import 'package:touchin_flutter/dev_preview/preview_build_mode.dart';

export 'preview_build_mode.dart';

enum PreviewData { populated, empty, error }

enum PreviewTiming { instant, delayed, pending }

enum PreviewServer { ready, delayed, unavailable, retrySuccess }

enum PreviewPersona { admin, manager, employee }

class PreviewController extends ChangeNotifier {
  PreviewController() {
    requireDeveloperPreview();
  }

  PreviewData data = PreviewData.populated;
  PreviewTiming timing = PreviewTiming.instant;
  PreviewServer server = PreviewServer.ready;
  PreviewPersona persona = PreviewPersona.admin;
  Duration delay = const Duration(seconds: 2);
  int pageRevision = 0;
  int sessionRevision = 0;
  bool _disposed = false;
  bool _booted = false;
  int _attempts = 0;
  final _requests = <_PreviewRequest>{};

  int get pendingCount => _requests.length;
  bool get isDisposed => _disposed;

  Future<void> bootstrap() async {
    _checkAlive();
    if (_booted) return;
    final revision = sessionRevision;
    _attempts++;
    if (server == PreviewServer.unavailable ||
        (server == PreviewServer.retrySuccess && _attempts == 1)) {
      throw ApiException('[Prévia] Servidor simulado indisponível.',
          statusCode: 503);
    }
    if (server == PreviewServer.delayed) await _wait(delay, boot: true);
    _checkAlive();
    if (revision != sessionRevision) throw _cancelled();
    _booted = true;
  }

  Future<void> beforeRequest() async {
    _checkAlive();
    final selectedData = data;
    if (timing != PreviewTiming.instant) {
      await _wait(timing == PreviewTiming.pending ? null : delay);
    }
    _checkAlive();
    if (selectedData == PreviewData.error) {
      throw ApiException(
          '[Prévia] Erro de dados simulado. Ajuste o cenário e tente novamente.',
          statusCode: 503,
          code: 'preview_error');
    }
  }

  Future<void> _wait(Duration? duration, {bool boot = false}) {
    final request = _PreviewRequest(boot);
    _requests.add(request);
    if (duration != null) {
      request.timer = Timer(duration, () {
        _requests.remove(request);
        request.completer.complete();
      });
    }
    return request.completer.future;
  }

  void _checkAlive() {
    if (_disposed) throw _cancelled();
  }

  ApiException _cancelled() => ApiException('[Prévia] Solicitação cancelada.',
      statusCode: 499, code: 'preview_cancelled');

  void cancelRequests({bool includeBoot = false}) {
    for (final request in _requests.toList()) {
      if (request.boot && !includeBoot) continue;
      _requests.remove(request);
      request.timer?.cancel();
      request.completer.completeError(_cancelled());
    }
  }

  void configure({PreviewData? data, PreviewTiming? timing, Duration? delay}) {
    cancelRequests();
    this.data = data ?? this.data;
    this.timing = timing ?? this.timing;
    this.delay = delay ?? this.delay;
    pageRevision++;
    notifyListeners();
  }

  /// Preserve page fixtures/timing while replaying only the cold-start path.
  void restartServer([PreviewServer? scenario]) {
    cancelRequests(includeBoot: true);
    server = scenario ?? server;
    _attempts = 0;
    _booted = false;
    sessionRevision++;
    notifyListeners();
  }

  void setPersona(PreviewPersona value) {
    persona = value;
    restartServer();
  }

  void reset() {
    data = PreviewData.populated;
    timing = PreviewTiming.instant;
    persona = PreviewPersona.admin;
    delay = const Duration(seconds: 2);
    pageRevision++;
    restartServer(PreviewServer.ready);
  }

  @override
  void dispose() {
    _disposed = true;
    cancelRequests(includeBoot: true);
    super.dispose();
  }
}

class _PreviewRequest {
  _PreviewRequest(this.boot);
  final bool boot;
  final completer = Completer<void>();
  Timer? timer;
}
