#!/usr/bin/env bash
set -eu

FLUTTER_VERSION="${FLUTTER_VERSION:-stable}"

if [ ! -d "$HOME/flutter" ]; then
  git clone https://github.com/flutter/flutter.git -b "$FLUTTER_VERSION" --depth 1 "$HOME/flutter"
fi

export PATH="$HOME/flutter/bin:$PATH"

# Required Flutter asset (see pubspec.yaml). Values come from Vercel env vars.
: > .env
{
  [ -n "${SUPABASE_URL:-}" ] && echo "SUPABASE_URL=${SUPABASE_URL}"
  [ -n "${SUPABASE_PUBLISHABLE_KEY:-}" ] && echo "SUPABASE_PUBLISHABLE_KEY=${SUPABASE_PUBLISHABLE_KEY}"
  [ -n "${MAPBOX_ACCESS_TOKEN:-}" ] && echo "MAPBOX_ACCESS_TOKEN=${MAPBOX_ACCESS_TOKEN}"
} >> .env

# Web map token (web/token.js is gitignored; generated at build time).
if [ -n "${MAPBOX_ACCESS_TOKEN:-}" ]; then
  printf "window.MAPBOX_ACCESS_TOKEN='%s';\n" "$MAPBOX_ACCESS_TOKEN" > web/token.js
else
  echo "window.MAPBOX_ACCESS_TOKEN='';" > web/token.js
fi

flutter config --enable-web
flutter precache --web
flutter pub get

BUILD_ARGS=(--release)

if [ -n "${MAPBOX_ACCESS_TOKEN:-}" ]; then
  BUILD_ARGS+=(--dart-define=MAPBOX_ACCESS_TOKEN="$MAPBOX_ACCESS_TOKEN")
fi

flutter build web "${BUILD_ARGS[@]}"
