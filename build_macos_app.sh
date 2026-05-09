#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")" && pwd)"
APP="$ROOT/build/DesktopCatPet.app"
CONTENTS="$APP/Contents"
MACOS="$CONTENTS/MacOS"
RESOURCES="$CONTENTS/Resources"

rm -rf "$APP"
mkdir -p "$MACOS" "$RESOURCES"

clang "$ROOT/macos_app/DesktopCatPet.m" \
  -fobjc-arc \
  -framework Cocoa \
  -framework AVFoundation \
  -framework CoreMedia \
  -framework UniformTypeIdentifiers \
  -o "$MACOS/DesktopCatPet"

cp "$ROOT/macos_app/Info.plist" "$CONTENTS/Info.plist"
mkdir -p "$RESOURCES/Animations"
cp "$ROOT/assets/icons/DesktopCatPet.icns" "$RESOURCES/DesktopCatPet.icns"

echo "$APP"
