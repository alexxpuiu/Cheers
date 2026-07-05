#!/usr/bin/env bash
set -eu

FLUTTER_VERSION="${FLUTTER_VERSION:-stable}"

if [ ! -d "$HOME/flutter" ]; then
  git clone https://github.com/flutter/flutter.git -b "$FLUTTER_VERSION" --depth 1 "$HOME/flutter"
fi

export PATH="$HOME/flutter/bin:$PATH"

# Friends' Supabase setup reads credentials from a bundled `.env` asset.
# Vercel env vars are written here at build time (never commit real secrets).
{
  [ -n "${SUPABASE_URL:-}" ] && echo "SUPABASE_URL=${SUPABASE_URL}"
  [ -n "${SUPABASE_PUBLISHABLE_KEY:-}" ] && echo "SUPABASE_PUBLISHABLE_KEY=${SUPABASE_PUBLISHABLE_KEY}"
  [ -n "${MAPBOX_ACCESS_TOKEN:-}" ] && echo "MAPBOX_ACCESS_TOKEN=${MAPBOX_ACCESS_TOKEN}"
} > .env

flutter config --enable-web
flutter precache --web
flutter pub get

BUILD_ARGS=(--release)

if [ -n "${MAPBOX_ACCESS_TOKEN:-}" ]; then
  BUILD_ARGS+=(--dart-define=MAPBOX_ACCESS_TOKEN="$MAPBOX_ACCESS_TOKEN")
fi

flutter build web "${BUILD_ARGS[@]}"
