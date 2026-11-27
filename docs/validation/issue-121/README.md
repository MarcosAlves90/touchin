# Issue #121 visual validation

## What was inspected

The production `ProjectTasksPage` was rendered in a release Flutter web build
with `listProjects()` held pending by
[`frontend/test/issue121_visual_entrypoint.dart`](../../../frontend/test/issue121_visual_entrypoint.dart).
This exercises the real page and its skeleton loading composition without an
authenticated account or live employee/project data. The harness uses the
light-theme color values from `AppTheme`; it uses Flutter's default Roboto font
because loading the app's Google Fonts in this isolated harness requires a
network font fetch.

The page was opened in a browser and inspected at both viewport sizes. Browser
readback reported a desktop content viewport of **1425 × 960** (requested
1440 × 960) and a mobile content viewport of **375 × 844** (requested
390 × 844). At both sizes the app bar, navigation, page title, summary cards,
and skeleton cards remained within the viewport; no horizontal overflow or
clipped skeleton card was visible. The responsive navigation changed from the
desktop sidebar to the mobile menu.

The recorded desktop/mobile inspection is retained in
[`project-tasks-responsive.webm`](project-tasks-responsive.webm). It is a
short browser recording of the release build, not an emulator or widget-test
image. Reproduce the build from `frontend/` with:

```sh
flutter build web --release --no-wasm-dry-run \
  -t test/issue121_visual_entrypoint.dart \
  --output /tmp/touchin-issue-121-visual-web
python3 -m http.server 8092 --directory /tmp/touchin-issue-121-visual-web
```

Open `http://localhost:8092`, inspect once at a 1440 × 960 browser window and
once at 390 × 844, and verify the viewport readback after browser chrome. The
recording captured 1425 × 960 and 375 × 844 content viewports respectively.

## Limits of this evidence

This validates responsive layout and the loading composition on the production
page in the light palette. It does not independently verify dark-theme colors,
large text scaling, or typography; those remain covered only by the existing
widget tests where applicable.
