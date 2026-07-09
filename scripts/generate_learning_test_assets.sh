#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
OUT_DIR="$ROOT/Resources/LearningTests"
mkdir -p "$OUT_DIR"

generate_with_ffmpeg() {
  echo "==> Generating lt_click.wav"
  ffmpeg -y -f lavfi -i "sine=frequency=440:duration=0.1" \
    -ar 44100 -ac 1 "$OUT_DIR/lt_click.wav" 2>/dev/null

  echo "==> Generating lt_transfer_5mb.mp3 (~5 MB)"
  ffmpeg -y -f lavfi -i "anullsrc=r=44100:cl=mono" -t 320 \
    -c:a libmp3lame -b:a 128k "$OUT_DIR/lt_transfer_5mb.mp3" 2>/dev/null
}

generate_with_python() {
  echo "==> Generating assets with Python (ffmpeg not found)"
  python3 - "$OUT_DIR" <<'PYEOF'
import math
import struct
import sys
import wave
from pathlib import Path

out = Path(sys.argv[1])
out.mkdir(parents=True, exist_ok=True)

sample_rate = 44100
click_path = out / "lt_click.wav"
frames = int(sample_rate * 0.1)
with wave.open(str(click_path), "w") as wf:
    wf.setnchannels(1)
    wf.setsampwidth(2)
    wf.setframerate(sample_rate)
    for i in range(frames):
        value = int(32767 * 0.8 * math.sin(2 * math.pi * 440 * i / sample_rate))
        wf.writeframes(struct.pack("<h", value))

mp3 = out / "lt_transfer_5mb.mp3"
header = b"ID3\x03\x00\x00\x00\x00\x00\x00"
mp3.write_bytes(header + b"\x00" * (5_000_000 - len(header)))
print(f"Wrote {click_path} ({click_path.stat().st_size} bytes)")
print(f"Wrote {mp3} ({mp3.stat().st_size} bytes)")
PYEOF
}

if command -v ffmpeg >/dev/null 2>&1; then
  generate_with_ffmpeg
else
  generate_with_python
fi

SIZE="$(wc -c < "$OUT_DIR/lt_transfer_5mb.mp3" | tr -d ' ')"
echo "lt_transfer_5mb.mp3 size: ${SIZE} bytes"
echo "Done. Assets in $OUT_DIR"
