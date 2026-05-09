#!/usr/bin/env bash
set -euo pipefail

if [[ $# -lt 1 ]]; then
  echo "usage: scripts/video_to_transparent_gif.sh <input-video> [output-name] [fps] [threshold]" >&2
  exit 2
fi

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
INPUT="$1"
NAME="${2:-$(basename "${INPUT%.*}")}"
FPS="${3:-12}"
THRESHOLD="${4:-42}"
OUT_DIR="$ROOT/assets/local_media/$NAME"
FRAMES="$OUT_DIR/frames"
GIF="$OUT_DIR/${NAME}_transparent.gif"
PYTHON="/Users/titi14gj/.cache/codex-runtimes/codex-primary-runtime/dependencies/python/bin/python3"
TOOL="$ROOT/build/video_to_alpha_frames"

mkdir -p "$OUT_DIR"
rm -rf "$FRAMES"
mkdir -p "$FRAMES"

clang "$ROOT/tools/video_to_alpha_frames.m" \
  -fobjc-arc \
  -fblocks \
  -framework Foundation \
  -framework AVFoundation \
  -framework CoreGraphics \
  -framework CoreMedia \
  -framework ImageIO \
  -lm \
  -o "$TOOL"

"$TOOL" "$INPUT" "$FRAMES" "$FPS" 512 "$THRESHOLD" >/dev/null

"$PYTHON" - "$FRAMES" "$GIF" "$FPS" <<'PY'
import sys
from pathlib import Path
from PIL import Image

frames_dir = Path(sys.argv[1])
out = Path(sys.argv[2])
fps = float(sys.argv[3])
duration = int(round(1000 / fps))

frames = []
for path in sorted(frames_dir.glob("frame_*.png")):
    frame = Image.open(path).convert("RGBA")
    frames.append(frame)

if not frames:
    raise SystemExit("no frames generated")

frames[0].save(
    out,
    save_all=True,
    append_images=frames[1:],
    duration=duration,
    loop=0,
    disposal=2,
    transparency=0,
)
print(out)
PY
