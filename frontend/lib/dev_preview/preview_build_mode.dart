// TouchIn's environment is independent of Flutter's compilation mode.
const developerPreviewAvailable =
    bool.fromEnvironment('TOUCHIN_FRONTEND_DEV_MODE');

void requireDeveloperPreview() {
  if (!developerPreviewAvailable) {
    throw UnsupportedError(
        'Developer preview requires TOUCHIN_FRONTEND_DEV_MODE=true.');
  }
}
