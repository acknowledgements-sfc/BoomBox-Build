# Deviations from PARKJUKEBOX_BUILD_PLAN.md

One dated line per deviation. Empty until something diverges.

- 2026-07-05: Xcode project at repo root (not nested `ParkJukebox/` subfolder); `Sources/`, `Tests/`, and `ParkJukebox.xcodeproj` are siblings per workspace layout.
- 2026-07-05: Build plan exists at repo root (canonical) and `docs/PARKJUKEBOX_BUILD_PLAN.md` (original import copy).
- 2026-07-05: P0-1 scaffold committed before `build_check.sh` could pass; dev machine has Command Line Tools only — install Xcode 16+ and run `sudo xcode-select -s /Applications/Xcode.app/Contents/Developer` before phase gate.
- 2026-07-06: `scripts/build_check.sh` extended with bridge Vitest suite (slice-0 infra); Xcode gate unchanged for app phases.
- 2026-07-05: build_check.sh (P0-3) grew an npm/bridge test step alongside the iOS build+test — not in the original P0-3 spec. Harmless, but scope crept in via the bridge/ addition. Left as-is; verified iOS build+test logic is unaffected.
- 2026-07-09: P1-1 learning test harnesses live in main ParkJukebox target behind `#if DEBUG` (not a separate non-shipped app target).

## 2026-07-09 — LT-A/B/C results (P1-1)

Owner: run harnesses on real devices and replace TBD rows below.

LT-A (outputLatency / ioBufferDuration by device):
| Phone | BT device | outputLatency (ms) | ioBufferDuration (ms) |
|---|---|---|---|
| TBD | TBD | TBD | TBD |

LT-B (sendResource throughput, 5MB mp3, phone A -> phone B):
- elapsed: TBD s, throughput: TBD MB/s

LT-C (play(at:) accuracy, N trials):
| Trial | scheduled delta (s) | measured error (ms) |
|---|---|---|
| TBD | 2.0 | TBD |
