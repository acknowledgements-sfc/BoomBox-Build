#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
PROJECT="$ROOT/ParkJukebox.xcodeproj"
SCHEME="ParkJukebox"
DESTINATION="${PKJB_DESTINATION:-platform=iOS Simulator,name=iPhone 17}"

if ! command -v xcodebuild >/dev/null 2>&1; then
  echo "ERROR: xcodebuild not found. Install Xcode 16+ and select it with xcode-select."
  exit 1
fi

if ! xcodebuild -version >/dev/null 2>&1; then
  echo "ERROR: xcodebuild requires full Xcode (not Command Line Tools only)."
  echo "Install Xcode from the App Store, then run:"
  echo "  sudo xcode-select -s /Applications/Xcode.app/Contents/Developer"
  exit 1
fi

cd "$ROOT"

echo "==> Building $SCHEME ($DESTINATION)"
xcodebuild \
  -project "$PROJECT" \
  -scheme "$SCHEME" \
  -destination "$DESTINATION" \
  build

echo ""
echo "==> Testing $SCHEME ($DESTINATION)"
TEST_OUTPUT="$(mktemp)"
trap 'rm -f "$TEST_OUTPUT"' EXIT

set +e
xcodebuild \
  -project "$PROJECT" \
  -scheme "$SCHEME" \
  -destination "$DESTINATION" \
  test \
  2>&1 | tee "$TEST_OUTPUT"
TEST_EXIT=${PIPESTATUS[0]}
set -e

PASSED="$(grep -c "Test case .* passed" "$TEST_OUTPUT" 2>/dev/null || true)"
FAILED="$(grep -c "Test case .* failed" "$TEST_OUTPUT" 2>/dev/null || true)"
PASSED="${PASSED:-0}"
FAILED="${FAILED:-0}"

echo ""
echo "==> Summary"
echo "Build: OK"
echo "Tests: ${PASSED} passed, ${FAILED} failed"

if [[ "$TEST_EXIT" -ne 0 ]]; then
  echo "ERROR: xcodebuild test exited with status $TEST_EXIT"
  exit "$TEST_EXIT"
fi

echo "All checks passed."
