#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
FRONTEND_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
SDK_DIR="${FLUTTER_HOME:-${HOME:-/tmp}/.cache/flutter-sdk}"
RELEASES_JSON="$SDK_DIR/releases_linux.json"

download_flutter_sdk() {
  mkdir -p "$SDK_DIR"

  curl -fsSL \
    "https://storage.googleapis.com/flutter_infra_release/releases/releases_linux.json" \
    -o "$RELEASES_JSON"

  local archive_url
  archive_url="$(node - "$RELEASES_JSON" <<'NODE'
const fs = require('fs');
const releasesPath = process.argv[2];
const releases = JSON.parse(fs.readFileSync(releasesPath, 'utf8'));
const stableHash = releases.current_release.stable;
const stableRelease = releases.releases.find((release) => release.hash === stableHash);

if (!stableRelease) {
  console.error('Unable to resolve the current Flutter stable release.');
  process.exit(1);
}

process.stdout.write(`https://storage.googleapis.com/flutter_infra_release/releases/${stableRelease.archive}`);
NODE
)"

  local archive_path="$SDK_DIR/flutter.tar.xz"
  local extract_dir
  extract_dir="$(mktemp -d)"
  curl -fsSL "$archive_url" -o "$archive_path"
  tar -xJf "$archive_path" -C "$extract_dir"
  rm -rf "$SDK_DIR"
  mv "$extract_dir/flutter" "$SDK_DIR"
  rm -rf "$extract_dir"
  rm -f "$archive_path" "$RELEASES_JSON"
}

if [[ ! -x "$SDK_DIR/bin/flutter" ]]; then
  download_flutter_sdk
fi

export PATH="$SDK_DIR/bin:$PATH"
git config --global --add safe.directory "$SDK_DIR"
cd "$FRONTEND_DIR"

flutter --version
flutter config --enable-web
flutter pub get

if [[ -n "${VERCEL:-}" && -z "${API_BASE_URL:-}" ]]; then
  echo "API_BASE_URL must be set in the Vercel project environment." >&2
  exit 1
fi

build_args=(build web --release --base-href=/)

if [[ -n "${API_BASE_URL:-}" ]]; then
  build_args+=(--dart-define="API_BASE_URL=${API_BASE_URL}")
fi

if [[ "${TOUCHIN_FRONTEND_DEV_MODE:-}" == "true" ]]; then
  build_args+=(--dart-define=TOUCHIN_FRONTEND_DEV_MODE=true)
fi

flutter "${build_args[@]}"
