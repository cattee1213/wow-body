#!/usr/bin/env bash
# Build Apple Vision hand server into an .app bundle for camera TCC + Godot spawn.
set -euo pipefail
ROOT="$(cd "$(dirname "$0")" && pwd)"
GODOT_ROOT="$(cd "$ROOT/../.." && pwd)"
OUT_APP="$GODOT_ROOT/bin/macos_hand_server.app"
BIN_DIR="$OUT_APP/Contents/MacOS"
RES_DIR="$OUT_APP/Contents"

echo "==> swift build (release)"
cd "$ROOT"
swift build -c release

BUILT="$(swift build -c release --show-bin-path)/macos_hand_server"
mkdir -p "$BIN_DIR"
cp "$BUILT" "$BIN_DIR/macos_hand_server"
cp "$ROOT/Info.plist" "$RES_DIR/Info.plist"
chmod +x "$BIN_DIR/macos_hand_server"

# Ad-hoc sign so macOS will attach a stable TCC identity when possible.
if command -v codesign >/dev/null 2>&1; then
  codesign --force --deep --sign - "$OUT_APP" 2>/dev/null || true
fi

# Bare executable copy (Godot spawn + git-friendly; *.app is often gitignored)
rm -f "$GODOT_ROOT/bin/macos_hand_server"
cp "$BUILT" "$GODOT_ROOT/bin/macos_hand_server"
chmod +x "$GODOT_ROOT/bin/macos_hand_server"

echo "==> built: $OUT_APP"
echo "    also: $GODOT_ROOT/bin/macos_hand_server"
echo "    test: $GODOT_ROOT/bin/macos_hand_server --port 17452"
