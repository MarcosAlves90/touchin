{{flutter_js}}
{{flutter_build_config}}

// Firefox currently has a less reliable CanvasKit/WebGL path for this app's
// layered workspace rendering. Prefer correctness over GPU acceleration there.
const isFirefox = navigator.userAgent.includes('Firefox');

_flutter.loader.load({
  config: {
    canvasKitForceCpuOnly: isFirefox,
  },
});
