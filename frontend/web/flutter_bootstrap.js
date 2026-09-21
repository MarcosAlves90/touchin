{{flutter_js}}
{{flutter_build_config}}

// Firefox uses CanvasKit's MultiSurfaceRasterizer on this Flutter line. Keep
// the app on one CanvasKit canvas so visual and pointer coordinates share the
// same compositor surface. Other browsers retain Flutter's default settings.
const isFirefox = navigator.userAgent.includes('Firefox');
const rendererConfig = isFirefox
  ? { canvasKitMaximumSurfaces: 1 }
  : {};

_flutter.loader.load({
  config: rendererConfig,
});
