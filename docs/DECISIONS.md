# Deviations from PARKJUKEBOX_BUILD_PLAN.md

One dated line per deviation. Empty until something diverges.

- 2026-07-05: Xcode project at repo root (not nested `ParkJukebox/` subfolder); `Sources/`, `Tests/`, and `ParkJukebox.xcodeproj` are siblings per workspace layout.
- 2026-07-05: Build plan exists at repo root (canonical) and `docs/PARKJUKEBOX_BUILD_PLAN.md` (original import copy).
- 2026-07-05: P0-1 scaffold committed before `build_check.sh` could pass; dev machine has Command Line Tools only — install Xcode 16+ and run `sudo xcode-select -s /Applications/Xcode.app/Contents/Developer` before phase gate.
